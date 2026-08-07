/// Concrete user-session capability (F1-02).
///
/// Wires the FS-02 [NebulaSession] state machine to a real [NebulaTransport] so
/// that login, single-flight refresh and sign-out perform actual network calls
/// (docs/08 §6/§7). Proof headers are attached via the injected
/// [RequestProofSigner] Port (FS-01); the core contains no crypto plugin.
///
/// Single-flight refresh is inherited from [NebulaSession]: concurrent callers
/// of [refresh]/[getAccessToken] await one in-flight refresh future, so a 401
/// storm triggers exactly one refresh HTTP request (F1 acceptance).
library;

import 'dart:async';

import '../capabilities.dart';
import '../foundation/errors.dart';
import '../foundation/options.dart';
import '../transport.dart';
import '../transport/cancellation_token.dart';
import 'auth_proof.dart';
import 'login_request.dart';
import 'proof.dart';
import 'session.dart';
import 'session_endpoints.dart';
import 'session_errors.dart';
import 'token_store.dart';

/// Concrete [NebulaAuth] backed by [NebulaSession] + [NebulaTransport] (F1-02).
final class NebulaSessionAuth implements NebulaAuth {
  NebulaSessionAuth({
    required NebulaOptions options,
    required NebulaTransport transport,
    required SecureTokenStore tokenStore,
    required RequestProofSigner proofSigner,
    required Future<String> Function() installationToken,
    this.endpoints = const SessionEndpoints(),
    List<SessionStateListener> listeners = const <SessionStateListener>[],
  })  : _options = options,
        _transport = transport,
        _tokenStore = tokenStore,
        _proofSigner = proofSigner,
        _installationToken = installationToken,
        _namespace = tokenNamespace(options.environment, options.appId) {
    // Assigned in the body (not the initializer list) because the session needs
    // the transport-backed executor and remote-logout hook, which close over
    // `this` (instance methods cannot be referenced in an initializer list).
    _session = NebulaSession(
      namespace: _namespace,
      tokenStore: _tokenStore,
      refreshExecutor: _refreshExecutor,
      remoteLogout: _remoteLogout,
      listeners: listeners,
    );
  }

  final NebulaOptions _options;
  final NebulaTransport _transport;
  final SecureTokenStore _tokenStore;
  final RequestProofSigner _proofSigner;
  final Future<String> Function() _installationToken;
  final SessionEndpoints endpoints;
  final String _namespace;

  late final NebulaSession _session;

  @override
  NebulaSessionState get state => _session.state;

  @override
  String? get accessToken => _session.accessToken;

  @override
  Stream<NebulaSessionEvent> get events => _session.events;

  /// Advances the session to INSTALLATION_ACTIVE after the host completes the
  /// installation bootstrap (FS-01). The auth capability does not perform the
  /// bootstrap network call itself; it only reflects the resulting state so that
  /// [login] may proceed (docs/08 §7).
  Future<void> onInstallationBootstrapSucceeded() async {
    if (_session.state == NebulaSessionState.uninitialized) {
      await _session.beginBootstrap();
    }
    await _session.onBootstrapSucceeded();
  }

  @override
  Future<bool> restoreSession() async {
    final String? refreshToken =
        await _tokenStore.read(namespace: _namespace, key: tokenKeyRefresh);
    if (refreshToken == null) return false;
    if (_session.state == NebulaSessionState.authenticated) return true;

    // Restore the user session from the persisted refresh token. The access
    // token is memory-only (docs/08 §6.2), so we enter AUTHENTICATED with a
    // placeholder and let [getAccessToken] lazily refresh on first use.
    if (_session.state == NebulaSessionState.uninitialized) {
      await _session.beginBootstrap();
      await _session.onBootstrapSucceeded();
    }
    if (_session.state == NebulaSessionState.installationActive) {
      await _session.beginAuthenticating();
      await _session.onAuthenticated(
        SessionTokenPair(accessToken: '', refreshToken: refreshToken),
      );
    }
    return _session.state == NebulaSessionState.authenticated;
  }

  @override
  Future<void> login(
    NebulaLoginRequest request, {
    NebulaCancellationToken? cancellationToken,
  }) async {
    request.validate();
    await _session.beginAuthenticating();
    try {
      final SessionTokenPair pair = await _loginRequest(
        request.toJson(),
        cancellationToken: cancellationToken,
      );
      await _session.onAuthenticated(pair);
    } on NebulaSessionError catch (error) {
      await _session.onFailure(error);
      rethrow;
    } catch (error) {
      final NebulaSessionError mapped = _mapException(error);
      await _session.onFailure(mapped);
      rethrow;
    }
  }

  @override
  Future<String> getAccessToken({
    NebulaCancellationToken? cancellationToken,
  }) async {
    if (_session.state == NebulaSessionState.authenticated &&
        _session.accessToken != null &&
        _session.accessToken!.isNotEmpty) {
      return _session.accessToken!;
    }
    final SessionTokenPair pair = await refresh();
    return pair.accessToken;
  }

