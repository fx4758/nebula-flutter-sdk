/// Analytics capability Port (F2-03, docs/02 §4 privacy).
///
/// Consent-gated, typed event collection. Identifiable events are only
/// accepted while consent is [NebulaConsent.granted]; revoking consent purges
/// unsent identifiable events. The bounded queue / batching / backoff / drop
/// policy is F2-04; the ingest backend contract is not frozen yet (docs/01 §6),
/// so [flush] is a documented no-op until F2-04 wires a transport.
library;

import 'consent.dart';
import 'event.dart';

/// Analytics capability（docs/02 §4）。
abstract interface class NebulaAnalytics {
  /// 当前同意状态；默认 revoked（fail-closed，docs/02 §4）。
  Future<NebulaConsent> get consent;

  /// 设置同意状态。置为 [NebulaConsent.revoked] 时清理未发送的可识别事件
  /// 并持久化（撤回同意后不再发送隐私事件）。
  Future<void> setConsent(NebulaConsent consent);

  /// 上报一条事件。可识别事件在未同意时被丢弃（绝不持久化/发送）；
  /// 匿名事件始终接受。本方法不抛业务异常（analytics 不得拖垮主流程）。
  Future<void> track(NebulaAnalyticsEvent event);

  /// 冲刷未发送事件。F2-03 为 no-op（发送管线与后端契约属 F2-04 范围）。
  Future<void> flush();
}
