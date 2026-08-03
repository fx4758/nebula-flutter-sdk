/// User session state machine (FS-02).
///
/// Implements the docs/08 §7 session state machine with the §6.3/§6.4 rules:
///
/// ```text
/// UNINITIALIZED -> BOOTSTRAPPING -> INSTALLATION_ACTIVE
///   -> AUTHENTICATING -> AUTHENTICATED
///   -> REFRESHING -> AUTHENTICATED
///   -> SIGNING_OUT -> INSTALLATION_ACTIVE
/// Any state -> RECOVERABLE_FAILURE
/// Any trusted state -> REVOKED -> BOOTSTRAPPING
/// ```
///
/// Guarantees:
/// - state transitions are serialized per SDK instance (§7);
/// - refresh is single-flight: one refresh Future per session, concurrent
///   callers await it; one refresh request ID reused across ambiguity retries
///   (§6.3);
/// - local logout clears access/refresh even when the network call fails
///   (§6.4);
/// - capability clients observe state through [SessionStateListener]/events,
///   never by reading storage directly (§7);
/// - no global mutable token singleton: all state lives on the instance, and
///   tokens are persisted only via the injected [SecureTokenStore] under the
///   instance namespace.
library;

import 'dart:async';
import 'dart:math';

import 'session_errors.dart';
import 'token_store.dart';

/// Session states (docs/08 §7).
enum NebulaSessionState {
  uninitialized,
  bootstrapping,
  installationActive,
  authenticating,
  authenticated,
  refreshing,
  signingOut,
  recoverableFailure,
  revoked,
}

/// Session events streamed to observers.
sealed class NebulaSessionEvent {
  const NebulaSessionEvent();
}

/// A completed state transition.
final class SessionStateChanged extends NebulaSessionEvent {
  const SessionStateChanged(this.state, {this.reason = ''});

  final NebulaSessionState state;
  final String reason;
}

/// Security-relevant event (e.g. refresh-token reuse revoking the family).
/// Low-cardinality reason only — never tokens, phones or user content.
final class SecurityAlert extends NebulaSessionEvent {
  const SecurityAlert(this.reason);

  final String reason;
}

/// Port through which capability clients receive session state (§7).
///
/// Capability clients MUST NOT read storage directly; they subscribe through
/// this Port (or the [NebulaSession.events] stream).
abstract interface class SessionStateListener {
  void onSessionState(NebulaSessionState state);
}

