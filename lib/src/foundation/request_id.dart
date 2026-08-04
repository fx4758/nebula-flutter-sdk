/// Request correlation id (F1-04).
///
/// A request id ties a single client call to its server-side trace and to every
/// log line the SDK emits for that call. The transport generates one per
/// [send], sends it as `X-Request-Id`, and uses the server's echoed
/// `request_id` (when present) as the authoritative id on the response/error.
library;

import 'dart:math';

/// Opaque client request correlation id.
///
/// Wraps a 128-bit cryptographically-random hex string (16 chars). Two ids are
/// equal iff their strings match; the value is the canonical form.
final class NebulaRequestId {
  NebulaRequestId._(this.value);

  /// Generates a fresh 128-bit id from a secure random source.
  factory NebulaRequestId.generate() {
    final Random r = Random.secure();
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < 16; i++) {
      sb.write(r.nextInt(16).toRadixString(16));
    }
    return NebulaRequestId._(sb.toString());
  }

  /// Parses an externally supplied id (e.g. the server's echoed `request_id`).
  ///
  /// Empty values are rejected: a request id must be meaningful for correlation.
  factory NebulaRequestId.parse(String value) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, 'value', 'must not be empty');
    }
    return NebulaRequestId._(value);
  }

  /// Canonical id string (128-bit hex).
  final String value;

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      other is NebulaRequestId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
