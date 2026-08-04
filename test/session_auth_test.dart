import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

/// Controllable fake [NebulaTransport] for the F1-02 auth capability tests.
///
/// It never touches the network: it echoes JSON envelopes or throws the
/// exception types the real [HttpTransport] would surface, so the auth layer's
/// error mapping, single-flight refresh, proof attachment and storage wiring can
/// be exercised deterministically.
class _FakeTransport implements NebulaTransport {
  _FakeTransport({
    this.errorCode,
    this.throwTimeout = false,
    this.throwCancel = false,
    this.loginFails = false,
    this.logoutFails = false,
  });

  /// When set, the login endpoint returns this business code as an envelope
  /// error ([NebulaApiException]).
  final int? errorCode;
  final bool throwTimeout;
  final bool throwCancel;
  final bool loginFails;
  final bool logoutFails;

  final List<NebulaRequest> requests = <NebulaRequest>[];

  int get refreshCount =>
      requests.where((NebulaRequest r) => r.path.endsWith('/refresh')).length;
  int get loginCount =>
      requests.where((NebulaRequest r) => r.path.endsWith('/login')).length;
  int get logoutCount =>
      requests.where((NebulaRequest r) => r.path.endsWith('/logout')).length;

  NebulaRequest get lastRefresh =>
      requests.lastWhere((NebulaRequest r) => r.path.endsWith('/refresh'));
  NebulaRequest get lastLogin =>
      requests.lastWhere((NebulaRequest r) => r.path.endsWith('/login'));

  @override
  Future<NebulaResponse> send(NebulaRequest request) async {
    requests.add(request);
    if (throwTimeout) throw const NebulaTimeoutException('timeout');
    if (throwCancel) throw const NebulaCancelledException();

    if (request.path.endsWith('/login')) {
      if (errorCode != null) {
        throw NebulaApiException(
          'business error',
          code: errorCode!,
          requestId: 'req-err',
        );
      }
      if (loginFails) {
        throw const NebulaHttpException('connection refused',
            statusCode: 503, requestId: 'req-503');
      }
      return const NebulaResponse(
        statusCode: 200,
        data: <String, Object?>{'access_token': 'a-login', 'refresh_token': 'r-login'},
        requestId: 'req-login',
      );
    }
    if (request.path.endsWith('/refresh')) {
      return const NebulaResponse(
        statusCode: 200,
        data: <String, Object?>{
          'access_token': 'a-refresh',
          'refresh_token': 'r-refresh'
        },
        requestId: 'req-refresh',
      );
    }
    if (request.path.endsWith('/logout')) {
      if (logoutFails) {
        throw const NebulaHttpException('logout failed',
            statusCode: 503, requestId: 'req-logout-503');
      }
      return const NebulaResponse(
        statusCode: 200,
        data: <String, Object?>{},
        requestId: 'req-logout',
      );
    }
    return const NebulaResponse(
      statusCode: 200,
      data: <String, Object?>{},
      requestId: 'req-other',
    );
  }
}

const String _ns = 'staging:com.example.a';

NebulaSessionAuth _auth(_FakeTransport transport, {SecureTokenStore? store}) =>
    NebulaSessionAuth(
      options: NebulaOptions(
        appId: 'com.example.a',
        baseUri: Uri.parse('http://localhost'),
        environment: NebulaEnvironment.staging,
      ),
      transport: transport,
      tokenStore: store ?? InMemoryTokenStore(),
      proofSigner: RecordingProofSigner(),
      installationToken: () async => 'inst-123',
    );

