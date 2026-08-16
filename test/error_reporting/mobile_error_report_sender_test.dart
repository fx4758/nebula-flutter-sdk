import 'dart:async';
import 'dart:convert';

import 'package:nebula_sdk/src/auth/proof.dart';
import 'package:nebula_sdk/src/error_reporting/mobile_error_report_sender.dart';
import 'package:nebula_sdk/src/error_reporting/report.dart';
import 'package:nebula_sdk/src/error_reporting/sender.dart';
import 'package:nebula_sdk/src/foundation/errors.dart';
import 'package:nebula_sdk/src/foundation/options.dart';
import 'package:nebula_sdk/src/transport.dart';
import 'package:test/test.dart';

typedef _Step = FutureOr<NebulaResponse> Function(NebulaRequest request);

final class _ScriptedTransport implements NebulaTransport {
  final List<_Step> steps = <_Step>[];
  final List<NebulaRequest> requests = <NebulaRequest>[];

  @override
  Future<NebulaResponse> send(NebulaRequest request) async {
    requests.add(request);
    if (steps.isEmpty) throw StateError('missing step');
    return steps.removeAt(0)(request);
  }
}

NebulaOptions get _options => NebulaOptions(
      appId: 'app-test',
      baseUri: Uri.parse('https://example.invalid/base'),
      environment: NebulaEnvironment.staging,
    );

NebulaErrorReport _report(String id, {String stack = '#0 main'}) =>
    NebulaErrorReport(
      reportId: id,
      occurredAt: DateTime.utc(2026, 8, 16, 1, 2, 3),
      errorType: 'StateError',
      safeMessage: 'safe',
      stack: stack,
      requestId: 'req-$id',
      reportedAppVersion: '2.4.0',
      reportedBuildNumber: '30',
    );

NebulaResponse _acceptAll(NebulaRequest request) {
  final Map<String, Object?> body = request.body! as Map<String, Object?>;
  final List<Object?> reports = body['reports']! as List<Object?>;
  return NebulaResponse(
    statusCode: 200,
    data: <String, Object?>{
      'accepted': <Object?>[
        for (final Object? item in reports)
          <String, Object?>{
            'report_id': (item! as Map<String, Object?>)['report_id'],
            'ingested_at': 1786850403,
            'duplicate': false,
          },
      ],
      'rejected': <Object?>[],
      'defer_remaining': false,
      'retry_after_seconds': null,
    },
  );
}

MobileErrorReportSender _sender(
  _ScriptedTransport transport, {
  DateTime Function()? now,
  Future<bool> Function()? recovery,
  Future<String> Function()? token,
  RequestProofSigner? signer,
}) =>
    MobileErrorReportSender(
      options: _options,
      transport: transport,
      proofSigner: signer ?? RecordingProofSigner(),
      installationToken: token ?? () async => 'token',
      recoverInstallationTrust: recovery ?? () async => true,
      now: now,
      rateLimitCooldown: const Duration(seconds: 30),
    );

