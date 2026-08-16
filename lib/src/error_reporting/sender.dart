library;

import 'report.dart';

enum ErrorReportSendDisposition {
  processed,
  rateLimitedDefer,
  transientFailure,
  deterministicRequestFailure,
  trustRecoveryRequired,
}

/// Domain-specific internal result from an Error Reporting transport binding.
///
/// For [ErrorReportSendDisposition.processed], IDs omitted from both accepted
/// and rejected sets remain unprocessed. Non-processed dispositions never
/// manufacture per-report ACK/rejection facts.
final class ErrorReportSendResult {
  ErrorReportSendResult({
    this.disposition = ErrorReportSendDisposition.processed,
    Iterable<String> acceptedReportIds = const <String>[],
    Iterable<String> rejectedReportIds = const <String>[],
    Iterable<String>? affectedReportIds,
    this.deferRemaining = false,
    this.retryAfter,
  })  : acceptedReportIds = Set<String>.unmodifiable(acceptedReportIds),
        rejectedReportIds = Set<String>.unmodifiable(rejectedReportIds),
        affectedReportIds = affectedReportIds == null
            ? null
            : Set<String>.unmodifiable(affectedReportIds) {
    if (this
        .acceptedReportIds
        .intersection(this.rejectedReportIds)
        .isNotEmpty) {
      throw ArgumentError('accepted and rejected report IDs must be disjoint');
    }
    if (disposition != ErrorReportSendDisposition.processed &&
        (this.acceptedReportIds.isNotEmpty ||
            this.rejectedReportIds.isNotEmpty)) {
      throw ArgumentError(
        'non-processed Error Reporting outcomes cannot carry ACK/rejection IDs',
      );
    }
  }

  final ErrorReportSendDisposition disposition;
  final Set<String> acceptedReportIds;
  final Set<String> rejectedReportIds;

  /// Exact report IDs governed by this sender outcome. `null` preserves the
  /// legacy internal Port meaning that the outcome applies to the complete
  /// list passed to [ErrorReportSender.send]. An explicit empty set means no
  /// transport attempt occurred (for example a local cooldown gate).
  final Set<String>? affectedReportIds;

  final bool deferRemaining;

  /// Optional transport-neutral cooldown hint. The client clamps it to its
  /// runtime retry budget; provider/policy names remain outside this core.
  final Duration? retryAfter;

  bool get shouldDefer =>
      disposition == ErrorReportSendDisposition.rateLimitedDefer ||
      disposition == ErrorReportSendDisposition.trustRecoveryRequired ||
      deferRemaining ||
      retryAfter != null;
}

abstract interface class ErrorReportSender {
  Future<ErrorReportSendResult> send(List<NebulaErrorReport> reports);
}
