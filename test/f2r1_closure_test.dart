import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

// =============================================================================
// F2-R1 — Review closure (2026-08-04) counter-example tests
//
// [P1] cache key isolation (installation identity + build + schema version);
// [P1] client hard caps complete (nested-JSON value bytes, total 64 KiB,
//      revision 128, cache byte cap, schema version);
// [supplement] getEffectiveConfig(cancellationToken:) plumbed to transport;
// [P1] analytics failed-requeue keeps original enqueuedAt (TTL not reset).
// =============================================================================

Map<String, Object?> _snapshot({
  int ttl = 300,
  int stale = 3600,
  String action = 'none',
  Map<String, Object?>? configs,
  String revision = 'rev-t',
}) =>
    <String, Object?>{
      'revision': revision,
      'server_time': 1785770000,
      'configs': configs ??
          <String, Object?>{
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
  String token = 'inst-token-1',
  int? appBuild,
}) {
  return NebulaConfigClient(
    options: NebulaOptions(
      appId: 'com.example.a',
      baseUri: Uri.parse('https://api.example.com'),
      environment: NebulaEnvironment.staging,
    ),
    transport: transport,
    proofSigner: RecordingProofSigner(),
    installationToken: () async => token,
    cacheStorage: store,
    appBuild: appBuild,
    retryBaseDelay: const Duration(milliseconds: 5),
  );
}

void main() {
  group('F2-R1 cache key isolation (docs/12 §6)', () {
    test('a different installation never hits the previous cache', () async {
      final store = InMemoryCacheStorage();
      final online = FakeTransport()..enqueue(FakeTransport.ok(_snapshot()));
      await _client(online, store: store, token: 'inst-A').getEffectiveConfig();

      // 新 installation（token 轮换/重装）+ 断网：不得命中 inst-A 的缓存。
      final offline = FakeTransport()
        ..enqueueError(const NebulaHttpException('offline', statusCode: 503))
        ..enqueueError(const NebulaHttpException('offline', statusCode: 503));
      await expectLater(
        _client(offline, store: store, token: 'inst-B').getEffectiveConfig(),
        throwsA(isA<NebulaHttpException>()),
      );
      expect(offline.requests, hasLength(2), reason: '重试后仍未命中旧缓存');
    });

    test('a different build never hits the previous cache', () async {
      final store = InMemoryCacheStorage();
      final online = FakeTransport()..enqueue(FakeTransport.ok(_snapshot()));
      await _client(online, store: store, appBuild: 100).getEffectiveConfig();

      final offline = FakeTransport()
        ..enqueueError(const NebulaTimeoutException('down'))
        ..enqueueError(const NebulaTimeoutException('down'));
      await expectLater(
        _client(offline, store: store, appBuild: 101).getEffectiveConfig(),
        throwsA(isA<NebulaTimeoutException>()),
        reason: 'App 升级后必须重新拉取，不得读取上一 build 的 fresh 缓存',
      );
    });

    test('same identity + build reuses the persisted cache offline', () async {
      final store = InMemoryCacheStorage();
      final online = FakeTransport()..enqueue(FakeTransport.ok(_snapshot()));
      await _client(online, store: store, token: 'inst-A', appBuild: 100)
          .getEffectiveConfig();

      final offline = FakeTransport()
        ..enqueueError(const NebulaHttpException('offline', statusCode: 503));
      final cfg =
          await _client(offline, store: store, token: 'inst-A', appBuild: 100)
              .getEffectiveConfig();
      expect(cfg.revision, 'rev-t');
      expect(offline.requests, isEmpty);
    });
  });

  group('F2-R1 client hard caps complete (docs/12 §8.3)', () {
    test('nested-JSON value exceeding 8 KiB is rejected', () async {
      final transport = FakeTransport()
        ..enqueue(FakeTransport.ok(_snapshot(configs: <String, Object?>{
          'big': <String, Object?>{
            'value': <String, Object?>{
              'payload': 'x' * (9 * 1024), // 嵌套 JSON，总字节 > 8 KiB
            },
            'updated_at': 1785769000,
          },
        })));
      await expectLater(
        _client(transport).getEffectiveConfig(),
        throwsA(isA<NebulaConfigParseException>()),
      );
    });

    test('revision longer than 128 chars is rejected', () async {
      final transport = FakeTransport()
        ..enqueue(FakeTransport.ok(_snapshot(revision: 'r' * 129)));
      await expectLater(
        _client(transport).getEffectiveConfig(),
        throwsA(isA<NebulaConfigParseException>()),
      );
    });

    test('total snapshot > 64 KiB is rejected even when items are small',
        () async {
      // 90 个 1 KiB 的合法单值（每项 < 8 KiB、数量 < 128）→ 总字节超限。
      final configs = <String, Object?>{};
      for (int i = 0; i < 90; i++) {
        configs['k$i'] = <String, Object?>{
          'value': 'v' * 1024,
          'updated_at': 1785769000,
        };
      }
      final transport = FakeTransport()
        ..enqueue(FakeTransport.ok(_snapshot(configs: configs)));
      await expectLater(
        _client(transport).getEffectiveConfig(),
        throwsA(isA<NebulaConfigParseException>()),
      );
    });
  });

  group('F2-R1 cancellationToken plumbed (supplement)', () {
    test('a cancelled token reaches the transport request', () async {
      final token = NebulaCancellationToken()..cancel();
      final transport = FakeTransport()
        ..enqueueHandler((NebulaRequest request) async {
          expect(request.cancellationToken, same(token),
              reason: '公开参数必须真正传入网络请求');
          throw const NebulaCancelledException();
        });
      await expectLater(
        _client(transport).getEffectiveConfig(cancellationToken: token),
        throwsA(isA<NebulaCancelledException>()),
      );
    });
  });

  group('F2-R1 analytics requeue keeps TTL (docs/02 §4)', () {
    test('failed-requeued events still expire on their original enqueuedAt',
        () async {
      DateTime now = DateTime.utc(2026, 1, 1, 12);
      final sender = _RejectingSender();
      final client = NebulaAnalyticsClient(
        consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
        sender: sender,
        maxEventAge: const Duration(hours: 1),
        sendRetries: 0,
        now: () => now,
      );
      await client.track(NebulaAnalyticsEvent(
        name: 'e',
        privacy: NebulaEventPrivacy.anonymous,
        timestamp: now,
      ));
      await client.flush(); // 失败 → 原样回队首
      expect(client.pendingCount, 1);

      // 反复失败 + 推进时钟超过 TTL（原入队时间起算）：事件必须过期丢弃，
      // 且第二次 flush 在发送前剔除（不再尝试发送）。
      now = now.add(const Duration(hours: 2));
      await client.flush();
      expect(client.pendingCount, 0, reason: '重入队不得重置 TTL');
      expect(client.droppedCount, 1);
      expect(sender.calls, 1, reason: '过期事件不得再被发送');
    });
  });
}

/// 永远失败的 sender（记录调用次数）。
final class _RejectingSender implements NebulaAnalyticsSender {
  int calls = 0;

  @override
  Future<bool> send(List<NebulaAnalyticsEvent> batch) async {
    calls++;
    throw const NebulaHttpException('down', statusCode: 503);
  }
}
