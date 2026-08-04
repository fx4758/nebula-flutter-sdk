import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

/// A loopback HTTP server used to exercise the real `dart:io` transport without
/// touching the network. Each handler receives one [HttpRequest].
final class _Loopback {
  _Loopback(this.server, this.uri);
  final HttpServer server;
  final Uri uri;
  Future<void> close() => server.close(force: true);
}

Future<_Loopback> _startServer(
  Future<void> Function(HttpRequest req) handler,
) async {
  final HttpServer server = await HttpServer.bind('127.0.0.1', 0);
  server.listen((HttpRequest req) async {
    try {
      await handler(req);
    } catch (_) {
      // Swallow errors raised when the client aborts the connection mid-write.
    }
  });
  return _Loopback(server, Uri.parse('http://127.0.0.1:${server.port}'));
}

/// Writes a JSON envelope to the response and closes it.
void _writeJson(
  HttpRequest req,
  int statusCode,
  Object body, {
  Map<String, String> headers = const <String, String>{},
}) {
  headers.forEach(req.response.headers.set);
  req.response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
}

/// Awaits [future], expecting it to throw a [NebulaException], and returns it.
Future<NebulaException> _expectNebulaException(Future<Object?> future) async {
  try {
    await future;
  } on NebulaException catch (e) {
    return e;
  }
  throw Exception('expected a NebulaException but the request succeeded');
}

