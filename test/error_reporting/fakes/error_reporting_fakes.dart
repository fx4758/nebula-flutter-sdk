import 'package:nebula_sdk/src/error_reporting/budget.dart';
import 'package:nebula_sdk/src/error_reporting/report.dart';
import 'package:nebula_sdk/src/error_reporting/report_id.dart';
import 'package:nebula_sdk/src/error_reporting/sender.dart';
import 'package:nebula_sdk/src/error_reporting/store.dart';

final class FixedErrorReportIdGenerator implements ErrorReportIdGenerator {
  FixedErrorReportIdGenerator([this.prefix = 'report']);
  final String prefix;
  int _next = 0;

  @override
  String nextId() => '$prefix-${++_next}';
}

final class FakeBoundedErrorStore implements ErrorReportStore {
  final List<StoredErrorReport> records = <StoredErrorReport>[];
  bool throwOnSave = false;
  bool throwOnRead = false;
  bool throwOnDelete = false;
  bool throwOnRetry = false;

  @override
  Future<ErrorStoreSaveResult> saveBounded(
    NebulaErrorReport report, {
    required ErrorReportingBudget budget,
    required DateTime now,
  }) async {
    if (throwOnSave) throw StateError('save failed');
    final int expired = _expire(budget, now);
    if (report.estimatedBytes > budget.maxStoredBytes) {
      return ErrorStoreSaveResult(persisted: false, expiredCount: expired);
    }
    int evicted = 0;
    while (records.isNotEmpty &&
        (records.length >= budget.maxStoredReports ||
            _bytes + report.estimatedBytes > budget.maxStoredBytes)) {
      records.removeAt(0);
      evicted++;
    }
    records.add(StoredErrorReport(report: report, storedAt: now.toUtc()));
    return ErrorStoreSaveResult(
      persisted: true,
      expiredCount: expired,
      evictedCount: evicted,
    );
  }

  @override
  Future<ErrorStoreReadResult> readReady({
    required ErrorReportingBudget budget,
    required DateTime now,
  }) async {
    if (throwOnRead) throw StateError('read failed');
    final int expired = _expire(budget, now);
    final List<StoredErrorReport> out = <StoredErrorReport>[];
    int bytes = 0;
    for (final StoredErrorReport stored in records) {
      if (stored.attemptCount >= budget.maxAttempts) continue;
      if (stored.nextAttemptAt?.isAfter(now) ?? false) continue;
      if (out.length >= budget.maxReportsPerFlush) break;
      if (bytes + stored.report.estimatedBytes > budget.maxBytesPerFlush) break;
      out.add(stored);
      bytes += stored.report.estimatedBytes;
    }
    return ErrorStoreReadResult(reports: out, expiredCount: expired);
  }

  @override
  Future<void> deleteById(Iterable<String> reportIds) async {
    if (throwOnDelete) throw StateError('delete failed');
    final Set<String> ids = reportIds.toSet();
    records.removeWhere(
      (StoredErrorReport r) => ids.contains(r.report.reportId),
    );
  }

  @override
  Future<void> scheduleRetry(
    Iterable<String> reportIds, {
    required int attemptCount,
    required DateTime nextAttemptAt,
  }) async {
    if (throwOnRetry) throw StateError('retry failed');
    final Set<String> ids = reportIds.toSet();
    for (int i = 0; i < records.length; i++) {
      final StoredErrorReport current = records[i];
      if (!ids.contains(current.report.reportId)) continue;
      records[i] = StoredErrorReport(
        report: current.report,
        storedAt: current.storedAt,
        attemptCount: attemptCount,
        nextAttemptAt: nextAttemptAt.toUtc(),
      );
    }
  }

  int _expire(ErrorReportingBudget budget, DateTime now) {
    final int before = records.length;
    records.removeWhere(
      (StoredErrorReport r) =>
          now.toUtc().difference(r.storedAt.toUtc()) > budget.maxReportAge,
    );
    return before - records.length;
  }

  int get _bytes => records.fold<int>(
        0,
        (int sum, StoredErrorReport r) => sum + r.report.estimatedBytes,
      );
}

final class RecordingErrorReportSender implements ErrorReportSender {
  final List<List<NebulaErrorReport>> batches = <List<NebulaErrorReport>>[];
  final List<Exception> errors = <Exception>[];
  final List<ErrorReportSendResult> results = <ErrorReportSendResult>[];

  @override
  Future<ErrorReportSendResult> send(List<NebulaErrorReport> reports) async {
    batches.add(List<NebulaErrorReport>.unmodifiable(reports));
    if (errors.isNotEmpty) throw errors.removeAt(0);
    if (results.isNotEmpty) return results.removeAt(0);
    return ErrorReportSendResult(
      acceptedReportIds: reports.map((NebulaErrorReport r) => r.reportId),
    );
  }
}
