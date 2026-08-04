import 'auth/login_request.dart';
import 'auth/session.dart';
import 'transport/cancellation_token.dart';

abstract interface class NebulaAuth {
  /// Current session state. Capability clients MUST observe state through this
  /// and [events], never by reading storage directly (docs/08 §7).
  NebulaSessionState get state;

  /// The in-memory access token, or null when unauthenticated. The token is
  /// memory-only (docs/08 §6.2); it is never persisted and must not be logged.
  String? get accessToken;

  /// Session state transition stream (docs/08 §7).
  Stream<NebulaSessionEvent> get events;

  /// Restore a previously authenticated session from secure storage.
  ///
  /// Returns true if a refresh token was present and the session is now
  /// AUTHENTICATED (lazy: the first [getAccessToken] triggers a real refresh).
  Future<bool> restoreSession();

  /// Authenticate through the provider (phone/code or oauth) and enter
  /// AUTHENTICATED. Requires an active installation (docs/08 §4.3).
  Future<void> login(
    NebulaLoginRequest request, {
    NebulaCancellationToken? cancellationToken,
  });

  /// Returns a valid access token, performing a single-flight refresh if the
  /// current one is missing or needs rotation.
  Future<String> getAccessToken({
    NebulaCancellationToken? cancellationToken,
  });

  /// Proactively refresh the session (single-flight; docs/08 §6.3). Concurrent
  /// callers await the same future, so a 401 storm issues one refresh request.
  Future<SessionTokenPair> refresh({
    NebulaCancellationToken? cancellationToken,
  });

  /// Sign out and clear the local user scope (docs/08 §6.4).
  Future<void> signOut();
}

abstract interface class NebulaAnalytics {
  Future<void> track(String event, {Map<String, Object?> properties});
  Future<void> flush();
}

/// Marker contract. Concrete asset operations are frozen in Sprint F3.
abstract interface class NebulaAsset {}

/// Marker contract. Concrete notification operations are frozen in Sprint F3.
abstract interface class NebulaNotification {}

/// Marker contract. Concrete payment operations are frozen in Sprint F4.
abstract interface class NebulaPayment {}

/// Marker contract. Concrete AI operations are frozen in Sprint F4.
abstract interface class NebulaAi {}
