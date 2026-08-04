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
import 'consent.dart';
import 'event.dart';
import 'nebula_analytics.dart';

/// 队列内一条未发送事件及其入队时间（TTL 依据）。
final class _Queued {
  const _Queued(this.event, this.enqueuedAt);
  final NebulaAnalyticsEvent event;
  final DateTime enqueuedAt;
}

final class NebulaAnalyticsClient implements NebulaAnalytics {
  NebulaAnalyticsClient({
    required NebulaConsentStore consentStore,
    NebulaAnalyticsSender? sender,
    int maxQueuedEvents = 200,
    int maxQueuedBytes = 64 * 1024,
    Duration maxEventAge = const Duration(hours: 24),
    int batchSize = 50,
    int sendRetries = 3,
    Duration sendRetryBaseDelay = const Duration(milliseconds: 250),
    DateTime Function()? now,
  })  : _consentStore = consentStore,
        _sender = sender,
        _maxQueuedEvents = maxQueuedEvents,
        _maxQueuedBytes = maxQueuedBytes,
        _maxEventAge = maxEventAge,
        _batchSize = batchSize,
        _sendRetries = sendRetries,
        _sendRetryBaseDelay = sendRetryBaseDelay,
        _now = now ?? DateTime.now;

  final NebulaConsentStore _consentStore;
  final NebulaAnalyticsSender? _sender;
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

  /// 当前缓冲中的未发送事件（诊断用，只读）。
  List<NebulaAnalyticsEvent> get pending =>
      List<NebulaAnalyticsEvent>.unmodifiable(_queue.map((q) => q.event));

  /// 当前缓冲事件数。
  int get pendingCount => _queue.length;

  /// 已因队列满/超限/TTL 过期被丢弃的事件总数（docs/04：满时丢弃并计数）。
  int get droppedCount => _dropped;

  /// 已成功发送的事件总数。
  int get sentCount => _sent;

  @override
  Future<NebulaConsent> get consent async {
    _consent ??= await _consentStore.load();
    return _consent!;
  }

  @override
  Future<void> setConsent(NebulaConsent consent) async {
    _consent = consent;
    await _consentStore.save(consent);
    if (consent == NebulaConsent.revoked) {
      // 撤回同意：清理未发送的可识别事件（docs/02 §4）。
      _removeWhere((NebulaAnalyticsEvent e) => e.identifiable);
    }
  }

  @override
  Future<void> track(NebulaAnalyticsEvent event) async {
    final NebulaConsent current = await consent;
    if (event.identifiable && current != NebulaConsent.granted) {
      return; // 未同意：可识别事件直接丢弃，绝不持久化/缓冲。
    }
    _enqueue(event);
  }

  /// 有界入队（docs/02 §4：数量 + 字节硬上限；docs/04：满时丢弃最旧并计数）。
  void _enqueue(NebulaAnalyticsEvent event) {
    final int bytes = event.estimatedBytes;
    if (bytes > _maxQueuedBytes) {
      _dropped++; // 单条超限：直接丢弃并计数。
      return;
    }
    // 为容纳新事件，按需丢弃最旧（FIFO）。
    while (_queue.isNotEmpty &&
        (_queue.length >= _maxQueuedEvents ||
            _queuedBytes + bytes > _maxQueuedBytes)) {
      _dropOldest();
    }
    _queue.add(_Queued(event, _now().toUtc()));
    _queuedBytes += bytes;
  }

  void _dropOldest() {
    if (_queue.isEmpty) return;
    _queuedBytes -= _queue.removeAt(0).event.estimatedBytes;
    _dropped++;
  }

  void _removeWhere(bool Function(NebulaAnalyticsEvent) test) {
    final List<_Queued> kept = <_Queued>[];
    int bytes = 0;
    for (final _Queued q in _queue) {
      if (test(q.event)) {
        _dropped++;
      } else {
        kept.add(q);
        bytes += q.event.estimatedBytes;
      }
    }
    _queue
      ..clear()
      ..addAll(kept);
    _queuedBytes = bytes;
  }

  /// 冲刷未发送事件（F2-04）：剔除 TTL 过期 → 按批发送，单飞；失败批次回队首。
  @override
  Future<void> flush() async {
    final NebulaAnalyticsSender? sender = _sender;
    if (sender == null) return; // 无 ingest 实现：文档化 no-op（docs/01 §6）。
    if (_flushing) return; // 单飞：并发 flush 共享一次发送。
    _flushing = true;
    try {
      _expireOldEvents();
      while (_queue.isNotEmpty) {
        final List<_Queued> taken = _takeBatch();
        if (taken.isEmpty) break;
        if (!await _sendWithRetry(
            sender, taken.map((q) => q.event).toList(growable: false))) {
          // F2-R1：失败整批以**原 _Queued（保留 enqueuedAt）**回队首——
          // 反复失败不会重置 TTL，事件仍按原入队时间过期（docs/02 §4）。
          _queue.insertAll(0, taken);
          for (final _Queued q in taken) {
            _queuedBytes += q.event.estimatedBytes;
          }
          break;
        }
        _sent += taken.length;
      }
    } finally {
      _flushing = false;
    }
  }

  List<_Queued> _takeBatch() {
    final int n = _batchSize < _queue.length ? _batchSize : _queue.length;
    final List<_Queued> taken = _queue.sublist(0, n);
    _queue.removeRange(0, n);
    for (final _Queued q in taken) {
      _queuedBytes -= q.event.estimatedBytes;
    }
    return taken;
  }

  /// 剔除 TTL 过期事件（docs/02 §4：队列有 TTL 上限），计入丢弃。
  void _expireOldEvents() {
    final DateTime now = _now().toUtc();
    final List<_Queued> kept = <_Queued>[];
    int bytes = 0;
    for (final _Queued q in _queue) {
      if (now.difference(q.enqueuedAt) > _maxEventAge) {
        _dropped++;
      } else {
        kept.add(q);
        bytes += q.event.estimatedBytes;
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
      final int base = _sendRetryBaseDelay.inMilliseconds;
      final int exp = base * (1 << (attempt - 1));
      final int jitter = Random().nextInt(exp ~/ 4 + 1);
      await Future<void>.delayed(Duration(milliseconds: exp + jitter));
    }
  }
}
