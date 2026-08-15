import 'package:nebula_sdk/src/error_reporting/budget.dart';
import 'package:nebula_sdk/src/error_reporting/client.dart';
import 'package:nebula_sdk/src/error_reporting/report.dart';
import 'package:nebula_sdk/src/error_reporting/sender.dart';
import 'package:test/test.dart';

import 'fakes/error_reporting_fakes.dart';

ErrorReportInput _input(String name, DateTime occurredAt) => ErrorReportInput(
      errorType: 'StateError',
      message: 'safe $name',
      stack: 'stack $name',
      occurredAt: occurredAt,
      requestId: 'req-$name',
      reportedAppVersion: '1.0.0',
      reportedBuildNumber: '1',
    );

void main() {
  test(
    'capture persists immutable report_id and preserves occurred_at',
    () async {
      final FakeBoundedErrorStore store = FakeBoundedErrorStore();
      final DateTime now = DateTime.utc(2026, 8, 15, 10);
      final DateTime occurred = DateTime.utc(2026, 8, 14, 23, 30);
      final ErrorReportingClient client = ErrorReportingClient(
        store: store,
        idGenerator: FixedErrorReportIdGenerator('fixed'),
        now: () => now,
      );

      final ErrorCaptureResult result = await client.capture(
        _input('a', occurred),
      );
      expect(result.disposition, ErrorCaptureDisposition.persisted);
      expect(result.reportId, 'fixed-1');
      expect(store.records.single.report.reportId, 'fixed-1');
      expect(store.records.single.report.occurredAt, occurred);
      expect(store.records.single.storedAt, now);
    },
  );

  test('persistence failure is best-effort and does not throw', () async {
    final FakeBoundedErrorStore store = FakeBoundedErrorStore()
      ..throwOnSave = true;
    final ErrorReportingClient client = ErrorReportingClient(
      store: store,
      idGenerator: FixedErrorReportIdGenerator(),
    );
    final ErrorCaptureResult result = await client.capture(
      _input('a', DateTime.utc(2026)),
    );
    expect(result.disposition, ErrorCaptureDisposition.persistenceFailed);
    expect(client.stats.persistenceFailures, 1);
  });

  test('bounded store evicts oldest and accounts for it', () async {
    final FakeBoundedErrorStore store = FakeBoundedErrorStore();
    DateTime now = DateTime.utc(2026, 8, 15);
    final ErrorReportingClient client = ErrorReportingClient(
      store: store,
      idGenerator: FixedErrorReportIdGenerator(),
      budget: const ErrorReportingBudget(maxStoredReports: 2),
      now: () => now,
    );
    await client.capture(_input('a', now));
    now = now.add(const Duration(seconds: 1));
    await client.capture(_input('b', now));
    now = now.add(const Duration(seconds: 1));
    await client.capture(_input('c', now));
    expect(store.records.map((e) => e.report.reportId), <String>[
      'report-2',
      'report-3',
    ]);
    expect(client.stats.storeEvictions, 1);
  });

  test('bounded store byte cap evicts oldest and remains finite', () async {
    final FakeBoundedErrorStore store = FakeBoundedErrorStore();
    DateTime now = DateTime.utc(2026, 8, 15);
    final ErrorReportingClient probe = ErrorReportingClient(
      store: store,
      idGenerator: FixedErrorReportIdGenerator(),
      now: () => now,
    );
    await probe.capture(_input('a', now));
    final int oneReportBytes = store.records.single.report.estimatedBytes;
    store.records.clear();

    final ErrorReportingClient client = ErrorReportingClient(
      store: store,
      idGenerator: FixedErrorReportIdGenerator('byte'),
      budget: ErrorReportingBudget(
        maxStoredBytes: oneReportBytes + 8,
        maxReportBytes: oneReportBytes,
        maxBytesPerFlush: oneReportBytes,
      ),
      now: () => now,
    );
    await client.capture(_input('b', now));
    now = now.add(const Duration(seconds: 1));
    await client.capture(_input('c', now));
    expect(store.records, hasLength(1));
    expect(store.records.single.report.reportId, 'byte-2');
    expect(client.stats.storeEvictions, 1);
  });

  test('TTL expiry is purged and accounted before upload', () async {
    final FakeBoundedErrorStore store = FakeBoundedErrorStore();
    final RecordingErrorReportSender sender = RecordingErrorReportSender();
    DateTime now = DateTime.utc(2026, 8, 15);
    final ErrorReportingClient client = ErrorReportingClient(
      store: store,
      sender: sender,
      idGenerator: FixedErrorReportIdGenerator(),
      budget: const ErrorReportingBudget(maxReportAge: Duration(hours: 1)),
      now: () => now,
    );
    await client.capture(_input('old', now));
    now = now.add(const Duration(hours: 2));
    await client.flush();
    expect(store.records, isEmpty);
    expect(sender.batches, isEmpty);
    expect(client.stats.expiredReports, 1);
  });

  test('ACK deletes persisted report after successful send', () async {
    final FakeBoundedErrorStore store = FakeBoundedErrorStore();
    final RecordingErrorReportSender sender = RecordingErrorReportSender();
    final ErrorReportingClient client = ErrorReportingClient(
      store: store,
      sender: sender,
      idGenerator: FixedErrorReportIdGenerator('stable'),
    );
    await client.capture(_input('a', DateTime.utc(2026)));
    await client.flush();
    expect(sender.batches.single.single.reportId, 'stable-1');
    expect(store.records, isEmpty);
    expect(client.stats.acknowledged, 1);
  });

  test(
    'transient failure preserves report_id and schedules bounded retry',
    () async {
      final FakeBoundedErrorStore store = FakeBoundedErrorStore();
      final RecordingErrorReportSender sender = RecordingErrorReportSender()
        ..errors.add(Exception('offline'));
      DateTime now = DateTime.utc(2026, 8, 15);
      final ErrorReportingClient client = ErrorReportingClient(
        store: store,
        sender: sender,
        idGenerator: FixedErrorReportIdGenerator('stable'),
        budget: const ErrorReportingBudget(
          retryBaseDelay: Duration(seconds: 10),
          retryMaxDelay: Duration(seconds: 30),
        ),
        now: () => now,
      );
      await client.capture(_input('a', now));
      await client.flush();
      expect(store.records.single.report.reportId, 'stable-1');
      expect(store.records.single.attemptCount, 1);
      expect(
        store.records.single.nextAttemptAt,
        now.add(const Duration(seconds: 10)),
      );
      expect(client.stats.retryScheduled, 1);

      await client.flush();
      expect(
        sender.batches,
        hasLength(1),
        reason: 'backoff window must defer retry',
      );
      now = now.add(const Duration(seconds: 10));
      await client.flush();
      expect(sender.batches, hasLength(2));
      expect(sender.batches[1].single.reportId, 'stable-1');
      expect(store.records, isEmpty);
    },
  );

  test('retry exhaustion purges report and is accounted', () async {
    final FakeBoundedErrorStore store = FakeBoundedErrorStore();
    final RecordingErrorReportSender sender = RecordingErrorReportSender()
      ..errors.addAll(<Exception>[Exception('1'), Exception('2')]);
    DateTime now = DateTime.utc(2026, 8, 15);
    final ErrorReportingClient client = ErrorReportingClient(
      store: store,
      sender: sender,
      idGenerator: FixedErrorReportIdGenerator(),
      budget: const ErrorReportingBudget(
        maxAttempts: 2,
        retryBaseDelay: Duration(seconds: 1),
        retryMaxDelay: Duration(seconds: 1),
      ),
      now: () => now,
    );
    await client.capture(_input('a', now));
    await client.flush();
    now = now.add(const Duration(seconds: 1));
    await client.flush();
    expect(store.records, isEmpty);
    expect(client.stats.retryExhausted, 1);
  });

  test(
    'deterministic non-retryable rejection is purged and accounted',
    () async {
      final FakeBoundedErrorStore store = FakeBoundedErrorStore();
      final RecordingErrorReportSender sender = RecordingErrorReportSender();
      final ErrorReportingClient client = ErrorReportingClient(
        store: store,
        sender: sender,
        idGenerator: FixedErrorReportIdGenerator(),
      );
      final ErrorCaptureResult captured = await client.capture(
        _input('a', DateTime.utc(2026)),
      );
      sender.results.add(
        ErrorReportSendResult(rejectedReportIds: <String>[captured.reportId!]),
      );
      await client.flush();
      expect(store.records, isEmpty);
      expect(client.stats.rejected, 1);
      expect(client.stats.retryScheduled, 0);
    },
  );

  test(
    'unknown sender result fails safe and preserves report for retry',
    () async {
      final FakeBoundedErrorStore store = FakeBoundedErrorStore();
      final RecordingErrorReportSender sender = RecordingErrorReportSender()
        ..results.add(
          ErrorReportSendResult(acceptedReportIds: const <String>['other-id']),
        );
      final ErrorReportingClient client = ErrorReportingClient(
        store: store,
        sender: sender,
        idGenerator: FixedErrorReportIdGenerator('stable'),
      );
      await client.capture(_input('a', DateTime.utc(2026)));
      await client.flush();
      expect(store.records.single.report.reportId, 'stable-1');
      expect(store.records.single.attemptCount, 1);
      expect(client.stats.invalidSenderResults, 1);
    },
  );

  test(
    'server-directed defer prevents immediate subsequent upload',
    () async {
      final FakeBoundedErrorStore store = FakeBoundedErrorStore();
      final RecordingErrorReportSender sender = RecordingErrorReportSender();
      DateTime now = DateTime.utc(2026, 8, 15);
      final ErrorReportingClient client = ErrorReportingClient(
        store: store,
        sender: sender,
        idGenerator: FixedErrorReportIdGenerator(),
        now: () => now,
      );
      final ErrorCaptureResult first = await client.capture(_input('a', now));
      sender.results.add(
        ErrorReportSendResult(
          acceptedReportIds: <String>[first.reportId!],
          deferRemaining: true,
          retryAfter: const Duration(seconds: 30),
        ),
      );
      await client.flush();
      await client.capture(_input('b', now));
      await client.flush();
      expect(
        sender.batches,
        hasLength(1),
        reason: 'cooldown blocks immediate upload',
      );
      now = now.add(const Duration(seconds: 30));
      await client.flush();
      expect(sender.batches, hasLength(2));
      expect(client.stats.uploadDeferrals, 1);
    },
  );

  test(
    'flush count budget prevents startup upload-all-history storm',
    () async {
      final FakeBoundedErrorStore store = FakeBoundedErrorStore();
      final RecordingErrorReportSender sender = RecordingErrorReportSender();
      final ErrorReportingClient client = ErrorReportingClient(
        store: store,
        sender: sender,
        idGenerator: FixedErrorReportIdGenerator(),
        budget: const ErrorReportingBudget(maxReportsPerFlush: 2),
      );
      for (final String name in <String>['a', 'b', 'c']) {
        await client.capture(_input(name, DateTime.utc(2026)));
      }
      await client.flush();
      expect(sender.batches.single, hasLength(2));
      expect(store.records, hasLength(1));
      await client.flush();
      expect(sender.batches, hasLength(2));
      expect(sender.batches[1], hasLength(1));
      expect(store.records, isEmpty);
    },
  );

  test('no sender is a no-op and does not mutate persisted backlog', () async {
    final FakeBoundedErrorStore store = FakeBoundedErrorStore();
    final ErrorReportingClient client = ErrorReportingClient(
      store: store,
      idGenerator: FixedErrorReportIdGenerator(),
    );
    await client.capture(_input('a', DateTime.utc(2026)));
    await client.flush();
    expect(store.records, hasLength(1));
  });
}
