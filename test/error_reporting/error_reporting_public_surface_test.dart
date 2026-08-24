import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:nebula_sdk/src/error_reporting/client.dart';
import 'package:test/test.dart';

import 'fakes/error_reporting_fakes.dart';

final class _Auth implements NebulaAuth {
  @override
  String? get accessToken => null;

  @override
  Stream<NebulaSessionEvent> get events =>
      const Stream<NebulaSessionEvent>.empty();

  @override
  NebulaSessionState get state => NebulaSessionState.uninitialized;

  @override
  Future<String> getAccessToken(
          {NebulaCancellationToken? cancellationToken}) async =>
      '';

  @override
  Future<void> login(
    NebulaLoginRequest request, {
    NebulaCancellationToken? cancellationToken,
  }) async {}

  @override
  Future<void> sendEmailCode({
    required String email,
    required NebulaEmailCodePurpose purpose,
    NebulaCancellationToken? cancellationToken,
  }) async {}

  @override
  Future<void> registerEmail({
    required String email,
    required String password,
    required String code,
    NebulaCancellationToken? cancellationToken,
  }) async {}

  @override
  Future<void> resetEmailPassword({
    required String email,
    required String code,
    required String newPassword,
    NebulaCancellationToken? cancellationToken,
  }) async {}

  @override
  Future<SessionTokenPair> refresh(
          {NebulaCancellationToken? cancellationToken}) async =>
      const SessionTokenPair(accessToken: '', refreshToken: '');

  @override
  Future<bool> restoreSession() async => false;

  @override
  Future<void> signOut() async {}
}

final class _Config implements NebulaConfig {
  @override
  String? get revision => null;

  @override
  Future<void> clearCache() async {}

  @override
  Future<NebulaEffectiveConfig> getEffectiveConfig({
    NebulaCancellationToken? cancellationToken,
  }) =>
      Future<NebulaEffectiveConfig>.error(UnimplementedError());
}

final class _Analytics implements NebulaAnalytics {
  @override
  Future<NebulaConsent> get consent async => NebulaConsent.revoked;

  @override
  Future<void> flush() async {}

  @override
  Future<void> setConsent(NebulaConsent consent) async {}

  @override
  Future<void> track(NebulaAnalyticsEvent event) async {}
}

Nebula _nebula({NebulaErrorReporting? errorReporting}) => Nebula(
      options: NebulaOptions(
        appId: 'test-app',
        baseUri: Uri.parse('https://example.invalid'),
        environment: NebulaEnvironment.staging,
      ),
      transport: FakeTransport(),
      auth: _Auth(),
      config: _Config(),
      analytics: _Analytics(),
      errorReporting: errorReporting,
    );

void main() {
  test('public barrel exposes only the frozen capability contract', () {
    final FakeBoundedErrorStore store = FakeBoundedErrorStore();
    final NebulaErrorReporting capability = ErrorReportingClient(
      store: store,
      idGenerator: FixedErrorReportIdGenerator(),
    );
    expect(capability, isA<NebulaErrorReporting>());
  });

  test('Nebula facade remains source-compatible and nullable', () {
    final Nebula withoutCapability = _nebula();
    expect(withoutCapability.errorReporting, isNull);

    final ErrorReportingClient client = ErrorReportingClient(
      store: FakeBoundedErrorStore(),
      idGenerator: FixedErrorReportIdGenerator(),
    );
    final Nebula withCapability = _nebula(errorReporting: client);
    expect(withCapability.errorReporting, same(client));
  });

  test('caught-error surface maps frozen diagnostic facts and request id',
      () async {
    final FakeBoundedErrorStore store = FakeBoundedErrorStore();
    final ErrorReportingClient client = ErrorReportingClient(
      store: store,
      idGenerator: FixedErrorReportIdGenerator('public'),
    );
    final DateTime occurredAt = DateTime.utc(2026, 8, 15, 1, 2, 3);
    final NebulaRequestId requestId = NebulaRequestId.parse('req-public-1');

    await client.reportCaughtError(
      errorType: 'StateError',
      safeMessage: 'safe message',
      stackTrace: StackTrace.fromString('frame-a\nframe-b'),
      occurredAt: occurredAt,
      requestId: requestId,
    );

    final report = store.records.single.report;
    expect(report.reportId, 'public-1');
    expect(report.errorType, 'StateError');
    expect(report.safeMessage, 'safe message');
    expect(report.stack, contains('frame-a'));
    expect(report.occurredAt, occurredAt);
    expect(report.requestId, requestId.value);
  });

  test('public reporting remains fail-soft when persistence fails', () async {
    final FakeBoundedErrorStore store = FakeBoundedErrorStore()
      ..throwOnSave = true;
    final NebulaErrorReporting capability = ErrorReportingClient(
      store: store,
      idGenerator: FixedErrorReportIdGenerator(),
    );

    await expectLater(
      capability.reportCaughtError(
        errorType: 'StateError',
        safeMessage: 'safe',
        stackTrace: StackTrace.fromString('frame'),
      ),
      completes,
    );
  });
}
