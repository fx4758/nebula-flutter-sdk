import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

// =============================================================================
// F2-03 — Analytics consent + event schema (docs/02 §4 privacy)
//
// Fail-closed consent, identifiable-event gating, revoke-purge + persistence,
// consent stores, event validation.
// =============================================================================

NebulaAnalyticsEvent _anon(String name) => NebulaAnalyticsEvent(
      name: name,
      privacy: NebulaEventPrivacy.anonymous,
    );

NebulaAnalyticsEvent _pii(String name) => NebulaAnalyticsEvent(
      name: name,
      privacy: NebulaEventPrivacy.identifiable,
      properties: <String, Object?>{'user_id': 'u-1'},
    );

void main() {
  group('F2-03 consent default (fail-closed, docs/02 §4)', () {
    test('default consent is revoked without any grant', () async {
      final client = NebulaAnalyticsClient(
        consentStore: InMemoryConsentStore(),
      );
      expect(await client.consent, NebulaConsent.revoked);
    });

    test('identifiable events are dropped while consent is revoked', () async {
      final client = NebulaAnalyticsClient(
        consentStore: InMemoryConsentStore(),
      );
      await client.track(_pii('purchase'));
      expect(client.pendingCount, 0, reason: '未同意时绝不收集/持久化可识别事件');
      // 匿名事件不受限。
      await client.track(_anon('screen_view'));
      expect(client.pendingCount, 1);
    });
  });

  group('F2-03 grant then revoke', () {
    test('grant accepts identifiable events; revoke purges them', () async {
      final client = NebulaAnalyticsClient(
        consentStore: InMemoryConsentStore(),
      );
      await client.setConsent(NebulaConsent.granted);
      await client.track(_pii('purchase'));
      await client.track(_anon('screen_view'));
      expect(client.pendingCount, 2);

      await client.setConsent(NebulaConsent.revoked);
      expect(client.pendingCount, 1, reason: '撤回同意后清理未发送的可识别事件');
      expect(client.pending.single.privacy, NebulaEventPrivacy.anonymous);
      expect(await client.consent, NebulaConsent.revoked);
    });

    test('consent persists across a new client (CacheConsentStore)', () async {
      final store = CacheConsentStore(
        storage: InMemoryCacheStorage(),
        environment: NebulaEnvironment.staging,
        appId: 'com.example.a',
      );
      final a = NebulaAnalyticsClient(consentStore: store);
      await a.setConsent(NebulaConsent.granted);

      // 新客户端实例 + 同一存储：同意状态跨启动保持。
      final b = NebulaAnalyticsClient(consentStore: store);
      expect(await b.consent, NebulaConsent.granted);
      await b.track(_pii('purchase'));
      expect(b.pendingCount, 1);
    });

    test('CacheConsentStore defaults to revoked when absent', () async {
      final store = CacheConsentStore(
        storage: InMemoryCacheStorage(),
        environment: NebulaEnvironment.production,
        appId: 'com.example.b',
      );
      expect(await store.load(), NebulaConsent.revoked);
    });

    test('consent is namespace-scoped per environment/App', () async {
      final storage = InMemoryCacheStorage();
      final storeA = CacheConsentStore(
        storage: storage,
        environment: NebulaEnvironment.staging,
        appId: 'com.example.a',
      );
      final storeB = CacheConsentStore(
        storage: storage,
        environment: NebulaEnvironment.production,
        appId: 'com.example.a',
      );
      await storeA.save(NebulaConsent.granted);
      expect(await storeA.load(), NebulaConsent.granted);
      expect(await storeB.load(), NebulaConsent.revoked,
          reason: '跨环境不得复用同意状态（docs/02 §2）');
    });
  });

  group('F2-03 event schema validation', () {
    test('empty / oversized names are rejected', () {
      expect(
        () => NebulaAnalyticsEvent(
            name: '  ', privacy: NebulaEventPrivacy.anonymous),
        throwsArgumentError,
      );
      expect(
        () => NebulaAnalyticsEvent(
            name: 'x' * 129, privacy: NebulaEventPrivacy.anonymous),
        throwsArgumentError,
      );
    });

    test('non-JSON-serializable properties are rejected', () {
      expect(
        () => NebulaAnalyticsEvent(
          name: 'bad',
          privacy: NebulaEventPrivacy.anonymous,
          properties: <String, Object?>{'obj': Object()},
        ),
        throwsArgumentError,
      );
    });

    test('oversized event (>8 KiB) is rejected', () {
      expect(
        () => NebulaAnalyticsEvent(
          name: 'big',
          privacy: NebulaEventPrivacy.anonymous,
          properties: <String, Object?>{'payload': 'x' * (9 * 1024)},
        ),
        throwsArgumentError,
      );
    });

    test('timestamp defaults to now UTC and is wire-serializable', () {
      final event = _anon('screen_view');
      expect(event.timestamp.isUtc, isTrue);
      final wire = event.toJson();
      expect(wire['name'], 'screen_view');
      expect(wire['identifiable'], isFalse);
      expect(wire['timestamp'] is int, isTrue);
      expect(event.estimatedBytes, greaterThan(0));
    });
  });

  group('F2-03 flush contract', () {
    test('flush is a documented no-op until F2-04 wires transport', () async {
      final client = NebulaAnalyticsClient(
        consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
      );
      await client.track(_anon('x'));
      await client.flush(); // 不抛、不吞事件（F2-04 前无发送管线）
      expect(client.pendingCount, 1);
    });
  });
}
