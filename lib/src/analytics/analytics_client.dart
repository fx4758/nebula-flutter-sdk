/// Consent-gated analytics client with bounded queue (F2-03 + F2-04).
///
/// F2-03: identifiable events are dropped while consent is not granted and
/// purged on revoke; anonymous events are always accepted (docs/02 §4).
///
/// F2-04: the unsent buffer is a **bounded queue** — hard caps on count and
/// bytes with drop-oldest + [droppedCount], TTL expiry via an injectable clock,
/// batched flush (batchSize) with single-flight, and bounded send backoff
/// (exponential + jitter) that retries only transient transport failures and
/// respects rate limiting (40002, no auto-retry). The ingest transport is the
/// injected [NebulaAnalyticsSender] Port; with no sender, [flush] is a
/// documented no-op (backend contract not frozen, docs/01 §6).
library;

import 'dart:async';
import 'dart:math';

import '../foundation/errors.dart';
import 'analytics_sender.dart';
import 'cache_anonymous_analytics_queue.dart';
import 'consent.dart';
import 'event.dart';
import 'mobile_analytics_sender.dart';
import 'nebula_analytics.dart';

/// 队列内一条未发送事件及其入队时间（TTL 依据）。
final class _Queued {
  const _Queued(this.event, this.enqueuedAt);
  final NebulaAnalyticsEvent event;
  final DateTime enqueuedAt;
}

final class _AssignedRetry {
  const _AssignedRetry(this.batch, this.items);
  final AssignedMobileAnalyticsBatch batch;
  final List<_Queued> items;
}

enum _MobileBatchOutcome { success, requeue, drop }

final class NebulaAnalyticsClient implements NebulaAnalytics {
  NebulaAnalyticsClient({
    required NebulaConsentStore consentStore,
    NebulaAnalyticsSender? sender,
    CachedAnonymousAnalyticsQueue? anonymousQueue,
    int maxQueuedEvents = 200,
    int maxQueuedBytes = 64 * 1024,
    Duration maxEventAge = const Duration(hours: 24),
    int batchSize = 50,
    int sendRetries = 3,
    Duration sendRetryBaseDelay = const Duration(milliseconds: 250),
    DateTime Function()? now,
  }) : _consentStore = consentStore,
       _sender = sender,
       _anonymousQueue = anonymousQueue,
       _maxQueuedEvents =
           anonymousQueue != null &&
               maxQueuedEvents > CachedAnonymousAnalyticsQueue.maxRecords
           ? CachedAnonymousAnalyticsQueue.maxRecords
           : maxQueuedEvents,
       _maxQueuedBytes = maxQueuedBytes,
       _maxEventAge = maxEventAge,
       _batchSize = batchSize,
       _sendRetries = sendRetries,
       _sendRetryBaseDelay = sendRetryBaseDelay,
       _now = now ?? DateTime.now;

  final NebulaConsentStore _consentStore;
  final NebulaAnalyticsSender? _sender;
  final CachedAnonymousAnalyticsQueue? _anonymousQueue;
  Future<void>? _restoreInFlight;
  Future<void> _writeTail = Future<void>.value();
  final int _maxQueuedEvents;
  final int _maxQueuedBytes;
  final Duration _maxEventAge;
  final int _batchSize;
  final int _sendRetries;
  final Duration _sendRetryBaseDelay;
  final DateTime Function() _now;

  final List<_Queued> _queue = <_Queued>[];
  int _queuedBytes = 0;
  bool _flushing = false;
  int _dropped = 0;
  int _sent = 0;

  NebulaConsent? _consent;
  _AssignedRetry? _assignedRetry;
  // An in-flight batch must stay in every durable snapshot, even while a
  // concurrent track() is appending fresh events to the memory queue.
  List<_Queued> _activeBatchItems = const <_Queued>[];

  /// 当前缓冲中的未发送事件（诊断用，只读）。
  List<NebulaAnalyticsEvent> get pending =>
      List<NebulaAnalyticsEvent>.unmodifiable(_queue.map((q) => q.event));

