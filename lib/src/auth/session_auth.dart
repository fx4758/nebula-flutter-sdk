/// Transport-backed user-session capability (F1-02 / Auth V2).
library;

import 'dart:async';
import 'dart:convert';

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

  /// Reflects a successful host installation bootstrap.
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
  Future<void> sendEmailCode({
    required String email,
    required NebulaEmailCodePurpose purpose,
    NebulaCancellationToken? cancellationToken,
  }) async {
    _validateEmail(email);
    await _sendWithProof(
      NebulaHttpMethod.post,
      endpoints.emailCodeSend,
      body: <String, Object?>{
        'email': email,
        'purpose': _emailPurposeWire(purpose),
      },
      cancellationToken: cancellationToken,
    );
  }

  @override
  Future<void> registerEmail({
    required String email,
    required String password,
    required String code,
    NebulaCancellationToken? cancellationToken,
  }) async {
    _validateEmail(email);
    _validatePassword(password, 'password');
    _validateEmailCode(code);
    await _session.beginAuthenticating();
    try {
      final SessionTokenPair pair = await _tokenRequest(
        endpoints.emailRegister,
        <String, Object?>{
          'email': email,
          'password': password,
          'code': code,
        },
        cancellationToken: cancellationToken,
      );
      await _session.onAuthenticated(pair);
    } on NebulaSessionError catch (error) {
      await _session.onFailure(error);
      rethrow;
    } catch (error) {
      final NebulaSessionError mapped = _mapException(error);
      await _session.onFailure(mapped);
      throw mapped;
    }
  }

  @override
  Future<void> resetEmailPassword({
    required String email,
    required String code,
    required String newPassword,
    NebulaCancellationToken? cancellationToken,
  }) async {
    _validateEmail(email);
    _validateEmailCode(code);
    _validatePassword(newPassword, 'newPassword');
    await _sendWithProof(
      NebulaHttpMethod.post,
      endpoints.emailPasswordReset,
      body: <String, Object?>{
        'email': email,
        'code': code,
        'new_password': newPassword,
      },
      cancellationToken: cancellationToken,
    );
    await _session.onPasswordResetSucceeded();
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

  Future<SessionTokenPair> _loginRequest(
    Map<String, Object?> body, {
    NebulaCancellationToken? cancellationToken,
  }) =>
      _tokenRequest(
        endpoints.login,
        body,
        cancellationToken: cancellationToken,
      );

  Future<SessionTokenPair> _tokenRequest(
    String endpointPath,
    Map<String, Object?> body, {
    NebulaCancellationToken? cancellationToken,
  }) async {
    final NebulaResponse response = await _sendWithProof(
      NebulaHttpMethod.post,
      endpointPath,
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
    // Best-effort remote logout; local cleanup remains authoritative.
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

  String _emailPurposeWire(NebulaEmailCodePurpose purpose) => switch (purpose) {
        NebulaEmailCodePurpose.register => 'REGISTER',
        NebulaEmailCodePurpose.resetPassword => 'RESET_PASSWORD',
      };

  void _validateEmail(String email) =>
      _validateUtf8(email, 'email', minBytes: 1, maxBytes: 254);

  void _validatePassword(String password, String field) =>
      _validateUtf8(password, field, minBytes: 8, maxBytes: 128);

  void _validateEmailCode(String code) {
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      throw ArgumentError(
          'code must be exactly 6 ASCII decimal digits', 'code');
    }
  }

  void _validateUtf8(
    String value,
    String field, {
    required int minBytes,
    required int maxBytes,
  }) {
    final int bytes = utf8.encode(value).length;
    if (bytes < minBytes || bytes > maxBytes) {
      throw ArgumentError(
        '$field must be $minBytes..$maxBytes UTF-8 bytes',
        field,
      );
    }
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
