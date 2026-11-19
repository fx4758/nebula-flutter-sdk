import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nebula_sdk/src/analytics/event.dart';
import 'package:nebula_sdk/src/analytics/mobile_analytics_sender.dart';
import 'package:nebula_sdk/src/error_reporting/mobile_error_report_sender.dart';
import 'package:nebula_sdk/src/error_reporting/report.dart';
import 'package:nebula_sdk/src/foundation/errors.dart';
import 'package:nebula_sdk/src/foundation/options.dart';
import 'package:nebula_sdk/src/foundation/sha256.dart';
import 'package:nebula_sdk/src/observability/mobile_wire_v2.dart';
import 'package:nebula_sdk/src/testing/recording_proof_signer.dart';
import 'package:nebula_sdk/src/transport.dart';
import 'package:nebula_sdk/src/transport/http_transport.dart';
import 'package:nebula_sdk/src/transport/proof_headers.dart';
import 'package:test/test.dart';

class _SpyTransport implements NebulaTransport {
  final requests = <NebulaRequest>[];
  @override
  Future<NebulaResponse> send(NebulaRequest request) async {
    requests.add(request);
    final body = request.body! as Map<String, Object?>;
    if (request.path.endsWith('analytics/batches')) {
      return NebulaResponse(
        statusCode: 200,
        data: <String, Object?>{
          'batch_id': body['b'] ?? body['batch_id'],
          'accepted_events': ((body['e'] ?? body['events']) as List).length,
          'duplicate': false,
          'ingested_at': 1795080000,
        },
      );
    }
    final rows = (body['r'] ?? body['reports']) as List<Object?>;
    return NebulaResponse(
      statusCode: 200,
      data: <String, Object?>{
        'accepted': [
          for (final row in rows)
            <String, Object?>{
              'report_id': row is List
                  ? row.first
                  : (row as Map<String, Object?>)['report_id'],
              'ingested_at': 1795080000,
              'duplicate': false,
            },
        ],
        'rejected': <Object>[],
        'defer_remaining': false,
      },
    );
  }
}

// Emulates the deployed V1 strict decoder rejecting the unknown V2 keys
// before any receipt is stored. Successful fallback returns legacy ACKs.
class _V1OnlyTransport implements NebulaTransport {
  final requests = <NebulaRequest>[];
  int rejectCount = 0;
  bool rejectAll = false;

  @override
  Future<NebulaResponse> send(NebulaRequest request) async {
    requests.add(request);
    final body = request.body! as Map<String, Object?>;
    if (rejectAll || body['v'] == 2) {
      rejectCount++;
      throw const NebulaApiException('unknown protocol', code: 30001);
    }
    if (request.path.endsWith('analytics/batches')) {
      final events = body['events']! as List<Object?>;
      return NebulaResponse(
        statusCode: 200,
        data: <String, Object?>{
          'batch_id': body['batch_id'],
          'accepted_events': events.length,
          'duplicate': false,
          'ingested_at': 1795080000,
        },
      );
    }
    final reports = body['reports']! as List<Object?>;
    return NebulaResponse(
      statusCode: 200,
      data: <String, Object?>{
        'accepted': <Object?>[
          for (final item in reports)
            <String, Object?>{
              'report_id': (item! as Map<String, Object?>)['report_id'],
              'duplicate': false,
              'ingested_at': 1795080000,
            },
        ],
        'rejected': <Object?>[],
        'defer_remaining': false,
      },
    );
  }
}

NebulaOptions get _options => NebulaOptions(
  appId: 'wire',
  baseUri: Uri.parse('https://wire.invalid'),
  environment: NebulaEnvironment.staging,
);

