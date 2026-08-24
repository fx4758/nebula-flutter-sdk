/// Session error categories (FS-02).
///
/// Typed forms of the docs/08 §8 category table. The SDK does not invent
/// backend codes: every category preserves the server integer `code` and
/// `requestId` for diagnostics, and the classifier only maps codes frozen by
/// FB-01 (12001-12004) plus stable legacy codes.
library;

/// 12001 — invalid_installation (FB-01 allocation).
const int nebulaCodeInstallationInvalid = 12001;

/// 12002 — session_revoked (FB-01 allocation).
const int nebulaCodeSessionRevoked = 12002;

/// 12003 — client_outdated (FB-01 allocation).
const int nebulaCodeClientOutdated = 12003;

/// 12004 — temporarily_unavailable (FB-01 allocation).
const int nebulaCodeTemporarilyUnavailable = 12004;

/// 10001 — invalid login / verification credentials (Auth V2).
const int nebulaCodeInvalidCredentials = 10001;

/// 10003 — token invalid (legacy stable code).
const int nebulaCodeTokenInvalid = 10003;

/// 30001 — parameter error (legacy stable code).
const int nebulaCodeParam = 30001;

/// 40002 — rate limited (legacy stable code, HTTP 429).
const int nebulaCodeRateLimited = 40002;

/// Base class for typed session failures.
///
/// Every instance keeps the raw server `code` and `requestId` — raw tokens are
/// never included, and no PII may be placed in `message` (docs/08 §6.2).
sealed class NebulaSessionError implements Exception {
  const NebulaSessionError(this.message, {this.code, this.requestId});

  final String message;
  final int? code;
  final String? requestId;
}

/// revoked/expired/proof invalid → clear installation token and bootstrap once.
final class InvalidInstallationError extends NebulaSessionError {
  const InvalidInstallationError({super.code, super.requestId})
      : super('installation is invalid, revoked or expired');
}

/// Invalid login or verification credentials. No account-existence detail.
final class InvalidCredentialsError extends NebulaSessionError {
  const InvalidCredentialsError({super.code, super.requestId})
      : super('invalid credentials');
}

/// access missing/expired → single-flight refresh if a refresh token exists.
final class AuthenticationRequiredError extends NebulaSessionError {
  const AuthenticationRequiredError({super.code, super.requestId})
      : super('authentication required');
}

/// refresh reuse/logout/token version → clear user session, do not retry.
final class SessionRevokedError extends NebulaSessionError {
  const SessionRevokedError({super.code, super.requestId})
      : super('session revoked');
}

/// HTTP 429 / 40002 → honor Retry-After; no immediate loop.
final class RateLimitedError extends NebulaSessionError {
  const RateLimitedError({super.code, super.requestId, this.retryAfterSeconds})
      : super('rate limited');

  /// Server `Retry-After` hint in seconds, when provided.
  final int? retryAfterSeconds;
}

/// minimum build policy → block or recommend upgrade.
final class ClientOutdatedError extends NebulaSessionError {
  const ClientOutdatedError({super.code, super.requestId})
      : super('client outdated');
}

/// auth state store/provider unavailable → bounded backoff; keep safe local
/// state.
final class TemporarilyUnavailableError extends NebulaSessionError {
  const TemporarilyUnavailableError({super.code, super.requestId})
      : super('temporarily unavailable');
}

/// bounded validation failure → no retry.
final class InvalidRequestError extends NebulaSessionError {
  const InvalidRequestError({super.code, super.requestId})
      : super('invalid request');
}

/// Classifies a server response into a typed category (docs/08 §8).
///
/// Unknown integer codes fall back to [AuthenticationRequiredError] (the
/// conservative trigger for single-flight refresh) while preserving the raw
/// code and request ID.
NebulaSessionError classifySessionError({
  required int statusCode,
  required int code,
  String? requestId,
  int? retryAfterSeconds,
}) {
  if (statusCode == 429 || code == nebulaCodeRateLimited) {
    return RateLimitedError(
      code: code,
      requestId: requestId,
      retryAfterSeconds: retryAfterSeconds,
    );
  }
  return switch (code) {
    nebulaCodeInvalidCredentials => InvalidCredentialsError(
        code: code,
        requestId: requestId,
      ),
    nebulaCodeInstallationInvalid => InvalidInstallationError(
        code: code,
        requestId: requestId,
      ),
    nebulaCodeSessionRevoked => SessionRevokedError(
        code: code,
        requestId: requestId,
      ),
    nebulaCodeClientOutdated => ClientOutdatedError(
        code: code,
        requestId: requestId,
      ),
    nebulaCodeTemporarilyUnavailable => TemporarilyUnavailableError(
        code: code,
        requestId: requestId,
      ),
    nebulaCodeTokenInvalid => AuthenticationRequiredError(
        code: code,
        requestId: requestId,
      ),
    nebulaCodeParam => InvalidRequestError(
        code: code,
        requestId: requestId,
      ),
    _ => AuthenticationRequiredError(code: code, requestId: requestId),
  };
}
