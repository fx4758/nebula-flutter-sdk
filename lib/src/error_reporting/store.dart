library;

import 'budget.dart';
import 'report.dart';

final class StoredErrorReport {
  const StoredErrorReport({
    required this.report,
    required this.storedAt,
    this.attemptCount = 0,
    this.nextAttemptAt,
  });

  final NebulaErrorReport report;
  final DateTime storedAt;
  final int attemptCount;
  final DateTime? nextAttemptAt;
}

final class ErrorStoreSaveResult {
  const ErrorStoreSaveResult({
    required this.persisted,
    this.evictedCount = 0,
    this.expiredCount = 0,
  });

  final bool persisted;
  final int evictedCount;
  final int expiredCount;
}

final class ErrorStoreReadResult {
  const ErrorStoreReadResult({required this.reports, this.expiredCount = 0});

  final List<StoredErrorReport> reports;
  final int expiredCount;
}

/// Host-injected app-private persistence Port.
///
/// Implementations MUST enforce the supplied count/bytes/age policy atomically
/// for their own storage semantics. The Error Reporting core never logs stored
/// diagnostic values.
abstract interface class ErrorReportStore {
  Future<ErrorStoreSaveResult> saveBounded(
    NebulaErrorReport report, {
    required ErrorReportingBudget budget,
    required DateTime now,
  });

  Future<ErrorStoreReadResult> readReady({
    required ErrorReportingBudget budget,
    required DateTime now,
  });

  Future<void> deleteById(Iterable<String> reportIds);

  Future<void> scheduleRetry(
    Iterable<String> reportIds, {
    required int attemptCount,
    required DateTime nextAttemptAt,
  });
}
