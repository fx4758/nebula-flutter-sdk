import 'dart:convert';
import 'dart:typed_data';

import 'package:nebula_sdk/src/error_reporting/budget.dart';
import 'package:nebula_sdk/src/error_reporting/cache_error_report_store.dart';
import 'package:nebula_sdk/src/error_reporting/report.dart';
import 'package:nebula_sdk/src/foundation/options.dart';
import 'package:nebula_sdk/src/storage/cache_storage.dart';
import 'package:nebula_sdk/src/storage/storage_namespace.dart';
import 'package:test/test.dart';

NebulaErrorReport _report(String id, {int padding = 0}) => NebulaErrorReport(
      reportId: id,
      occurredAt: DateTime.utc(2026, 8, 17, 1, 2, 3),
      errorType: 'StateError',
      safeMessage: 'safe-$id',
      stack: '#0 main${'x' * padding}',
      requestId: 'req-$id',
      reportedAppVersion: '2.4.0',
      reportedBuildNumber: '30',
    );

CacheErrorReportStore _store(CacheStorage storage, String appId) =>
    CacheErrorReportStore(
      storage: storage,
      environment: NebulaEnvironment.staging,
      appId: appId,
    );

const ErrorReportingBudget _budget = ErrorReportingBudget(
  maxReportBytes: 12 * 1024,
  maxStoredReports: 3,
  maxStoredBytes: 30 * 1024,
  maxReportAge: Duration(days: 7),
  maxReportsPerFlush: 3,
  maxBytesPerFlush: 30 * 1024,
);