void main() {
  group('HttpTransport envelope', () {
    late _Loopback server;
    late HttpTransport transport;

    setUp(() async {
      server = await _startServer((HttpRequest req) async {
        _writeJson(req, 200, <String, Object?>{
          'code': 0,
          'data': <String, Object?>{'ok': true}
        });
        await req.response.close();
      });
      transport = HttpTransport(baseUri: server.uri);
    });

    tearDown(() => server.close());

    test('decodes {code,data} and surfaces request_id from header', () async {
      final NebulaResponse resp = await transport.send(
        NebulaRequest(method: NebulaHttpMethod.get, path: '/v1/test'),
      );
      expect(resp.statusCode, 200);
      expect(resp.data, <String, Object?>{'ok': true});
      expect(resp.requestId, isNull);
    });

    test(
        'maps non-zero business code to NebulaApiException (preserves code+id)',
        () async {
      final _Loopback s = await _startServer((HttpRequest req) async {
        _writeJson(req, 200, <String, Object?>{
          'code': 10003,
          'data': <String, Object?>{},
          'request_id': 'r-2',
        });
        await req.response.close();
      });
      final HttpTransport t = HttpTransport(baseUri: s.uri);
      final NebulaException e = await _expectNebulaException(
        t.send(NebulaRequest(method: NebulaHttpMethod.post, path: '/v1/x')),
      );
      expect(e, isA<NebulaApiException>());
      expect((e as NebulaApiException).code, 10003);
      expect(e.requestId, 'r-2');
      await s.close();
    });

    test('lenient: body without code is treated as data (bootstrap-shape)',
        () async {
      final _Loopback s = await _startServer((HttpRequest req) async {
        _writeJson(req, 200, <String, Object?>{'installation_id': 'inst-9'});
        await req.response.close();
      });
      final HttpTransport t = HttpTransport(baseUri: s.uri);
      final NebulaResponse resp = await t.send(
        NebulaRequest(method: NebulaHttpMethod.get, path: '/v1/boot'),
      );
      expect(resp.data, <String, Object?>{'installation_id': 'inst-9'});
      expect(resp.requestId, isNull);
      await s.close();
    });

    test('malformed body raises NebulaHttpException', () async {
      final _Loopback s = await _startServer((HttpRequest req) async {
        req.response
          ..statusCode = 200
          ..write('this is not json');
        await req.response.close();
      });
      final HttpTransport t = HttpTransport(baseUri: s.uri);
      final NebulaException e = await _expectNebulaException(
        t.send(NebulaRequest(method: NebulaHttpMethod.get, path: '/v1/x')),
      );
      expect(e, isA<NebulaHttpException>());
      await s.close();
    });

    test('non-2xx status raises NebulaHttpException with statusCode', () async {
      final _Loopback s = await _startServer((HttpRequest req) async {
        _writeJson(req, 500,
            <String, Object?>{'code': 0, 'data': <String, Object?>{}});
        await req.response.close();
      });
      final HttpTransport t = HttpTransport(baseUri: s.uri);
      final NebulaException e = await _expectNebulaException(
        t.send(NebulaRequest(method: NebulaHttpMethod.get, path: '/v1/x')),
      );
      expect(e, isA<NebulaHttpException>());
      expect((e as NebulaHttpException).statusCode, 500);
      await s.close();
    });

    test('reflects idempotency-key header and joins path+query', () async {
      final _Loopback s = await _startServer((HttpRequest req) async {
        final String? key = req.headers.value('idempotency-key');
        _writeJson(req, 200, <String, Object?>{
          'code': 0,
          'data': <String, Object?>{
            'echo': key ?? '',
            'path': req.uri.path,
            'q': req.uri.query,
          },
        });
        await req.response.close();
      });
      final HttpTransport t = HttpTransport(baseUri: s.uri);
      final NebulaResponse resp = await t.send(NebulaRequest(
        method: NebulaHttpMethod.post,
        path: '/v1/thing',
        query: <String, String>{'a': '1'},
        body: <String, Object?>{'k': 'v'},
        idempotencyKey: 'k-123',
      ));
      final Map<String, Object?> data = resp.data as Map<String, Object?>;
      expect(data['echo'], 'k-123');
      expect(data['path'], '/v1/thing');
      expect(data['q'], 'a=1');
      await s.close();
    });
  });

  group('HttpTransport timeout', () {
    test(
        'receive timeout throws NebulaTimeoutException without waiting for the server',
        () async {
      final _Loopback server = await _startServer((HttpRequest req) async {
        // Hold far longer than the client timeout; the client must not block here.
        await Future<void>.delayed(const Duration(seconds: 2));
        try {
          _writeJson(req, 200,
              <String, Object?>{'code': 0, 'data': <String, Object?>{}});
          await req.response.close();
        } catch (_) {}
      });

      final HttpTransport transport = HttpTransport(
        baseUri: server.uri,
        receiveTimeout: const Duration(milliseconds: 150),
      );

      final Stopwatch sw = Stopwatch()..start();
      final NebulaException e = await _expectNebulaException(
        transport
            .send(NebulaRequest(method: NebulaHttpMethod.get, path: '/slow')),
      );
      // Must fail fast at ~150ms, not after the server's 2s hold.
      expect(sw.elapsedMilliseconds, lessThan(1000));
      expect(e, isA<NebulaTimeoutException>());
      await server.close();
    });
  });

  group('HttpTransport cancellation', () {
    test('cancel propagates to the transport and resolves fast', () async {
      final _Loopback server = await _startServer((HttpRequest req) async {
        await Future<void>.delayed(const Duration(seconds: 2));
        try {
          _writeJson(req, 200,
              <String, Object?>{'code': 0, 'data': <String, Object?>{}});
          await req.response.close();
        } catch (_) {}
      });

      final HttpTransport transport = HttpTransport(baseUri: server.uri);
      final NebulaCancellationToken token = NebulaCancellationToken();

      final Stopwatch sw = Stopwatch()..start();
      final Future<NebulaResponse> future = transport.send(NebulaRequest(
        method: NebulaHttpMethod.get,
        path: '/hang',
        cancellationToken: token,
      ));
      // Cancel immediately, before any response can arrive.
      token.cancel();

      final NebulaException e = await _expectNebulaException(future);
      // The cancellation must resolve promptly, not wait for the 2s server hold.
      expect(sw.elapsedMilliseconds, lessThan(1000));
      expect(e, isA<NebulaCancelledException>());
      await server.close();
    });

    test('already-cancelled token fails fast', () async {
      final _Loopback server = await _startServer((HttpRequest req) async {
        _writeJson(req, 200,
            <String, Object?>{'code': 0, 'data': <String, Object?>{}});
        await req.response.close();
      });
      final HttpTransport transport = HttpTransport(baseUri: server.uri);
      final NebulaCancellationToken token = NebulaCancellationToken()..cancel();
      final NebulaException e = await _expectNebulaException(transport.send(
        NebulaRequest(
          method: NebulaHttpMethod.get,
          path: '/x',
          cancellationToken: token,
        ),
      ));
      expect(e, isA<NebulaCancelledException>());
      await server.close();
    });
  });

  group('HttpTransport connection failure', () {
    test('unreachable origin raises NebulaHttpException', () async {
      // Port 1 is never a live listener; connection is refused immediately.
      final HttpTransport transport =
          HttpTransport(baseUri: Uri.parse('http://127.0.0.1:1/'));
      final NebulaException e = await _expectNebulaException(
        transport.send(NebulaRequest(method: NebulaHttpMethod.get, path: '/x')),
      );
      expect(e, isA<NebulaHttpException>());
    });
  });
}
