library;

import 'dart:convert';

import '../auth/proof.dart';
import '../foundation/errors.dart';
import '../foundation/options.dart';
import '../transport.dart';
import '../transport/proof_headers.dart';
import 'report.dart';
import 'sender.dart';

const String _errorReportsPath = '/api/v1/mobile/error-reports';
const int _maxErrorRequestBytes = 16 * 1024;
const int _maxErrorReports = 10;

final class MobileErrorReportSender implements ErrorReportSender {
  MobileErrorReportSender({
    required NebulaOptions options,
    required NebulaTransport transport,
    required RequestProofSigner proofSigner,
    required Future<String> Function() installationToken,
    DateTime Function()? now,
    this.rateLimitCooldown = const Duration(seconds: 30),
  })  : _options = options,
        _transport = transport,
        _proofSigner = proofSigner,
        _installationToken = installationToken,
        _now = now ?? DateTime.now;

  final NebulaOptions _options;
  final NebulaTransport _transport;
  final RequestProofSigner _proofSigner;
  final Future<String> Function() _installationToken;
  final DateTime Function() _now;
  final Duration rateLimitCooldown;

  DateTime? _cooldownUntil;

  @override
  Future<ErrorReportSendResult> send(List<NebulaErrorReport> reports) async {
    if (reports.isEmpty) return ErrorReportSendResult();
    final DateTime now = _now().toUtc();
    final DateTime? cooldownUntil = _cooldownUntil;
    if (cooldownUntil != null && cooldownUntil.isAfter(now)) {
      return ErrorReportSendResult(
        deferRemaining: true,
        retryAfter: cooldownUntil.difference(now),
      );
    }
    _cooldownUntil = null;

    final _PreparedErrorBatch prepared = _prepare(reports);
    final Map<String, String> headers = await buildAuthHeaders(
      method: NebulaHttpMethod.post,
      resolvedPath: _resolvePath(_errorReportsPath),
      body: prepared.body,
      installationToken: await _installationToken(),
      signer: _proofSigner,
    );
    try {
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
          return _rateLimited(now);
        case 12004:
        case 50001:
          throw NebulaHttpException(
            'Transient Error Reporting backend failure (${error.code})',
            requestId: error.requestId,
          );
        case 30001:
        case 12001:
        default:
          rethrow;
      }
    } on NebulaHttpException catch (error) {
      if (error.statusCode == 429) return _rateLimited(now);
      rethrow;
    }
  }

  _PreparedErrorBatch _prepare(List<NebulaErrorReport> reports) {
    int count =
        reports.length < _maxErrorReports ? reports.length : _maxErrorReports;
    while (count > 0) {
      final List<NebulaErrorReport> selected =
          List<NebulaErrorReport>.unmodifiable(
        reports.take(count),
      );
      final Set<String> ids =
          selected.map((NebulaErrorReport report) => report.reportId).toSet();
      if (ids.length != selected.length) {
        throw const NebulaApiException(
          'Duplicate report_id in one Error Reporting request',
          code: 30001,
        );
      }
      final Map<String, Object?> body = Map<String, Object?>.unmodifiable(
        <String, Object?>{
          'reports': List<Map<String, Object?>>.unmodifiable(
            selected.map(
              (NebulaErrorReport report) => Map<String, Object?>.unmodifiable(
                report.toDiagnosticMap(),
              ),
            ),
          ),
        },
      );
      if (utf8.encode(jsonEncode(body)).length <= _maxErrorRequestBytes) {
        return _PreparedErrorBatch(body: body, reportIds: ids);
      }
      count--;
    }
    throw const NebulaApiException(
      'Single Error Reporting request cannot fit 16 KiB ceiling',
      code: 30001,
    );
  }

  ErrorReportSendResult _decode(Object? data, Set<String> requestIds) {
    if (data is! Map<String, Object?>) {
      throw const NebulaHttpException('Malformed Error Reporting ACK');
    }
    final Object? acceptedRaw = data['accepted'];
    final Object? rejectedRaw = data['rejected'];
    final Object? deferRaw = data['defer_remaining'];
    final Object? retryRaw = data['retry_after_seconds'];
    if (acceptedRaw is! List || rejectedRaw is! List || deferRaw is! bool) {
      throw const NebulaHttpException('Malformed Error Reporting ACK');
    }

    final Set<String> accepted = <String>{};
    for (final Object? item in acceptedRaw) {
      if (item is! Map<String, Object?> ||
          item['report_id'] is! String ||
          item['ingested_at'] is! int ||
          item['duplicate'] is! bool) {
        throw const NebulaHttpException('Malformed accepted report ACK');
      }
      accepted.add(item['report_id'] as String);
    }

    final Set<String> rejected = <String>{};
    for (final Object? item in rejectedRaw) {
      if (item is! Map<String, Object?> ||
          item['report_id'] is! String ||
          item['reason'] is! String) {
        throw const NebulaHttpException('Malformed rejected report ACK');
      }
      final String reason = item['reason'] as String;
      if (reason != 'invalid_payload' && reason != 'id_conflict') {
        throw const NebulaHttpException('Unknown Error Reporting rejection');
      }
      rejected.add(item['report_id'] as String);
    }

    if (!requestIds.containsAll(accepted) ||
        !requestIds.containsAll(rejected) ||
        accepted.intersection(rejected).isNotEmpty) {
      throw const NebulaHttpException('Error Reporting ACK IDs are invalid');
    }
    if (accepted.length != acceptedRaw.length ||
        rejected.length != rejectedRaw.length) {
      throw const NebulaHttpException('Duplicate Error Reporting ACK ID');
    }

    Duration? retryAfter;
    if (retryRaw != null) {
      if (retryRaw is! int || retryRaw < 0) {
        throw const NebulaHttpException(
          'Invalid Error Reporting retry_after_seconds',
        );
      }
      retryAfter = Duration(seconds: retryRaw);
    }
    return ErrorReportSendResult(
      acceptedReportIds: accepted,
      rejectedReportIds: rejected,
      deferRemaining: deferRaw,
      retryAfter: retryAfter,
    );
  }

  ErrorReportSendResult _rateLimited(DateTime now) {
    final Duration bounded =
        rateLimitCooldown < Duration.zero ? Duration.zero : rateLimitCooldown;
    _cooldownUntil = now.add(bounded);
    return ErrorReportSendResult(
      deferRemaining: true,
      retryAfter: bounded,
    );
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
}

final class _PreparedErrorBatch {
  const _PreparedErrorBatch({required this.body, required this.reportIds});

  final Map<String, Object?> body;
  final Set<String> reportIds;
}