void main() {
  test('restart preserves report identity, occurrence and retry metadata',
      () async {
    final InMemoryCacheStorage storage = InMemoryCacheStorage();
    final DateTime now = DateTime.utc(2026, 8, 17, 2);
    final NebulaErrorReport report = _report('restart-1');
    await _store(storage, 'app-a').saveBounded(
      report,
      budget: _budget,
      now: now,
    );
    await _store(storage, 'app-a').scheduleRetry(
      <String>[report.reportId],
      attemptCount: 1,
      nextAttemptAt: now.add(const Duration(minutes: 2)),
    );

    final CacheErrorReportStore restarted = _store(storage, 'app-a');
    expect(
      (await restarted.readReady(
        budget: _budget,
        now: now.add(const Duration(minutes: 1)),
      ))
          .reports,
      isEmpty,
    );
    final ready = await restarted.readReady(
      budget: _budget,
      now: now.add(const Duration(minutes: 3)),
    );
    expect(ready.reports, hasLength(1));
    final stored = ready.reports.single;
    expect(stored.report.reportId, report.reportId);
    expect(stored.report.occurredAt, report.occurredAt);
    expect(stored.attemptCount, 1);
    expect(stored.nextAttemptAt, now.add(const Duration(minutes: 2)));
  });

  test('ACK deletion remains deleted after restart', () async {
    final InMemoryCacheStorage storage = InMemoryCacheStorage();
    final DateTime now = DateTime.utc(2026, 8, 17, 2);
    final CacheErrorReportStore first = _store(storage, 'app-a');
    await first.saveBounded(_report('a'), budget: _budget, now: now);
    await first.saveBounded(_report('b'), budget: _budget, now: now);
    await first.deleteById(const <String>['a']);

    final ready = await _store(storage, 'app-a').readReady(
      budget: _budget,
      now: now,
    );
    expect(
      ready.reports.map((stored) => stored.report.reportId),
      <String>['b'],
    );
  });

  test('count and byte caps evict oldest deterministically', () async {
    final InMemoryCacheStorage countStorage = InMemoryCacheStorage();
    final DateTime now = DateTime.utc(2026, 8, 17, 2);
    const ErrorReportingBudget countBudget = ErrorReportingBudget(
      maxReportBytes: 4096,
      maxStoredReports: 2,
      maxStoredBytes: 8192,
      maxReportsPerFlush: 2,
      maxBytesPerFlush: 8192,
    );
    final CacheErrorReportStore countStore = _store(countStorage, 'count');
    await countStore.saveBounded(_report('a'), budget: countBudget, now: now);
    await countStore.saveBounded(
      _report('b'),
      budget: countBudget,
      now: now.add(const Duration(seconds: 1)),
    );
    final result = await countStore.saveBounded(
      _report('c'),
      budget: countBudget,
      now: now.add(const Duration(seconds: 2)),
    );
    expect(result.evictedCount, 1);
    expect(
      (await countStore.readReady(budget: countBudget, now: now))
          .reports
          .map((stored) => stored.report.reportId),
      <String>['b', 'c'],
    );

    final InMemoryCacheStorage byteStorage = InMemoryCacheStorage();
    final NebulaErrorReport one = _report('one', padding: 300);
    const int margin = 16;
    final ErrorReportingBudget byteBudget = ErrorReportingBudget(
      maxReportBytes: one.estimatedBytes + margin,
      maxStoredReports: 10,
      maxStoredBytes: one.estimatedBytes * 2 - 1,
      maxReportsPerFlush: 10,
      maxBytesPerFlush: one.estimatedBytes * 2,
    );
    final CacheErrorReportStore byteStore = _store(byteStorage, 'bytes');
    await byteStore.saveBounded(one, budget: byteBudget, now: now);
    final byteResult = await byteStore.saveBounded(
      _report('two', padding: 300),
      budget: byteBudget,
      now: now.add(const Duration(seconds: 1)),
    );
    expect(byteResult.evictedCount, 1);
    expect(
      (await byteStore.readReady(budget: byteBudget, now: now))
          .reports
          .single
          .report
          .reportId,
      'two',
    );
  });

  test('TTL expiry is persisted across restart', () async {
    final InMemoryCacheStorage storage = InMemoryCacheStorage();
    final DateTime now = DateTime.utc(2026, 8, 17, 2);
    const ErrorReportingBudget ttlBudget = ErrorReportingBudget(
      maxReportAge: Duration(minutes: 5),
    );
    final CacheErrorReportStore store = _store(storage, 'ttl');
    await store.saveBounded(_report('old'), budget: ttlBudget, now: now);
    final expired = await store.readReady(
      budget: ttlBudget,
      now: now.add(const Duration(minutes: 6)),
    );
    expect(expired.expiredCount, 1);
    expect(expired.reports, isEmpty);
    expect(
      (await _store(storage, 'ttl').readReady(
        budget: ttlBudget,
        now: now.add(const Duration(minutes: 6)),
      ))
          .reports,
      isEmpty,
    );
  });

  test('corrupt or unknown version purges only Error Reporting queue key',
      () async {
    final InMemoryCacheStorage storage = InMemoryCacheStorage();
    final String namespace = StorageNamespace.app(
      NebulaEnvironment.staging,
      'corrupt',
    ).toString();
    await storage.write(
      namespace: namespace,
      key: 'sentinel',
      value: Uint8List.fromList(utf8.encode('keep-me')),
    );
    await storage.write(
      namespace: namespace,
      key: 'error_reporting_queue_v1',
      value: Uint8List.fromList(utf8.encode('{"version":999,"records":[]}')),
    );

    final result = await _store(storage, 'corrupt').readReady(
      budget: _budget,
      now: DateTime.utc(2026, 8, 17, 2),
    );
    expect(result.reports, isEmpty);
    expect(
      await storage.read(namespace: namespace, key: 'error_reporting_queue_v1'),
      isNull,
    );
    expect(
      utf8.decode((await storage.read(namespace: namespace, key: 'sentinel'))!),
      'keep-me',
    );
  });

  test('App and environment namespaces remain isolated', () async {
    final InMemoryCacheStorage storage = InMemoryCacheStorage();
    final DateTime now = DateTime.utc(2026, 8, 17, 2);
    final CacheErrorReportStore appA = _store(storage, 'app-a');
    final CacheErrorReportStore appB = _store(storage, 'app-b');
    final CacheErrorReportStore prodA = CacheErrorReportStore(
      storage: storage,
      environment: NebulaEnvironment.production,
      appId: 'app-a',
    );
    await appA.saveBounded(_report('a'), budget: _budget, now: now);
    await appB.saveBounded(_report('b'), budget: _budget, now: now);
    await prodA.saveBounded(_report('prod'), budget: _budget, now: now);

    expect(
      (await appA.readReady(budget: _budget, now: now))
          .reports
          .single
          .report
          .reportId,
      'a',
    );
    expect(
      (await appB.readReady(budget: _budget, now: now))
          .reports
          .single
          .report
          .reportId,
      'b',
    );
    expect(
      (await prodA.readReady(budget: _budget, now: now))
          .reports
          .single
          .report
          .reportId,
      'prod',
    );
  });

  test('concurrent operations are serialized without losing queue records',
      () async {
    final InMemoryCacheStorage storage = InMemoryCacheStorage();
    final CacheErrorReportStore store = _store(storage, 'serialized');
    final DateTime now = DateTime.utc(2026, 8, 17, 2);
    await Future.wait(<Future<Object?>>[
      for (int i = 0; i < 3; i++)
        store.saveBounded(
          _report('r$i'),
          budget: _budget,
          now: now.add(Duration(seconds: i)),
        ),
    ]);
    final ready = await store.readReady(budget: _budget, now: now);
    expect(
      ready.reports.map((stored) => stored.report.reportId).toSet(),
      <String>{'r0', 'r1', 'r2'},
    );
  });
}
