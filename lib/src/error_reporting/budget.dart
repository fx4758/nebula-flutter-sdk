library;

/// Runtime-tunable Error Reporting limits.
///
/// Defaults are SDK implementation choices, not architecture invariants. A
/// future composition root may inject different values without changing the
/// frozen V1 contract, subject to the same boundedness semantics.
final class ErrorReportingBudget {
  const ErrorReportingBudget({
    this.maxErrorTypeBytes = 128,
    this.maxSafeMessageBytes = 1024,
    this.maxStackBytes = 8 * 1024,
    this.maxRequestIdBytes = 128,
    this.maxAppVersionBytes = 128,
    this.maxBuildNumberBytes = 128,
    this.maxReportBytes = 12 * 1024,
    this.maxStoredReports = 50,
    this.maxStoredBytes = 256 * 1024,
    this.maxReportAge = const Duration(days: 7),
    this.maxReportsPerFlush = 10,
    this.maxBytesPerFlush = 12 * 1024,
    this.maxAttempts = 3,
    this.retryBaseDelay = const Duration(seconds: 2),
    this.retryMaxDelay = const Duration(minutes: 5),
  });

  final int maxErrorTypeBytes;
  final int maxSafeMessageBytes;
  final int maxStackBytes;
  final int maxRequestIdBytes;
  final int maxAppVersionBytes;
  final int maxBuildNumberBytes;
  final int maxReportBytes;

  final int maxStoredReports;
  final int maxStoredBytes;
  final Duration maxReportAge;

  final int maxReportsPerFlush;
  final int maxBytesPerFlush;
  final int maxAttempts;
  final Duration retryBaseDelay;
  final Duration retryMaxDelay;

  void validate() {
    final List<int> positive = <int>[
      maxErrorTypeBytes,
      maxSafeMessageBytes,
      maxStackBytes,
      maxRequestIdBytes,
      maxAppVersionBytes,
      maxBuildNumberBytes,
      maxReportBytes,
      maxStoredReports,
      maxStoredBytes,
      maxReportsPerFlush,
      maxBytesPerFlush,
      maxAttempts,
    ];
    if (positive.any((int value) => value <= 0)) {
      throw ArgumentError('Error Reporting budgets must be positive');
    }
    if (maxReportAge <= Duration.zero ||
        retryBaseDelay < Duration.zero ||
        retryMaxDelay < Duration.zero) {
      throw ArgumentError(
        'Error Reporting durations must be non-negative and age must be positive',
      );
    }
    if (retryMaxDelay < retryBaseDelay) {
      throw ArgumentError('retryMaxDelay must be >= retryBaseDelay');
    }
    if (maxReportBytes > maxStoredBytes || maxReportBytes > maxBytesPerFlush) {
      throw ArgumentError(
        'maxReportBytes must fit both store and single-flush byte budgets',
      );
    }
  }

  Duration retryDelayAfterFailure(int failedAttemptCount) {
    if (failedAttemptCount <= 0) return Duration.zero;
    final int multiplier = 1 << (failedAttemptCount - 1).clamp(0, 20);
    final int millis = retryBaseDelay.inMilliseconds * multiplier;
    final int capped = millis > retryMaxDelay.inMilliseconds
        ? retryMaxDelay.inMilliseconds
        : millis;
    return Duration(milliseconds: capped);
  }
}
