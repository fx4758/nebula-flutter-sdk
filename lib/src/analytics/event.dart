/// Typed analytics event schema (F2-03, docs/02 §4 privacy).
///
/// Events are immutable and locally validated before the analytics pipeline
/// touches them. `identifiable` marks events carrying personal identifiable
/// information (PII) — such events are only collected after consent is
/// [NebulaConsent.granted] and are purged when consent is revoked. The SDK
/// never interprets business meaning (docs/01 §2: 业务指标解释不属于 SDK).
library;

import 'dart:convert';

/// 事件隐私类别：可识别（含 PII）vs 匿名。
enum NebulaEventPrivacy { anonymous, identifiable }

/// 单条分析事件（不可变）。
///
/// 本地校验上限（docs/02 §4 队列有数量/字节上限的输入侧约束）：
/// 名称非空且 ≤ 128 字符；属性为合法 JSON 且 ≤ 64 键、序列化后 ≤ 8 KiB。
final class NebulaAnalyticsEvent {
  NebulaAnalyticsEvent({
    required this.name,
    required this.privacy,
    this.properties = const <String, Object?>{},
    DateTime? timestamp,
  })  : timestamp = timestamp ?? DateTime.now().toUtc() {
    _validate();
  }

  /// 事件名（例如 `screen_view`）；长度 ≤ 128。
  final String name;

  /// 事件时间（UTC）。未传时取构造时刻。
  final DateTime timestamp;

  /// 结构化属性（JSON 可序列化）。
  final Map<String, Object?> properties;

  /// 隐私类别：可识别事件仅在同意后收集。
  final NebulaEventPrivacy privacy;

  /// 是否可识别（含 PII）。
  bool get identifiable => privacy == NebulaEventPrivacy.identifiable;

  /// 序列化后估算字节数（F2-04 队列字节上限的输入依据）。
  int get estimatedBytes => utf8.encode(jsonEncode(toJson())).length;

  /// Wire 表示（供批量发送/持久化复用，docs/02 §4 白名单外字段不入）。
  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
        'identifiable': identifiable,
        'properties': properties,
      };

  void _validate() {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    if (name.length > kMaxEventNameLength) {
      throw ArgumentError.value(name, 'name', 'exceeds 128 chars');
    }
    if (properties.length > kMaxEventPropertyCount) {
      throw ArgumentError.value(properties, 'properties', 'exceeds 64 keys');
    }
    try {
      final List<int> bytes =
          utf8.encode(jsonEncode(toJson()));
      if (bytes.length > kMaxEventBytes) {
        throw ArgumentError.value(name, 'event', 'exceeds 8 KiB');
      }
    } on JsonUnsupportedObjectError catch (e) {
      throw ArgumentError.value(
        properties,
        'properties',
        'not JSON-serializable: ${e.unsupportedObject}',
      );
    }
  }
}

const int kMaxEventNameLength = 128;
const int kMaxEventPropertyCount = 64;
const int kMaxEventBytes = 8 * 1024;