/// A freshly rotated access/refresh pair.
final class SessionTokenPair {
  const SessionTokenPair({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

/// Executes the server refresh call for a session.
///
/// Receives the single refresh request ID for this rotation — all retries of
/// the same ambiguous network response MUST reuse this ID (§6.3). The runner
/// throws a [NebulaSessionError] to drive state transitions.
typedef RefreshExecutor = Future<SessionTokenPair> Function(
  String refreshRequestId,
);

/// Optional remote logout hook; failures are swallowed (§6.4: local state is
/// cleared even when the network call fails).
typedef RemoteLogout = Future<void> Function();

/// Serialized, single-flight user session state machine (FS-02).
final class NebulaSession {
  NebulaSession({
    required this.namespace,
    required SecureTokenStore tokenStore,
    required this.refreshExecutor,
    this.remoteLogout,
    List<SessionStateListener> listeners = const <SessionStateListener>[],
  })  : _tokenStore = tokenStore,
        _listeners = List<SessionStateListener>.unmodifiable(listeners);

  /// Storage namespace (environment/App scoped, FS-01). Changing environment
  /// or App ID MUST create a new session instance with a new namespace (§7).
  final String namespace;
  final RefreshExecutor refreshExecutor;
  final RemoteLogout? remoteLogout;

  final SecureTokenStore _tokenStore;
  final List<SessionStateListener> _listeners;
  final StreamController<NebulaSessionEvent> _events =
      StreamController<NebulaSessionEvent>.broadcast(sync: true);
  final Random _random = Random.secure();

  NebulaSessionState _state = NebulaSessionState.uninitialized;
  String? _accessToken;
  Future<void> _tail = Future<void>.value();
  Future<SessionTokenPair>? _inflightRefresh;

  NebulaSessionState get state => _state;

  /// The current in-memory access token, or null when unauthenticated.
  String? get accessToken => _accessToken;

  /// Session event stream (§7 event delivery).
  Stream<NebulaSessionEvent> get events => _events.stream;

  /// Serializes every transition per SDK instance (§7: transitions are
  /// serialized; no interleaving of async state changes).
  Future<T> _serialized<T>(Future<T> Function() op) {
    final Future<T> result = _tail.then((_) => op());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  bool _canTransition(NebulaSessionState from, NebulaSessionState to) {
    return switch ((from, to)) {
      (NebulaSessionState.uninitialized, NebulaSessionState.bootstrapping) ||
      (
        NebulaSessionState.bootstrapping,
        NebulaSessionState.installationActive
      ) ||
      (
        NebulaSessionState.bootstrapping,
        NebulaSessionState.recoverableFailure
      ) ||
      (
        NebulaSessionState.installationActive,
        NebulaSessionState.authenticating
      ) ||
      (
        NebulaSessionState.installationActive,
        NebulaSessionState.recoverableFailure
      ) ||
      (NebulaSessionState.authenticating, NebulaSessionState.authenticated) ||
      (
        NebulaSessionState.authenticating,
        NebulaSessionState.recoverableFailure
      ) ||
      (NebulaSessionState.authenticated, NebulaSessionState.refreshing) ||
      (NebulaSessionState.authenticated, NebulaSessionState.signingOut) ||
      (
        NebulaSessionState.authenticated,
        NebulaSessionState.recoverableFailure
      ) ||
      (NebulaSessionState.refreshing, NebulaSessionState.authenticated) ||
      (NebulaSessionState.refreshing, NebulaSessionState.recoverableFailure) ||
      (NebulaSessionState.signingOut, NebulaSessionState.installationActive) ||
      (NebulaSessionState.signingOut, NebulaSessionState.recoverableFailure) ||
      (
        NebulaSessionState.recoverableFailure,
        NebulaSessionState.bootstrapping
      ) ||
      (
        NebulaSessionState.recoverableFailure,
        NebulaSessionState.uninitialized
      ) ||
      (NebulaSessionState.revoked, NebulaSessionState.bootstrapping) =>
        true,
      // Any trusted state may be revoked (§7).
      (NebulaSessionState.installationActive, NebulaSessionState.revoked) ||
      (NebulaSessionState.authenticated, NebulaSessionState.revoked) ||
      (NebulaSessionState.refreshing, NebulaSessionState.revoked) =>
        true,
      _ => false,
    };
  }

  void _transition(NebulaSessionState next, {String reason = ''}) {
    if (!_canTransition(_state, next)) {
      throw StateError(
        'invalid session transition ${_state.name} -> ${next.name}',
      );
    }
    _state = next;
    _events.add(SessionStateChanged(next, reason: reason));
    for (final SessionStateListener listener in _listeners) {
      listener.onSessionState(next);
    }
  }

  /// Begins installation bootstrap (UNINITIALIZED -> BOOTSTRAPPING).
  ///
  /// The caller drives the actual bootstrap network call (FS-01 Ports) and
  /// then calls [onBootstrapSucceeded]/[onBootstrapFailed].
  Future<void> beginBootstrap() => _serialized(() async {
        _transition(NebulaSessionState.bootstrapping);
      });

  /// Bootstrap succeeded (BOOTSTRAPPING -> INSTALLATION_ACTIVE).
  Future<void> onBootstrapSucceeded() => _serialized(() async {
        _transition(NebulaSessionState.installationActive);
      });

  /// Bootstrap failed (-> RECOVERABLE_FAILURE).
  Future<void> onBootstrapFailed() => _serialized(() async {
        _transition(
          NebulaSessionState.recoverableFailure,
          reason: 'bootstrap failed',
        );
      });

  /// Begins login (INSTALLATION_ACTIVE -> AUTHENTICATING).
  Future<void> beginAuthenticating() => _serialized(() async {
        _transition(NebulaSessionState.authenticating);
      });

  /// Login succeeded: persists the refresh token, holds the access token in
  /// memory (docs/08 §6.2 storage rules) and enters AUTHENTICATED.
  Future<void> onAuthenticated(SessionTokenPair tokens) =>
      _serialized(() async {
        _accessToken = tokens.accessToken;
        await _tokenStore.write(
          namespace: namespace,
          key: tokenKeyRefresh,
          value: tokens.refreshToken,
        );
        _transition(NebulaSessionState.authenticated);
      });

  /// Single-flight refresh (AUTHENTICATED -> REFRESHING -> AUTHENTICATED).
  ///
  /// Concurrent callers await the same future (§6.3). All retries of one
  /// rotation share a single refresh request ID. On success the new refresh
  /// token is persisted in place (rotation never creates a session row).
  Future<SessionTokenPair> refresh() {
    final Future<SessionTokenPair>? inflight = _inflightRefresh;
    if (inflight != null) return inflight;

    final Future<SessionTokenPair> future = _serialized(() async {
      _transition(NebulaSessionState.refreshing);
      final String requestId = _nextRefreshRequestId();
      try {
        final SessionTokenPair pair = await refreshExecutor(requestId);
        if (_state != NebulaSessionState.refreshing) {
          // 刷新期间会话被吊销/取消（cancellation）：丢弃结果，绝不落库，
          // 也不回 AUTHENTICATED。
          throw const InvalidInstallationError();
        }
        await _tokenStore.write(
          namespace: namespace,
          key: tokenKeyRefresh,
          value: pair.refreshToken,
        );
        _accessToken = pair.accessToken;
        _transition(NebulaSessionState.authenticated);
        return pair;
      } on NebulaSessionError catch (error) {
        if (error is SessionRevokedError) {
          // Consumed refresh reused later revokes the session family (§6.3).
          await _revoke('refresh token reuse (family revoked)');
          rethrow;
        }
        if (_state != NebulaSessionState.refreshing) rethrow;
        _transition(
          NebulaSessionState.recoverableFailure,
          reason: 'refresh failed',
        );
        rethrow;
      } finally {
        _inflightRefresh = null;
      }
    });
    _inflightRefresh = future;
    return future;
  }

  /// Logout (AUTHENTICATED -> SIGNING_OUT -> INSTALLATION_ACTIVE, §6.4).
  ///
  /// Local access/refresh state is cleared even when the remote call fails.
  /// Repeated logout returns success (§6.4): when no session exists
  /// (INSTALLATION_ACTIVE/UNINITIALIZED) it is a no-op.
  Future<void> signOut() => _serialized(() async {
        if (_state == NebulaSessionState.installationActive ||
            _state == NebulaSessionState.uninitialized) {
          return; // idempotent: nothing to sign out
        }
        _transition(NebulaSessionState.signingOut);
        if (remoteLogout != null) {
          try {
            await remoteLogout!();
          } on Object {
            // §6.4: network failure must not block local cleanup.
          }
        }
        await _clearLocalSession();
        _transition(NebulaSessionState.installationActive);
      });

  /// Any trusted state -> REVOKED -> BOOTSTRAPPING (§7).
  ///
  /// Clears local tokens, emits a security alert, then waits for the caller
  /// to [beginBootstrap] again. Idempotent: already-revoked sessions are a
  /// no-op.
  ///
  /// Revocation deliberately bypasses the serialization queue: it is a
  /// security-critical signal that must take effect immediately even while a
  /// refresh is in flight. An in-flight refresh whose response arrives after
  /// revocation discards its result (the refresh future completes with
  /// [InvalidInstallationError] and never persists tokens).
  Future<void> onRevoked(String reason) async {
    if (_state == NebulaSessionState.revoked) return;
    await _revoke(reason);
  }

  /// Marks a recoverable failure (any state -> RECOVERABLE_FAILURE).
  Future<void> onFailure(NebulaSessionError error) => _serialized(() async {
        if (_state == NebulaSessionState.recoverableFailure) return;
        _transition(
          NebulaSessionState.recoverableFailure,
          reason: error.message,
        );
      });

  /// Retry after a recoverable failure (RECOVERABLE_FAILURE -> BOOTSTRAPPING).
  Future<void> retryAfterFailure() => _serialized(() async {
        _transition(NebulaSessionState.bootstrapping);
      });

  Future<void> _revoke(String reason) async {
    _transition(NebulaSessionState.revoked, reason: reason);
    _events.add(SecurityAlert(reason));
    await _clearLocalSession();
  }

  Future<void> _clearLocalSession() async {
    _accessToken = null;
    await _tokenStore.delete(namespace: namespace, key: tokenKeyRefresh);
  }

  String _nextRefreshRequestId() =>
      'rf-${_random.nextInt(1 << 32).toRadixString(16)}-'
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';

  /// Closes the event stream. Subsequent [events] subscription is rejected.
  void dispose() {
    _events.close();
  }
}
