library;

import 'dart:convert';

/// Immutable Error Reporting V1 diagnostic report.
///
/// Trusted app / installation / platform identity is deliberately absent: it
/// belongs to the server-side InstallationProof trust context, not this client
/// payload. `ingested_at` is also absent because it is server-authoritative.
final class NebulaErrorReport {
  NebulaErrorReport({
    required this.reportId,
    required DateTime occurredAt,
    required this.errorType,
    required this.safeMessage,
    required this.stack,
    this.requestId,
    this.reportedAppVersion,
    this.reportedBuildNumber,
  }) : occurredAt = occurredAt.toUtc() {
    if (reportId.trim().isEmpty) {
      throw ArgumentError.value(reportId, 'reportId', 'must not be empty');
    }
    if (errorType.trim().isEmpty) {
      throw ArgumentError.value(errorType, 'errorType', 'must not be empty');
    }
  }

  final String reportId;
  final DateTime occurredAt;
  final String errorType;
  final String safeMessage;
  final String stack;
  final String? requestId;
  final String? reportedAppVersion;
  final String? reportedBuildNumber;

  /// Canonical client diagnostic facts only. Server-owned `ingested_at` and
  /// trusted identity are intentionally not serialized by the internal core.
  Map<String, Object?> toDiagnosticMap() => <String, Object?>{
        'report_id': reportId,
        'occurred_at': occurredAt.millisecondsSinceEpoch ~/ 1000,
        'error_type': errorType,
        'safe_message': safeMessage,
        'stack': stack,
        'request_id': requestId,
        'reported_app_version': reportedAppVersion,
        'reported_build_number': reportedBuildNumber,
      };

  int get estimatedBytes => utf8.encode(jsonEncode(toDiagnosticMap())).length;
}

/// Raw internal capture input before redaction / byte-bound normalization.
final class ErrorReportInput {
  ErrorReportInput({
    required this.errorType,
    required this.message,
    required this.stack,
    DateTime? occurredAt,
    this.requestId,
    this.reportedAppVersion,
    this.reportedBuildNumber,
  }) : occurredAt = (occurredAt ?? DateTime.now()).toUtc();

  final DateTime occurredAt;
  final String errorType;
  final String message;
  final String stack;
  final String? requestId;
  final String? reportedAppVersion;
  final String? reportedBuildNumber;
}
