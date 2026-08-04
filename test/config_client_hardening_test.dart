import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

// =============================================================================
// F2-02 — Runtime-config cache hardening (docs/02 §3 + docs/12 §6)
//
// Bounded idempotent GET retry (≤2 attempts, exponential backoff + jitter),
// no retry on rate-limit/business/parse/cancel, clearCache() invalidation,
// stale-after-restart via CacheStorage persistence.
// =============================================================================

Map<String, Object?> _snapshot({
  int ttl = 300,
  int stale = 3600,
  String action = 'none',
}) =>
    <String, Object?>{
      'revision': 'rev-t',
      'server_time': 1785770000,
      'configs': <String, Object?>{
        'k': <String, Object?>{'value': 'v', 'updated_at': 1785769000},
      },
      'features': <Object?>[],
      'version_policy': <String, Object?>{
        'minimum_supported_build': 100,
        'latest_build': 120,
        'action': action,
        'message_key': '',
      },
      'cache_policy': <String, Object?>{
        'ttl_seconds': ttl,
        'stale_if_error_seconds': stale,
      },
    };

NebulaConfigClient _client(
  FakeTransport transport, {
  InMemoryCacheStorage? store,
  int maxRetries = 1,
}) {
  return NebulaConfigClient(
    options: NebulaOptions(
      appId: 'com.example.a',
      baseUri: Uri.parse('https://api.example.com'),
      environment: NebulaEnvironment.staging,
    ),
    transport: transport,
    proofSigner: RecordingProofSigner(),
    installationToken: () async => 'inst-token-1',
    cacheStorage: store,
    maxRetries: maxRetries,
    retryBaseDelay: const Duration(milliseconds: 5),
  );
}

void main() {
  group('F2-02 bounded idempotent retry (docs/02 §3)', () {
    test('transient failure is retried once and succeeds', () async {
      final transport = FakeTransport()
        ..enqueueError(const NebulaTimeoutException('down'))
        ..enqueue(FakeTransport.ok(_snapshot()));
      final client = _client(transport);

      final cfg = await client.getEffectiveConfig();
      expect(cfg.revision, 'rev-t');
      expect(transport.requests, hasLength(2), reason: '1 次重试成功');
    });

    test('retries exhausted then stale fallback serves the cache', () async {
      final transport = FakeTransport()
        ..enqueue(FakeTransport.ok(_snapshot(ttl: 0, stale: 3600)))
        ..enqueueError(const NebulaHttpException('down', statusCode: 503))
        ..enqueueError(const NebulaHttpException('down', statusCode: 503));
      final client = _client(transport);

      final a = await client.getEffectiveConfig();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final b = await client.getEffectiveConfig();
      expect(b.revision, a.revision);
      expect(transport.requests, hasLength(3));
    });

    test('rate-limited (40002) is never retried — no retry storm', () async {
      final transport = FakeTransport()
        ..enqueueError(const NebulaApiException('rl', code: 40002));
      final client = _client(transport);

      await expectLater(
        client.getEffectiveConfig(),
        throwsA(isA<NebulaApiException>()),
      );
      expect(transport.requests, hasLength(1), reason: '限流必须尊重，禁止自动重试');
    });

    test('business code (12001) is never retried', () async {
      final transport = FakeTransport()
        ..enqueueError(const NebulaApiException('inst', code: 12001));
      final client = _client(transport);
      await expectLater(
        client.getEffectiveConfig(),
        throwsA(isA<NebulaApiException>()),
      );
      expect(transport.requests, hasLength(1));
    });

    test('malformed snapshot is never retried', () async {
      final transport = FakeTransport()
        ..enqueue(FakeTransport.ok(<String, Object?>{
          'revision': '',
          'server_time': 1,
          'configs': <String, Object?>{},
          'features': <Object?>[],
          'version_policy': <String, Object?>{
            'minimum_supported_build': 0,
            'latest_build': 0,
            'action': 'bogus',
            'message_key': '',
          },
          'cache_policy': <String, Object?>{
            'ttl_seconds': 0,
            'stale_if_error_seconds': 0
          },
        }));
      await expectLater(
        _client(transport).getEffectiveConfig(),
        throwsA(isA<NebulaConfigParseException>()),
      );
      expect(transport.requests, hasLength(1));
    });

    test('retry does not break single-flight dedup', () async {
      final transport = FakeTransport()
        ..enqueueError(const NebulaTimeoutException('down'))
        ..enqueue(FakeTransport.ok(_snapshot()));
      final client = _client(transport);

      final results = await Future.wait(
        List<Future<NebulaEffectiveConfig>>.generate(
            10, (_) => client.getEffectiveConfig()),
      );
      expect(results.map((c) => c.revision).toSet(), hasLength(1));
      // 10 个并发共享一次 load：1 次失败 + 1 次重试成功 = 2 个请求。
      expect(transport.requests, hasLength(2));
    });
  });

  group('F2-02 cache invalidation and persistence', () {
    test('clearCache discards memory and persisted cache', () async {
      final store = InMemoryCacheStorage();
      final transport = FakeTransport()
        ..enqueue(FakeTransport.ok(_snapshot()))
        ..enqueue(FakeTransport.ok(_snapshot()));
      final client = _client(transport, store: store);

      await client.getEffectiveConfig();
      expect(client.revision, 'rev-t');

      await client.clearCache();
      expect(client.revision, isNull);
      // 持久化条目已删除 → 再取必须重新拉取。
      final cfg = await client.getEffectiveConfig();
      expect(cfg.revision, 'rev-t');
      expect(transport.requests, hasLength(2));
    });

    test('stale-after-restart: persistence serves past-TTL within stale window',
        () async {
      final store = InMemoryCacheStorage();
      final online = FakeTransport()
        ..enqueue(FakeTransport.ok(_snapshot(ttl: 0, stale: 3600)));
      await _client(online, store: store).getEffectiveConfig();

      // 全新客户端 + 断网 transport + 同一 store：ttl=0（过期）但 stale 窗口内
      // 且无安全关键 → 拉取失败后从持久化缓存兜底（离线可用）。
      final offline = FakeTransport()
        ..enqueueError(const NebulaHttpException('offline', statusCode: 503))
        ..enqueueError(const NebulaHttpException('offline', statusCode: 503));
      final b = _client(offline, store: store);
      final cfg = await b.getEffectiveConfig();
      expect(cfg.revision, 'rev-t');
      expect(offline.requests, hasLength(2)); // 初次 + 重试，然后 stale 兜底
    });
  });
}
