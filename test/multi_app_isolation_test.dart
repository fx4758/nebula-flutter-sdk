import 'dart:convert';
import 'dart:typed_data';

import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:nebula_sdk/src/analytics/analytics_client.dart';
import 'package:nebula_sdk/src/analytics/consent.dart';
import 'package:nebula_sdk/src/analytics/event.dart';
import 'package:nebula_sdk/src/config/config_client.dart';
import 'package:nebula_sdk/src/error_reporting/budget.dart';
import 'package:nebula_sdk/src/error_reporting/cache_error_report_store.dart';
import 'package:nebula_sdk/src/error_reporting/report.dart';
import 'package:nebula_sdk/src/foundation/options.dart';
import 'package:nebula_sdk/src/storage/cache_storage.dart';
import 'package:nebula_sdk/src/storage/storage_namespace.dart';
import 'package:nebula_sdk/src/testing/fake_transport.dart';
import 'package:test/test.dart';

const NebulaEnvironment _environment = NebulaEnvironment.staging;

Map<String, Object?> _snapshot(String revision, String value) =>
    <String, Object?>{
      'revision': revision,
      'server_time': 1785770000,
      'configs': <String, Object?>{
        'owner': <String, Object?>{
          'value': value,
          'updated_at': 1785769000,
        },
      },
      'features': <Object?>[],
      'version_policy': <String, Object?>{
        'minimum_supported_build': 1,
        'latest_build': 1,
        'action': 'none',
        'message_key': '',
      },
      'cache_policy': <String, Object?>{
        'ttl_seconds': 300,
        'stale_if_error_seconds': 3600,
      },
    };

NebulaConfigClient _configClient({
  required String appId,
  required CacheStorage storage,
  required FakeTransport transport,
}) =>
    NebulaConfigClient(
      options: NebulaOptions(
        appId: appId,
        baseUri: Uri.parse('https://api.example.test'),
        environment: _environment,
      ),
      transport: transport,
      proofSigner: RecordingProofSigner(),
      installationToken: () async => 'shared-installation-token',
      cacheStorage: storage,
      appBuild: 42,
      maxRetries: 0,
    );

NebulaErrorReport _report(String id) => NebulaErrorReport(
      reportId: id,
      occurredAt: DateTime.utc(2026, 8, 25, 12),
      errorType: 'StateError',
      safeMessage: 'safe-$id',
      stack: '#0 isolation',
    );

const ErrorReportingBudget _errorBudget = ErrorReportingBudget(
  maxStoredReports: 10,
  maxReportsPerFlush: 10,
  maxStoredBytes: 32 * 1024,
  maxBytesPerFlush: 32 * 1024,
);