  @override
  Future<SessionTokenPair> refresh({
    NebulaCancellationToken? cancellationToken,
  }) =>
      _session.refresh();

  @override
  Future<void> signOut() => _session.signOut();

  // --- internals -----------------------------------------------------------

  Future<SessionTokenPair> _loginRequest(
    Map<String, Object?> body, {
    NebulaCancellationToken? cancellationToken,
  }) async {
    final NebulaResponse response = await _sendWithProof(
      NebulaHttpMethod.post,
      endpoints.login,
      body: body,
      cancellationToken: cancellationToken,
    );
    return _tokensFromResponse(response.data);
  }

  Future<SessionTokenPair> _refreshExecutor(String refreshRequestId) async {
    final String? refreshToken =
        await _tokenStore.read(namespace: _namespace, key: tokenKeyRefresh);
    if (refreshToken == null) {
      // No persisted refresh token: the installation must re-bootstrap.
      throw const InvalidInstallationError();
    }
    final NebulaResponse response = await _sendWithProof(
      NebulaHttpMethod.post,
      endpoints.refresh,
      body: <String, Object?>{'refresh_token': refreshToken},
      idempotencyKey: refreshRequestId,
    );
    return _tokensFromResponse(response.data);
  }

  Future<void> _remoteLogout() async {
    // Best-effort: the session state machine clears local state regardless of
    // whether this succeeds (docs/08 §6.4). Failures are swallowed by the
    // session's signOut path.
    await _sendWithProof(
      NebulaHttpMethod.post,
      endpoints.logout,
      accessToken: _session.accessToken,
    );
  }

  Future<NebulaResponse> _sendWithProof(
    NebulaHttpMethod method,
    String endpointPath, {
    Object? body,
    String? idempotencyKey,
    String? accessToken,
    NebulaCancellationToken? cancellationToken,
  }) async {
    final String resolvedPath = _resolvePath(endpointPath);
    final Map<String, String> headers = await buildAuthHeaders(
      method: method,
      resolvedPath: resolvedPath,
      body: body,
      installationToken: await _installationToken(),
      signer: _proofSigner,
    );
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    final NebulaRequest request = NebulaRequest(
      method: method,
      path: endpointPath,
      headers: headers,
      body: body,
      idempotencyKey: idempotencyKey,
      cancellationToken: cancellationToken,
    );
    try {
      return await _transport.send(request);
    } on NebulaApiException catch (error) {
      // Envelope business error: map the server code to a typed category.
      throw classifySessionError(
        statusCode: 200,
        code: error.code,
        requestId: error.requestId,
      );
    } on NebulaHttpException catch (error) {
      throw _mapHttpException(error);
    } on NebulaTimeoutException catch (error) {
      throw TemporarilyUnavailableError(requestId: error.requestId);
    } on NebulaCancelledException {
      // Cancellation is a transient control signal at this layer: surface it as
      // a recoverable failure so the session transitions stay consistent.
      throw const TemporarilyUnavailableError();
    }
  }

  SessionTokenPair _tokensFromResponse(Object? data) {
    if (data is! Map<String, Object?>) {
      throw const InvalidRequestError();
    }
    final Object? access = data['access_token'];
    final Object? refresh = data['refresh_token'];
    if (access is! String || refresh is! String) {
      throw const InvalidRequestError();
    }
    return SessionTokenPair(accessToken: access, refreshToken: refresh);
  }

  NebulaSessionError _mapException(Object error) {
    if (error is NebulaException) {
      if (error is NebulaApiException) {
        return classifySessionError(
          statusCode: 200,
          code: error.code,
          requestId: error.requestId,
        );
      }
      if (error is NebulaHttpException) return _mapHttpException(error);
      if (error is NebulaTimeoutException) {
        return TemporarilyUnavailableError(requestId: error.requestId);
      }
    }
    return const TemporarilyUnavailableError();
  }

  NebulaSessionError _mapHttpException(NebulaHttpException error) {
    final int? statusCode = error.statusCode;
    if (statusCode == 429) {
      return RateLimitedError(requestId: error.requestId);
    }
    if (statusCode != null && statusCode >= 500) {
      return TemporarilyUnavailableError(requestId: error.requestId);
    }
    if (statusCode == 401 || statusCode == 403) {
      return AuthenticationRequiredError(requestId: error.requestId);
    }
    return TemporarilyUnavailableError(requestId: error.requestId);
  }

  String _resolvePath(String endpointPath) {
    final String base = _options.baseUri.path;
    final String b = base.endsWith('/') && base.isNotEmpty
        ? base.substring(0, base.length - 1)
        : base;
    final String p =
        endpointPath.startsWith('/') ? endpointPath : '/$endpointPath';
    return '$b$p';
  }

  /// Closes the underlying session event stream.
  void dispose() => _session.dispose();
}