  /// 当前缓冲事件数。
  int get pendingCount => _queue.length;

  /// 已因队列满/超限/TTL 过期被丢弃的事件总数（docs/04：满时丢弃并计数）。
  int get droppedCount => _dropped;

  /// 已成功发送的事件总数。
  int get sentCount => _sent;

  /// Restore at most 48 anonymous, low-cardinality events. Identity and
  /// original receipt batch_id survive process termination and ambiguous ACKs.
  Future<void> _ensureRestored() =>
      _restoreInFlight ??= _restoreAnonymousQueue();

  Future<void> _restoreAnonymousQueue() async {
    final store = _anonymousQueue;
    if (store == null) return;
    try {
      final snapshot = await store.load();
      for (final record in snapshot.records) {
        if (_now().toUtc().difference(record.queuedAt) > _maxEventAge) continue;
        final event = record.event;
        _enqueueAt(event, record.queuedAt);
      }
      final sender = _sender;
      final count = snapshot.assignedCount;
      if (sender is MobileAnalyticsSender &&
          snapshot.assignedBatchId != null &&
          count > 0 &&
          count <= _queue.length) {
        final selected = _queue.take(count).toList(growable: false);
        final restored = sender.assignBatchWithId(
          selected.map((queued) => queued.event).toList(growable: false),
          snapshot.assignedBatchId!,
        );
        if (restored.events.length == count) {
          _assignedRetry = _AssignedRetry(restored, selected);
        }
      }
    } on Object {
      // Bad local cache must not affect account, NFC or app navigation.
    }
  }

  /// Serializing immutable snapshots avoids an older async write overwriting
  /// newer queue/ACK state. Persist *before* a batch goes over the network.
  Future<bool> _persistQueue() async {
    final store = _anonymousQueue;
    if (store == null) return true;
    final items = <_Queued>[..._activeBatchItems, ..._queue];
    final safeItems = items
        .where((item) => CachedAnonymousAnalyticsQueue.allows(item.event))
        .toList(growable: false);
    final retry = _assignedRetry;
    final count = retry?.items.length ?? 0;
    final id =
        retry != null &&
            count <= safeItems.length &&
            safeItems.take(count).every((e) => retry.items.contains(e))
        ? retry.batch.batchId
        : null;
    final snapshot = CachedAnonymousAnalyticsSnapshot(
      records: [
        for (final item in safeItems)
          CachedAnonymousAnalyticsRecord(item.event, item.enqueuedAt),
      ],
      assignedBatchId: id,
      assignedCount: id == null ? 0 : count,
    );
    bool saved = false;
    final next = _writeTail.then((_) async {
      try {
        await store.save(snapshot);
        saved = true;
      } on Object {
        // Storage failure remains fail-soft, without sending an untracked
        // batch that could be duplicated after an ambiguous ACK.
      }
    });
    _writeTail = next;
    await next;
    return saved;
  }

  @override
  Future<NebulaConsent> get consent async {
    _consent ??= await _consentStore.load();
    return _consent!;
  }

  @override
  Future<void> setConsent(NebulaConsent consent) async {
    await _ensureRestored();
    _consent = consent;
    await _consentStore.save(consent);
    if (consent == NebulaConsent.revoked) {
      // 撤回同意：清理未发送的可识别事件（docs/02 §4）。
      _removeWhere((NebulaAnalyticsEvent e) => e.identifiable);
      await _persistQueue();
    }
  }

  @override
  Future<void> track(NebulaAnalyticsEvent event) async {
    await _ensureRestored();
    final NebulaConsent current = await consent;
    if (event.identifiable && current != NebulaConsent.granted) {
      return; // 未同意：可识别事件直接丢弃，绝不持久化/缓冲。
    }
    _enqueue(event);
    await _persistQueue();
  }

  /// 有界入队（docs/02 §4：数量 + 字节硬上限；docs/04：满时丢弃最旧并计数）。
  void _enqueue(NebulaAnalyticsEvent event) =>
      _enqueueAt(event, _now().toUtc());

