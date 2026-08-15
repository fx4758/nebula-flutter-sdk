library;

import 'dart:math';

abstract interface class ErrorReportIdGenerator {
  String nextId();
}

/// Secure random UUIDv4-style report identity generator.
///
/// Identity is generated once per report capture and must be persisted with the
/// report. Retries reuse the stored value; this generator is never consulted
/// again for that report instance.
final class SecureErrorReportIdGenerator implements ErrorReportIdGenerator {
  SecureErrorReportIdGenerator({Random? random})
      : _random = random ?? Random.secure();

  final Random _random;

  @override
  String nextId() {
    final List<int> bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final String raw = bytes.map(hex).join();
    return '${raw.substring(0, 8)}-'
        '${raw.substring(8, 12)}-'
        '${raw.substring(12, 16)}-'
        '${raw.substring(16, 20)}-'
        '${raw.substring(20)}';
  }
}
