library;

import 'dart:convert';

import 'budget.dart';
import 'report.dart';

final class ErrorNormalizationResult {
  const ErrorNormalizationResult({
    required this.report,
    required this.truncatedFieldCount,
    required this.redacted,
    required this.droppedForTotalBytes,
  });

  final NebulaErrorReport? report;
  final int truncatedFieldCount;
  final bool redacted;
  final bool droppedForTotalBytes;
}

/// Privacy-safe normalization and deterministic byte bounding.
final class ErrorReportNormalizer {
  ErrorReportNormalizer({required ErrorReportingBudget budget})
      : _budget = budget;

  final ErrorReportingBudget _budget;

  ErrorNormalizationResult normalize({
    required String reportId,
    required ErrorReportInput input,
  }) {
    int truncated = 0;
    bool redacted = false;

    String bound(String value, int maxBytes) {
      final _RedactionResult rr = _redact(value);
      redacted = redacted || rr.changed;
      final String bounded = _truncateUtf8(rr.value, maxBytes);
      if (bounded != rr.value) truncated++;
      return bounded;
    }

    String? boundOptional(String? value, int maxBytes) {
      if (value == null) return null;
      return bound(value, maxBytes);
    }

    final String errorType = bound(
      input.errorType.trim(),
      _budget.maxErrorTypeBytes,
    );
    if (errorType.isEmpty) {
      return ErrorNormalizationResult(
        report: null,
        truncatedFieldCount: truncated,
        redacted: redacted,
        droppedForTotalBytes: true,
      );
    }

    final NebulaErrorReport report = NebulaErrorReport(
      reportId: reportId,
      occurredAt: input.occurredAt,
      errorType: errorType,
      safeMessage: bound(input.message, _budget.maxSafeMessageBytes),
      stack: bound(input.stack, _budget.maxStackBytes),
      requestId: boundOptional(input.requestId, _budget.maxRequestIdBytes),
      reportedAppVersion: boundOptional(
        input.reportedAppVersion,
        _budget.maxAppVersionBytes,
      ),
      reportedBuildNumber: boundOptional(
        input.reportedBuildNumber,
        _budget.maxBuildNumberBytes,
      ),
    );

    if (report.estimatedBytes > _budget.maxReportBytes) {
      return ErrorNormalizationResult(
        report: null,
        truncatedFieldCount: truncated,
        redacted: redacted,
        droppedForTotalBytes: true,
      );
    }

    return ErrorNormalizationResult(
      report: report,
      truncatedFieldCount: truncated,
      redacted: redacted,
      droppedForTotalBytes: false,
    );
  }
}

final class _RedactionResult {
  const _RedactionResult(this.value, this.changed);
  final String value;
  final bool changed;
}

_RedactionResult _redact(String input) {
  String value = input;
  final List<RegExp> patterns = <RegExp>[
    RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
    RegExp(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b'),
    RegExp(
      r'\b(token|password|passwd|secret|api[_-]?key|access[_-]?token)\s*[:=]\s*[^\s,;]+',
      caseSensitive: false,
    ),
  ];
  for (final RegExp pattern in patterns) {
    value = value.replaceAllMapped(pattern, (Match match) {
      final String text = match.group(0)!;
      final int separator = text.indexOf(RegExp(r'[:=]'));
      if (separator >= 0) {
        return '${text.substring(0, separator + 1)}[REDACTED]';
      }
      if (text.toLowerCase().startsWith('bearer ')) {
        return 'Bearer [REDACTED]';
      }
      return '[REDACTED]';
    });
  }
  return _RedactionResult(value, value != input);
}

String _truncateUtf8(String value, int maxBytes) {
  if (utf8.encode(value).length <= maxBytes) return value;
  final StringBuffer out = StringBuffer();
  int used = 0;
  for (final int rune in value.runes) {
    final String char = String.fromCharCode(rune);
    final int bytes = utf8.encode(char).length;
    if (used + bytes > maxBytes) break;
    out.write(char);
    used += bytes;
  }
  return out.toString();
}
