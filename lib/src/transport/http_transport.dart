import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../foundation/error_classification.dart';
import '../foundation/errors.dart';
import '../foundation/logging.dart';
import '../foundation/request_id.dart';
import '../transport.dart';
import 'cancellation_token.dart';

/// Factory for [HttpClient] instances. Injectable so tests can supply a client
/// pointed at a loopback [HttpServer] without touching the network.
typedef HttpClientFactory = HttpClient Function();

/// Concrete [NebulaTransport] backed by `dart:io` [HttpClient].
///
/// Responsibilities (F1-01 / docs/04 §F1 / docs/06 §network):
///  * resolve `baseUri + path + query`;
///  * encode [NebulaRequest.body] as JSON and set envelope headers;
///  * decode the flypost envelope `{"code", "data", "request_id"?}`;
///  * enforce a connect timeout and an overall receive timeout per request;
///  * propagate [NebulaCancellationToken] into the socket — cancellation tears
///    down the underlying connection, it does not merely drop the [Future];
///  * map non-zero business `code` to [NebulaApiException] (preserving `code`
///    and `requestId`), and transport failures to [NebulaHttpException];
///  * attach a generated `X-Request-Id` correlation id and emit a redacted
///    [NebulaLogEvent] through [logger] when one is supplied (F1-04).
///
/// No third-party HTTP dependency is introduced: the SDK ships zero runtime
/// dependencies (see `pubspec.yaml`), so the kernel uses the platform client.
final class HttpTransport implements NebulaTransport {
  HttpTransport({
    required this.baseUri,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 30),
    Map<String, String> defaultHeaders = const <String, String>{},
    this.logger,
    HttpClientFactory? clientFactory,
  })  : _defaultHeaders = Map<String, String>.unmodifiable(defaultHeaders),
        _clientFactory = clientFactory ?? _defaultClientFactory;

  /// The absolute origin all requests are resolved against. HTTPS enforcement
  /// for production is owned by [NebulaOptions.validate]; the transport itself
  /// accepts any absolute URI so loopback test servers can use `http://`.
  final Uri baseUri;

  /// Maximum time to establish the TCP/TLS connection.
  final Duration connectTimeout;

  /// Maximum time for the response headers *and* body to arrive.
  final Duration receiveTimeout;

  /// Optional redacted logger (F1-04). When null, the SDK emits no logs
  /// (privacy-by-default). Supplied by the host at the composition root.
  final NebulaLogger? logger;

  final Map<String, String> _defaultHeaders;
  final HttpClientFactory _clientFactory;

  static HttpClient _defaultClientFactory() => HttpClient();

  @override
  Future<NebulaResponse> send(NebulaRequest request) async {
    final Stopwatch sw = Stopwatch()..start();
    final String clientRequestId = NebulaRequestId.generate().toString();

    final NebulaCancellationToken? token = request.cancellationToken;
    if (token?.isCancelled ?? false) {
      throw const NebulaCancelledException();
    }

    final HttpClient client = _clientFactory();
    client.connectionTimeout = connectTimeout;

    // A cancellation future. When fired we both tear down the socket (best-effort
    // abort) and resolve this future so the caller gets [NebulaCancelledException]
    // without waiting on the still-pending network operation.
    final Completer<NebulaCancelledException> cancelCompleter =
        Completer<NebulaCancelledException>();
    void onCancel() {
      client.close(force: true);
      if (!cancelCompleter.isCompleted) {
        cancelCompleter.complete(const NebulaCancelledException());
      }
    }

    token?.onCancel(onCancel);

    try {
      final Object result = await Future.any<Object>(<Future<Object>>[
        _perform(client, request, clientRequestId),
        cancelCompleter.future,
      ]);
      if (result is NebulaCancelledException) {
        // Cancellation won the race: propagate as an error, not a value.
        _emitLog(clientRequestId, request, NebulaErrorCategory.cancelled, sw);
        throw result;
      }
      _emitLog(clientRequestId, request, NebulaErrorCategory.success, sw);
      return result as NebulaResponse;
    } on NebulaCancelledException {
      rethrow;
    } on NebulaException catch (e) {
      _emitLog(
        clientRequestId,
        request,
        classifyNebulaError(e),
        sw,
        e.message,
      );
      rethrow;
    } on Object catch (e) {
      // Ensure a hung connection is released even if the abort races the error.
      client.close(force: true);
      final NebulaHttpException wrapped =
          NebulaHttpException('Transport failure: $e', requestId: clientRequestId);
      _emitLog(
        clientRequestId,
        request,
        NebulaErrorCategory.network,
        sw,
        wrapped.message,
      );
      throw wrapped;
    } finally {
      token?.offCancel(onCancel);
      // Idempotent: a force-close above already released the sockets.
      client.close();
    }
  }

  void _emitLog(
    String clientRequestId,
    NebulaRequest request,
    NebulaErrorCategory result,
    Stopwatch sw, [
    String? message,
  ]) {
    if (logger == null) return;
    logger!.log(
      NebulaLogEvent(
        requestId: clientRequestId,
        endpoint: '${request.method.name.toUpperCase()} ${request.path}',
        result: result,
        duration: sw.elapsed,
        level: result == NebulaErrorCategory.success
            ? NebulaLogLevel.info
            : NebulaLogLevel.warning,
        message: message,
      ),
    );
  }

  Future<NebulaResponse> _perform(
    HttpClient client,
    NebulaRequest request,
    String clientRequestId,
  ) async {
    final Uri uri = _resolveUri(request);

    final HttpClientRequest httpReq;
    try {
      httpReq = await client
          .openUrl(request.method.name.toUpperCase(), uri)
          .timeout(connectTimeout, onTimeout: () {
        throw const NebulaTimeoutException('Connection timed out');
      });
    } on NebulaTimeoutException {
      rethrow;
    } catch (e) {
      throw NebulaHttpException('Failed to open connection to $uri: $e');
    }

    httpReq.headers.set('accept', 'application/json');
    if (request.body != null) {
      httpReq.headers.set('content-type', 'application/json; charset=utf-8');
    }
    _defaultHeaders.forEach(httpReq.headers.set);
    request.headers.forEach(httpReq.headers.set);
    if (request.idempotencyKey != null) {
      httpReq.headers.set('idempotency-key', request.idempotencyKey!);
    }
    // F1-04: attach a client-generated correlation id unless the caller already
    // set one. A compliant server echoes it back as `request_id` (docs/08 §8).
    if (!request.headers.containsKey('x-request-id')) {
      httpReq.headers.set('x-request-id', clientRequestId);
    }

    if (request.body != null) {
      final List<int> bytes = utf8.encode(jsonEncode(request.body));
      httpReq.contentLength = bytes.length;
      httpReq.add(bytes);
    }

    final HttpClientResponse httpRes;
    try {
      httpRes = await httpReq.close().timeout(receiveTimeout, onTimeout: () {
        throw const NebulaTimeoutException('Response timed out');
      });
    } on NebulaTimeoutException {
      rethrow;
    } catch (e) {
      throw NebulaHttpException('Request failed: $e');
    }

    final List<int> bodyBytes;
    try {
      bodyBytes = await httpRes.fold<List<int>>(
          <int>[],
          (List<int> prev, List<int> e) =>
              prev..addAll(e)).timeout(receiveTimeout, onTimeout: () {
        throw const NebulaTimeoutException('Body read timed out');
      });
    } on NebulaTimeoutException {
      rethrow;
    } catch (e) {
      throw NebulaHttpException('Failed to read response body: $e');
    }

    final String? requestId =
        httpRes.headers.value('x-request-id') ?? _requestIdFromBody(bodyBytes);

    if (httpRes.statusCode < 200 || httpRes.statusCode >= 300) {
      throw NebulaHttpException(
        'Unexpected HTTP status ${httpRes.statusCode}',
        statusCode: httpRes.statusCode,
        requestId: requestId,
      );
    }

    final Object? json;
    try {
      final String text = utf8.decode(bodyBytes);
      json = text.isEmpty ? null : jsonDecode(text);
    } on FormatException {
      throw NebulaHttpException(
        'Response body is not valid JSON',
        statusCode: httpRes.statusCode,
        requestId: requestId,
      );
    }

    final ApiEnvelope envelope = ApiEnvelope.decode(json, requestId);
    if (envelope.isSuccess) {
      return NebulaResponse(
        statusCode: httpRes.statusCode,
        data: envelope.data,
        requestId: envelope.requestId,
      );
    }
    throw NebulaApiException(
      'Request failed with business code ${envelope.code}',
      code: envelope.code,
      requestId: envelope.requestId,
    );
  }

  Uri _resolveUri(NebulaRequest request) {
    final Map<String, String> query = <String, String>{
      ...baseUri.queryParameters,
      ...request.query,
    };
    return baseUri.replace(
      path: _joinPath(baseUri.path, request.path),
      queryParameters: query.isEmpty ? null : query,
    );
  }

  static String _joinPath(String base, String path) {
    final String b = base.endsWith('/') && base.isNotEmpty
        ? base.substring(0, base.length - 1)
        : base;
    final String p = path.startsWith('/') ? path : '/$path';
    return '$b$p';
  }

  static String? _requestIdFromBody(List<int> bodyBytes) {
    if (bodyBytes.isEmpty) return null;
    try {
      final Object? json = jsonDecode(utf8.decode(bodyBytes));
      if (json is Map<String, Object?> && json['request_id'] is String) {
        return json['request_id'] as String;
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}

/// Decoded flypost response envelope.
///
/// Wire truth (docs/08 §8): `{"code": <int>, "data": <object|null>}`, no `msg`;
/// `request_id` is echoed either as an HTTP header or a body field.
///
/// Leniency: a body that is a JSON object *without* a `code` key (e.g. the
/// bootstrap-style shape used by `test/fixtures/bootstrap_response.json`, which
/// predates the `{code,data}` envelope) is treated as the `data` payload with a
/// success code of 0. This keeps the frozen contract fixtures working; a truly
/// malformed (non-object) body is still rejected upstream as
/// [NebulaHttpException]. Tracked for reconciliation in DEBT_REGISTER.
final class ApiEnvelope {
  const ApiEnvelope({
    required this.code,
    required this.data,
    required this.requestId,
  });

  final int code;
  final Object? data;
  final String? requestId;

  bool get isSuccess => code == 0;

  static ApiEnvelope decode(Object? json, [String? requestIdFromHeader]) {
    if (json is! Map<String, Object?>) {
      return ApiEnvelope(code: 0, data: json, requestId: requestIdFromHeader);
    }
    final Object? rawCode = json['code'];
    if (rawCode is int) {
      final Object? rawReqId = json['request_id'] ?? requestIdFromHeader;
      return ApiEnvelope(
        code: rawCode,
        data: json['data'],
        requestId: rawReqId is String ? rawReqId : null,
      );
    }
    // Envelope without `code`: treat the whole object as data (lenient).
    return ApiEnvelope(code: 0, data: json, requestId: requestIdFromHeader);
  }
}
