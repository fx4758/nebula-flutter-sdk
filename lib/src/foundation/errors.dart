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
