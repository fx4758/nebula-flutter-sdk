library;

import 'dart:convert';
import 'dart:math';

import '../foundation/request_proof.dart';
import '../foundation/errors.dart';
import '../foundation/options.dart';
import '../transport.dart';
import '../transport/proof_headers.dart';
import 'analytics_sender.dart';
import 'event.dart';

const String _analyticsPath = '/api/v1/mobile/analytics/batches';
const int _maxAnalyticsRequestBytes = 16 * 1024;
const int _maxAnalyticsEvents = 50;

enum MobileAnalyticsSendDisposition { success, defer, nonRetryable }

final class AssignedMobileAnalyticsBatch {
  const AssignedMobileAnalyticsBatch({
    required this.batchId,
    required this.events,
    required this.body,
    required this.encodedBytes,
  });

  final String batchId;
  final List<NebulaAnalyticsEvent> events;
  final Map<String, Object?> body;
  final int encodedBytes;
}

abstract interface class MobileAnalyticsAssignedSender {
  AssignedMobileAnalyticsBatch assignBatch(
    List<NebulaAnalyticsEvent> candidates,
  );

  Future<MobileAnalyticsSendDisposition> sendAssigned(
    AssignedMobileAnalyticsBatch batch,
  );
}

typedef AnalyticsInstallationTrustRecovery = Future<bool> Function();

