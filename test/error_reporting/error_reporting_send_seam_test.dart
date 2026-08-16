import 'package:nebula_sdk/src/error_reporting/budget.dart';
import 'package:nebula_sdk/src/error_reporting/client.dart';
import 'package:nebula_sdk/src/error_reporting/report.dart';
import 'package:nebula_sdk/src/error_reporting/sender.dart';
import 'package:test/test.dart';

import 'fakes/error_reporting_fakes.dart';

ErrorReportInput _input(String name, DateTime now) => ErrorReportInput(
      errorType: 'StateError',
      message: 'safe-$name',
      stack: '#0 $name',
      occurredAt: now,
    );

Future<String> _capture(
  ErrorReportingClient client,
  String name,
  DateTime now,
) async {
  final ErrorCaptureResult result = await client.capture(_input(name, now));
  return result.reportId!;
}

void main() {
  test(
      'processed partial defer ACKs subset and preserves omitted without attempt',
      () async {
    final DateTime now = DateTime.utc(2026, 8, 16);
    final FakeBoundedErrorStore store = FakeBoundedErrorStore();
    final RecordingErrorReportSender sender = RecordingErrorReportSender();
    final ErrorReportingClient client = ErrorReportingClient(
      store: store,
      sender: sender,
      idGenerator: FixedErrorReportIdGenerator('partial'),
      now: () => now,
    );
    final String a = await _capture(client, 'a', now);
    final String b = await _capture(client, 'b', now);
    sender.results.add(
      ErrorReportSendResult(
        acceptedReportIds: <String>[a],
        deferRemaining: true,
        retryAfter: const Duration(seconds: 30),
      ),
    );

    await client.flush();
    expect(store.records, hasLength(1));
    expect(store.records.single.report.reportId, b);
    expect(store.records.single.attemptCount, 0);
    expect(store.records.single.nextAttemptAt, isNull);
    expect(client.stats.acknowledged, 1);
    expect(client.stats.retryScheduled, 0);
    expect(client.stats.uploadDeferrals, 1);
  });

  test('rate limit defer preserves full batch and consumes no retry attempt',
      () async {
    DateTime now = DateTime.utc(2026, 8, 16);
    final FakeBoundedErrorStore store = FakeBoundedErrorStore();
    final RecordingErrorReportSender sender = RecordingErrorReportSender();
    final ErrorReportingClient client = ErrorReportingClient(
      store: store,
      sender: sender,
      idGenerator: FixedErrorReportIdGenerator('rate'),
      now: () => now,
      budget: const ErrorReportingBudget(
        retryBaseDelay: Duration(seconds: 2),
        retryMaxDelay: Duration(seconds: 30),
      ),
    );
    await _capture(client, 'a', now);
    sender.results.add(
      ErrorReportSendResult(
        disposition: ErrorReportSendDisposition.rateLimitedDefer,
        retryAfter: Duration.zero,
      ),
    );
    await client.flush();
    expect(store.records.single.attemptCount, 0);
    expect(client.stats.retryScheduled, 0);
    await client.flush();
    expect(sender.batches, hasLength(1));
    now = now.add(const Duration(seconds: 1));
    await client.flush();
    expect(sender.batches, hasLength(1),
        reason: 'zero hint clamps to base delay');
  });

  test('transient disposition consumes normal bounded retry budget', () async {
    final DateTime now = DateTime.utc(2026, 8, 16);
    final FakeBoundedErrorStore store = FakeBoundedErrorStore();
    final RecordingErrorReportSender sender = RecordingErrorReportSender();
    final ErrorReportingClient client = ErrorReportingClient(
      store: store,
      sender: sender,
      idGenerator: FixedErrorReportIdGenerator('transient'),
      now: () => now,
    );
    await _capture(client, 'a', now);
    sender.results.add(
      ErrorReportSendResult(
        disposition: ErrorReportSendDisposition.transientFailure,
      ),
    );
    await client.flush();
    expect(store.records.single.attemptCount, 1);
    expect(client.stats.retryScheduled, 1);
  });

  test('deterministic request failure locally drops without fabricated ACK',
      () async {
    final DateTime now = DateTime.utc(2026, 8, 16);
    final FakeBoundedErrorStore store = FakeBoundedErrorStore();
    final RecordingErrorReportSender sender = RecordingErrorReportSender();
    final ErrorReportingClient client = ErrorReportingClient(
      store: store,
      sender: sender,
      idGenerator: FixedErrorReportIdGenerator('bad'),
      now: () => now,
    );
    await _capture(client, 'a', now);
    sender.results.add(
      ErrorReportSendResult(
        disposition: ErrorReportSendDisposition.deterministicRequestFailure,
      ),
    );
    await client.flush();
    expect(store.records, isEmpty);
    expect(client.stats.deterministicDrops, 1);
    expect(client.stats.acknowledged, 0);
    expect(client.stats.rejected, 0);
    expect(client.stats.retryExhausted, 0);
  });

  test('trust recovery requirement preserves report without attempt burn',
      () async {
    final DateTime now = DateTime.utc(2026, 8, 16);
    final FakeBoundedErrorStore store = FakeBoundedErrorStore();
    final RecordingErrorReportSender sender = RecordingErrorReportSender();
    final ErrorReportingClient client = ErrorReportingClient(
      store: store,
      sender: sender,
      idGenerator: FixedErrorReportIdGenerator('trust'),
      now: () => now,
    );
    await _capture(client, 'a', now);
    sender.results.add(
      ErrorReportSendResult(
        disposition: ErrorReportSendDisposition.trustRecoveryRequired,
        retryAfter: const Duration(seconds: 30),
      ),
    );
    await client.flush();
    expect(store.records.single.attemptCount, 0);
    expect(store.records.single.nextAttemptAt, isNull);
    expect(client.stats.retryScheduled, 0);
    expect(client.stats.trustRecoveryDeferrals, 1);
    expect(client.stats.uploadDeferrals, 1);
  });

  test('deterministic outcome only drops the sender-affected subset', () async {
    final DateTime now = DateTime.utc(2026, 8, 16);
    final FakeBoundedErrorStore store = FakeBoundedErrorStore();
    final RecordingErrorReportSender sender = RecordingErrorReportSender();
    final ErrorReportingClient client = ErrorReportingClient(
      store: store,
      sender: sender,
      idGenerator: FixedErrorReportIdGenerator('subset'),
      now: () => now,
    );
    final String a = await _capture(client, 'a', now);
    final String b = await _capture(client, 'b', now);
    sender.results.add(
      ErrorReportSendResult(
        disposition: ErrorReportSendDisposition.deterministicRequestFailure,
        affectedReportIds: <String>[a],
      ),
    );
    await client.flush();
    expect(store.records, hasLength(1));
    expect(store.records.single.report.reportId, b);
    expect(store.records.single.attemptCount, 0);
    expect(client.stats.deterministicDrops, 1);
    expect(client.stats.retryScheduled, 0);
  });

  test('transient outcome only burns attempt budget for affected subset',
      () async {
    final DateTime now = DateTime.utc(2026, 8, 16);
    final FakeBoundedErrorStore store = FakeBoundedErrorStore();
    final RecordingErrorReportSender sender = RecordingErrorReportSender();
    final ErrorReportingClient client = ErrorReportingClient(
      store: store,
      sender: sender,
      idGenerator: FixedErrorReportIdGenerator('subset-transient'),
      now: () => now,
    );
    final String a = await _capture(client, 'a', now);
    final String b = await _capture(client, 'b', now);
    sender.results.add(
      ErrorReportSendResult(
        disposition: ErrorReportSendDisposition.transientFailure,
        affectedReportIds: <String>[a],
      ),
    );
    await client.flush();
    final byId = <String, int>{
      for (final stored in store.records)
        stored.report.reportId: stored.attemptCount,
    };
    expect(byId[a], 1);
    expect(byId[b], 0);
    expect(client.stats.retryScheduled, 1);
  });
}
