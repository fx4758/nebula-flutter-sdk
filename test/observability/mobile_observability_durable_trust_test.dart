import 'package:nebula_sdk/src/auth/proof.dart';
import 'package:nebula_sdk/src/error_reporting/budget.dart';
import 'package:nebula_sdk/src/error_reporting/cache_error_report_store.dart';
import 'package:nebula_sdk/src/error_reporting/client.dart';
import 'package:nebula_sdk/src/error_reporting/mobile_error_report_sender.dart';
import 'package:nebula_sdk/src/error_reporting/report.dart';
import 'package:nebula_sdk/src/error_reporting/report_id.dart';
import 'package:nebula_sdk/src/foundation/errors.dart';
import 'package:nebula_sdk/src/foundation/options.dart';
import 'package:nebula_sdk/src/storage/cache_storage.dart';
import 'package:nebula_sdk/src/testing/fake_transport.dart';
import 'package:nebula_sdk/src/transport.dart';
import 'package:test/test.dart';

final class _FixedId implements ErrorReportIdGenerator {
  @override
  String nextId() => 'report-stable-1';
}

void main() {
  test('12001 preserves durable ID until recovery send and ACK deletion',
      () async {
    DateTime now = DateTime.utc(2026, 8, 17, 3);
    int recoveryCalls = 0;
    String token = 'token-old';
    final InMemoryCacheStorage storage = InMemoryCacheStorage();
    final NebulaOptions options = NebulaOptions(
      appId: 'app-trust',
      baseUri: Uri.parse('https://example.invalid'),
      environment: NebulaEnvironment.staging,
    );
    final FakeTransport transport = FakeTransport()
      ..enqueueError(const NebulaApiException('trust', code: 12001))
      ..enqueueHandler((NebulaRequest request) {
        final Map<String, Object?> body = request.body! as Map<String, Object?>;
        final List<Object?> reports = body['reports']! as List<Object?>;
        final Map<String, Object?> report =
            reports.single! as Map<String, Object?>;
        return NebulaResponse(
          statusCode: 200,
          data: <String, Object?>{
            'accepted': <Object?>[
              <String, Object?>{
                'report_id': report['report_id'],
                'ingested_at': 1786935600,
                'duplicate': false,
              },
            ],
            'rejected': <Object?>[],
            'defer_remaining': false,
            'retry_after_seconds': null,
          },
        );
      });
    final CacheErrorReportStore store = CacheErrorReportStore(
      storage: storage,
      environment: options.environment,
      appId: options.appId,
    );
    final MobileErrorReportSender sender = MobileErrorReportSender(
      options: options,
      transport: transport,
      proofSigner: RecordingProofSigner(),
      installationToken: () async => token,
      recoverInstallationTrust: () async {
        recoveryCalls++;
        token = 'token-new';
        return true;
      },
      now: () => now,
      rateLimitCooldown: const Duration(seconds: 3),
    );
    final ErrorReportingClient client = ErrorReportingClient(
      store: store,
      sender: sender,
      idGenerator: _FixedId(),
      now: () => now,
    );

    final ErrorCaptureResult captured = await client.capture(
      ErrorReportInput(
        errorType: 'StateError',
        message: 'safe',
        stack: '#0 main',
        occurredAt: DateTime.utc(2026, 8, 17, 2, 59),
      ),
    );
    expect(captured.reportId, 'report-stable-1');

    await client.flush();
    expect(transport.requests, hasLength(1));
    expect(recoveryCalls, 0);

    final CacheErrorReportStore restartedBeforeRecovery = CacheErrorReportStore(
      storage: storage,
      environment: options.environment,
      appId: options.appId,
    );
    final beforeRecovery = await restartedBeforeRecovery.readReady(
      budget: const ErrorReportingBudget(),
      now: now,
    );
    expect(beforeRecovery.reports, hasLength(1));
    expect(beforeRecovery.reports.single.report.reportId, 'report-stable-1');
    expect(
      beforeRecovery.reports.single.report.occurredAt,
      DateTime.utc(2026, 8, 17, 2, 59),
    );

    now = now.add(const Duration(seconds: 4));
    await client.flush();
    expect(recoveryCalls, 1);
    expect(transport.requests, hasLength(2));
    final firstBody = transport.requests.first.body! as Map<String, Object?>;
    final secondBody = transport.requests.last.body! as Map<String, Object?>;
    final firstReport = (firstBody['reports']! as List<Object?>).single!
        as Map<String, Object?>;
    final secondReport = (secondBody['reports']! as List<Object?>).single!
        as Map<String, Object?>;
    expect(firstReport['report_id'], 'report-stable-1');
    expect(secondReport['report_id'], firstReport['report_id']);

    final afterAck = await CacheErrorReportStore(
      storage: storage,
      environment: options.environment,
      appId: options.appId,
    ).readReady(
      budget: const ErrorReportingBudget(),
      now: now,
    );
    expect(afterAck.reports, isEmpty);
  });
}