void main() {
  final clock = DateTime.utc(2026, 11, 19, 12, 0);
  test('V2 omits redundant and personally identifiable fields', () {
    final events = <NebulaAnalyticsEvent>[
      NebulaAnalyticsEvent(
        name: 'page_view',
        privacy: NebulaEventPrivacy.anonymous,
        properties: {'page': 'home'},
        timestamp: clock,
      ),
      NebulaAnalyticsEvent(
        name: 'feature_outcome',
        privacy: NebulaEventPrivacy.anonymous,
        properties: {'feature': 'nfc_write', 'result': 'success'},
        timestamp: clock,
      ),
    ];
    final compact = compactAnalyticsBatch('batch', events)!;
    expect(compact.keys, containsAll(<String>['v', 'b', 'e']));
    expect(jsonEncode(compact), isNot(contains('identifiable')));
    expect(jsonEncode(compact), isNot(contains('properties')));
    final legacy = <String, Object?>{
      'batch_id': 'batch',
      'events': [
        for (final e in events)
          <String, Object?>{
            'name': e.name,
            'occurred_at': e.timestamp.millisecondsSinceEpoch ~/ 1000,
            'identifiable': false,
            'properties': e.properties,
          },
      ],
    };
    expect(
      utf8.encode(jsonEncode(compact)).length,
      lessThan(utf8.encode(jsonEncode(legacy)).length ~/ 2),
    );
  });
  test('unknown or identifiable analytics never silently lose fields', () {
    final e = NebulaAnalyticsEvent(
      name: 'page_view',
      privacy: NebulaEventPrivacy.identifiable,
      properties: {'page': 'home'},
      timestamp: clock,
    );
    expect(compactAnalyticsBatch('batch', [e]), isNull);
    final unknown = NebulaAnalyticsEvent(
      name: 'page_view',
      privacy: NebulaEventPrivacy.anonymous,
      properties: {'page': 'home', 'card_uid': 'SECRET'},
      timestamp: clock,
    );
    expect(compactAnalyticsBatch('batch', [unknown]), isNull);
  });
  test(
    'errors omit fixed message and null IDs; unknown stack falls back to V1',
    () {
      NebulaErrorReport report(String stack) => NebulaErrorReport(
        reportId: 'r1',
        occurredAt: clock,
        errorType: 'StateError',
        safeMessage: 'caught_error',
        stack: stack,
      );
      final compact = compactErrorReports([report('#0 NFCWriter.run')])!;
      expect(jsonEncode(compact), isNot(contains('safe_message')));
      expect(jsonEncode(compact), isNot(contains('request_id')));
      expect(
        compactErrorReports([report('URL=https://example.com/private')]),
        isNull,
      );
    },
  );
  test('adaptive gzip reduces large uploads, skips tiny packets', () {
    final large = {
      'v': 2,
      'b': 'batch',
      'e': [
        for (var i = 0; i < 48; i++) <Object>['p', 1795080000, 'home'],
      ],
    };
    final zip = maybeCompressTelemetry(large)!;
    final raw = utf8.encode(jsonEncode(large));
    expect(zip.length, lessThan(raw.length * 0.8));
    expect(utf8.decode(gzip.decode(zip)), jsonEncode(large));
    expect(
      maybeCompressTelemetry({
        'v': 2,
        'b': 'x',
        'e': [
          ['p', 1795080000, 'home'],
        ],
      }),
      isNull,
    );
  });
  test(
    'analytics V2 signed hash matches gzip bytes and stable batch ACK',
    () async {
      final spy = _SpyTransport();
      final signer = RecordingProofSigner();
      final sender = MobileAnalyticsSender(
        options: _options,
        transport: spy,
        proofSigner: signer,
        installationToken: () async => 'token',
        recoverInstallationTrust: () async => true,
        batchIdGenerator: () => 'fixed-id',
        compactWireV2: true,
      );
      final events = <NebulaAnalyticsEvent>[
        for (var i = 0; i < 48; i++)
          NebulaAnalyticsEvent(
            name: 'page_view',
            privacy: NebulaEventPrivacy.anonymous,
            properties: {'page': 'home'},
            timestamp: clock,
          ),
      ];
      final assigned = sender.assignBatch(events);
      expect(assigned.body['v'], 2);
      expect((await sender.sendAssigned(assigned)).name, 'success');
      final req = spy.requests.single;
      expect(req.headers['Content-Encoding'], 'gzip');
      final bytes = req.bodyBytes!;
      expect(utf8.decode(gzip.decode(bytes)), jsonEncode(req.body));
      expect(signer.signed.single.split('\n')[5], sha256Hex(bytes));
    },
  );
  test('error-report V2 removes fixed message, keeps ACK contract', () async {
    final spy = _SpyTransport();
    final signer = RecordingProofSigner();
    final sender = MobileErrorReportSender(
      options: _options,
      transport: spy,
      proofSigner: signer,
      installationToken: () async => 'token',
      recoverInstallationTrust: () async => true,
      compactWireV2: true,
    );
    final report = NebulaErrorReport(
      reportId: 'report-1',
      occurredAt: clock,
      errorType: 'StateError',
      safeMessage: 'caught_error',
      stack: '#0 NFCWriter.run',
    );
    final result = await sender.send([report]);
    expect(result.acceptedReportIds, contains('report-1'));
    expect((spy.requests.single.body as Map)['v'], 2);
    expect(spy.requests.single.bodyBytes, isNull); // tiny packet, no gzip CPU
  });
  test('real HttpTransport uploads only pre-signed compressed bytes', () async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    final captured = Completer<List<int>>();
    server.listen((req) async {
      final data = await req.fold<List<int>>(
        <int>[],
        (acc, bytes) => acc..addAll(bytes),
      );
      expect(req.headers.value('Content-Encoding'), 'gzip');
      captured.complete(data);
      req.response.headers.contentType = ContentType.json;
      req.response.write('{"code":0,"data":{"ok":true}}');
      await req.response.close();
    });
    addTearDown(() => server.close(force: true));
    final body = {
      'v': 2,
      'b': 'id',
      'e': [
        for (var i = 0; i < 48; i++) ['p', 1795080000, 'home'],
      ],
    };
    final encoded = maybeCompressTelemetry(body)!;
    final signer = RecordingProofSigner();
    final headers = await buildAuthHeaders(
      method: NebulaHttpMethod.post,
      resolvedPath: '/wire',
      body: body,
      bodyBytes: encoded,
      installationToken: 'token',
      signer: signer,
    );
    final response =
        await HttpTransport(
          baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        ).send(
          NebulaRequest(
            method: NebulaHttpMethod.post,
            path: '/wire',
            body: body,
            bodyBytes: encoded,
            headers: {...headers, 'Content-Encoding': 'gzip'},
          ),
        );
    expect(response.statusCode, 200);
    expect(await captured.future, encoded);
    expect(signer.signed.single.split('\n')[5], sha256Hex(encoded));
  });
  test(
    'new SDK on V1 server downgrades analytics once; keeps batch id',
    () async {
      final legacy = _V1OnlyTransport();
      final signer = RecordingProofSigner();
      final sender = MobileAnalyticsSender(
        options: _options,
        transport: legacy,
        proofSigner: signer,
        installationToken: () async => 'token',
        recoverInstallationTrust: () async => true,
        batchIdGenerator: () => 'stable-batch',
        compactWireV2: true,
      );
      NebulaAnalyticsEvent getPage() => NebulaAnalyticsEvent(
        name: 'page_view',
        privacy: NebulaEventPrivacy.anonymous,
        properties: {'page': 'home'},
        timestamp: clock,
      );
      final assigned = sender.assignBatch([getPage()]);
      expect(assigned.body['v'], 2);
      expect(
        await sender.sendAssigned(assigned),
        MobileAnalyticsSendDisposition.success,
      );
      expect(legacy.requests, hasLength(2));
      expect(legacy.rejectCount, 1);
      expect(legacy.requests.first.body! as Map, containsPair('v', 2));
      expect(
        legacy.requests.last.body! as Map,
        containsPair('batch_id', 'stable-batch'),
      );
      expect(legacy.requests.last.headers, isNot(contains('Content-Encoding')));
      // Future batches do not make another V2 probe to the old server.
      expect(sender.assignBatch([getPage()]).body['v'], isNull);
      expect(
        await sender.sendAssigned(assigned),
        MobileAnalyticsSendDisposition.success,
      );
      expect(legacy.rejectCount, 1);
      expect(legacy.requests.length, 3);
    },
  );

  test(
    'V1-only server error-report fallback keeps report IDs and queue data',
    () async {
      final legacy = _V1OnlyTransport();
      final sender = MobileErrorReportSender(
        options: _options,
        transport: legacy,
        proofSigner: RecordingProofSigner(),
        installationToken: () async => 'token',
        recoverInstallationTrust: () async => true,
        compactWireV2: true,
      );
      NebulaErrorReport mk(String id) => NebulaErrorReport(
        reportId: id,
        occurredAt: clock,
        errorType: 'StateError',
        safeMessage: 'caught_error',
        stack: '#0 NFCWriter.run',
      );
      final result = await sender.send([mk('report-1')]);
      expect(result.acceptedReportIds, {'report-1'});
      expect(legacy.requests.length, 2);
      expect(legacy.requests.first.body! as Map, containsPair('v', 2));
      final rows = (legacy.requests.last.body! as Map)['reports'] as List;
      expect((rows.first as Map)['report_id'], 'report-1');
      expect(legacy.rejectCount, 1);
      expect((await sender.send([mk('report-2')])).acceptedReportIds, {
        'report-2',
      });
      expect(legacy.requests.length, 3);
      expect(legacy.rejectCount, 1);
    },
  );

  test('old server rejecting even V1 is bounded to two attempts', () async {
    final legacy = _V1OnlyTransport()..rejectAll = true;
    final analytics = MobileAnalyticsSender(
      options: _options,
      transport: legacy,
      proofSigner: RecordingProofSigner(),
      installationToken: () async => 'token',
      recoverInstallationTrust: () async => true,
      batchIdGenerator: () => 'bad-server',
      compactWireV2: true,
    );
    final e = NebulaAnalyticsEvent(
      name: 'page_view',
      privacy: NebulaEventPrivacy.anonymous,
      properties: {'page': 'home'},
      timestamp: clock,
    );
    expect(
      await analytics.sendAssigned(analytics.assignBatch([e])),
      MobileAnalyticsSendDisposition.nonRetryable,
    );
    expect(legacy.requests.length, 2);
    expect(analytics.assignBatch([e]).body['v'], isNull);
  });
}
