import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('NebulaRequestId (F1-04 correlation id)', () {
    test('generate produces a 16-char hex id', () {
      final NebulaRequestId id = NebulaRequestId.generate();
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(id.value), isTrue);
    });

    test('generate produces distinct ids across calls', () {
      final Set<String> seen = <String>{};
      for (int i = 0; i < 1000; i++) {
        seen.add(NebulaRequestId.generate().value);
      }
      // Extremely unlikely to collide; proves entropy, not a strict guarantee.
      expect(seen.length, greaterThan(990));
    });

    test('parse round-trips and rejects empty', () {
      final NebulaRequestId parsed = NebulaRequestId.parse('abc123');
      expect(parsed.value, 'abc123');
      expect(parsed, NebulaRequestId.parse('abc123'));
      expect(parsed.hashCode, NebulaRequestId.parse('abc123').hashCode);
      expect(() => NebulaRequestId.parse(''), throwsArgumentError);
    });
  });

  group('classifyNebulaError (F1-04 error categories)', () {
    test('maps transport exception types to categories', () {
      expect(
        classifyNebulaError(const NebulaTimeoutException('t')),
        NebulaErrorCategory.timeout,
      );
      expect(
        classifyNebulaError(const NebulaCancelledException()),
        NebulaErrorCategory.cancelled,
      );
      expect(
        classifyNebulaError(const NebulaConfigurationException('c')),
        NebulaErrorCategory.client,
      );
    });

    test('maps NebulaApiException by business code', () {
      expect(
        classifyNebulaError(const NebulaApiException('x', code: 401)),
        NebulaErrorCategory.authentication,
      );
      expect(
        classifyNebulaError(const NebulaApiException('x', code: 429)),
        NebulaErrorCategory.rateLimited,
      );
      expect(
        classifyNebulaError(const NebulaApiException('x', code: 400)),
        NebulaErrorCategory.validation,
      );
      expect(
        // Codes below the 5xxx unavailable band and outside the HTTP-aligned
        // set map to unknown (raw code is preserved on the exception).
        classifyNebulaError(const NebulaApiException('x', code: 2)),
        NebulaErrorCategory.unknown,
      );
      expect(
        classifyNebulaError(const NebulaApiException('x', code: 12345)),
        NebulaErrorCategory.temporarilyUnavailable,
      );
    });

    test('maps NebulaHttpException by status code', () {
      expect(
        classifyNebulaError(const NebulaHttpException('x', statusCode: 503)),
        NebulaErrorCategory.temporarilyUnavailable,
      );
      expect(
        classifyNebulaError(const NebulaHttpException('x', statusCode: 500)),
        NebulaErrorCategory.temporarilyUnavailable,
      );
      expect(
        classifyNebulaError(const NebulaHttpException('x')),
        NebulaErrorCategory.network,
      );
      expect(
        classifyNebulaError(const NebulaHttpException('x', statusCode: 404)),
        NebulaErrorCategory.notFound,
      );
    });

    test('unknown error types fall back to unknown', () {
      expect(classifyNebulaError(Exception('boom')), NebulaErrorCategory.unknown);
    });
  });

  group('redact (F1-04 privacy)', () {
    test('masks long values but keeps short ones', () {
      expect(redact('tok_abcdef1234567890'),
          startsWith('tok_…(redacted '));
      expect(redact('abcd'), 'abcd');
      expect(redact(''), '');
      expect(redact(null), isNull);
    });

    test('redactValues keeps keys, scrubs values', () {
      final Map<String, String> out = redactValues(<String, String>{
        'authorization': 'Bearer-secret-token-value',
        'x': 'ab',
      });
      expect(out['authorization'], startsWith('Bear…(redacted '));
      expect(out['x'], 'ab');
    });
  });

  group('NebulaLogger (F1-04 redacted logging Port)', () {
    test('NoOpLogger emits nothing', () {
      final NoOpLogger logger = NoOpLogger();
      // Should not throw and produce no side effects.
      logger.log(const NebulaLogEvent(
        requestId: 'r1',
        endpoint: 'GET /x',
        result: NebulaErrorCategory.success,
        duration: Duration(milliseconds: 5),
      ));
    });

    test('RedactingLogger formats and redacts the message', () {
      final List<String> lines = <String>[];
      final RedactingLogger logger = RedactingLogger(sink: lines.add);
      logger.log(const NebulaLogEvent(
        requestId: 'req-9',
        endpoint: 'POST /api/v1/mobile/auth/login',
        result: NebulaErrorCategory.authentication,
        duration: Duration(milliseconds: 42),
        level: NebulaLogLevel.warning,
        message: 'token=supersecretvaluetoken',
      ));
      expect(lines, hasLength(1));
      final String line = lines.single;
      expect(line, contains('rid=req-9'));
      expect(line, contains('endpoint="POST /api/v1/mobile/auth/login"'));
      expect(line, contains('authentication'));
      expect(line, contains('dur=42ms'));
      // The raw secret must never appear in full.
      expect(line, isNot(contains('supersecretvaluetoken')));
      expect(line, contains('…(redacted '));
    });

    test('RedactingLogger never redacts the endpoint template', () {
      final List<String> lines = <String>[];
      final RedactingLogger logger = RedactingLogger(sink: lines.add);
      logger.log(const NebulaLogEvent(
        requestId: null,
        endpoint: 'GET /v1/long/path/template/that/is/safe',
        result: NebulaErrorCategory.success,
        duration: Duration.zero,
      ));
      expect(lines.single, contains('GET /v1/long/path/template/that/is/safe'));
    });
  });

  group('HttpTransport request-id + logging integration', () {
    Future<HttpServer> _bind(
      Future<void> Function(HttpRequest) handler,
    ) async {
      final HttpServer server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((HttpRequest req) async {
        try {
          await handler(req);
        } catch (_) {}
      });
      return server;
    }

    test('emits a redacted success log with request id + endpoint + duration',
        () async {
      final List<NebulaLogEvent> events = <NebulaLogEvent>[];
      final HttpServer server = await _bind((HttpRequest req) async {
        // Echo the client request id back so the response carries it.
        final String? rid = req.headers.value('x-request-id');
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(<String, Object?>{
            'code': 0,
            'data': <String, Object?>{},
            if (rid != null) 'request_id': rid,
          }));
        await req.response.close();
      });
      final Uri uri = Uri.parse('http://127.0.0.1:${server.port}');
      final HttpTransport transport = HttpTransport(
        baseUri: uri,
        logger: _RecordingLogger(events),
      );

      final NebulaResponse resp = await transport.send(
        NebulaRequest(method: NebulaHttpMethod.get, path: '/v1/test'),
      );
      await server.close(force: true);

      expect(resp.statusCode, 200);
      expect(events, hasLength(1));
      final NebulaLogEvent ev = events.single;
      expect(ev.result, NebulaErrorCategory.success);
      expect(ev.endpoint, 'GET /v1/test');
      expect(ev.requestId, isNotNull);
      expect(ev.requestId!.length, 16); // client-generated id
      expect(ev.duration, isA<Duration>());
    });

    test('emits an error-category log on business failure', () async {
      final List<NebulaLogEvent> events = <NebulaLogEvent>[];
      final HttpServer server = await _bind((HttpRequest req) async {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(<String, Object?>{
            'code': 401,
            'data': <String, Object?>{},
            'request_id': 'server-rid',
          }));
        await req.response.close();
      });
      final Uri uri = Uri.parse('http://127.0.0.1:${server.port}');
      final HttpTransport transport = HttpTransport(
        baseUri: uri,
        logger: _RecordingLogger(events),
      );

      Object? caught;
      try {
        await transport.send(
          NebulaRequest(method: NebulaHttpMethod.post, path: '/v1/x'),
        );
      } on Object catch (e) {
        caught = e;
      }
      await server.close(force: true);

      expect(caught, isA<NebulaApiException>());
      expect(events, hasLength(1));
      final NebulaLogEvent ev = events.single;
      expect(ev.result, NebulaErrorCategory.authentication);
      expect(ev.level, NebulaLogLevel.warning);
    });
  });
}

/// A logger that records events for assertions.
final class _RecordingLogger implements NebulaLogger {
  _RecordingLogger(this.events);
  final List<NebulaLogEvent> events;
  @override
  void log(NebulaLogEvent event) => events.add(event);
}
