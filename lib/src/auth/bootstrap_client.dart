/// Canonical installation-bootstrap client (Bootstrap Contract V2).
library;

import '../foundation/errors.dart';
import '../transport.dart';
import '../transport/cancellation_token.dart';
import 'bootstrap_endpoints.dart';
import 'installation.dart';
import 'session_errors.dart';

/// Typed SDK-owned client for `POST /api/v1/mobile/bootstrap`.
final class NebulaBootstrapClient {
  const NebulaBootstrapClient({required NebulaTransport transport})
      : _transport = transport;

  final NebulaTransport _transport;

  /// Registers or renews one installation identity.
  ///
  /// Automatic retry is capped at one extra attempt and reuses the exact same
  /// canonical body object and `bootstrap_request_id`.
  Future<BootstrapResult> bootstrap(
    BootstrapRequest request, {
    NebulaCancellationToken? cancellationToken,
  }) async {
    request.validate();
    if (cancellationToken?.isCancelled ?? false) {
      throw const NebulaCancelledException();
    }
    final Map<String, Object?> body =
        Map<String, Object?>.unmodifiable(request.toJson());

    int attempt = 0;
    while (true) {
      try {
        final NebulaResponse response = await _transport.send(
          NebulaRequest(
            method: NebulaHttpMethod.post,
            path: BootstrapEndpoints.bootstrap,
            body: body,
            cancellationToken: cancellationToken,
          ),
        );
        return _parseResult(response.data, request);
      } on Object catch (error) {
        if (attempt == 0 &&
            !(cancellationToken?.isCancelled ?? false) &&
            _isAutomaticRetryInput(error)) {
          attempt++;
          continue;
        }
        rethrow;
      }
    }
  }

  bool _isAutomaticRetryInput(Object error) {
    if (error is NebulaTimeoutException) return true;
    if (error is NebulaHttpException) return error.statusCode == null;
    if (error is NebulaApiException) {
      return error.code == 50001 ||
          error.code == nebulaCodeTemporarilyUnavailable;
    }
    return false;
  }

  BootstrapResult _parseResult(Object? data, BootstrapRequest request) {
    if (data is! Map<String, Object?>) {
      throw const FormatException('bootstrap data must be an object');
    }
    final BootstrapResult result = BootstrapResult.fromJson(data);
    if (result.appId != request.appId ||
        result.installationId != request.installationId ||
        result.requestId != request.bootstrapRequestId) {
      throw const FormatException('bootstrap response identity mismatch');
    }
    return result;
  }
}