void main() {
  test('secure token namespace isolates App A and App B in one physical store',
      () async {
    final InMemoryTokenStore storage = InMemoryTokenStore();
    final String appA = tokenNamespace(_environment, 'app-a');
    final String appB = tokenNamespace(_environment, 'app-b');

    expect(appA, isNot(appB));
    await storage.write(
      namespace: appA,
      key: tokenKeyInstallation,
      value: 'installation-a',
    );
    await storage.write(
      namespace: appB,
      key: tokenKeyInstallation,
      value: 'installation-b',
    );
    await storage.write(
      namespace: appA,
      key: tokenKeyRefresh,
      value: 'refresh-a',
    );
    await storage.write(
      namespace: appB,
      key: tokenKeyRefresh,
      value: 'refresh-b',
    );

    await storage.clearNamespace(appA);

    expect(
      await storage.read(namespace: appA, key: tokenKeyRefresh),
      isNull,
    );
    expect(
      await storage.read(namespace: appB, key: tokenKeyInstallation),
      'installation-b',
    );
    expect(
      await storage.read(namespace: appB, key: tokenKeyRefresh),
      'refresh-b',
    );
  });

  test('generic App/user namespaces isolate scope and reject scope escape', () {
    final String appA = StorageNamespace.app(_environment, 'app-a').toString();
    final String appB = StorageNamespace.app(_environment, 'app-b').toString();
    final String userA =
        StorageNamespace.user(_environment, 'app-a', 'user-1').toString();
    final String userB =
        StorageNamespace.user(_environment, 'app-b', 'user-1').toString();

    expect(appA, isNot(appB));
    expect(userA, isNot(userB));
    expect(StorageNamespace.app(_environment, 'app-a').key('snapshot'),
        'staging/app-a/snapshot');
    expect(
      () => StorageNamespace.app(_environment, 'app/a'),
      throwsArgumentError,
    );
    expect(
      () => StorageNamespace.user(_environment, 'app-a', 'user\x00escape'),
      throwsArgumentError,
    );
  });

  test('Runtime Config persisted snapshots do not cross App identity',
      () async {
    final InMemoryCacheStorage storage = InMemoryCacheStorage();
    final FakeTransport transportA = FakeTransport()
      ..enqueue(FakeTransport.ok(_snapshot('rev-a', 'A')));
    final FakeTransport transportB = FakeTransport()
      ..enqueue(FakeTransport.ok(_snapshot('rev-b', 'B')));
    final NebulaConfigClient appA = _configClient(
      appId: 'app-a',
      storage: storage,
      transport: transportA,
    );
    final NebulaConfigClient appB = _configClient(
      appId: 'app-b',
      storage: storage,
      transport: transportB,
    );

    expect((await appA.getEffectiveConfig()).revision, 'rev-a');
    expect((await appB.getEffectiveConfig()).revision, 'rev-b');

    await appA.clearCache();

    final FakeTransport offlineB = FakeTransport();
    final NebulaConfigClient restartedB = _configClient(
      appId: 'app-b',
      storage: storage,
      transport: offlineB,
    );
    final configB = await restartedB.getEffectiveConfig();
    expect(configB.revision, 'rev-b');
    expect(configB.configs['owner']!.value, 'B');
    expect(offlineB.requests, isEmpty,
        reason: 'App B must read only its own persisted fresh snapshot');

    final FakeTransport offlineA = FakeTransport();
    final NebulaConfigClient restartedA = _configClient(
      appId: 'app-a',
      storage: storage,
      transport: offlineA,
    );
    await expectLater(restartedA.getEffectiveConfig(), throwsStateError);
    expect(offlineA.requests, hasLength(1),
        reason: 'App A clear must remove A only, not expose App B cache');
  });

  test('Analytics persisted consent and in-memory queue remain App-local',
      () async {
    final InMemoryCacheStorage storage = InMemoryCacheStorage();
    final CacheConsentStore consentA = CacheConsentStore(
      storage: storage,
      environment: _environment,
      appId: 'app-a',
    );
    final CacheConsentStore consentB = CacheConsentStore(
      storage: storage,
      environment: _environment,
      appId: 'app-b',
    );
    await consentA.save(NebulaConsent.granted);

    expect(await consentA.load(), NebulaConsent.granted);
    expect(await consentB.load(), NebulaConsent.revoked);

    final NebulaAnalyticsClient clientA =
        NebulaAnalyticsClient(consentStore: consentA);
    final NebulaAnalyticsClient clientB =
        NebulaAnalyticsClient(consentStore: consentB);
    await clientA.track(NebulaAnalyticsEvent(
      name: 'account_action',
      privacy: NebulaEventPrivacy.identifiable,
      properties: const <String, Object?>{'user_id': 'user-a'},
    ));
    await clientB.track(NebulaAnalyticsEvent(
      name: 'account_action',
      privacy: NebulaEventPrivacy.identifiable,
      properties: const <String, Object?>{'user_id': 'user-b'},
    ));

    expect(clientA.pendingCount, 1);
    expect(clientB.pendingCount, 0,
        reason:
            'App B stays fail-closed and never observes App A consent/queue');
  });

  test('Error Reporting delete and corruption recovery in A preserve B',
      () async {
    final InMemoryCacheStorage storage = InMemoryCacheStorage();
    final CacheErrorReportStore appA = CacheErrorReportStore(
      storage: storage,
      environment: _environment,
      appId: 'app-a',
    );
    final CacheErrorReportStore appB = CacheErrorReportStore(
      storage: storage,
      environment: _environment,
      appId: 'app-b',
    );
    final DateTime now = DateTime.utc(2026, 8, 25, 12);
    await appA.saveBounded(_report('a-1'), budget: _errorBudget, now: now);
    await appB.saveBounded(_report('b-1'), budget: _errorBudget, now: now);

    await appA.deleteById(const <String>['a-1']);
    expect(
      (await appA.readReady(budget: _errorBudget, now: now)).reports,
      isEmpty,
    );
    expect(
      (await appB.readReady(budget: _errorBudget, now: now))
          .reports
          .single
          .report
          .reportId,
      'b-1',
    );

    await storage.write(
      namespace: StorageNamespace.app(_environment, 'app-a').toString(),
      key: 'error_reporting_queue_v1',
      value: Uint8List.fromList(utf8.encode('{bad-json')),
    );
    expect(
      (await appA.readReady(budget: _errorBudget, now: now)).reports,
      isEmpty,
    );
    expect(
      (await appB.readReady(budget: _errorBudget, now: now))
          .reports
          .single
          .report
          .reportId,
      'b-1',
      reason: 'App A corruption recovery must delete only App A queue key',
    );
  });
}
