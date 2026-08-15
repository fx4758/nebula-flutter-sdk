import 'package:nebula_sdk/src/error_reporting/budget.dart';
import 'package:nebula_sdk/src/error_reporting/normalizer.dart';
import 'package:nebula_sdk/src/error_reporting/report.dart';
import 'package:test/test.dart';

void main() {
  test('diagnostic map contains only frozen client facts', () {
    final NebulaErrorReport report = NebulaErrorReport(
      reportId: 'r1',
      occurredAt: DateTime.parse('2026-08-15T10:00:00+09:00'),
      errorType: 'StateError',
      safeMessage: 'safe',
      stack: 'stack',
      requestId: 'req-1',
      reportedAppVersion: '1.2.3',
      reportedBuildNumber: '42',
    );
    final Map<String, Object?> wire = report.toDiagnosticMap();
    expect(wire.keys.toSet(), <String>{
      'report_id',
      'occurred_at',
      'error_type',
      'safe_message',
      'stack',
      'request_id',
      'reported_app_version',
      'reported_build_number',
    });
    expect(wire, isNot(contains('ingested_at')));
    expect(wire, isNot(contains('app_id')));
    expect(wire, isNot(contains('installation_id')));
    expect(wire, isNot(contains('platform')));
    expect(wire, isNot(contains('user_id')));
    expect(report.occurredAt, DateTime.utc(2026, 8, 15, 1));
  });

  test(
    'normalizer redacts obvious secrets and bounds UTF-8 without splitting',
    () {
      final ErrorReportNormalizer normalizer = ErrorReportNormalizer(
        budget: const ErrorReportingBudget(
          maxSafeMessageBytes: 24,
          maxStackBytes: 30,
          maxReportBytes: 1024,
          maxBytesPerFlush: 1024,
        ),
      );
      final ErrorNormalizationResult result = normalizer.normalize(
        reportId: 'r1',
        input: ErrorReportInput(
          errorType: 'StateError',
          message: 'Bearer abc.def.ghi 密密密密密密密',
          stack: 'password=supersecret stack stack stack',
          occurredAt: DateTime.utc(2026, 8, 15),
        ),
      );
      expect(result.report, isNotNull);
      expect(result.redacted, isTrue);
      expect(result.truncatedFieldCount, greaterThanOrEqualTo(1));
      expect(result.report!.safeMessage, contains('[REDACTED]'));
      expect(result.report!.safeMessage, isNot(contains('abc.def.ghi')));
      expect(result.report!.stack, isNot(contains('supersecret')));
    },
  );

  test(
    'total payload overflow drops deterministically instead of retaining',
    () {
      final ErrorReportNormalizer normalizer = ErrorReportNormalizer(
        budget: const ErrorReportingBudget(
          maxSafeMessageBytes: 100,
          maxStackBytes: 100,
          maxReportBytes: 64,
          maxBytesPerFlush: 64,
        ),
      );
      final ErrorNormalizationResult result = normalizer.normalize(
        reportId: 'report-identity-that-is-long',
        input: ErrorReportInput(
          errorType: 'StateError',
          message: 'm' * 30,
          stack: 's' * 30,
        ),
      );
      expect(result.report, isNull);
      expect(result.droppedForTotalBytes, isTrue);
    },
  );
}
