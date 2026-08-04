sealed class NebulaException implements Exception {
  const NebulaException(this.message, {this.requestId});

  final String message;
  final String? requestId;
}

final class NebulaApiException extends NebulaException {
  const NebulaApiException(
    super.message, {
    required this.code,
    super.requestId,
  });

  final int code;
}

final class NebulaConfigurationException extends NebulaException {
  const NebulaConfigurationException(super.message);
}

/// Raised when an HTTP exchange exceeds its connect or receive deadline.
///
/// Transport-level only: a successful response that carries a non-zero business
/// [NebulaApiException.code] is *not* a timeout. See [docs/04 §F1] ("每个请求有
/// 连接/响应总超时和取消路径").
final class NebulaTimeoutException extends NebulaException {
  const NebulaTimeoutException(
    super.message, {
    this.timeout,
    super.requestId,
  });

  /// The deadline that was exceeded, when known.
  final Duration? timeout;
}

/// Raised when the caller cancels an in-flight request via
/// [NebulaCancellationToken]. The transport must have already torn down the
/// underlying connection, not merely discarded the [Future].
final class NebulaCancelledException extends NebulaException {
  const NebulaCancelledException() : super('The request was cancelled');
}

/// Raised for transport-level failures that cannot be expressed as a business
/// envelope — DNS/connection errors, TLS failures, non-2xx responses whose body
/// is missing or not a parseable `{"code", "data"}` envelope, etc.
///
/// Business errors that *do* carry a valid envelope are reported via
/// [NebulaApiException] instead, preserving the server `code` and `requestId`.
final class NebulaHttpException extends NebulaException {
  const NebulaHttpException(
    super.message, {
    this.statusCode,
    super.requestId,
  });

  /// The HTTP status code, when the failure occurred after a response arrived.
  final int? statusCode;
}
