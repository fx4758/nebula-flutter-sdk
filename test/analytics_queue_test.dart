import 'package:nebula_sdk/nebula_sdk.dart';
import 'package:test/test.dart';

// =============================================================================
// F2-04 — Analytics bounded queue / batching / backoff / drop policy
// (docs/02 §4 queue caps + docs/04 batch & drop acceptance)
//
// The ingest target is the injected NebulaAnalyticsSender Port; the queue /
// batch / backoff / drop machinery is what this file proves.
// =============================================================================

NebulaAnalyticsEvent _anon(String name) => NebulaAnalyticsEvent(
      name: name,
      privacy: NebulaEventPrivacy.anonymous,
    );

NebulaAnalyticsEvent _pii(String name) => NebulaAnalyticsEvent(
      name: name,
      privacy: NebulaEventPrivacy.identifiable,
      properties: <String, Object?>{'uid': 'u'},
    );

/// 记录收到的批次；可按脚本失败。
final class _RecordingSender implements NebulaAnalyticsSender {
  final List<List<NebulaAnalyticsEvent>> batches =
      <List<NebulaAnalyticsEvent>>[];
  final List<Exception?> errors = <Exception?>[]; // 每次 send 前依次弹出；null=成功
  int calls = 0;

  @override
  Future<bool> send(List<NebulaAnalyticsEvent> batch) async {
    calls++;
    batches.add(batch);
    if (errors.isNotEmpty) {
      final Exception? error = errors.removeAt(0);
      if (error != null) throw error;
    }
    return true;
  }
}

