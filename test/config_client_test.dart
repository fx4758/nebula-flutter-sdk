import 'dart:convert';
import 'dart:io';

import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

// =============================================================================
// F2-01 — Effective config client (docs/12 §12 + §6 cache semantics)
//
// FakeTransport-driven (F1-05), consuming the frozen FC-02 fixtures
// (test/fixtures/runtime_config/). Proves: wire 1:1 mapping, proof headers,
// TTL fresh window, 304 revalidation, single-flight, stale-if-error,
// security-critical no-stale, kill-switch not cached, offline start via
// CacheStorage persistence, client-side hard caps (§8.3).
// =============================================================================

Map<String, Object?> _fixtureData(String name) {
  final raw =
      File('test/fixtures/runtime_config/$name.json').readAsStringSync();
  final json = jsonDecode(raw) as Map<String, Object?>;
  return (json['data']! as Map).cast<String, Object?>();
}

/// Builds a custom snapshot with the given cache policy / version action.
Map<String, Object?> _snapshot({
  int ttl = 300,
  int stale = 3600,
  String action = 'none',
  bool securityCritical = false,
}) =>
    <String, Object?>{
      'revision': 'rev-t',
      'server_time': 1785770000,
      'configs': <String, Object?>{
        'k': <String, Object?>{'value': 'v', 'updated_at': 1785769000},
      },
      'features': <Object?>[
        <String, Object?>{
          'key': 'f',
          'enabled': true,
          if (securityCritical) 'security_critical': true,
        },
      ],
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
    installationToken: () async => 'inst-token-1',
    cacheStorage: store,
    appBuild: appBuild,
  );
}

