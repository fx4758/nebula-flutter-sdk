/// Redacted logging Port (F1-04).
///
/// The SDK core never logs raw tokens, request bodies, headers, query strings,
/// prompts, payment credentials or full device identifiers (docs/02 §4 privacy).
/// The only safe default fields are: request id, endpoint template, result
/// category and duration. Anything else the caller supplies in [NebulaLogEvent]
/// is treated as untrusted and passed through [redact].
///
/// The concrete logger (console, file, remote) is supplied by the host app; the
/// core ships a safe [NoOpLogger] default and a [RedactingLogger] reference
/// implementation (docs/01 §4: pure-Dart core must not depend on a plugin).
library;

import 'error_classification.dart';

/// Severity of a log event.
enum NebulaLogLevel { debug, info, warning, error }

/// A single redacted log record emitted by the SDK kernel.
///
/// Every field here is safe to log by default. `message` is optional and MUST
/// already avoid sensitive data — the logger re-scrubs it via [redact] as a
/// defense-in-depth measure.
final class NebulaLogEvent {
  const NebulaLogEvent({
    required this.requestId,
    required this.endpoint,
    required this.result,
    required this.duration,
    this.level = NebulaLogLevel.info,
    this.message,
  });

  /// Correlation id for this call (client-generated; server echo when available).
  final String? requestId;

  /// Endpoint template, e.g. `POST /api/v1/mobile/auth/login`. No query/body.
  final String endpoint;

  /// Coarse result category (success or an error category).
  final NebulaErrorCategory result;

  /// Wall-clock duration of the operation.
  final Duration duration;

  /// Severity.
  final NebulaLogLevel level;

  /// Optional caller-supplied detail; re-scrubbed through [redact] by loggers.
  final String? message;
}

/// Logging Port. Host apps provide the sink (console, file, remote aggregator).
abstract interface class NebulaLogger {
  void log(NebulaLogEvent event);
}

/// Default no-op logger. Safe default: the SDK emits nothing until the host
/// installs a real logger (privacy-by-default, docs/02 §4).
final class NoOpLogger implements NebulaLogger {
  const NoOpLogger();

  @override
  void log(NebulaLogEvent event) {}
}

/// Reference logger that formats one line per event and redacts any message.
///
/// It never logs endpoint templates through [redact] (they are safe strings),
/// but scrubs `message` so callers cannot accidentally leak a token or body by
/// passing it there.
final class RedactingLogger implements NebulaLogger {
  RedactingLogger({
    this.sink = print,
    this.tag = 'nebula',
  });

  /// Output sink; defaults to [print]. Host apps may pass a file/remote writer.
  final void Function(String) sink;

  /// Prefix tag for each line.
  final String tag;

  @override
  void log(NebulaLogEvent event) {
    final String rid = event.requestId ?? '-';
    final String msg = event.message == null ? '' : ' ${redact(event.message)}';
    sink(
      '[$tag] ${event.level.name} ${event.result.name} '
      'rid=$rid endpoint="${event.endpoint}" '
      'dur=${event.duration.inMilliseconds}ms$msg',
    );
  }
}

/// Masks potentially sensitive values for logging.
///
/// Values of 4 characters or fewer are returned unchanged (too short to be a
/// useful secret, and masking would destroy signal). Longer values keep only the
/// first 4 characters and are replaced with a length-only redaction marker.
String? redact(String? value) {
  if (value == null || value.isEmpty) return value;
  if (value.length <= 4) return value;
  return '${value.substring(0, 4)}…(redacted ${value.length} chars)';
}

/// Returns a copy of [map] with every value redacted, keeping the keys.
///
/// Useful for structured logging of e.g. a query/header map where the *names*
/// are safe but the *values* may contain tokens or identifiers.
Map<String, String> redactValues(Map<String, String> map) => <String, String>{
      for (final MapEntry<String, String> e in map.entries)
        e.key: redact(e.value) ?? '',
    };