void main() {
  group('F2-04 bounded queue (docs/02 §4 caps)', () {
    test('drop-oldest when the event count cap is reached, counted', () async {
      final client = NebulaAnalyticsClient(
        consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
        maxQueuedEvents: 3,
      );
      for (final n in <String>['e1', 'e2', 'e3', 'e4']) {
        await client.track(_anon(n));
      }
      expect(client.pendingCount, 3);
      expect(client.droppedCount, 1);
      expect(client.pending.map((e) => e.name).toList(),
          <String>['e2', 'e3', 'e4'],
          reason: '最旧 e1 应被丢弃');
    });

    test('drop-oldest when the byte cap is reached', () async {
      final client = NebulaAnalyticsClient(
        consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
        maxQueuedBytes: 120,
      );
      // 每个事件 ~90+ 字节；第二个会把队列顶出字节上限 → 丢最旧。
      await client.track(_pii('p1'));
      await client.track(_pii('p2'));
      expect(client.pendingCount, 1);
      expect(client.droppedCount, 1);
      expect(client.pending.single.name, 'p2');
    });

    test('a single oversized event is dropped immediately and counted',
        () async {
      final client = NebulaAnalyticsClient(
        consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
        maxQueuedBytes: 64,
      );
      await client.track(NebulaAnalyticsEvent(
        name: 'big',
        privacy: NebulaEventPrivacy.anonymous,
        properties: <String, Object?>{'payload': 'x' * 200},
      ));
      expect(client.pendingCount, 0);
      expect(client.droppedCount, 1);
    });
  });

  group('F2-04 TTL expiry (docs/02 §4 queue TTL)', () {
    test('events older than maxEventAge are purged at flush', () async {
      DateTime now = DateTime.utc(2026, 1, 1);
      final client = NebulaAnalyticsClient(
        consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
        sender: _RecordingSender(),
        maxEventAge: const Duration(hours: 1),
        now: () => now,
      );
      await client.track(_anon('fresh'));
      await client.track(_anon('old1'));
      now = now.add(const Duration(hours: 2)); // 全部过期
      await client.track(_anon('old2'));
      await client.flush();
      expect(client.pendingCount, 0);
      expect(client.droppedCount, 2, reason: 'fresh 之外两个都过期');
      expect(client.sentCount, 1, reason: '只有 fresh 被发送');
    });
  });

  group('F2-04 batching (docs/04 批量上报)', () {
    test('flush splits into batchSize chunks and drains the queue', () async {
      final sender = _RecordingSender();
      final client = NebulaAnalyticsClient(
        consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
        sender: sender,
        batchSize: 50,
      );
      for (int i = 0; i < 120; i++) {
        await client.track(_anon('e$i'));
      }
      await client.flush();
      expect(sender.batches, hasLength(3));
      expect(sender.batches[0], hasLength(50));
      expect(sender.batches[1], hasLength(50));
      expect(sender.batches[2], hasLength(20));
      expect(client.pendingCount, 0);
      expect(client.sentCount, 120);
    });

    test('concurrent flush is single-flight (one drain)', () async {
      final sender = _RecordingSender();
      final client = NebulaAnalyticsClient(
        consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
        sender: sender,
        batchSize: 50,
      );
      for (int i = 0; i < 60; i++) {
        await client.track(_anon('e$i'));
      }
      await Future.wait(<Future<void>>[client.flush(), client.flush()]);
      expect(sender.batches, hasLength(2)); // 60 条 → 2 批，且只发一轮
      expect(client.sentCount, 60);
    });
  });

  group('F2-04 send backoff & drop (docs/02 §3)', () {
    test('transient failure is retried and eventually succeeds', () async {
      final sender = _RecordingSender()
        ..errors.addAll(<Exception?>[
          const NebulaTimeoutException('down'),
          const NebulaTimeoutException('down'),
          null,
        ]);
      final client = NebulaAnalyticsClient(
        consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
        sender: sender,
        sendRetries: 3,
        sendRetryBaseDelay: const Duration(milliseconds: 5),
      );
      await client.track(_anon('e'));
      await client.flush();
      expect(client.sentCount, 1);
      expect(client.pendingCount, 0);
      expect(sender.calls, 3, reason: '2 次失败 + 1 次成功');
    });

    test('retries exhausted: the failed batch is requeued, nothing lost',
        () async {
      final sender = _RecordingSender()
        ..errors.addAll(<Exception?>[
          const NebulaHttpException('down', statusCode: 503),
          const NebulaHttpException('down', statusCode: 503),
          const NebulaHttpException('down', statusCode: 503),
          const NebulaHttpException('down', statusCode: 503),
        ]);
      final client = NebulaAnalyticsClient(
        consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
        sender: sender,
        sendRetries: 2, // 3 次尝试（1 初始 + 2 重试）后放弃本轮
        sendRetryBaseDelay: const Duration(milliseconds: 5),
      );
      await client.track(_anon('e'));
      await client.flush();
      expect(client.pendingCount, 1, reason: '失败批次回队首，数据保留');
      expect(client.sentCount, 0);
      expect(client.droppedCount, 0);
    });

    test('rate limited (40002) is respected: no auto-retry, batch requeued',
        () async {
      final sender = _RecordingSender()
        ..errors.add(const NebulaApiException('rl', code: 40002));
      final client = NebulaAnalyticsClient(
        consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
        sender: sender,
        sendRetries: 5,
        sendRetryBaseDelay: const Duration(milliseconds: 5),
      );
      await client.track(_anon('e'));
      await client.flush();
      expect(sender.calls, 1, reason: '限流必须尊重，禁止自动重试');
      expect(client.pendingCount, 1);
    });

    test('business-code failure is not retried', () async {
      final sender = _RecordingSender()
        ..errors.add(const NebulaApiException('rejected', code: 30001));
      final client = NebulaAnalyticsClient(
        consentStore: InMemoryConsentStore(initial: NebulaConsent.granted),
        sender: sender,
        sendRetries: 5,
      );
      await client.track(_anon('e'));
      await client.flush();
      expect(sender.calls, 1);
    });
  });

  group('F2-04 consent gating regression (F2-03)', () {
    test('identifiable events still dropped while revoked; revoke purges',
        () async {
      final sender = _RecordingSender();
      final client = NebulaAnalyticsClient(
        consentStore: InMemoryConsentStore(),
        sender: sender,
      );
      await client.track(_pii('purchase'));
      await client.setConsent(NebulaConsent.granted);
      await client.track(_pii('purchase2'));
      await client.setConsent(NebulaConsent.revoked);
      await client.flush();
      expect(client.sentCount, 0, reason: '撤回后无可发送的可识别事件');
      expect(client.pendingCount, 0);
      expect(sender.calls, 0);
    });
  });
}