  void _enqueueAt(NebulaAnalyticsEvent event, DateTime enqueuedAt) {
    final int bytes = event.estimatedBytes;
    final int activeCount = _activeBatchItems.length;
    final int activeBytes = _activeBatchItems.fold<int>(
      0, (sum, item) => sum + item.event.estimatedBytes,
    );
    if (bytes + activeBytes > _maxQueuedBytes ||
        activeCount >= _maxQueuedEvents) {
      _dropped++; // Never evict a signed in-flight batch to admit new data.
      return;
    }
    // In-flight records count against the same local disk/queue budget.
    while (_queue.isNotEmpty &&
        (_queue.length + activeCount >= _maxQueuedEvents ||
            _queuedBytes + activeBytes + bytes > _maxQueuedBytes)) {
      _dropOldest();
    }
    _queue.add(_Queued(event, enqueuedAt));
    _queuedBytes += bytes;
  }

  void _dropOldest() {
    if (_queue.isEmpty) return;
    final _Queued removed = _queue.removeAt(0);
    _invalidateAssignedIfContains(removed);
    _queuedBytes -= removed.event.estimatedBytes;
    _dropped++;
  }

  void _removeWhere(bool Function(NebulaAnalyticsEvent) test) {
    final List<_Queued> kept = <_Queued>[];
    int bytes = 0;
    for (final _Queued queued in _queue) {
      if (test(queued.event)) {
        _invalidateAssignedIfContains(queued);
        _dropped++;
      } else {
        kept.add(queued);
        bytes += queued.event.estimatedBytes;
      }
    }
    _queue
      ..clear()
      ..addAll(kept);
    _queuedBytes = bytes;
  }

