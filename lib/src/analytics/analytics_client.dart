/// Consent-gated analytics client with bounded queue (F2-03 + F2-04).
library;

import 'dart:async';
import 'dart:math';

import '../foundation/errors.dart';
import 'analytics_sender.dart';
import 'consent.dart';
import 'event.dart';
import 'mobile_analytics_sender.dart';
import 'nebula_analytics.dart';

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
  _AssignedRetry? _assignedRetry;

  List<NebulaAnalyticsEvent> get pending =>
      List<NebulaAnalyticsEvent>.unmodifiable(_queue.map((q) => q.event));
  int get pendingCount => _queue.length;
  int get droppedCount => _dropped;
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
      _removeWhere((NebulaAnalyticsEvent event) => event.identifiable);
    }
  }

  @override
  Future<void> track(NebulaAnalyticsEvent event) async {
    final NebulaConsent current = await consent;
    if (event.identifiable && current != NebulaConsent.granted) return;
    _enqueue(event);
  }

  void _enqueue(NebulaAnalyticsEvent event) {
    final int bytes = event.estimatedBytes;
    if (bytes > _maxQueuedBytes) {
      _dropped++;
      return;
    }
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

  @override
  Future<void> flush() async {
    final NebulaAnalyticsSender? sender = _sender;
    if (sender == null || _flushing) return;
    _flushing = true;
    try {
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
        taken.map((q) => q.event).toList(growable: false),
      )) {
        _requeue(taken);
        break;
      }
      _sent += taken.length;
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
            .map((q) => q.event)
            .toList(growable: false);
        try {
          assigned = sender.assignBatch(candidates);
        } on Object {
          return;
        }
        taken = _takeCount(assigned.events.length);
      }

      final _MobileBatchOutcome outcome =
          await _sendAssignedWithRetry(sender, assigned);
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
          return;
      }
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
    if (retry != null && retry.items.contains(queued)) _assignedRetry = null;
  }

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

  Future<bool> _sendWithRetry(
    NebulaAnalyticsSender sender,
    List<NebulaAnalyticsEvent> batch,
  ) async {
    int attempt = 0;
    while (true) {
      try {
        if (await sender.send(batch)) return true;
      } on NebulaApiException catch (error) {
        if (error.code == 40002) return false;
        return false;
      } on NebulaCancelledException {
        return false;
      } on NebulaException {
        // Transient transport failure: bounded retry below.
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
        final MobileAnalyticsSendDisposition result =
            await sender.sendAssigned(batch);
        if (result == MobileAnalyticsSendDisposition.success) {
          return _MobileBatchOutcome.success;
        }
        if (result == MobileAnalyticsSendDisposition.nonRetryable) {
          return _MobileBatchOutcome.drop;
        }
        return _MobileBatchOutcome.requeue;
      } on NebulaCancelledException {
        return _MobileBatchOutcome.requeue;
      } on NebulaException {
        // Ambiguous/transient failure retries the same assigned batch object.
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