void main() {
  group('NebulaSessionAuth.login (docs/08 §4.3/§6)', () {
    test('success enters AUTHENTICATED and persists the refresh token',
        () async {
      final transport = _FakeTransport();
      final store = InMemoryTokenStore();
      final auth = _auth(transport, store: store);

      await auth.onInstallationBootstrapSucceeded();
      await auth.login(
        const NebulaLoginRequest.phone(phone: '13800000000', code: '123456'),
      );

      expect(auth.state, NebulaSessionState.authenticated);
      expect(await store.read(namespace: _ns, key: tokenKeyRefresh), 'r-login');
      expect(transport.loginCount, 1);

      // Proof headers attached on the wire.
      final NebulaRequest req = transport.lastLogin;
      expect(req.headers['X-Installation-Token'], 'inst-123');
      expect(req.headers['X-Device-Proof'], isNotEmpty);
      expect(req.body, <String, Object?>{
        'provider': 'PHONE',
        'phone': '13800000000',
        'code': '123456',
      });
    });

    test('business error maps to a typed NebulaSessionError with code/requestId',
        () async {
      final transport = _FakeTransport(errorCode: 12004);
      final auth = _auth(transport);

      await auth.onInstallationBootstrapSucceeded();
      await expectLater(
        auth.login(
          const NebulaLoginRequest.phone(phone: '13800000000', code: '123456'),
        ),
        throwsA(
          isA<TemporarilyUnavailableError>()
              .having((e) => e.code, 'code', 12004)
              .having((e) => e.requestId, 'requestId', 'req-err'),
        ),
      );
      // Failed login -> RECOVERABLE_FAILURE, not stuck authenticating.
      expect(auth.state, NebulaSessionState.recoverableFailure);
    });

    test('transport 503 maps to recoverable failure', () async {
      final transport = _FakeTransport(loginFails: true);
      final auth = _auth(transport);
      await auth.onInstallationBootstrapSucceeded();
      await expectLater(
        auth.login(
          const NebulaLoginRequest.phone(phone: '13800000000', code: '123456'),
        ),
        throwsA(isA<TemporarilyUnavailableError>()),
      );
      expect(auth.state, NebulaSessionState.recoverableFailure);
    });

    test('invalid request (empty code) is rejected before any network call',
        () async {
      final transport = _FakeTransport();
      final auth = _auth(transport);
      await auth.onInstallationBootstrapSucceeded();
      await expectLater(
        auth.login(const NebulaLoginRequest.phone(phone: '138', code: '')),
        throwsA(isA<ArgumentError>()),
      );
      expect(transport.loginCount, 0);
    });
  });

  group('NebulaSessionAuth.restoreSession + single-flight refresh (docs/08 §6.3)', () {
    test('returns false when no refresh token is stored', () async {
      final auth = _auth(_FakeTransport());
      expect(await auth.restoreSession(), isFalse);
      expect(auth.state, NebulaSessionState.uninitialized);
    });

    test('restores to AUTHENTICATED with a placeholder access token', () async {
      final store = InMemoryTokenStore();
      await store.write(namespace: _ns, key: tokenKeyRefresh, value: 'r-saved');
      final auth = _auth(_FakeTransport(), store: store);

      expect(await auth.restoreSession(), isTrue);
      expect(auth.state, NebulaSessionState.authenticated);
      // Access token is memory-only, so it is a placeholder until first use.
      expect(auth.accessToken, '');
    });

    test('concurrent getAccessToken after restore -> ONE refresh HTTP call',
        () async {
      final store = InMemoryTokenStore();
      await store.write(namespace: _ns, key: tokenKeyRefresh, value: 'r-saved');
      final transport = _FakeTransport();
      final auth = _auth(transport, store: store);

      await auth.restoreSession();
      expect(auth.state, NebulaSessionState.authenticated);

      // 10 parallel callers all need a token: the single-flight refresh must
      // collapse them into exactly one network request (F1 acceptance: 401
      // storm issues one refresh).
      final List<String> results = await Future.wait(
        List<Future<String>>.generate(10, (_) => auth.getAccessToken()),
      );

      expect(transport.refreshCount, 1,
          reason: 'single-flight: exactly one refresh request');
      expect(results.every((String t) => t == 'a-refresh'), isTrue,
          reason: 'all callers share the same refreshed token');
      // Refresh token rotated in place in secure storage.
      expect(await store.read(namespace: _ns, key: tokenKeyRefresh), 'r-refresh');
      // Proof headers attached on the single refresh request.
      expect(transport.lastRefresh.headers['X-Device-Proof'], isNotEmpty);
      expect(transport.lastRefresh.headers['X-Installation-Token'], 'inst-123');
    });

    test('getAccessToken returns cached token without refreshing when present',
        () async {
      final transport = _FakeTransport();
      final auth = _auth(transport);
      await auth.onInstallationBootstrapSucceeded();
      await auth.login(
        const NebulaLoginRequest.phone(phone: '13800000000', code: '123456'),
      );
      // Now authenticated with a real in-memory access token.
      final String first = await auth.getAccessToken();
      expect(first, 'a-login');
      expect(transport.refreshCount, 0,
          reason: 'no refresh while a valid access token is held');
    });
  });

  group('NebulaSessionAuth.signOut (docs/08 §6.4)', () {
    test('clears local state and calls remote logout', () async {
      final transport = _FakeTransport();
      final store = InMemoryTokenStore();
      final auth = _auth(transport, store: store);
      await auth.onInstallationBootstrapSucceeded();
      await auth.login(
        const NebulaLoginRequest.phone(phone: '13800000000', code: '123456'),
      );

      await auth.signOut();

      expect(auth.state, NebulaSessionState.installationActive);
      expect(auth.accessToken, isNull);
      expect(await store.read(namespace: _ns, key: tokenKeyRefresh), isNull);
      expect(transport.logoutCount, 1);
      // Logout carries the user access token as a bearer credential.
      expect(transport.requests
          .lastWhere((r) => r.path.endsWith('/logout'))
          .headers['Authorization'],
          'Bearer a-login');
    });

    test('clears local state even when remote logout fails', () async {
      final transport = _FakeTransport(logoutFails: true);
      final store = InMemoryTokenStore();
      final auth = _auth(transport, store: store);
      await auth.onInstallationBootstrapSucceeded();
      await auth.login(
        const NebulaLoginRequest.phone(phone: '13800000000', code: '123456'),
      );

      // Remote call throws, but signOut must not propagate it and must still
      // clear local state (docs/08 §6.4).
      await auth.signOut();
      expect(await store.read(namespace: _ns, key: tokenKeyRefresh), isNull);
      expect(auth.state, NebulaSessionState.installationActive);
      expect(transport.logoutCount, 1);
    });
  });

  group('NebulaSessionAuth resilient error mapping', () {
    test('timeout during login -> recoverable failure', () async {
      final transport = _FakeTransport(throwTimeout: true);
      final auth = _auth(transport);
      await auth.onInstallationBootstrapSucceeded();
      await expectLater(
        auth.login(
          const NebulaLoginRequest.phone(phone: '13800000000', code: '123456'),
        ),
        throwsA(isA<TemporarilyUnavailableError>()),
      );
      expect(auth.state, NebulaSessionState.recoverableFailure);
    });

    test('cancellation during login -> recoverable failure (no hang)',
        () async {
      final transport = _FakeTransport(throwCancel: true);
      final auth = _auth(transport);
      await auth.onInstallationBootstrapSucceeded();
      await expectLater(
        auth.login(
          const NebulaLoginRequest.phone(phone: '13800000000', code: '123456'),
        ),
        throwsA(isA<TemporarilyUnavailableError>()),
      );
      expect(auth.state, NebulaSessionState.recoverableFailure);
    });
  });
}