final class MobileAnalyticsSender
    implements NebulaAnalyticsSender, MobileAnalyticsAssignedSender {
  MobileAnalyticsSender({
    required NebulaOptions options,
    required NebulaTransport transport,
    required RequestProofSigner proofSigner,
    required Future<String> Function() installationToken,
    required AnalyticsInstallationTrustRecovery recoverInstallationTrust,
    String Function()? batchIdGenerator,
    DateTime Function()? now,
    this.rateLimitCooldown = const Duration(seconds: 30),
  })  : _options = options,
        _transport = transport,
        _proofSigner = proofSigner,
        _installationToken = installationToken,
        _recoverInstallationTrust = recoverInstallationTrust,
        _batchIdGenerator = batchIdGenerator ?? _newBatchId,
        _now = now ?? DateTime.now;

  final NebulaOptions _options;
  final NebulaTransport _transport;
  final RequestProofSigner _proofSigner;
  final Future<String> Function() _installationToken;
  final AnalyticsInstallationTrustRecovery _recoverInstallationTrust;
  final String Function() _batchIdGenerator;
  final DateTime Function() _now;
  final Duration rateLimitCooldown;

  DateTime? _cooldownUntil;
  bool _trustRecoveryRequired = false;

  @override
  AssignedMobileAnalyticsBatch assignBatch(
    List<NebulaAnalyticsEvent> candidates,
  ) {
    if (candidates.isEmpty) {
      throw ArgumentError.value(candidates, 'candidates', 'must not be empty');
    }
    final String batchId = _batchIdGenerator();
    final int idBytes = utf8.encode(batchId).length;
    if (idBytes == 0 || idBytes > 128) {
      throw StateError('batch_id must be 1..128 UTF-8 bytes');
    }

    int count = candidates.length < _maxAnalyticsEvents
        ? candidates.length
        : _maxAnalyticsEvents;
    while (count > 0) {
      final List<NebulaAnalyticsEvent> events =
          List<NebulaAnalyticsEvent>.unmodifiable(candidates.take(count));
      final Map<String, Object?> body = _body(batchId, events);
      final int bytes = utf8.encode(jsonEncode(body)).length;
      if (bytes <= _maxAnalyticsRequestBytes) {
        return AssignedMobileAnalyticsBatch(
          batchId: batchId,
          events: events,
          body: body,
          encodedBytes: bytes,
        );
      }
      count--;
    }
    throw StateError(
        'single analytics event cannot fit 16 KiB request ceiling');
  }

  @override
  Future<MobileAnalyticsSendDisposition> sendAssigned(
    AssignedMobileAnalyticsBatch batch,
  ) async {
    final DateTime now = _now().toUtc();
    if (_trustRecoveryRequired) {
      final DateTime? cooldown = _cooldownUntil;
      if (cooldown != null && cooldown.isAfter(now)) {
        return MobileAnalyticsSendDisposition.defer;
      }
      bool recovered = false;
      try {
        recovered = await _recoverInstallationTrust();
      } on Object {
        recovered = false;
      }
      if (!recovered) {
        _deferTrust(now);
        return MobileAnalyticsSendDisposition.defer;
      }
      _trustRecoveryRequired = false;
      _cooldownUntil = null;
    } else {
      final DateTime? cooldown = _cooldownUntil;
      if (cooldown != null && cooldown.isAfter(now)) {
        return MobileAnalyticsSendDisposition.defer;
      }
      _cooldownUntil = null;
    }

    if (batch.events.isEmpty ||
        batch.events.length > _maxAnalyticsEvents ||
        batch.encodedBytes > _maxAnalyticsRequestBytes ||
        utf8.encode(jsonEncode(batch.body)).length >
            _maxAnalyticsRequestBytes) {
      return MobileAnalyticsSendDisposition.nonRetryable;
    }

    try {
      final String token = await _installationToken();
      final Map<String, String> headers = await buildAuthHeaders(
        method: NebulaHttpMethod.post,
        resolvedPath: _resolvePath(_analyticsPath),
        body: batch.body,
        installationToken: token,
        signer: _proofSigner,
      );
      final NebulaResponse response = await _transport.send(
        NebulaRequest(
          method: NebulaHttpMethod.post,
          path: _analyticsPath,
          headers: headers,
          body: batch.body,
        ),
      );
      if (!_validAck(response.data, batch)) {
        throw NebulaHttpException(
          'Malformed or mismatched Analytics ACK',
          requestId: response.requestId,
        );
      }
      return MobileAnalyticsSendDisposition.success;
    } on NebulaApiException catch (error) {
      switch (error.code) {
        case 40002:
          _deferRateLimit(now);
          return MobileAnalyticsSendDisposition.defer;
        case 12004:
        case 50001:
          throw NebulaHttpException(
            'Transient Analytics backend failure (${error.code})',
            requestId: error.requestId,
          );
        case 12001:
          _deferTrust(now);
          return MobileAnalyticsSendDisposition.defer;
        case 30001:
          return MobileAnalyticsSendDisposition.nonRetryable;
        default:
          return MobileAnalyticsSendDisposition.nonRetryable;
      }
    } on NebulaHttpException catch (error) {
      if (error.statusCode == 429) {
        _deferRateLimit(now);
        return MobileAnalyticsSendDisposition.defer;
      }
      rethrow;
    }
  }

  @override
  Future<bool> send(List<NebulaAnalyticsEvent> batch) async {
    final MobileAnalyticsSendDisposition result = await sendAssigned(
      assignBatch(batch),
    );
    return result == MobileAnalyticsSendDisposition.success;
  }

  void _deferRateLimit(DateTime now) {
    final Duration cooldown =
        rateLimitCooldown < Duration.zero ? Duration.zero : rateLimitCooldown;
    _cooldownUntil = now.add(cooldown);
  }

  void _deferTrust(DateTime now) {
    _trustRecoveryRequired = true;
    _deferRateLimit(now);
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

  static Map<String, Object?> _body(
    String batchId,
    List<NebulaAnalyticsEvent> events,
  ) =>
      Map<String, Object?>.unmodifiable(<String, Object?>{
        'batch_id': batchId,
        'events': List<Map<String, Object?>>.unmodifiable(
          events.map(_eventWire),
        ),
      });

  static Map<String, Object?> _eventWire(NebulaAnalyticsEvent event) {
    final Object? properties = jsonDecode(jsonEncode(event.properties));
    return Map<String, Object?>.unmodifiable(<String, Object?>{
      'name': event.name,
      'occurred_at': event.timestamp.millisecondsSinceEpoch ~/ 1000,
      'identifiable': event.identifiable,
      'properties': properties,
    });
  }

  static bool _validAck(
    Object? data,
    AssignedMobileAnalyticsBatch batch,
  ) {
    if (data is! Map<String, Object?>) return false;
    if (data['batch_id'] != batch.batchId) return false;
    if (data['accepted_events'] != batch.events.length) return false;
    if (data['duplicate'] is! bool) return false;
    if (data['ingested_at'] is! int) return false;
    return true;
  }

  static String _newBatchId() {
    final Random random = Random.secure();
    final StringBuffer out = StringBuffer('batch_');
    for (int i = 0; i < 16; i++) {
      out.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return out.toString();
  }
}
