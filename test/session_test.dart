import 'dart:async';

import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

/// Fake backend recording every refresh call and its request ID.
class _FakeRefreshBackend {
  final List<String> requestIds = <String>[];
  int _calls = 0;
  Completer<SessionTokenPair>? _gate;

  /// If set, refresh blocks until the completer completes (for concurrency
  /// and cancellation tests).
  Completer<SessionTokenPair> get gate =>
      _gate ??= Completer<SessionTokenPair>();

  Future<SessionTokenPair> run(String refreshRequestId) {
    _calls += 1;
    requestIds.add(refreshRequestId);
    final Completer<SessionTokenPair>? g = _gate;
    if (g != null && !g.isCompleted) {
      return g.future;
    }
    return Future<SessionTokenPair>.value(
      SessionTokenPair(
          accessToken: 'access-$_calls', refreshToken: 'refresh-$_calls'),
    );
  }

  int get callCount => _calls;
}

/// Recording listener Port.
class _RecordingListener implements SessionStateListener {
  final List<NebulaSessionState> seen = <NebulaSessionState>[];

  @override
  void onSessionState(NebulaSessionState state) {
    seen.add(state);
  }
}

void main() {
  late InMemoryTokenStore store;
  late _FakeRefreshBackend backend;
  const ns = 'staging:com.example.a';

  setUp(() {
    store = InMemoryTokenStore();
    backend = _FakeRefreshBackend();
  });

  NebulaSession session({RemoteLogout? remoteLogout}) => NebulaSession(
        namespace: ns,
        tokenStore: store,
        refreshExecutor: backend.run,
        remoteLogout: remoteLogout,
      );

  Future<void> bootstrapToAuthenticated(NebulaSession s) async {
    await s.beginBootstrap();
    await s.onBootstrapSucceeded();
    await s.beginAuthenticating();
    await s.onAuthenticated(
      const SessionTokenPair(accessToken: 'a0', refreshToken: 'r0'),
    );
  }

  group('state machine serialization (docs/08 §7)', () {
    test('happy path reaches AUTHENTICATED and persists refresh token',
        () async {
      final s = session();
      final listener = _RecordingListener();
      final events = <NebulaSessionEvent>[];
      s.events.listen(events.add);
      // Rebuild with listener (listeners are fixed at construction).
      final s2 = NebulaSession(
        namespace: ns,
        tokenStore: store,
        refreshExecutor: backend.run,
        listeners: [listener],
      );
      s2.events.listen(events.add);

      await bootstrapToAuthenticated(s2);
      expect(s2.state, NebulaSessionState.authenticated);
      expect(listener.seen.last, NebulaSessionState.authenticated);
      expect(
        await store.read(namespace: ns, key: tokenKeyRefresh),
        'r0',
      );
      expect(
        events.whereType<SessionStateChanged>().map((e) => e.state),
        containsAll(<NebulaSessionState>[
          NebulaSessionState.bootstrapping,
          NebulaSessionState.installationActive,
          NebulaSessionState.authenticating,
          NebulaSessionState.authenticated,
        ]),
      );
      s.dispose();
      s2.dispose();
    });

    test('rejects illegal transitions with StateError', () async {
      final s = session();
      await expectLater(
          s.onAuthenticated(
              const SessionTokenPair(accessToken: 'a', refreshToken: 'r')),
          throwsStateError);
      await s.beginBootstrap();
      // bootstrapping -> authenticated is illegal.
      await expectLater(
        s.onAuthenticated(
            const SessionTokenPair(accessToken: 'a', refreshToken: 'r')),
        throwsStateError,
      );
      s.dispose();
    });

    test('transitions are serialized: overlapping calls do not interleave',
        () async {
      final s = session();
      backend.gate; // ensure gate exists
      final results = await Future.wait<Object?>([
        s.beginBootstrap().then((_) => null),
        s.onBootstrapSucceeded().then((_) => null),
        s.beginAuthenticating().then((_) => null),
        s
            .onAuthenticated(
                const SessionTokenPair(accessToken: 'a', refreshToken: 'r'))
            .then((_) => null),
      ]);
      expect(results, hasLength(4));
      expect(s.state, NebulaSessionState.authenticated);
      s.dispose();
    });

    test(
        'recoverable failure then retry (Any -> RECOVERABLE_FAILURE -> BOOTSTRAPPING)',
        () async {
      final s = session();
      await bootstrapToAuthenticated(s);
      await s.onFailure(const AuthenticationRequiredError());
      expect(s.state, NebulaSessionState.recoverableFailure);
      await s.retryAfterFailure();
      expect(s.state, NebulaSessionState.bootstrapping);
      s.dispose();
    });
  });

  group('single-flight refresh (docs/08 §6.3)', () {
    test('concurrent callers await the same refresh future', () async {
      final s = session();
      await bootstrapToAuthenticated(s);
      backend.gate; // force the completer to exist before refresh starts

      final f1 = s.refresh();
      final f2 = s.refresh();
      final f3 = s.refresh();
      expect(identical(f1, f2), isTrue);
      expect(identical(f2, f3), isTrue);
      // Let the queued refresh op run and block on the gate before completing.
      await Future<void>.delayed(Duration.zero);

      backend.gate.complete(
        const SessionTokenPair(accessToken: 'a1', refreshToken: 'r1'),
      );
      final pair = await f1;
      expect(pair.refreshToken, 'r1');
      expect(backend.callCount, 1);
      expect(s.state, NebulaSessionState.authenticated);
      expect(
        await store.read(namespace: ns, key: tokenKeyRefresh),
        'r1', // rotated in place, no new row
      );
      s.dispose();
    });

    test('one refresh request ID per rotation (ambiguity retry reuses it)',
        () async {
      final s = session();
      await bootstrapToAuthenticated(s);
      await s.refresh();
      await s.refresh();
      expect(backend.requestIds, hasLength(2));
      // Each rotation gets exactly one ID; the executor reuses it on retries.
      expect(backend.requestIds.toSet(), hasLength(2));
      s.dispose();
    });

    test('concurrent 401 -> single-flight refresh recovers', () async {
      final s = session();
      await bootstrapToAuthenticated(s);

      // Two parallel 401-driven refresh triggers must collapse into one call.
      final results = await Future.wait([
        s.refresh(),
        s.refresh(),
      ]);
      expect(backend.callCount, 1);
      expect(results[0].accessToken, results[1].accessToken);
      expect(s.state, NebulaSessionState.authenticated);
      s.dispose();
    });

    test('refresh reuse revokes the family and emits a security alert',
        () async {
      final s = session();
      await bootstrapToAuthenticated(s);

      final alerts = <SecurityAlert>[];
      s.events.listen((e) {
        if (e is SecurityAlert) alerts.add(e);
      });

      // First refresh succeeds, then a SessionRevokedError (reuse) is raised.
      backend.gate; // force gate so the first refresh blocks
      backend.gate.complete(
          const SessionTokenPair(accessToken: 'a1', refreshToken: 'r1'));
      await s.refresh();
      final s2 = NebulaSession(
        namespace: ns,
        tokenStore: store,
        refreshExecutor: (id) async {
          throw const SessionRevokedError(code: 12002);
        },
      );
      final alerts2 = <SecurityAlert>[];
      s2.events.listen((e) {
        if (e is SecurityAlert) alerts2.add(e);
      });
      await bootstrapToAuthenticated(s2);
      await expectLater(
        s2.refresh(),
        throwsA(isA<SessionRevokedError>()),
      );
      expect(s2.state, NebulaSessionState.revoked);
      expect(alerts2, hasLength(1)); // family-revoke security alert on s2
      expect(
        await store.read(namespace: ns, key: tokenKeyRefresh),
        isNull, // family revoked: local refresh cleared
      );
      s.dispose();
      s2.dispose();
    });

    test('refresh failure -> RECOVERABLE_FAILURE, can retry', () async {
      final s = session();
      await bootstrapToAuthenticated(s);

      final s2 = NebulaSession(
        namespace: ns,
        tokenStore: store,
        refreshExecutor: (id) async {
          throw const TemporarilyUnavailableError(code: 12004);
        },
      );
      await bootstrapToAuthenticated(s2);
      await expectLater(
          s2.refresh(), throwsA(isA<TemporarilyUnavailableError>()));
      expect(s2.state, NebulaSessionState.recoverableFailure);
      s.dispose();
      s2.dispose();
    });

    test('cancellation: revoke during in-flight refresh drops the result',
        () async {
      final s = session();
      await bootstrapToAuthenticated(s);
      backend.gate; // force the completer to exist

      final f = s.refresh();
      await Future<void>.delayed(Duration.zero); // refresh op blocks on gate
      await s.onRevoked('server revoked installation'); // refreshing -> revoked
      expect(s.state, NebulaSessionState.revoked);

      backend.gate.complete(
        const SessionTokenPair(accessToken: 'aX', refreshToken: 'rX'),
      );
      await expectLater(f, throwsA(isA<InvalidInstallationError>()));
      // Revoked result never persisted.
      expect(await store.read(namespace: ns, key: tokenKeyRefresh), isNull);
      // REVOKED -> BOOTSTRAPPING is the only legal way forward.
      await s.beginBootstrap();
      expect(s.state, NebulaSessionState.bootstrapping);
      s.dispose();
    });
  });

  group('password reset cleanup', () {
    test('authenticated user scope is cleared without remote logout', () async {
      var logoutCalls = 0;
      final s = session(remoteLogout: () async => logoutCalls++);
      await bootstrapToAuthenticated(s);

      await s.onPasswordResetSucceeded();

      expect(s.state, NebulaSessionState.installationActive);
      expect(s.accessToken, isNull);
      expect(await store.read(namespace: ns, key: tokenKeyRefresh), isNull);
      expect(logoutCalls, 0);
      s.dispose();
    });

    test('installation-active state remains installation-active', () async {
      final s = session();
      await s.beginBootstrap();
      await s.onBootstrapSucceeded();

      await s.onPasswordResetSucceeded();

      expect(s.state, NebulaSessionState.installationActive);
      s.dispose();
    });
  });

  group('logout (docs/08 §6.4)', () {
    test('clears local state even when remote logout fails', () async {
      final s = session(
        remoteLogout: () async => throw Exception('network down'),
      );
      await bootstrapToAuthenticated(s);

      await s.signOut();
      expect(s.state, NebulaSessionState.installationActive);
      expect(s.accessToken, isNull);
      expect(await store.read(namespace: ns, key: tokenKeyRefresh), isNull);
      s.dispose();
    });

    test('repeated logout succeeds (idempotent from INSTALLATION_ACTIVE)',
        () async {
      final s = session();
      await bootstrapToAuthenticated(s);
      await s.signOut();
      await expectLater(s.signOut(), completes); // already installationActive
      expect(s.state, NebulaSessionState.installationActive);
      s.dispose();
    });
  });

  group('environment switch (docs/08 §7)', () {
    test('different environment/App namespace yields independent sessions',
        () async {
      const nsProd = 'production:com.example.a';

      final sA = NebulaSession(
        namespace: ns,
        tokenStore: store,
        refreshExecutor: backend.run,
      );
      final sB = NebulaSession(
        namespace: nsProd,
        tokenStore: store,
        refreshExecutor: (_) async =>
            const SessionTokenPair(accessToken: 'aP', refreshToken: 'rP'),
      );
      await bootstrapToAuthenticated(sA);

      expect(sB.state, NebulaSessionState.uninitialized);
      // Same store, different namespace: no cross-environment leakage.
      expect(await store.read(namespace: nsProd, key: tokenKeyRefresh), isNull);
      expect(
        await store.read(namespace: ns, key: tokenKeyRefresh),
        'r0',
      );
      sA.dispose();
      sB.dispose();
    });
  });
}
