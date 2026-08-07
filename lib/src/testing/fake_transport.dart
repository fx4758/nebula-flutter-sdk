/// Scriptable [NebulaTransport] test double (F1-05).
///
/// Lets the SDK kernel and every capability be exercised without a real
/// backend: enqueue responses or errors, then assert on the recorded
/// [requests]. This is the F1 exit-criterion vehicle — "无真实后端也能用
/// fake transport 验证所有异常路径；并发 refresh 只有一次网络调用" — and is
/// exported so host apps can reuse it in their own tests.
library;

import 'dart:async';

import '../transport.dart';

/// A handler that produces the response for one [NebulaRequest].
typedef FakeTransportHandler = FutureOr<NebulaResponse> Function(
    NebulaRequest request);

/// Deterministic, scripted [NebulaTransport] for tests.
///
/// Every [send] records the request in [requests] and consumes the next
/// handler from the FIFO queue. A response/error is only produced when the
/// caller enqueued one — this makes "exactly one network call" assertions
/// exact: any unexpected request throws [StateError] instead of silently
/// succeeding.
final class FakeTransport implements NebulaTransport {
  FakeTransport({Iterable<FakeTransportHandler> handlers = const []})
      : _handlers = List<FakeTransportHandler>.of(handlers);

  final List<FakeTransportHandler> _handlers;

  /// Every request seen by [send], in arrival order.
  final List<NebulaRequest> requests = <NebulaRequest>[];

  /// Queues a response for the next [send].
  void enqueue(NebulaResponse response) {
    _handlers.add((NebulaRequest _) async => response);
  }

  /// Queues an error to be thrown by the next [send].
  void enqueueError(Object error) {
    _handlers.add(
      (NebulaRequest _) => Future<NebulaResponse>.error(error),
    );
  }

  /// Queues a request-aware handler (e.g. to assert on request contents and
  /// return different responses per path).
  void enqueueHandler(FakeTransportHandler handler) {
    _handlers.add(handler);
  }

  /// Number of responses/errors still queued.
  int get pendingCount => _handlers.length;

  /// Builds a success envelope response (`{"code":0,"data":...}` shape at the
  /// transport layer, i.e. `statusCode: 200`).
  static NebulaResponse ok(Object? data, {String? requestId}) =>
      NebulaResponse(statusCode: 200, data: data, requestId: requestId);

  @override
  Future<NebulaResponse> send(NebulaRequest request) async {
    requests.add(request);
    if (_handlers.isEmpty) {
      throw StateError(
        'FakeTransport: no handler queued for '
        '${request.method.name.toUpperCase()} ${request.path}',
      );
    }
    final FakeTransportHandler handler = _handlers.removeAt(0);
    return await handler(request);
  }
}
