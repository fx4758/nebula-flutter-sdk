import 'dart:convert';

import 'package:nebula_sdk/src/auth/proof.dart';
import 'package:nebula_sdk/src/error_reporting/mobile_error_report_sender.dart';
import 'package:nebula_sdk/src/error_reporting/report.dart';
import 'package:nebula_sdk/src/foundation/errors.dart';
import 'package:nebula_sdk/src/foundation/options.dart';
import 'package:nebula_sdk/src/transport.dart';
import 'package:test/test.dart';

final class _Transport implements NebulaTransport {
  final List<NebulaRequest> requests = <NebulaRequest>[];
  final List<Object> scripted = <Object>[];

  @override
  Future<NebulaResponse> send(NebulaRequest request) async {
    requests.add(request);
    if (scripted.isNotEmpty) {
      final Object next = scripted.removeAt(0);
      if (next is NebulaResponse) return next;
      if (next is Exception) throw next;
      if (next is Error) throw next;
      throw StateError('invalid transport script entry');
    }
    final List<Object?> reports =
        (request.body! as Map<String, Object?>)['reports']! as List<Object?>;
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
        'rejected': const <Object?>[],
        'defer_remaining': false,
        'retry_after_seconds': null,
      },
    );
  }
}

NebulaOptions _options() => NebulaOptions(
      appId: 'app',
      baseUri: Uri.parse('https://api.example.com/base'),
      environment: NebulaEnvironment.production,
    );

NebulaErrorReport _report(String id, {int stackBytes = 8}) => NebulaErrorReport(
      reportId: id,
      occurredAt:
          DateTime.fromMillisecondsSinceEpoch(1786850400000, isUtc: true),
      errorType: 'StateError',
      safeMessage: 'failed',
      stack: 's' * stackBytes,
      requestId: null,
      reportedAppVersion: '2.4.0',
      reportedBuildNumber: '30',
    );

void main() {
  test('sends exact wire with proof and maps partial result', () async {
    final _Transport transport = _Transport()
      ..scripted.add(
        const NebulaResponse(
          statusCode: 200,
          data: <String, Object?>{
            'accepted': <Object?>[
              <String, Object?>{
                'report_id': 'r1',
                'ingested_at': 1786850403,
                'duplicate': false,
              },
            ],
            'rejected': <Object?>[
              <String, Object?>{
                'report_id': 'r2',
                'reason': 'id_conflict',
              },
            ],
            'defer_remaining': true,
            'retry_after_seconds': 7,
          },
        ),
      );
    final RecordingProofSigner signer = RecordingProofSigner();
    final MobileErrorReportSender sender = MobileErrorReportSender(
      options: _options(),
      transport: transport,
      proofSigner: signer,
      installationToken: () async => 'installation-token',
    );
    final result = await sender.send(
      <NebulaErrorReport>[_report('r1'), _report('r2')],
    );
    expect(result.acceptedReportIds, <String>{'r1'});
    expect(result.rejectedReportIds, <String>{'r2'});
    expect(result.deferRemaining, isTrue);
    expect(result.retryAfter, const Duration(seconds: 7));
    final NebulaRequest request = transport.requests.single;
    expect(request.path, '/api/v1/mobile/error-reports');
    expect(request.headers['X-Installation-Token'], 'installation-token');
    final List<Object?> reports =
        (request.body! as Map<String, Object?>)['reports']! as List<Object?>;
    final Map<String, Object?> first = reports.first as Map<String, Object?>;
    expect(first.keys, <String>[
      'report_id',
      'occurred_at',
      'error_type',
      'safe_message',
      'stack',
      'request_id',
      'reported_app_version',
      'reported_build_number',
    ]);
    expect(first['request_id'], isNull);
    final List<String> canonical = signer.signed.single.split('\n');
    expect(canonical[1], 'POST');
    expect(canonical[2], '/base/api/v1/mobile/error-reports');
  });

  test('shrinks complete request to <=16 KiB without inventing ACKs', () async {
    final _Transport transport = _Transport();
    final MobileErrorReportSender sender = MobileErrorReportSender(
      options: _options(),
      transport: transport,
      proofSigner: RecordingProofSigner(),
      installationToken: () async => 'installation-token',
    );
    final result = await sender.send(<NebulaErrorReport>[
      _report('r1', stackBytes: 7000),
      _report('r2', stackBytes: 7000),
      _report('r3', stackBytes: 7000),
    ]);
    final Map<String, Object?> body =
        transport.requests.single.body! as Map<String, Object?>;
    final List<Object?> sent = body['reports']! as List<Object?>;
    expect(sent.length, 2);
    expect(utf8.encode(jsonEncode(body)).length, lessThanOrEqualTo(16 * 1024));
    expect(result.acceptedReportIds, <String>{'r1', 'r2'});
    expect(result.acceptedReportIds.contains('r3'), isFalse);
  });

  test('unknown ACK IDs fail closed', () async {
    final _Transport transport = _Transport()
      ..scripted.add(
        const NebulaResponse(
          statusCode: 200,
          data: <String, Object?>{
            'accepted': <Object?>[
              <String, Object?>{
                'report_id': 'other',
                'ingested_at': 1,
                'duplicate': false,
              },
            ],
            'rejected': <Object?>[],
            'defer_remaining': false,
            'retry_after_seconds': null,
          },
        ),
      );
    final MobileErrorReportSender sender = MobileErrorReportSender(
      options: _options(),
      transport: transport,
      proofSigner: RecordingProofSigner(),
      installationToken: () async => 'installation-token',
    );
    await expectLater(
      sender.send(<NebulaErrorReport>[_report('r1')]),
      throwsA(isA<NebulaHttpException>()),
    );
  });

  test('429 defers full unprocessed set with bounded cooldown', () async {
    DateTime now = DateTime.utc(2026, 8, 16);
    final _Transport transport = _Transport()
      ..scripted.add(const NebulaHttpException('rate', statusCode: 429));
    final MobileErrorReportSender sender = MobileErrorReportSender(
      options: _options(),
      transport: transport,
      proofSigner: RecordingProofSigner(),
      installationToken: () async => 'installation-token',
      now: () => now,
      rateLimitCooldown: const Duration(seconds: 20),
    );
    final first = await sender.send(<NebulaErrorReport>[_report('r1')]);
    expect(first.acceptedReportIds, isEmpty);
    expect(first.rejectedReportIds, isEmpty);
    expect(first.deferRemaining, isTrue);
    expect(first.retryAfter, const Duration(seconds: 20));
    final second = await sender.send(<NebulaErrorReport>[_report('r1')]);
    expect(second.deferRemaining, isTrue);
    expect(transport.requests, hasLength(1));
    now = now.add(const Duration(seconds: 20));
    await sender.send(<NebulaErrorReport>[_report('r1')]);
    expect(transport.requests, hasLength(2));
  });

  test('12004 stays retryable and never manufactures per-report result',
      () async {
    final _Transport transport = _Transport()
      ..scripted
          .add(const NebulaApiException('store unavailable', code: 12004));
    final MobileErrorReportSender sender = MobileErrorReportSender(
      options: _options(),
      transport: transport,
      proofSigner: RecordingProofSigner(),
      installationToken: () async => 'installation-token',
    );
    await expectLater(
      sender.send(<NebulaErrorReport>[_report('r1')]),
      throwsA(isA<NebulaHttpException>()),
    );
  });
}
