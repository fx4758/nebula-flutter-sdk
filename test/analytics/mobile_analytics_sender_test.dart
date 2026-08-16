import 'dart:async';
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

typedef _Step = FutureOr<NebulaResponse> Function(NebulaRequest request);

final class _ScriptedTransport implements NebulaTransport {
  final List<_Step> steps = <_Step>[];
  final List<NebulaRequest> requests = <NebulaRequest>[];

  @override
  Future<NebulaResponse> send(NebulaRequest request) async {
    requests.add(request);
    if (steps.isEmpty) throw StateError('missing transport step');
    return steps.removeAt(0)(request);
  }
}

NebulaOptions get _options => NebulaOptions(
      appId: 'app-test',
      baseUri: Uri.parse('https://example.invalid/base'),
      environment: NebulaEnvironment.staging,
    );

NebulaAnalyticsEvent _event(String name, {int padding = 0}) =>
    NebulaAnalyticsEvent(
      name: name,
      privacy: NebulaEventPrivacy.anonymous,
      timestamp: DateTime.utc(2026, 8, 16, 1, 2, 3),
      properties: <String, Object?>{
        if (padding > 0) 'padding': 'x' * padding,
      },
    );

NebulaResponse _analyticsAck(NebulaRequest request) {
  final Map<String, Object?> body = request.body! as Map<String, Object?>;
  return NebulaResponse(
    statusCode: 200,
    data: <String, Object?>{
      'batch_id': body['batch_id'],
      'accepted_events': (body['events']! as List<Object?>).length,
      'duplicate': false,
      'ingested_at': 1786850403,
    },
  );
}

