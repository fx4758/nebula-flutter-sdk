library;

import 'dart:convert';

import '../foundation/errors.dart';
import '../foundation/options.dart';
import '../foundation/request_proof.dart';
import '../transport.dart';
import '../transport/proof_headers.dart';
import 'report.dart';
import 'sender.dart';

const String _errorReportsPath = '/api/v1/mobile/error-reports';
const int _maxErrorRequestBytes = 16 * 1024;
const int _maxErrorReports = 10;

typedef InstallationTrustRecovery = Future<bool> Function();

final class MobileErrorReportSender implements ErrorReportSender {
  MobileErrorReportSender({
    required NebulaOptions options,
    required NebulaTransport transport,
    required RequestProofSigner proofSigner,
    required Future<String> Function() installationToken,
    required InstallationTrustRecovery recoverInstallationTrust,
    DateTime Function()? now,
    this.rateLimitCooldown = const Duration(seconds: 30),
  })  : _options = options,
        _transport = transport,
        _proofSigner = proofSigner,
        _installationToken = installationToken,
        _recoverInstallationTrust = recoverInstallationTrust,
        _now = now ?? DateTime.now;

  final NebulaOptions _options;
  final NebulaTransport _transport;
  final RequestProofSigner _proofSigner;
  final Future<String> Function() _installationToken;
  final InstallationTrustRecovery _recoverInstallationTrust;
  final DateTime Function() _now;
  final Duration rateLimitCooldown;
  DateTime? _cooldownUntil;
  bool _trustRecoveryRequired = false;

  @override
  Future<ErrorReportSendResult> send(List<NebulaErrorReport> reports) async {
    if (reports.isEmpty) return ErrorReportSendResult();
    final DateTime now = _now().toUtc();
    if (_trustRecoveryRequired) {
      final DateTime? cooldown = _cooldownUntil;
      if (cooldown != null && cooldown.isAfter(now)) {
        return ErrorReportSendResult(
          disposition: ErrorReportSendDisposition.trustRecoveryRequired,
          affectedReportIds: const <String>[],
          retryAfter: cooldown.difference(now),
        );
      }
      bool recovered = false;
      try {
        recovered = await _recoverInstallationTrust();
      } on Object {
        recovered = false;
      }
      if (!recovered) return _trustRequired(now);
      _trustRecoveryRequired = false;
      _cooldownUntil = null;
    } else {
      final DateTime? cooldown = _cooldownUntil;
      if (cooldown != null && cooldown.isAfter(now)) {
        return ErrorReportSendResult(
          disposition: ErrorReportSendDisposition.rateLimitedDefer,
          affectedReportIds: const <String>[],
          retryAfter: cooldown.difference(now),
        );
      }
      _cooldownUntil = null;
    }

    final _PreparedErrorBatch? prepared = _prepare(reports);
    if (prepared == null) {
      return ErrorReportSendResult(
        disposition: ErrorReportSendDisposition.deterministicRequestFailure,
        affectedReportIds:
            reports.map((NebulaErrorReport report) => report.reportId),
      );
    }

    try {
      final String token = await _installationToken();
      final Map<String, String> headers = await buildAuthHeaders(
        method: NebulaHttpMethod.post,
        resolvedPath: _resolvePath(_errorReportsPath),
        body: prepared.body,
        installationToken: token,
        signer: _proofSigner,
      );
      final NebulaResponse response = await _transport.send(
        NebulaRequest(
          method: NebulaHttpMethod.post,
          path: _errorReportsPath,
          headers: headers,
          body: prepared.body,
        ),
      );
      return _decode(response.data, prepared.reportIds);
    } on NebulaApiException catch (error) {
      switch (error.code) {
        case 40002:
          return _rateLimited(now, prepared.reportIds);
        case 12004:
        case 50001:
          return ErrorReportSendResult(
            disposition: ErrorReportSendDisposition.transientFailure,
            affectedReportIds: prepared.reportIds,
          );
        case 30001:
          return ErrorReportSendResult(
            disposition: ErrorReportSendDisposition.deterministicRequestFailure,
            affectedReportIds: prepared.reportIds,
          );
        case 12001:
          return _trustRequired(now, prepared.reportIds);
        default:
          return ErrorReportSendResult(
            disposition: ErrorReportSendDisposition.transientFailure,
            affectedReportIds: prepared.reportIds,
          );
      }
    } on NebulaHttpException catch (error) {
      if (error.statusCode == 429) {
        return _rateLimited(now, prepared.reportIds);
      }
      return ErrorReportSendResult(
        disposition: ErrorReportSendDisposition.transientFailure,
        affectedReportIds: prepared.reportIds,
      );
    } on NebulaException {
      return ErrorReportSendResult(
        disposition: ErrorReportSendDisposition.transientFailure,
        affectedReportIds: prepared.reportIds,
      );
    }
  }

