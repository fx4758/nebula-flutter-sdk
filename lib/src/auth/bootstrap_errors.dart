/// Bootstrap-specific error classification (Bootstrap Contract V2).
library;

import '../foundation/errors.dart';
import 'session_errors.dart';

/// Exhaustive handling categories for installation bootstrap failures.
enum NebulaBootstrapErrorCategory {
  invalidInstallation,
  invalidRequest,
  clientOutdated,
  rateLimited,
  temporarilyUnavailable,
  serverFailure,
  cancelled,
  invalidResponse,
  network,
  unknown,
}

/// Classifies a raw SDK/transport failure using bootstrap semantics.
NebulaBootstrapErrorCategory classifyBootstrapError(Object error) {
  if (error is NebulaCancelledException) {
    return NebulaBootstrapErrorCategory.cancelled;
  }
  if (error is ArgumentError) {
    return NebulaBootstrapErrorCategory.invalidRequest;
  }
  if (error is FormatException || error is TypeError) {
    return NebulaBootstrapErrorCategory.invalidResponse;
  }
  if (error is NebulaTimeoutException) {
    return NebulaBootstrapErrorCategory.temporarilyUnavailable;
  }
  if (error is NebulaHttpException) {
    return switch (error.statusCode) {
      429 => NebulaBootstrapErrorCategory.rateLimited,
      503 => NebulaBootstrapErrorCategory.temporarilyUnavailable,
      null => NebulaBootstrapErrorCategory.network,
      >= 500 => NebulaBootstrapErrorCategory.serverFailure,
      _ => NebulaBootstrapErrorCategory.unknown,
    };
  }
  if (error is NebulaApiException) {
    return switch (error.code) {
      nebulaCodeInstallationInvalid =>
        NebulaBootstrapErrorCategory.invalidInstallation,
      nebulaCodeParam => NebulaBootstrapErrorCategory.invalidRequest,
      nebulaCodeClientOutdated => NebulaBootstrapErrorCategory.clientOutdated,
      nebulaCodeRateLimited => NebulaBootstrapErrorCategory.rateLimited,
      nebulaCodeTemporarilyUnavailable =>
        NebulaBootstrapErrorCategory.temporarilyUnavailable,
      50001 => NebulaBootstrapErrorCategory.serverFailure,
      _ => NebulaBootstrapErrorCategory.unknown,
    };
  }
  return NebulaBootstrapErrorCategory.unknown;
}