void main() {
  test('assigns final immutable batch only after exact body fits 16 KiB', () {
    int ids = 0;
    final MobileAnalyticsSender sender = MobileAnalyticsSender(
      options: _options,
      transport: _ScriptedTransport(),
      proofSigner: RecordingProofSigner(),
      installationToken: () async => 'token',
      recoverInstallationTrust: () async => true,
      batchIdGenerator: () => 'batch-${++ids}',
    );
    final List<NebulaAnalyticsEvent> candidates = <NebulaAnalyticsEvent>[
      _event('a', padding: 5000),
      _event('b', padding: 5000),
      _event('c', padding: 5000),
      _event('d', padding: 5000),
    ];
    final AssignedMobileAnalyticsBatch assigned =
        sender.assignBatch(candidates);
    expect(assigned.batchId, 'batch-1');
    expect(assigned.events.length, lessThan(candidates.length));
    expect(assigned.encodedBytes, lessThanOrEqualTo(16 * 1024));
    expect(
        utf8.encode(jsonEncode(assigned.body)).length, assigned.encodedBytes);
    final Map<String, Object?> first =
        (assigned.body['events']! as List<Object?>).first
            as Map<String, Object?>;
    expect(first.containsKey('occurred_at'), isTrue);
    expect(first.containsKey('timestamp'), isFalse);
  });

  test('transient retry reuses exact assigned batch_id and body', () async {
    final _ScriptedTransport transport = _ScriptedTransport()
      ..steps.add((_) => throw const NebulaTimeoutException('timeout'))
      ..steps.add(_analyticsAck);
    int ids = 0;
    final RecordingProofSigner signer = RecordingProofSigner();
    final MobileAnalyticsSender sender = MobileAnalyticsSender(
      options: _options,
      transport: transport,
      proofSigner: signer,
      installationToken: () async => 'token',
      recoverInstallationTrust: () async => true,
      batchIdGenerator: () => 'stable-${++ids}',
    );
    final NebulaAnalyticsClient client = NebulaAnalyticsClient(
      consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
      sender: sender,
      sendRetries: 1,
      sendRetryBaseDelay: Duration.zero,
    );
    await client.track(_event('tap'));
    await client.flush();
    expect(transport.requests, hasLength(2));
    expect(transport.requests[0].body, transport.requests[1].body);
    final Map<String, Object?> body =
        transport.requests[0].body! as Map<String, Object?>;
    expect(body['batch_id'], 'stable-1');
    expect(ids, 1);
    expect(signer.signed, hasLength(2));
    final List<String> firstProof = signer.signed[0].split('\n');
    final List<String> secondProof = signer.signed[1].split('\n');
    expect(firstProof[1], 'POST');
    expect(firstProof[2], '/base/api/v1/mobile/analytics/batches');
    expect(secondProof[2], firstProof[2]);
    expect(secondProof[5], firstProof[5], reason: 'same assigned body hash');
    expect(secondProof[6], firstProof[6],
        reason: 'same installation token hash');
    expect(client.pendingCount, 0);
    expect(client.sentCount, 1);
  });

  test('429 cooldown makes no network retry and preserves assigned ID',
      () async {
    DateTime now = DateTime.utc(2026, 8, 16);
    final _ScriptedTransport transport = _ScriptedTransport()
      ..steps
          .add((_) => throw const NebulaHttpException('rate', statusCode: 429))
      ..steps.add(_analyticsAck);
    int ids = 0;
    final MobileAnalyticsSender sender = MobileAnalyticsSender(
      options: _options,
      transport: transport,
      proofSigner: RecordingProofSigner(),
      installationToken: () async => 'token',
      recoverInstallationTrust: () async => true,
      batchIdGenerator: () => 'rate-${++ids}',
      now: () => now,
      rateLimitCooldown: const Duration(seconds: 30),
    );
    final NebulaAnalyticsClient client = NebulaAnalyticsClient(
      consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
      sender: sender,
      sendRetries: 0,
      now: () => now,
    );
    await client.track(_event('tap'));
    await client.flush();
    await client.flush();
    expect(transport.requests, hasLength(1));
    expect(client.pendingCount, 1);
    expect(ids, 1);
    now = now.add(const Duration(seconds: 30));
    await client.flush();
    expect(transport.requests, hasLength(2));
    expect(transport.requests[0].body, transport.requests[1].body);
    expect(client.pendingCount, 0);
  });

  test('12001 recovers installation trust before next network send', () async {
    DateTime now = DateTime.utc(2026, 8, 16);
    final _ScriptedTransport transport = _ScriptedTransport()
      ..steps.add(
        (_) => throw const NebulaApiException('invalid install', code: 12001),
      )
      ..steps.add(_analyticsAck);
    int recoveryCalls = 0;
    int ids = 0;
    String token = 'token-old';
    final MobileAnalyticsSender sender = MobileAnalyticsSender(
      options: _options,
      transport: transport,
      proofSigner: RecordingProofSigner(),
      installationToken: () async => token,
      recoverInstallationTrust: () async {
        recoveryCalls++;
        token = 'token-new';
        return true;
      },
      batchIdGenerator: () => 'trust-${++ids}',
      now: () => now,
      rateLimitCooldown: const Duration(seconds: 30),
    );
    final NebulaAnalyticsClient client = NebulaAnalyticsClient(
      consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
      sender: sender,
      sendRetries: 0,
      now: () => now,
    );
    await client.track(_event('tap'));
    await client.flush();
    await client.flush();
    expect(transport.requests, hasLength(1));
    expect(recoveryCalls, 0);
    expect(client.pendingCount, 1);

    now = now.add(const Duration(seconds: 30));
    await client.flush();
    expect(recoveryCalls, 1);
    expect(transport.requests, hasLength(2));
    expect(transport.requests[0].body, transport.requests[1].body);
    expect(transport.requests[1].headers['X-Installation-Token'], 'token-new');
    expect(ids, 1);
    expect(client.pendingCount, 0);
  });

  test('30001 is non-retryable and never replaces assigned batch_id', () async {
    final _ScriptedTransport transport = _ScriptedTransport()
      ..steps
          .add((_) => throw const NebulaApiException('conflict', code: 30001));
    int ids = 0;
    final MobileAnalyticsSender sender = MobileAnalyticsSender(
      options: _options,
      transport: transport,
      proofSigner: RecordingProofSigner(),
      installationToken: () async => 'token',
      recoverInstallationTrust: () async => true,
      batchIdGenerator: () => 'conflict-${++ids}',
    );
    final NebulaAnalyticsClient client = NebulaAnalyticsClient(
      consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
      sender: sender,
      sendRetries: 3,
      sendRetryBaseDelay: Duration.zero,
    );
    await client.track(_event('tap'));
    await client.flush();
    expect(transport.requests, hasLength(1));
    expect(ids, 1);
    expect(client.pendingCount, 0);
    expect(client.droppedCount, 1);
  });
}
