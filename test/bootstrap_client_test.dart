import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

import 'bootstrap_test_support.dart';

void main() {
  group('BootstrapEndpoints', () {
    test('freezes the canonical bootstrap route', () {
      expect(BootstrapEndpoints.bootstrap, '/api/v1/mobile/bootstrap');
    });

    test('matches the machine-readable V2 endpoint and request-key oracle', () {
      final Map<String, Object?> contract =
          bootstrapFixture('bootstrap_contract_v2');
      final Set<Object?> expectedKeys = <Object?>{
        ...(contract['required_request_fields']! as List<Object?>),
        ...(contract['optional_request_fields']! as List<Object?>),
      };
      final BootstrapRequest request =
          fixtureBootstrapRequest(populatedOptionals: false);

      expect(BootstrapEndpoints.bootstrap, contract['endpoint']);
      expect(request.toJson().keys.toSet(), expectedKeys);
      expect(contract['automatic_retry_max'], 1);
      expect(contract['retry_requires_same_request_id_and_values'], isTrue);
    });
  });

  group('NebulaBootstrapClient', () {
    test('sends canonical POST body and parses the typed result', () async {
      final BootstrapRequest request = fixtureBootstrapRequest();
      final FakeTransport transport = FakeTransport()
        ..enqueue(FakeTransport.ok(bootstrapSuccessData(request)));
      final NebulaBootstrapClient client =
          NebulaBootstrapClient(transport: transport);

      final BootstrapResult result = await client.bootstrap(request);

      expect(result.installationId, request.installationId);
      expect(result.requestId, request.bootstrapRequestId);
      expect(transport.requests, hasLength(1));
      final NebulaRequest sent = transport.requests.single;
      expect(sent.method, NebulaHttpMethod.post);
      expect(sent.path, BootstrapEndpoints.bootstrap);
      expect(sent.body, request.toJson());
      expect((sent.body! as Map<String, Object?>), hasLength(11));
      expect(sent.idempotencyKey, isNull); // idempotency is the frozen body ID.
    });

    test('50001 retries once with the exact same canonical body object',
        () async {
      final BootstrapRequest request = fixtureBootstrapRequest();
      final FakeTransport transport = FakeTransport()
        ..enqueueError(const NebulaApiException('server', code: 50001))
        ..enqueue(FakeTransport.ok(bootstrapSuccessData(request)));
      final NebulaBootstrapClient client =
          NebulaBootstrapClient(transport: transport);

      await client.bootstrap(request);

      expect(transport.requests, hasLength(2));
      expect(
        identical(transport.requests[0].body, transport.requests[1].body),
        isTrue,
      );
      expect(
        (transport.requests[1].body!
            as Map<String, Object?>)['bootstrap_request_id'],
        request.bootstrapRequestId,
      );
    });

    test('12004 and transport ambiguity may consume the one retry', () async {
      for (final Object firstError in <Object>[
        const NebulaApiException('unavailable', code: 12004),
        const NebulaTimeoutException('timeout'),
        const NebulaHttpException('network'),
      ]) {
        final BootstrapRequest request = fixtureBootstrapRequest();
        final FakeTransport transport = FakeTransport()
          ..enqueueError(firstError)
          ..enqueue(FakeTransport.ok(bootstrapSuccessData(request)));
        await NebulaBootstrapClient(transport: transport).bootstrap(request);
        expect(transport.requests, hasLength(2), reason: '$firstError');
      }
    });

    test('50001 retry is capped at one extra attempt', () async {
      final FakeTransport transport = FakeTransport()
        ..enqueueError(const NebulaApiException('server', code: 50001))
        ..enqueueError(const NebulaApiException('server', code: 50001));
      final Future<BootstrapResult> future =
          NebulaBootstrapClient(transport: transport)
              .bootstrap(fixtureBootstrapRequest());
      await expectLater(
        future,
        throwsA(
          isA<NebulaApiException>().having((e) => e.code, 'code', 50001),
        ),
      );
      expect(transport.requests, hasLength(2));
    });

    test('frozen no-immediate-retry inputs make exactly one request', () async {
      final List<Object> errors = <Object>[
        const NebulaApiException('invalid installation', code: 12001),
        const NebulaApiException('invalid request', code: 30001),
        const NebulaApiException('client outdated', code: 12003),
        const NebulaApiException('rate limited', code: 40002),
        const NebulaHttpException('rate limited', statusCode: 429),
        const NebulaHttpException('limiter unavailable', statusCode: 503),
      ];
      for (final Object error in errors) {
        final BootstrapRequest request = fixtureBootstrapRequest();
        final FakeTransport transport = FakeTransport()
          ..enqueueError(error)
          ..enqueue(FakeTransport.ok(bootstrapSuccessData(request)));
        await expectLater(
          NebulaBootstrapClient(transport: transport).bootstrap(request),
          throwsA(same(error)),
          reason: '$error',
        );
        expect(transport.requests, hasLength(1), reason: '$error');
        expect(transport.pendingCount, 1, reason: '$error');
      }
    });

    test('response identity mismatch is rejected and never retried', () async {
      final BootstrapRequest request = fixtureBootstrapRequest();
      final Map<String, Object?> wrong = bootstrapSuccessData(request)
        ..['request_id'] = 'different-request';
      final FakeTransport transport = FakeTransport()
        ..enqueue(FakeTransport.ok(wrong))
        ..enqueue(FakeTransport.ok(bootstrapSuccessData(request)));

      await expectLater(
        NebulaBootstrapClient(transport: transport).bootstrap(request),
        throwsFormatException,
      );
      expect(transport.requests, hasLength(1));
      expect(transport.pendingCount, 1);
    });

    test('pre-cancelled request sends no network call', () async {
      final NebulaCancellationToken token = NebulaCancellationToken()..cancel();
      final FakeTransport transport = FakeTransport();
      await expectLater(
        NebulaBootstrapClient(transport: transport).bootstrap(
          fixtureBootstrapRequest(),
          cancellationToken: token,
        ),
        throwsA(isA<NebulaCancelledException>()),
      );
      expect(transport.requests, isEmpty);
    });
  });

  group('classifyBootstrapError', () {
    test('50001 is server failure, never an authentication fallback', () {
      const NebulaApiException error = NebulaApiException(
        'server',
        code: 50001,
        requestId: 'r',
      );
      expect(
        classifyBootstrapError(error),
        NebulaBootstrapErrorCategory.serverFailure,
      );
      expect(classifyNebulaError(error), NebulaErrorCategory.server);
    });

    test('maps frozen bootstrap categories without session semantics', () {
      expect(
        classifyBootstrapError(
          const NebulaApiException('invalid', code: 12001),
        ),
        NebulaBootstrapErrorCategory.invalidInstallation,
      );
      expect(
        classifyBootstrapError(
          const NebulaApiException('bad request', code: 30001),
        ),
        NebulaBootstrapErrorCategory.invalidRequest,
      );
      expect(
        classifyBootstrapError(
          const NebulaHttpException('rate', statusCode: 429),
        ),
        NebulaBootstrapErrorCategory.rateLimited,
      );
      expect(
        classifyBootstrapError(
          const NebulaHttpException('limiter', statusCode: 503),
        ),
        NebulaBootstrapErrorCategory.temporarilyUnavailable,
      );
      expect(
        classifyBootstrapError(const FormatException('bad response')),
        NebulaBootstrapErrorCategory.invalidResponse,
      );
      expect(
        classifyBootstrapError(ArgumentError('bad request')),
        NebulaBootstrapErrorCategory.invalidRequest,
      );
    });
  });
}
