import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

NebulaMobileObservability _create(FakeTransport transport) =>
    NebulaMobileObservability.create(
      options: NebulaOptions(
        appId: 'app-lifecycle',
        baseUri: Uri.parse('https://example.invalid'),
        environment: NebulaEnvironment.staging,
      ),
      transport: transport,
      proofSigner: RecordingProofSigner(),
      installationToken: () async => 'installation-token',
      recoverInstallationTrust: () async => true,
      persistentStorage: InMemoryCacheStorage(),
    );

NebulaResponse _success(NebulaRequest request) {
  if (request.path.endsWith('/api/v1/mobile/analytics/batches')) {
    final Map<String, Object?> body = request.body! as Map<String, Object?>;
    return NebulaResponse(
      statusCode: 200,
      data: <String, Object?>{
        'batch_id': body['batch_id'],
        'accepted_events': (body['events']! as List<Object?>).length,
        'duplicate': false,
        'ingested_at': 1786935600,
      },
    );
  }
  if (request.path.endsWith('/api/v1/mobile/error-reports')) {
    final Map<String, Object?> body = request.body! as Map<String, Object?>;
    final List<Object?> reports = body['reports']! as List<Object?>;
    return NebulaResponse(
      statusCode: 200,
      data: <String, Object?>{
        'accepted': <Object?>[
          for (final Object? item in reports)
            <String, Object?>{
              'report_id': (item! as Map<String, Object?>)['report_id'],
              'ingested_at': 1786935600,
              'duplicate': false,
            },
        ],
        'rejected': <Object?>[],
        'defer_remaining': false,
        'retry_after_seconds': null,
      },
    );
  }
  throw StateError('unexpected path ${request.path}');
}

Future<void> _enqueueWork(NebulaMobileObservability observability) async {
  await observability.analytics.track(
    NebulaAnalyticsEvent(
      name: 'screen_view',
      privacy: NebulaEventPrivacy.anonymous,
      properties: const <String, Object?>{'page': 'home'},
    ),
  );
  await observability.errorReporting.reportCaughtError(
    errorType: 'StateError',
    safeMessage: 'operation failed',
    stackTrace: StackTrace.current,
  );
}

void main() {
  test('empty lifecycle flush performs zero network', () async {
    final FakeTransport transport = FakeTransport();
    final NebulaMobileObservability observability = _create(transport);

    await observability.flush();

    expect(transport.requests, isEmpty);
  });

  test('analytics failure does not suppress Error Reporting delivery',
      () async {
    final FakeTransport transport = FakeTransport();
    for (int i = 0; i < 2; i++) {
      transport.enqueueHandler((NebulaRequest request) {
        if (request.path.endsWith('/api/v1/mobile/analytics/batches')) {
          throw const NebulaApiException('invalid analytics', code: 30001);
        }
        return _success(request);
      });
    }
    final NebulaMobileObservability observability = _create(transport);
    await _enqueueWork(observability);

    await observability.flush();

    expect(transport.requests, hasLength(2));
    expect(
      transport.requests.map((NebulaRequest request) => request.path).toSet(),
      <String>{
        '/api/v1/mobile/analytics/batches',
        '/api/v1/mobile/error-reports',
      },
    );
  });

  test('concurrent lifecycle flushes reuse domain in-flight guards', () async {
    final FakeTransport transport = FakeTransport();
    transport
      ..enqueueHandler(_success)
      ..enqueueHandler(_success);
    final NebulaMobileObservability observability = _create(transport);
    await _enqueueWork(observability);

    await Future.wait<void>(<Future<void>>[
      observability.flush(),
      observability.flush(),
    ]);

    expect(transport.requests, hasLength(2));
    expect(
      transport.requests.map((NebulaRequest request) => request.path).toSet(),
      <String>{
        '/api/v1/mobile/analytics/batches',
        '/api/v1/mobile/error-reports',
      },
    );
  });
}
