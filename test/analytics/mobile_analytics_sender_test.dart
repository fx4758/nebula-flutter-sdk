import 'dart:convert';

import 'package:nebula_sdk/src/analytics/analytics_client.dart';
import 'package:nebula_sdk/src/analytics/consent.dart';
import 'package:nebula_sdk/src/analytics/event.dart';
import 'package:nebula_sdk/src/analytics/mobile_analytics_sender.dart';
import 'package:nebula_sdk/src/auth/proof.dart';
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
    final Map<String, Object?> body = request.body! as Map<String, Object?>;
    final List<Object?> events = body['events']! as List<Object?>;
    return NebulaResponse(
      statusCode: 200,
      data: <String, Object?>{
        'batch_id': body['batch_id'],
        'accepted_events': events.length,
        'duplicate': false,
        'ingested_at': 1786850403,
      },
    );
  }
}

NebulaOptions _options() => NebulaOptions(
      appId: 'app',
      baseUri: Uri.parse('https://api.example.com/base'),
      environment: NebulaEnvironment.production,
    );

NebulaAnalyticsEvent _event(String name, {int payloadBytes = 0}) =>
    NebulaAnalyticsEvent(
      name: name,
      privacy: NebulaEventPrivacy.anonymous,
      timestamp:
          DateTime.fromMillisecondsSinceEpoch(1786850400000, isUtc: true),
      properties: payloadBytes == 0
          ? const <String, Object?>{'screen': 'home'}
          : <String, Object?>{'payload': 'x' * payloadBytes},
    );

void main() {
  test('assigns exact frozen wire and shrinks to <=16 KiB', () {
    final MobileAnalyticsSender sender = MobileAnalyticsSender(
      options: _options(),
      transport: _Transport(),
      proofSigner: RecordingProofSigner(),
      installationToken: () async => 'installation-token',
      batchIdGenerator: () => 'batch-fixed',
    );
    final AssignedMobileAnalyticsBatch batch = sender.assignBatch(
      <NebulaAnalyticsEvent>[
        _event('a', payloadBytes: 7000),
        _event('b', payloadBytes: 7000),
        _event('c', payloadBytes: 7000),
      ],
    );
    expect(batch.batchId, 'batch-fixed');
    expect(batch.events.length, 2);
    expect(batch.encodedBytes, lessThanOrEqualTo(16 * 1024));
    expect(utf8.encode(jsonEncode(batch.body)).length, batch.encodedBytes);
    final Map<String, Object?> mapped =
        (batch.body['events']! as List<Object?>).first as Map<String, Object?>;
    expect(mapped.keys,
        <String>['name', 'occurred_at', 'identifiable', 'properties']);
    expect(mapped['occurred_at'], 1786850400);
    expect(mapped.containsKey('timestamp'), isFalse);
  });

  test('proof covers exact resolved path and exact body', () async {
    final _Transport transport = _Transport();
    final RecordingProofSigner signer = RecordingProofSigner();
    final MobileAnalyticsSender sender = MobileAnalyticsSender(
      options: _options(),
      transport: transport,
      proofSigner: signer,
      installationToken: () async => 'installation-token',
      batchIdGenerator: () => 'batch-proof',
    );
    final AssignedMobileAnalyticsBatch batch =
        sender.assignBatch(<NebulaAnalyticsEvent>[_event('screen')]);
    expect(await sender.sendAssigned(batch),
        MobileAnalyticsSendDisposition.success);
    final NebulaRequest request = transport.requests.single;
    expect(request.path, '/api/v1/mobile/analytics/batches');
    expect(identical(request.body, batch.body), isTrue);
    expect(request.headers['X-Installation-Token'], 'installation-token');
    final List<String> canonical = signer.signed.single.split('\n');
    expect(canonical[1], 'POST');
    expect(canonical[2], '/base/api/v1/mobile/analytics/batches');
  });

  test('same assigned batch_id survives bounded retry and later flush',
      () async {
    final _Transport transport = _Transport()
      ..scripted.addAll(<Object>[
        const NebulaHttpException('down', statusCode: 503),
        const NebulaHttpException('down', statusCode: 503),
      ]);
    int ids = 0;
    final MobileAnalyticsSender sender = MobileAnalyticsSender(
      options: _options(),
      transport: transport,
      proofSigner: RecordingProofSigner(),
      installationToken: () async => 'installation-token',
      batchIdGenerator: () => 'batch-${++ids}',
    );
    final NebulaAnalyticsClient client = NebulaAnalyticsClient(
      consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
      sender: sender,
      sendRetries: 1,
      sendRetryBaseDelay: Duration.zero,
    );
    await client.track(_event('retry'));
    await client.flush();
    expect(client.pendingCount, 1);
    expect(ids, 1);
    await client.flush();
    expect(client.pendingCount, 0);
    expect(client.sentCount, 1);
    final List<Object?> batchIds = transport.requests
        .map((NebulaRequest r) => (r.body! as Map<String, Object?>)['batch_id'])
        .toList();
    expect(batchIds, <Object?>['batch-1', 'batch-1', 'batch-1']);
    expect(ids, 1, reason: 'requeue must not allocate replacement batch_id');
  });

  test('429 defers without immediate retry and keeps assigned batch', () async {
    final _Transport transport = _Transport()
      ..scripted.add(const NebulaHttpException('rate', statusCode: 429));
    final MobileAnalyticsSender sender = MobileAnalyticsSender(
      options: _options(),
      transport: transport,
      proofSigner: RecordingProofSigner(),
      installationToken: () async => 'installation-token',
      batchIdGenerator: () => 'batch-rate',
    );
    final NebulaAnalyticsClient client = NebulaAnalyticsClient(
      consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
      sender: sender,
      sendRetries: 5,
      sendRetryBaseDelay: Duration.zero,
    );
    await client.track(_event('rate'));
    await client.flush();
    expect(transport.requests, hasLength(1));
    expect(client.pendingCount, 1);
  });

  test('30001 is non-retryable and does not poison later queue', () async {
    final _Transport transport = _Transport()
      ..scripted.add(const NebulaApiException('invalid', code: 30001));
    final MobileAnalyticsSender sender = MobileAnalyticsSender(
      options: _options(),
      transport: transport,
      proofSigner: RecordingProofSigner(),
      installationToken: () async => 'installation-token',
      batchIdGenerator: () => 'batch-invalid',
    );
    final NebulaAnalyticsClient client = NebulaAnalyticsClient(
      consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
      sender: sender,
      sendRetries: 5,
    );
    await client.track(_event('invalid'));
    await client.flush();
    expect(transport.requests, hasLength(1));
    expect(client.pendingCount, 0);
    expect(client.droppedCount, 1);
  });
}
