import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

/// F1-05 kernel integration: the whole auth kernel (NebulaSessionAuth + session
/// state machine + proof headers) driven by the scriptable [FakeTransport] —
/// no real backend, no network. Proves the F1 exit criteria:
/// "无真实后端也能用 fake transport 验证所有异常路径；并发 refresh 只有一次网络调用."
void main() {
  final SessionEndpoints endpoints = const SessionEndpoints();
  const String ns = 'staging:com.example.a';

  NebulaSessionAuth buildAuth(
    FakeTransport transport, {
    InMemoryTokenStore? store,
  }) {
    return NebulaSessionAuth(
      options: NebulaOptions(
        appId: 'com.example.a',
        baseUri: Uri.parse('https://api.example.com'),
        environment: NebulaEnvironment.staging,
      ),
      transport: transport,
      tokenStore: store ?? InMemoryTokenStore(),
      proofSigner: RecordingProofSigner(),
      installationToken: () async => 'inst-token-1',
    );
  }

  Map<String, Object?> tokens(String access, String refresh) =>
      <String, Object?>{'access_token': access, 'refresh_token': refresh};

  Future<void> install(NebulaSessionAuth auth) =>
      auth.onInstallationBootstrapSucceeded();

  group('kernel: login via FakeTransport', () {
    test('login success -> authenticated, refresh persisted, exactly 1 request',
        () async {
      final FakeTransport transport = FakeTransport()
        ..enqueue(FakeTransport.ok(tokens('a1', 'r1')));
      final InMemoryTokenStore store = InMemoryTokenStore();
      final NebulaSessionAuth auth = buildAuth(transport, store: store);
      await install(auth);

      await auth
          .login(NebulaLoginRequest.phone(phone: '13800000000', code: '123456'));

      expect(auth.state, NebulaSessionState.authenticated);
      expect(auth.accessToken, 'a1');
      expect(await store.read(namespace: ns, key: tokenKeyRefresh), 'r1');
      expect(transport.requests, hasLength(1));
      expect(transport.requests.single.path, endpoints.login);
      expect(transport.pendingCount, 0);
    });

    test('login business error -> typed SessionRevokedError, recoverable',
        () async {
      final FakeTransport transport = FakeTransport()
        ..enqueueError(const NebulaApiException('revoked', code: 12002));
      final NebulaSessionAuth auth = buildAuth(transport);
      await install(auth);

      await expectLater(
        auth.login(
            NebulaLoginRequest.phone(phone: '13800000000', code: '123456')),
        throwsA(
          isA<SessionRevokedError>().having((e) => e.code, 'code', 12002),
        ),
      );
      expect(auth.state, NebulaSessionState.recoverableFailure);
    });

    test('login rate limited -> RateLimitedError', () async {
      final FakeTransport transport = FakeTransport()
        ..enqueueError(const NebulaApiException('rl', code: 40002));
      final NebulaSessionAuth auth = buildAuth(transport);
      await install(auth);

      await expectLater(
        auth.login(
            NebulaLoginRequest.phone(phone: '13800000000', code: '123456')),
        throwsA(isA<RateLimitedError>()),
      );
    });

    test('login HTTP 5xx -> TemporarilyUnavailableError', () async {
      final FakeTransport transport = FakeTransport()
        ..enqueueError(const NebulaHttpException('down', statusCode: 503));
      final NebulaSessionAuth auth = buildAuth(transport);
      await install(auth);

      await expectLater(
        auth.login(
            NebulaLoginRequest.phone(phone: '13800000000', code: '123456')),
        throwsA(isA<TemporarilyUnavailableError>()),
      );
      expect(auth.state, NebulaSessionState.recoverableFailure);
    });

    test('login timeout -> TemporarilyUnavailableError', () async {
      final FakeTransport transport = FakeTransport()
        ..enqueueError(const NebulaTimeoutException('slow'));
      final NebulaSessionAuth auth = buildAuth(transport);
      await install(auth);

      await expectLater(
        auth.login(
            NebulaLoginRequest.phone(phone: '13800000000', code: '123456')),
        throwsA(isA<TemporarilyUnavailableError>()),
      );
    });

    test('login cancellation -> recoverable TemporarilyUnavailableError',
        () async {
      final FakeTransport transport = FakeTransport()
        ..enqueueError(const NebulaCancelledException());
      final NebulaSessionAuth auth = buildAuth(transport);
      await install(auth);

      await expectLater(
        auth.login(
            NebulaLoginRequest.phone(phone: '13800000000', code: '123456')),
        throwsA(isA<TemporarilyUnavailableError>()),
      );
      expect(auth.state, NebulaSessionState.recoverableFailure);
    });

    test('unexpected transport failure -> recoverable state, raw error surfaced',
        () async {
      // `login` maps unexpected errors for the state machine (RECOVERABLE_FAILURE)
      // but rethrows the original error to the caller (never a silent success).
      final FakeTransport transport =
          FakeTransport()..enqueueError(Exception('boom'));
      final NebulaSessionAuth auth = buildAuth(transport);
      await install(auth);

      await expectLater(
        auth.login(
            NebulaLoginRequest.phone(phone: '13800000000', code: '123456')),
        throwsA(isA<Exception>()),
      );
      expect(auth.state, NebulaSessionState.recoverableFailure);
    });
  });

  group('kernel: restore + single-flight refresh (401 storm)', () {
    test('10 concurrent getAccessToken -> exactly 1 refresh network call',
        () async {
      final InMemoryTokenStore store = InMemoryTokenStore();
      await store.write(namespace: ns, key: tokenKeyRefresh, value: 'r-saved');
      final FakeTransport transport = FakeTransport()
        ..enqueue(FakeTransport.ok(tokens('a2', 'r2')));
      final NebulaSessionAuth auth = buildAuth(transport, store: store);

      expect(await auth.restoreSession(), isTrue);
      expect(auth.state, NebulaSessionState.authenticated);
      // Restored sessions hold a memory placeholder; the access token is
      // lazily refreshed on first use (docs/08 §6.2).
      expect(auth.accessToken, isEmpty);

      final List<String> results = await Future.wait(
        List<Future<String>>.generate(10, (_) => auth.getAccessToken()),
      );
      expect(results, everyElement('a2'));

      final int refreshCalls =
          transport.requests.where((r) => r.path == endpoints.refresh).length;
      expect(refreshCalls, 1,
          reason: '401 storm must trigger exactly one refresh request');
      expect(await store.read(namespace: ns, key: tokenKeyRefresh), 'r2');
      expect(transport.pendingCount, 0);
    });

    test('refresh revoked -> session revoked, local token cleared', () async {
      final InMemoryTokenStore store = InMemoryTokenStore();
      await store.write(namespace: ns, key: tokenKeyRefresh, value: 'r-saved');
      final FakeTransport transport = FakeTransport()
        ..enqueueError(const NebulaApiException('reuse', code: 12002));
      final NebulaSessionAuth auth = buildAuth(transport, store: store);
      await auth.restoreSession();

      await expectLater(
        auth.getAccessToken(),
        throwsA(isA<SessionRevokedError>()),
      );
      expect(auth.state, NebulaSessionState.revoked);
      expect(await store.read(namespace: ns, key: tokenKeyRefresh), isNull);
    });

    test('refresh timeout -> recoverable, refresh token preserved', () async {
      final InMemoryTokenStore store = InMemoryTokenStore();
      await store.write(namespace: ns, key: tokenKeyRefresh, value: 'r-saved');
      final FakeTransport transport = FakeTransport()
        ..enqueueError(const NebulaTimeoutException('slow'));
      final NebulaSessionAuth auth = buildAuth(transport, store: store);
      await auth.restoreSession();

      await expectLater(
        auth.getAccessToken(),
        throwsA(isA<TemporarilyUnavailableError>()),
      );
      expect(auth.state, NebulaSessionState.recoverableFailure);
      // Only revocation clears the persisted token; a transient failure keeps
      // it for the next bounded retry.
      expect(await store.read(namespace: ns, key: tokenKeyRefresh), 'r-saved');
    });
  });

  group('kernel: sign-out', () {
    test('local state cleared even when remote logout fails (docs/08 §6.4)',
        () async {
      final FakeTransport transport = FakeTransport()
        ..enqueue(FakeTransport.ok(tokens('a1', 'r1')))
        ..enqueueError(const NebulaApiException('logout down', code: 50001));
      final InMemoryTokenStore store = InMemoryTokenStore();
      final NebulaSessionAuth auth = buildAuth(transport, store: store);
      await install(auth);
      await auth
          .login(NebulaLoginRequest.phone(phone: '13800000000', code: '123456'));

      await auth.signOut();

      expect(auth.state, NebulaSessionState.installationActive);
      expect(await store.read(namespace: ns, key: tokenKeyRefresh), isNull);
      expect(
        transport.requests.where((r) => r.path == endpoints.logout),
        hasLength(1),
        reason: 'remote logout must be attempted before local cleanup',
      );
    });
  });

  group('FakeTransport contract', () {
    test('unexpected request throws StateError (exact assertions)', () async {
      final FakeTransport transport = FakeTransport();
      await expectLater(
        transport.send(
            NebulaRequest(method: NebulaHttpMethod.get, path: '/x')),
        throwsStateError,
      );
      expect(transport.requests, hasLength(1));
      expect(transport.pendingCount, 0);
    });

    test('handlers receive the request and can adapt the response', () async {
      final FakeTransport transport = FakeTransport()
        ..enqueueHandler((NebulaRequest request) async {
          return FakeTransport.ok(<String, Object?>{
            'echo': request.path,
            'q': request.query['a'],
          });
        });

      final NebulaResponse resp = await transport.send(NebulaRequest(
        method: NebulaHttpMethod.get,
        path: '/echo',
        query: const <String, String>{'a': '1'},
      ));
      expect(resp.data, <String, Object?>{'echo': '/echo', 'q': '1'});

      // Each send consumes exactly one queued handler (FIFO).
      transport.enqueueHandler(
        (NebulaRequest _) async =>
            throw const NebulaApiException('nope', code: 401),
      );
      await expectLater(
        transport.send(
            NebulaRequest(method: NebulaHttpMethod.get, path: '/fail')),
        throwsA(isA<NebulaApiException>()),
      );
      expect(transport.requests, hasLength(2));
      expect(transport.pendingCount, 0);
    });
  });
}
