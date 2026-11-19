import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nebula_sdk/src/analytics/analytics_client.dart';
import 'package:nebula_sdk/src/analytics/cache_anonymous_analytics_queue.dart';
import 'package:nebula_sdk/src/analytics/consent.dart';
import 'package:nebula_sdk/src/analytics/event.dart';
import 'package:nebula_sdk/src/analytics/mobile_analytics_sender.dart';
import 'package:nebula_sdk/src/auth/proof.dart';
import 'package:nebula_sdk/src/foundation/errors.dart';
import 'package:nebula_sdk/src/foundation/options.dart';
import 'package:nebula_sdk/src/storage/cache_storage.dart';
import 'package:nebula_sdk/src/storage/storage_namespace.dart';
import 'package:nebula_sdk/src/transport.dart';
import 'package:test/test.dart';

final clock = DateTime.utc(2026, 11, 19, 8);
NebulaAnalyticsEvent page(String p) => NebulaAnalyticsEvent(
  name: 'page_view',
  privacy: NebulaEventPrivacy.anonymous,
  properties: {'page': p},
  timestamp: clock,
);

final class Transport implements NebulaTransport {
  final requests = <NebulaRequest>[];
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<NebulaResponse> send(NebulaRequest request) async {
    requests.add(request);
    if (gate != null) await gate!.future;
    if (fail) throw const NebulaTimeoutException('offline');
    final body = request.body! as Map<String, Object?>;
    return NebulaResponse(
      statusCode: 200,
      data: {
        'batch_id': body['b'] ?? body['batch_id'],
        'accepted_events': ((body['e'] ?? body['events']) as List).length,
        'duplicate': false,
        'ingested_at': 1795080000,
      },
    );
  }
}

CachedAnonymousAnalyticsQueue store(CacheStorage storage) =>
    CachedAnonymousAnalyticsQueue(
      storage: storage,
      environment: NebulaEnvironment.staging,
      appId: 'nfcwriter',
    );
NebulaAnalyticsClient client(
  CacheStorage storage,
  Transport transport, {
  String Function()? batchId,
}) {
  final sender = MobileAnalyticsSender(
    options: NebulaOptions(
      appId: 'nfcwriter',
      baseUri: Uri.parse('https://staging.invalid'),
      environment: NebulaEnvironment.staging,
    ),
    transport: transport,
    proofSigner: RecordingProofSigner(),
    installationToken: () async => 'token',
    recoverInstallationTrust: () async => true,
    compactWireV2: true,
    batchIdGenerator: batchId ?? () => 'fixed-id',
  );
  return NebulaAnalyticsClient(
    consentStore: InMemoryConsentStore(),
    sender: sender,
    anonymousQueue: store(storage),
    now: () => clock,
    sendRetries: 0,
  );
}

void main() {
  test(
    'anonymous events survive restart and ACK clears durable queue',
    () async {
      final storage = InMemoryCacheStorage();
      final first = client(storage, Transport());
      await first.track(page('home'));
      await first.track(page('history'));
      expect((await store(storage).load()).records, hasLength(2));
      final afterRestart = client(storage, Transport());
      expect(afterRestart.pendingCount, 0);
      await afterRestart.flush();
      expect(afterRestart.sentCount, 2);
      expect((await store(storage).load()).records, isEmpty);
    },
  );

  test('URL and identifiable event never persist', () async {
    final storage = InMemoryCacheStorage();
    final c = client(storage, Transport());
    await c.track(page('home'));
    await c.track(page('https://example.com/card?secret=1'));
    await c.track(
      NebulaAnalyticsEvent(
        name: 'page_view',
        privacy: NebulaEventPrivacy.identifiable,
        properties: {'page': 'home', 'uid': 'sensitive'},
        timestamp: clock,
      ),
    );
    final rows = (await store(storage).load()).records;
    expect(rows, hasLength(1));
    expect(rows.single.event.properties['page'], 'home');
  });

  test('uncertain ACK restart retries same batch ID and body', () async {
    final storage = InMemoryCacheStorage();
    final failed = Transport()..fail = true;
    final first = client(storage, failed, batchId: () => 'original-id');
    await first.track(page('home'));
    await first.flush();
    expect(first.pendingCount, 1);
    expect((await store(storage).load()).assignedBatchId, 'original-id');
    final replay = Transport();
    final resumed = client(storage, replay, batchId: () => 'WRONG-ID');
    await resumed.flush();
    expect(replay.requests, hasLength(1));
    expect(replay.requests.first.body, failed.requests.first.body);
    expect((replay.requests.first.body! as Map)['b'], 'original-id');
    expect((await store(storage).load()).records, isEmpty);
  });

  test('concurrent track during upload stays persisted', () async {
    final storage = InMemoryCacheStorage();
    final transport = Transport()..gate = Completer<void>();
    final c = client(storage, transport);
    await c.track(page('home'));
    final running = c.flush();
    for (var i = 0; i < 20 && transport.requests.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(transport.requests, hasLength(1));
    await c.track(page('history'));
    final inFlight = await store(storage).load();
    expect(inFlight.records.map((r) => r.event.properties['page']), [
      'home',
      'history',
    ]);
    expect(inFlight.assignedBatchId, 'fixed-id');
    transport.gate!.complete();
    await running;
    expect((await store(storage).load()).records, isEmpty);
  });

  test('bounded to 48 rows even if caller emits many events', () async {
    final storage = InMemoryCacheStorage();
    final c = client(storage, Transport());
    for (var i = 0; i < 75; i++) {
      await c.track(page('page_$i'));
    }
    expect(c.pendingCount, 48);
    expect(c.droppedCount, 27);
    expect((await store(storage).load()).records, hasLength(48));
  });
  test('in-flight records reserve the same 48-row cap', () async {
    final storage = InMemoryCacheStorage();
    final transport = Transport()..gate = Completer<void>();
    final c = client(storage, transport);
    for (var i=0; i<48; i++) { await c.track(page('home_$i')); }
    final running = c.flush();
    for (var i=0; i<20 && transport.requests.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(transport.requests, hasLength(1));
    await c.track(page('new_event'));
    expect(c.droppedCount, 1);
    expect((await store(storage).load()).records, hasLength(48));
    transport.gate!.complete();
    await running;
  });

  test('damaged local state is discarded, never becomes an upload', () async {
    final storage = InMemoryCacheStorage();
    final namespace = StorageNamespace.app(
      NebulaEnvironment.staging,
      'nfcwriter',
    ).toString();
    await storage.write(
      namespace: namespace,
      key: 'anonymous_analytics_queue_v1',
      value: Uint8List.fromList(utf8.encode('{"v":1,"rows":["unsafe"]}')),
    );
    final transport = Transport();
    final restarted = client(storage, transport);
    await restarted.flush();
    expect(restarted.pendingCount, 0);
    expect(transport.requests, isEmpty);
    expect((await store(storage).load()).records, isEmpty);
  });

  test('anonymous cache is isolated by app and expires old events', () async {
    final storage = InMemoryCacheStorage();
    final old = CachedAnonymousAnalyticsRecord(
      page('home'),
      clock.subtract(const Duration(hours: 25)),
    );
    await store(storage).save(CachedAnonymousAnalyticsSnapshot(records: [old]));
    final other = CachedAnonymousAnalyticsQueue(
      storage: storage,
      environment: NebulaEnvironment.staging,
      appId: 'nearvia',
    );
    expect((await other.load()).records, isEmpty);
    final transport = Transport();
    final restarted = client(storage, transport);
    await restarted.flush();
    expect(restarted.pendingCount, 0);
    expect(transport.requests, isEmpty);
  });
}
