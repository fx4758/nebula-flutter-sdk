/// Error classification (F1-04).
///
/// Maps any SDK failure to an exhaustive [NebulaErrorCategory] so callers and
/// the redacting logger can decide handling (retry / re-auth / surface to user)
/// without pattern-matching on exception types or raw codes.
///
/// Scope: this classifier covers the transport/business [NebulaException]
/// hierarchy (docs/04 §F1: "服务端业务错误映射为可穷举类别，同时保留原始
/// code/request ID"). Session-specific semantics (single-flight refresh, logout
/// cleanup) live in `auth/session_errors.dart` via [classifySessionError]; that
/// layer is intentionally not imported here to keep foundation free of auth
/// dependencies.
library;

import 'errors.dart';

/// Exhaustive category for any SDK failure or a successful result.
enum NebulaErrorCategory {
  /// The request completed successfully.
  success,

  /// Auth missing/expired/revoked — caller should re-authenticate.
  authentication,

  /// Authenticated but not permitted.
  authorization,

  /// Rate limited — honor Retry-After, do not loop.
  rateLimited,

  /// Server transient failure — bounded backoff is acceptable.
  temporarilyUnavailable,

  /// Resource not found.
  notFound,

  /// Client-side validation failure — no retry.
  validation,

  /// Client/configuration error (no network involved).
  client,

  /// Server error (generic 5xx).
  server,

  /// The caller cancelled the request.
  cancelled,

  /// A connect or receive deadline was exceeded.
  timeout,

  /// Connection/DNS/TLS failure before any response.
  network,

  /// Anything not otherwise classified.
  unknown,
}

/// Classifies an arbitrary error into a [NebulaErrorCategory].
///
/// The original `code` / `requestId` are always preserved on the underlying
/// exception; classification only derives a coarse category for handling and
/// logging. Unknown integer codes fall back to [NebulaErrorCategory.unknown]
/// while keeping the raw code available for diagnostics.
NebulaErrorCategory classifyNebulaError(Object error) {
  if (error is NebulaCancelledException) {
    return NebulaErrorCategory.cancelled;
  }
  if (error is NebulaTimeoutException) {
    return NebulaErrorCategory.timeout;
  }
  if (error is NebulaConfigurationException) {
    return NebulaErrorCategory.client;
  }
  if (error is NebulaConfigParseException) {
    return NebulaErrorCategory.client;
  }
  if (error is NebulaApiException) {
    final int code = error.code;
    if (code == 429 || code == 40002) return NebulaErrorCategory.rateLimited;
    if (code == 401 || code == 403 || code == 10003) {
      return NebulaErrorCategory.authentication;
    }
    if (code == 400 || code == 30001) return NebulaErrorCategory.validation;
    if (code == 404) return NebulaErrorCategory.notFound;
    if (code >= 50000) return NebulaErrorCategory.server;
    if (code >= 5000) return NebulaErrorCategory.temporarilyUnavailable;
    return NebulaErrorCategory.unknown;
  }
  if (error is NebulaHttpException) {
    final int? status = error.statusCode;
    if (status == null) return NebulaErrorCategory.network;
    if (status == 429) return NebulaErrorCategory.rateLimited;
    if (status == 401 || status == 403) {
      return NebulaErrorCategory.authentication;
    }
    if (status == 400) return NebulaErrorCategory.validation;
    if (status == 404) return NebulaErrorCategory.notFound;
    if (status >= 500) return NebulaErrorCategory.temporarilyUnavailable;
    return NebulaErrorCategory.network;
  }
  return NebulaErrorCategory.unknown;
}