  /// 冲刷未发送事件。Mobile sender 额外冻结 assigned batch identity；
  /// legacy host sender 继续沿用原批量语义。
  @override
  Future<void> flush() async {
    final NebulaAnalyticsSender? sender = _sender;
    if (sender == null || _flushing) return;
    _flushing = true;
    try {
      await _ensureRestored();
      _expireOldEvents();
      if (sender is MobileAnalyticsAssignedSender) {
        await _flushMobile(sender as MobileAnalyticsAssignedSender);
      } else {
        await _flushLegacy(sender);
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _flushLegacy(NebulaAnalyticsSender sender) async {
    while (_queue.isNotEmpty) {
      final List<_Queued> taken = _takeCount(_batchCount());
      if (!await _sendWithRetry(
        sender,
        taken.map((_Queued q) => q.event).toList(growable: false),
      )) {
        _requeue(taken);
        break;
      }
      _sent += taken.length;
      await _persistQueue();
    }
  }

  Future<void> _flushMobile(MobileAnalyticsAssignedSender sender) async {
    while (_queue.isNotEmpty) {
      late final AssignedMobileAnalyticsBatch assigned;
      late final List<_Queued> taken;
      final _AssignedRetry? retry = _assignedRetry;
      if (retry != null && _queueStartsWith(retry.items)) {
        assigned = retry.batch;
        taken = _takeCount(retry.items.length);
      } else {
        _assignedRetry = null;
        final List<NebulaAnalyticsEvent> candidates = _queue
            .take(_batchCount())
            .map((_Queued q) => q.event)
            .toList(growable: false);
        try {
          assigned = sender.assignBatch(candidates);
        } on Object {
          return;
        }
        taken = _takeCount(assigned.events.length);
      }

      _assignedRetry = _AssignedRetry(assigned, taken);
      _activeBatchItems = taken;
      if (!await _persistQueue()) {
        _activeBatchItems = const <_Queued>[];
        _requeue(taken);
        return;
      }
      final _MobileBatchOutcome outcome = await _sendAssignedWithRetry(
        sender,
        assigned,
      );
      _activeBatchItems = const <_Queued>[];
      switch (outcome) {
        case _MobileBatchOutcome.success:
          _assignedRetry = null;
          _sent += taken.length;
        case _MobileBatchOutcome.drop:
          _assignedRetry = null;
          _dropped += taken.length;
        case _MobileBatchOutcome.requeue:
          _requeue(taken);
          _assignedRetry = _AssignedRetry(assigned, taken);
          await _persistQueue();
          return;
      }
      await _persistQueue();
    }
  }

  int _batchCount() => _batchSize < _queue.length ? _batchSize : _queue.length;

  List<_Queued> _takeCount(int count) {
    if (count <= 0 || count > _queue.length) return const <_Queued>[];
    final List<_Queued> taken = _queue.sublist(0, count);
    _queue.removeRange(0, count);
    for (final _Queued queued in taken) {
      _queuedBytes -= queued.event.estimatedBytes;
    }
    return taken;
  }

  void _requeue(List<_Queued> taken) {
    _queue.insertAll(0, taken);
    for (final _Queued queued in taken) {
      _queuedBytes += queued.event.estimatedBytes;
    }
  }

  bool _queueStartsWith(List<_Queued> items) {
    if (items.length > _queue.length) return false;
    for (int i = 0; i < items.length; i++) {
      if (!identical(items[i], _queue[i])) return false;
    }
    return true;
  }

  void _invalidateAssignedIfContains(_Queued queued) {
    final _AssignedRetry? retry = _assignedRetry;
    if (retry != null && retry.items.contains(queued)) {
      _assignedRetry = null;
    }
  }

  /// 剔除 TTL 过期事件（docs/02 §4：队列有 TTL 上限），计入丢弃。
  void _expireOldEvents() {
    final DateTime now = _now().toUtc();
    final List<_Queued> kept = <_Queued>[];
    int bytes = 0;
    for (final _Queued queued in _queue) {
      if (now.difference(queued.enqueuedAt) > _maxEventAge) {
        _invalidateAssignedIfContains(queued);
        _dropped++;
      } else {
        kept.add(queued);
        bytes += queued.event.estimatedBytes;
      }
    }
    _queue
      ..clear()
      ..addAll(kept);
    _queuedBytes = bytes;
  }

  /// 有界重试（docs/02 §3）：仅瞬时传输失败重试；限流(40002)/业务码/取消不重试。
  Future<bool> _sendWithRetry(
    NebulaAnalyticsSender sender,
    List<NebulaAnalyticsEvent> batch,
  ) async {
    int attempt = 0;
    while (true) {
      try {
        if (await sender.send(batch)) return true;
      } on NebulaApiException catch (e) {
        if (e.code == 40002) return false; // 限流：尊重，不自动重试。
        return false; // 业务性错误：重试无意义。
      } on NebulaCancelledException {
        return false;
      } on NebulaException {
        // 超时/连接/5xx → 走退避重试。
      }
      if (attempt >= _sendRetries) return false;
      attempt++;
      await _retryDelay(attempt);
    }
  }

  Future<_MobileBatchOutcome> _sendAssignedWithRetry(
    MobileAnalyticsAssignedSender sender,
    AssignedMobileAnalyticsBatch batch,
  ) async {
    int attempt = 0;
    while (true) {
      try {
        final MobileAnalyticsSendDisposition disposition = await sender
            .sendAssigned(batch);
        switch (disposition) {
          case MobileAnalyticsSendDisposition.success:
            return _MobileBatchOutcome.success;
          case MobileAnalyticsSendDisposition.defer:
            return _MobileBatchOutcome.requeue;
          case MobileAnalyticsSendDisposition.nonRetryable:
            return _MobileBatchOutcome.drop;
        }
      } on NebulaCancelledException {
        return _MobileBatchOutcome.requeue;
      } on NebulaException {
        // Transient/ambiguous failure retries this exact assigned batch object.
      } on Object {
        return _MobileBatchOutcome.requeue;
      }
      if (attempt >= _sendRetries) return _MobileBatchOutcome.requeue;
      attempt++;
      await _retryDelay(attempt);
    }
  }

  Future<void> _retryDelay(int attempt) {
    final int base = _sendRetryBaseDelay.inMilliseconds;
    final int exp = base * (1 << (attempt - 1));
    final int jitter = Random().nextInt(exp ~/ 4 + 1);
    return Future<void>.delayed(Duration(milliseconds: exp + jitter));
  }
}