  _PreparedErrorBatch? _prepare(List<NebulaErrorReport> reports) {
    final Set<String> allIds =
        reports.map((NebulaErrorReport report) => report.reportId).toSet();
    if (allIds.length != reports.length) return null;
    int count =
        reports.length < _maxErrorReports ? reports.length : _maxErrorReports;
    while (count > 0) {
      final List<NebulaErrorReport> selected =
          List<NebulaErrorReport>.unmodifiable(reports.take(count));
      final Map<String, Object?> body = Map<String, Object?>.unmodifiable(
        <String, Object?>{
          'reports': List<Map<String, Object?>>.unmodifiable(
            selected.map((NebulaErrorReport report) =>
                Map<String, Object?>.unmodifiable(report.toDiagnosticMap())),
          ),
        },
      );
      if (utf8.encode(jsonEncode(body)).length <= _maxErrorRequestBytes) {
        return _PreparedErrorBatch(
          body: body,
          reportIds: selected.map((NebulaErrorReport r) => r.reportId).toSet(),
        );
      }
      count--;
    }
    return null;
  }

  ErrorReportSendResult _decode(Object? data, Set<String> requestIds) {
    if (data is! Map<String, Object?>) return _transient(requestIds);
    final Object? acceptedRaw = data['accepted'];
    final Object? rejectedRaw = data['rejected'];
    final Object? deferRaw = data['defer_remaining'];
    final Object? retryRaw = data['retry_after_seconds'];
    if (acceptedRaw is! List || rejectedRaw is! List || deferRaw is! bool) {
      return _transient(requestIds);
    }

    final Set<String> accepted = <String>{};
    for (final Object? item in acceptedRaw) {
      if (item is! Map<String, Object?> ||
          item['report_id'] is! String ||
          item['ingested_at'] is! int ||
          item['duplicate'] is! bool) {
        return _transient(requestIds);
      }
      accepted.add(item['report_id'] as String);
    }

    final Set<String> rejected = <String>{};
    for (final Object? item in rejectedRaw) {
      if (item is! Map<String, Object?> ||
          item['report_id'] is! String ||
          item['reason'] is! String) {
        return _transient(requestIds);
      }
      final String reason = item['reason'] as String;
      if (reason != 'invalid_payload' && reason != 'id_conflict') {
        return _transient(requestIds);
      }
      rejected.add(item['report_id'] as String);
    }

    if (!requestIds.containsAll(accepted) ||
        !requestIds.containsAll(rejected) ||
        accepted.intersection(rejected).isNotEmpty ||
        accepted.length != acceptedRaw.length ||
        rejected.length != rejectedRaw.length) {
      return _transient(requestIds);
    }

    Duration? retryAfter;
    if (retryRaw != null) {
      if (retryRaw is! int || retryRaw < 0) return _transient(requestIds);
      retryAfter = Duration(seconds: retryRaw);
    }
    return ErrorReportSendResult(
      acceptedReportIds: accepted,
      rejectedReportIds: rejected,
      affectedReportIds: requestIds,
      deferRemaining: deferRaw,
      retryAfter: retryAfter,
    );
  }

  ErrorReportSendResult _transient(Set<String> affectedIds) =>
      ErrorReportSendResult(
        disposition: ErrorReportSendDisposition.transientFailure,
        affectedReportIds: affectedIds,
      );

  ErrorReportSendResult _rateLimited(
    DateTime now,
    Iterable<String> affectedIds,
  ) {
    final Duration cooldown = _nonNegativeCooldown;
    _cooldownUntil = now.add(cooldown);
    return ErrorReportSendResult(
      disposition: ErrorReportSendDisposition.rateLimitedDefer,
      affectedReportIds: affectedIds,
      retryAfter: cooldown,
    );
  }

  ErrorReportSendResult _trustRequired(
    DateTime now, [
    Iterable<String> affectedIds = const <String>[],
  ]) {
    _trustRecoveryRequired = true;
    final Duration cooldown = _nonNegativeCooldown;
    _cooldownUntil = now.add(cooldown);
    return ErrorReportSendResult(
      disposition: ErrorReportSendDisposition.trustRecoveryRequired,
      affectedReportIds: affectedIds,
      retryAfter: cooldown,
    );
  }

  Duration get _nonNegativeCooldown =>
      rateLimitCooldown < Duration.zero ? Duration.zero : rateLimitCooldown;

  String _resolvePath(String endpointPath) {
    final String base = _options.baseUri.path;
    final String b = base.endsWith('/') && base.isNotEmpty
        ? base.substring(0, base.length - 1)
        : base;
    final String p =
        endpointPath.startsWith('/') ? endpointPath : '/$endpointPath';
    return '$b$p';
  }
}

final class _PreparedErrorBatch {
  const _PreparedErrorBatch({required this.body, required this.reportIds});
  final Map<String, Object?> body;
  final Set<String> reportIds;
}