void main() {
  group('F2-01 wire mapping (docs/12 §4)', () {
    test('parses the frozen success snapshot 1:1', () async {
      final transport = FakeTransport()
        ..enqueue(FakeTransport.ok(_fixtureData('success_snapshot')));
      final client = _client(transport);

      final cfg = await client.getEffectiveConfig();
      expect(cfg.revision, 'rev-3-1785770000000000000');
      expect(cfg.serverTime.isUtc, isTrue);
      expect(cfg.configs['feature_payment']!.value,
          <String, Object?>{'max_amount': 500000});
      expect(cfg.configs['welcome']!.value, 'hi');
      final paymentV2 = cfg.features.firstWhere((f) => f.key == 'payment_v2');
      expect(paymentV2.enabled, isTrue);
      final nfc = cfg.features.firstWhere((f) => f.key == 'nfc_export');
      expect(nfc.securityCritical, isTrue);
      expect(cfg.versionPolicy.action, NebulaVersionAction.none);
      expect(cfg.cachePolicy.ttlSeconds, 300);
      expect(cfg.cachePolicy.staleIfErrorSeconds, 86400);
      expect(cfg.hasSecurityCritical, isTrue, reason: 'nfc_export is critical');
    });

    test('sends proof headers, endpoint path and X-App-Build', () async {
      final transport = FakeTransport()
        ..enqueue(FakeTransport.ok(_fixtureData('success_snapshot')));
      final client = _client(transport, appBuild: 42);

      await client.getEffectiveConfig();
      final req = transport.requests.single;
      expect(req.method, NebulaHttpMethod.get);
      expect(req.path, '/api/v1/mobile/runtime-config');
      expect(req.headers['X-Installation-Token'], 'inst-token-1');
      expect(req.headers.containsKey('X-Proof-Timestamp'), isTrue);
      expect(req.headers.containsKey('X-Proof-Nonce'), isTrue);
      expect(req.headers.containsKey('X-Device-Proof'), isTrue);
      expect(req.headers['X-App-Build'], '42');
    });

    test('maps the three version-policy fixtures', () async {
      const cases = <String, NebulaVersionAction>{
        'version_policy_forced_upgrade': NebulaVersionAction.forcedUpgrade,
        'version_policy_upgrade': NebulaVersionAction.upgrade,
        'version_policy_none': NebulaVersionAction.none,
      };
      cases.forEach((name, action) async {
        final transport = FakeTransport()
          ..enqueue(FakeTransport.ok(_fixtureData(name)));
        final cfg = await _client(transport).getEffectiveConfig();
        expect(cfg.versionPolicy.action, action, reason: name);
      });
    });

    test('rejects an over-limit snapshot whole (docs/12 §8.3)', () async {
      final transport = FakeTransport()
        ..enqueue(FakeTransport.ok(_fixtureData('over_limit_snapshot')));
      await expectLater(
        _client(transport).getEffectiveConfig(),
        throwsA(isA<NebulaConfigParseException>()),
      );
    });

    test('rejects non-object data as malformed (never retried)', () async {
      final transport = FakeTransport()
        ..enqueue(FakeTransport.ok('not-an-object'));
      await expectLater(
        _client(transport).getEffectiveConfig(),
        throwsA(isA<NebulaConfigParseException>()),
      );
      expect(transport.requests, hasLength(1),
          reason: 'malformed responses are never retried');
    });
  });

  group('F2-01 cache semantics (docs/12 §6)', () {
    test('TTL fresh window serves cache without a second request', () async {
      final transport = FakeTransport()
        ..enqueue(FakeTransport.ok(_fixtureData('success_snapshot')));
      final client = _client(transport);

      final a = await client.getEffectiveConfig();
      final b = await client.getEffectiveConfig();
      expect(a.revision, b.revision);
      expect(transport.requests, hasLength(1));
    });

    test('304 revalidates the cache and extends freshness', () async {
      // ttl=1s：第一次取回后过 1.1s 再取 → 不再新鲜 → 触发 304 重校验。
      final transport = FakeTransport()
        ..enqueue(FakeTransport.ok(_snapshot(ttl: 1, stale: 0)))
        ..enqueueError(
            const NebulaHttpException('not modified', statusCode: 304));
      final client = _client(transport);

      final a = await client.getEffectiveConfig();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final b = await client.getEffectiveConfig(); // 过期 → 304 续期
      expect(b.revision, a.revision);
      expect(transport.requests, hasLength(2));
      // 304 刷新了新鲜度 → 第三次调用命中缓存，不再发请求。
      await client.getEffectiveConfig();
      expect(transport.requests, hasLength(2));
    });

    test('single-flight: 10 concurrent cold calls issue 1 request', () async {
      final transport = FakeTransport()
        ..enqueue(FakeTransport.ok(_fixtureData('success_snapshot')));
      final client = _client(transport);

      final results = await Future.wait(
        List<Future<NebulaEffectiveConfig>>.generate(
            10, (_) => client.getEffectiveConfig()),
      );
      expect(results.map((c) => c.revision).toSet(), hasLength(1));
      expect(transport.requests, hasLength(1));
    });

    test('stale-if-error serves the cached snapshot on network failure',
        () async {
      // 第二次调用：初次超时 → 有界重试 1 次再超时 → 重试耗尽 → stale 兜底。
      final transport = FakeTransport()
        ..enqueue(FakeTransport.ok(_snapshot(ttl: 0, stale: 3600)))
        ..enqueueError(const NebulaTimeoutException('down'))
        ..enqueueError(const NebulaTimeoutException('down'));
      final client = _client(transport);

      final a = await client.getEffectiveConfig();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final b = await client.getEffectiveConfig(); // ttl=0 → stale path
      expect(b.revision, a.revision);
      expect(transport.requests, hasLength(3)); // 1 + (初次 + 1 次重试)
    });

    test('security-critical snapshot is never served stale', () async {
      final transport = FakeTransport()
        ..enqueue(FakeTransport.ok(
            _snapshot(ttl: 0, stale: 3600, action: 'forced_upgrade')))
        ..enqueueError(const NebulaTimeoutException('down'))
        ..enqueueError(const NebulaTimeoutException('down'));
      final client = _client(transport);

      await client.getEffectiveConfig();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await expectLater(
        client.getEffectiveConfig(),
        throwsA(isA<NebulaTimeoutException>()),
      );
    });

    test('kill-switch (12004) surfaces as a classified error, never cached',
        () async {
      final transport = FakeTransport()
        ..enqueueError(const NebulaApiException('disabled', code: 12004));
      final client = _client(transport);

      await expectLater(
        client.getEffectiveConfig(),
        throwsA(
          isA<NebulaApiException>().having((e) => e.code, 'code', 12004),
        ),
      );
      expect(client.revision, isNull,
          reason: 'disabled state must never be cached (docs/12 §6.7)');
    });

    test('offline start: CacheStorage persistence serves the last snapshot',
        () async {
      final store = InMemoryCacheStorage();
      final online = FakeTransport()
        ..enqueue(FakeTransport.ok(_fixtureData('success_snapshot')));
      final a = _client(online, store: store);
      await a.getEffectiveConfig();

      // 全新客户端 + 断网 transport + 同一 store：应在新鲜窗口内离线启动。
      final offline = FakeTransport()
        ..enqueueError(const NebulaHttpException('offline', statusCode: 503));
      final b = _client(offline, store: store);
      final cfg = await b.getEffectiveConfig();
      expect(cfg.revision, 'rev-3-1785770000000000000');
      expect(b.revision, cfg.revision);
      expect(offline.requests, isEmpty, reason: '离线启动不应发网络请求');
    });
  });
}
