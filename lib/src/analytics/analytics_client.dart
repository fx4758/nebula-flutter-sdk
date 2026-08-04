/// Consent-gated analytics client (F2-03).
///
/// Enforces docs/02 §4: identifiable events are dropped when consent is not
/// granted and purged on revoke; anonymous events are always accepted. The
/// unsent buffer is deliberately minimal and unbounded here — F2-04 replaces
/// it with the bounded queue / batching / backoff / drop policy and wires a
/// transport; [flush] is a no-op until then (ingest backend contract not
/// frozen, docs/01 §6).
library;

import 'consent.dart';
import 'event.dart';
import 'nebula_analytics.dart';

final class NebulaAnalyticsClient implements NebulaAnalytics {
  NebulaAnalyticsClient({
    required NebulaConsentStore consentStore,
    List<NebulaAnalyticsEvent>? initialBuffer,
  })  : _consentStore = consentStore,
        _buffer = initialBuffer ?? <NebulaAnalyticsEvent>[];

  final NebulaConsentStore _consentStore;

  /// 未发送事件缓冲（F2-03 最小实现；F2-04 引入有界队列）。
  final List<NebulaAnalyticsEvent> _buffer;

  NebulaConsent? _consent;

  /// 当前缓冲中的未发送事件（诊断用，只读）。
  List<NebulaAnalyticsEvent> get pending =>
      List<NebulaAnalyticsEvent>.unmodifiable(_buffer);

  /// 当前缓冲事件数。
  int get pendingCount => _buffer.length;

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
      _buffer.removeWhere((NebulaAnalyticsEvent e) => e.identifiable);
    }
  }

  @override
  Future<void> track(NebulaAnalyticsEvent event) async {
    final NebulaConsent current = await consent;
    if (event.identifiable && current != NebulaConsent.granted) {
      return; // 未同意：可识别事件直接丢弃，绝不持久化/缓冲。
    }
    _buffer.add(event);
  }

  @override
  Future<void> flush() async {
    // F2-03 no-op：发送管线/后端契约属 F2-04（docs/01 §6 未冻结端点不假实现）。
  }
}
