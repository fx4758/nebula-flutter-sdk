import 'transport/cancellation_token.dart';

enum NebulaHttpMethod { get, post, put, patch, delete }

final class NebulaRequest {
  const NebulaRequest({
    required this.method,
    required this.path,
    this.headers = const <String, String>{},
    this.query = const <String, String>{},
    this.body,
    this.idempotencyKey,
    this.cancellationToken,
  });

  final NebulaHttpMethod method;
  final String path;
  final Map<String, String> headers;
  final Map<String, String> query;
  final Object? body;
  final String? idempotencyKey;

  /// Optional cooperative cancel signal. When cancelled mid-flight the transport
  /// aborts the underlying connection (see [NebulaCancellationToken]).
  final NebulaCancellationToken? cancellationToken;
}

final class NebulaResponse {
  const NebulaResponse({
    required this.statusCode,
    required this.data,
    this.requestId,
  });

  final int statusCode;
  final Object? data;
  final String? requestId;
}

abstract interface class NebulaTransport {
  Future<NebulaResponse> send(NebulaRequest request);
}
