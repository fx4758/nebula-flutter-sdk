library;

import 'budget.dart';
import 'normalizer.dart';
import 'report.dart';
import 'report_id.dart';
import 'sender.dart';
import 'store.dart';

enum ErrorCaptureDisposition {
  persisted,
  droppedByPayloadBudget,
  persistenceFailed,
}

final class ErrorCaptureResult {
  const ErrorCaptureResult({required this.disposition, this.reportId});
  final ErrorCaptureDisposition disposition;
  final String? reportId;
}

final class ErrorReportingStats {
  int captured = 0;
  int persisted = 0;
  int persistenceFailures = 0;
  int droppedByPayloadBudget = 0;
  int truncatedFields = 0;
  int redactedReports = 0;
  int storeEvictions = 0;
  int expiredReports = 0;
  int acknowledged = 0;
  int rejected = 0;
  int retryScheduled = 0;
  int retryExhausted = 0;
  int senderFailures = 0;
  int invalidSenderResults = 0;
  int uploadDeferrals = 0;
}

final class ErrorReportingClient {
  ErrorReportingClient({
    required ErrorReportStore store,
    ErrorReportSender? sender,
    ErrorReportIdGenerator? idGenerator,
    ErrorReportingBudget budget = const ErrorReportingBudget(),
    DateTime Function()? now,
  })  : _store = store,
        _sender = sender,
        _idGenerator = idGenerator ?? SecureErrorReportIdGenerator(),
        _budget = budget,
        _normalizer = ErrorReportNormalizer(budget: budget),
        _now = now ?? DateTime.now {
    _budget.validate();
  }

  final ErrorReportStore _store;
  final ErrorReportSender? _sender;
  final ErrorReportIdGenerator _idGenerator;
  final ErrorReportingBudget _budget;
  final ErrorReportNormalizer _normalizer;
  final DateTime Function() _now;
  final ErrorReportingStats stats = ErrorReportingStats();
  bool _flushing = false;
  DateTime? _uploadDeferredUntil;

  Future<ErrorCaptureResult> capture(ErrorReportInput input) async {
    stats.captured++;
    final String reportId = _idGenerator.nextId();
    final ErrorNormalizationResult normalized = _normalizer.normalize(
      reportId: reportId,
      input: input,
    );
    stats.truncatedFields += normalized.truncatedFieldCount;
    if (normalized.redacted) stats.redactedReports++;
    final NebulaErrorReport? report = normalized.report;
    if (report == null) {
      stats.droppedByPayloadBudget++;
      return const ErrorCaptureResult(
        disposition: ErrorCaptureDisposition.droppedByPayloadBudget,
      );
    }
    try {
      final ErrorStoreSaveResult result = await _store.saveBounded(
        report,
        budget: _budget,
        now: _now().toUtc(),
      );
      stats.storeEvictions += result.evictedCount;
      stats.expiredReports += result.expiredCount;
      if (!result.persisted) {
        stats.persistenceFailures++;
        return ErrorCaptureResult(
          disposition: ErrorCaptureDisposition.persistenceFailed,
          reportId: reportId,
        );
      }
      stats.persisted++;
      return ErrorCaptureResult(
        disposition: ErrorCaptureDisposition.persisted,
        reportId: reportId,
      );
    } on Object {
      stats.persistenceFailures++;
      return ErrorCaptureResult(
        disposition: ErrorCaptureDisposition.persistenceFailed,
        reportId: reportId,
      );
    }
  }

  Future<void> flush() async {
    final ErrorReportSender? sender = _sender;
    if (sender == null || _flushing) return;
    final DateTime now = _now().toUtc();
    final DateTime? deferredUntil = _uploadDeferredUntil;
    if (deferredUntil != null && deferredUntil.isAfter(now)) return;
    _uploadDeferredUntil = null;
    _flushing = true;
    try {
      final ErrorStoreReadResult read = await _store.readReady(
        budget: _budget,
        now: now,
      );
      stats.expiredReports += read.expiredCount;
      final List<StoredErrorReport> batch = _defensivelyBound(
        read.reports,
        now,
      );
      if (batch.isEmpty) return;

      final List<NebulaErrorReport> reports = batch
          .map((StoredErrorReport stored) => stored.report)
          .toList(growable: false);
      late final ErrorReportSendResult result;
      try {
        result = await sender.send(reports);
      } on Object {
        stats.senderFailures++;
        await _scheduleRetry(batch, now);
        return;
      }

      final Set<String> batchIds =
          reports.map((NebulaErrorReport report) => report.reportId).toSet();
      if (!_validSenderResult(result, batchIds)) {
        stats.invalidSenderResults++;
        await _scheduleRetry(batch, now);
        return;
      }

      if (result.acceptedReportIds.isNotEmpty) {
        await _store.deleteById(result.acceptedReportIds);
        stats.acknowledged += result.acceptedReportIds.length;
      }
      if (result.rejectedReportIds.isNotEmpty) {
        await _store.deleteById(result.rejectedReportIds);
        stats.rejected += result.rejectedReportIds.length;
      }

      final Set<String> retryIds = Set<String>.of(batchIds)
        ..removeAll(result.acceptedReportIds)
        ..removeAll(result.rejectedReportIds);
      if (retryIds.isNotEmpty) {
        await _scheduleRetry(
          batch
              .where(
                (StoredErrorReport stored) =>
                    retryIds.contains(stored.report.reportId),
              )
              .toList(growable: false),
          now,
        );
      }
      if (result.shouldDefer) {
        stats.uploadDeferrals++;
        final Duration cooldown = result.retryAfter ?? _budget.retryBaseDelay;
        _uploadDeferredUntil = now.add(cooldown);
      }
    } on Object {
      stats.persistenceFailures++;
    } finally {
      _flushing = false;
    }
  }

  List<StoredErrorReport> _defensivelyBound(
    List<StoredErrorReport> input,
    DateTime now,
  ) {
    final List<StoredErrorReport> out = <StoredErrorReport>[];
    int bytes = 0;
    for (final StoredErrorReport stored in input) {
      if (now.difference(stored.storedAt.toUtc()) > _budget.maxReportAge) {
        continue;
      }
      final DateTime? nextAttemptAt = stored.nextAttemptAt;
      if (nextAttemptAt != null && nextAttemptAt.toUtc().isAfter(now)) {
        continue;
      }
      if (stored.attemptCount >= _budget.maxAttempts) continue;
      final int reportBytes = stored.report.estimatedBytes;
      if (out.length >= _budget.maxReportsPerFlush ||
          bytes + reportBytes > _budget.maxBytesPerFlush) {
        break;
      }
      out.add(stored);
      bytes += reportBytes;
    }
    return out;
  }

  bool _validSenderResult(ErrorReportSendResult result, Set<String> batchIds) {
    return batchIds.containsAll(result.acceptedReportIds) &&
        batchIds.containsAll(result.rejectedReportIds);
  }

  Future<void> _scheduleRetry(
    List<StoredErrorReport> reports,
    DateTime now,
  ) async {
    for (final StoredErrorReport stored in reports) {
      final int nextAttemptCount = stored.attemptCount + 1;
      if (nextAttemptCount >= _budget.maxAttempts) {
        await _store.deleteById(<String>[stored.report.reportId]);
        stats.retryExhausted++;
        continue;
      }
      await _store.scheduleRetry(
        <String>[stored.report.reportId],
        attemptCount: nextAttemptCount,
        nextAttemptAt: now.add(
          _budget.retryDelayAfterFailure(nextAttemptCount),
        ),
      );
      stats.retryScheduled++;
    }
  }
}
