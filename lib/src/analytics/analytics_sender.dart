/// Analytics ingest sender Port (F2-04).
///
/// The bounded queue / batching / backoff / drop machinery lives in the SDK;
/// the actual ingest transport is host-injected through this Port because the
/// backend contract is not frozen yet (docs/01 §6 — the SDK must not fabricate
/// an endpoint). Return `true` on success; throw a [NebulaException] subclass
/// to signal failure (40002 = rate limited → caller respects it and does not
/// auto-retry).
library;

import '../foundation/errors.dart';
import 'event.dart';

/// 批量事件发送 Port：host 提供 ingest 实现。
abstract interface class NebulaAnalyticsSender {
  /// 发送一批事件。成功返回 true；失败抛 [NebulaException]（
  /// [NebulaApiException] code=40002 表示限流，调用方不自动重试）或返回 false。
  Future<bool> send(List<NebulaAnalyticsEvent> batch);
}
