library;

import 'report.dart';

/// Domain-specific result from a later transport binding.
///
/// IDs not present in accepted/rejected sets remain retryable. `deferRemaining`
/// is the transport-neutral seam for server-directed upload reduction policy;
/// policy names are deliberately not frozen in the SDK core.
final class ErrorReportSendResult {
  ErrorReportSendResult({
    Iterable<String> acceptedReportIds = const <String>[],
    Iterable<String> rejectedReportIds = const <String>[],
    this.deferRemaining = false,
    this.retryAfter,
  })  : acceptedReportIds = Set<String>.unmodifiable(acceptedReportIds),
        rejectedReportIds = Set<String>.unmodifiable(rejectedReportIds) {
    if (this
        .acceptedReportIds
        .intersection(this.rejectedReportIds)
        .isNotEmpty) {
      throw ArgumentError('accepted and rejected report IDs must be disjoint');
    }
  }

  final Set<String> acceptedReportIds;
  final Set<String> rejectedReportIds;
  final bool deferRemaining;

  /// Optional transport-neutral cooldown. Concrete server/provider policy names
  /// remain outside this internal core.
  final Duration? retryAfter;

  bool get shouldDefer => deferRemaining || retryAfter != null;
}

abstract interface class ErrorReportSender {
  Future<ErrorReportSendResult> send(List<NebulaErrorReport> reports);
}