void main() {
  test('maps partial accepted/rejected response exactly', () async {
    final _ScriptedTransport transport = _ScriptedTransport()
      ..steps.add((NebulaRequest request) {
        final body = request.body! as Map<String, Object?>;
        final reports = body['reports']! as List<Object?>;
        final a = reports[0]! as Map<String, Object?>;
        final b = reports[1]! as Map<String, Object?>;
        return NebulaResponse(
          statusCode: 200,
          data: <String, Object?>{
            'accepted': <Object?>[
              <String, Object?>{
                'report_id': a['report_id'],
                'ingested_at': 1,
                'duplicate': false,
              },
            ],
            'rejected': <Object?>[
              <String, Object?>{
                'report_id': b['report_id'],
                'reason': 'id_conflict',
              },
            ],
            'defer_remaining': false,
            'retry_after_seconds': null,
          },
        );
      });
    final RecordingProofSigner signer = RecordingProofSigner();
    final ErrorReportSendResult result =
        await _sender(transport, signer: signer)
            .send(<NebulaErrorReport>[_report('a'), _report('b')]);
    expect(result.disposition, ErrorReportSendDisposition.processed);
    expect(result.acceptedReportIds, <String>{'a'});
    expect(result.rejectedReportIds, <String>{'b'});
    final Map<String, Object?> body =
        transport.requests.single.body! as Map<String, Object?>;
    expect(body.containsKey('app_id'), isFalse);
    expect(body.containsKey('installation_id'), isFalse);
    expect(utf8.encode(jsonEncode(body)).length, lessThanOrEqualTo(16 * 1024));
    expect(signer.signed, hasLength(1));
    final List<String> proof = signer.signed.single.split('\n');
    expect(proof[1], 'POST');
    expect(proof[2], '/base/api/v1/mobile/error-reports');
  });

  test('429 defers without a second network call during cooldown', () async {
    final DateTime now = DateTime.utc(2026, 8, 16);
    final _ScriptedTransport transport = _ScriptedTransport()
      ..steps
          .add((_) => throw const NebulaHttpException('rate', statusCode: 429));
    final MobileErrorReportSender sender = _sender(transport, now: () => now);
    final ErrorReportSendResult first =
        await sender.send(<NebulaErrorReport>[_report('a')]);
    expect(first.disposition, ErrorReportSendDisposition.rateLimitedDefer);
    final ErrorReportSendResult second =
        await sender.send(<NebulaErrorReport>[_report('a')]);
    expect(second.disposition, ErrorReportSendDisposition.rateLimitedDefer);
    expect(transport.requests, hasLength(1));
  });

  test('30001 and transient backend codes map to distinct dispositions',
      () async {
    final _ScriptedTransport transport = _ScriptedTransport()
      ..steps.add((_) => throw const NebulaApiException('bad', code: 30001))
      ..steps.add((_) => throw const NebulaApiException('temp', code: 12004));
    final MobileErrorReportSender sender = _sender(transport);
    expect(
      (await sender.send(<NebulaErrorReport>[_report('a')])).disposition,
      ErrorReportSendDisposition.deterministicRequestFailure,
    );
    expect(
      (await sender.send(<NebulaErrorReport>[_report('b')])).disposition,
      ErrorReportSendDisposition.transientFailure,
    );
  });

  test('12001 requires recovery before next network send', () async {
    DateTime now = DateTime.utc(2026, 8, 16);
    String token = 'old-token';
    int recoveryCalls = 0;
    final _ScriptedTransport transport = _ScriptedTransport()
      ..steps.add((_) => throw const NebulaApiException('trust', code: 12001))
      ..steps.add(_acceptAll);
    final MobileErrorReportSender sender = _sender(
      transport,
      now: () => now,
      token: () async => token,
      recovery: () async {
        recoveryCalls++;
        token = 'new-token';
        return true;
      },
    );
    final NebulaErrorReport report = _report('a');
    final ErrorReportSendResult first =
        await sender.send(<NebulaErrorReport>[report]);
    expect(first.disposition, ErrorReportSendDisposition.trustRecoveryRequired);
    final ErrorReportSendResult blocked =
        await sender.send(<NebulaErrorReport>[report]);
    expect(
        blocked.disposition, ErrorReportSendDisposition.trustRecoveryRequired);
    expect(transport.requests, hasLength(1));
    expect(recoveryCalls, 0);

    now = now.add(const Duration(seconds: 30));
    final ErrorReportSendResult recovered =
        await sender.send(<NebulaErrorReport>[report]);
    expect(recoveryCalls, 1);
    expect(recovered.disposition, ErrorReportSendDisposition.processed);
    expect(recovered.acceptedReportIds, <String>{'a'});
    expect(transport.requests, hasLength(2));
    expect(
        transport.requests.last.headers['X-Installation-Token'], 'new-token');
  });

  test('defensively splits complete request to at most 16 KiB', () async {
    final _ScriptedTransport transport = _ScriptedTransport()
      ..steps.add(_acceptAll);
    final MobileErrorReportSender sender = _sender(transport);
    final ErrorReportSendResult result = await sender.send(<NebulaErrorReport>[
      _report('a', stack: 'x' * 8000),
      _report('b', stack: 'y' * 8000),
      _report('c', stack: 'z' * 8000),
    ]);
    final Map<String, Object?> body =
        transport.requests.single.body! as Map<String, Object?>;
    final List<Object?> sent = body['reports']! as List<Object?>;
    expect(sent.length, lessThan(3));
    expect(utf8.encode(jsonEncode(body)).length, lessThanOrEqualTo(16 * 1024));
    expect(result.acceptedReportIds.length, sent.length);
    expect(result.affectedReportIds, result.acceptedReportIds);
  });
}
