enum NebulaHttpMethod { get, post, put, patch, delete }

final class NebulaRequest {
  const NebulaRequest({
    required this.method,
    required this.path,
    this.headers = const <String, String>{},
    this.query = const <String, String>{},
    this.body,
    this.idempotencyKey,
  });

  final NebulaHttpMethod method;
  final String path;
  final Map<String, String> headers;
  final Map<String, String> query;
  final Object? body;
  final String? idempotencyKey;
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
