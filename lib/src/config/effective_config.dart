/// Effective runtime-config models (F2-01, docs/12 §4/§5/§8.3).
///
/// Immutable 1:1 mapping of the frozen wire snapshot. Parsing is strict about
/// required fields and enforces the client-side hard caps (§8.3): an
/// over-limit or malformed snapshot is rejected whole — never partially
/// trusted. Control-plane fields (rules_json/rollout_percentage/created_by/
/// updated_by) are structurally impossible in these models.
library;

import '../foundation/errors.dart';

/// 一等版本策略 action（docs/12 §5）：服务端按 X-App-Build 计算。
enum NebulaVersionAction { none, upgrade, forcedUpgrade }

/// 一等版本策略模型（docs/12 §5）。
final class NebulaVersionPolicy {
  const NebulaVersionPolicy({
    required this.minimumSupportedBuild,
    required this.latestBuild,
    required this.action,
    required this.messageKey,
  });

  final int minimumSupportedBuild;
  final int latestBuild;
  final NebulaVersionAction action;
  final String messageKey;

  factory NebulaVersionPolicy.fromJson(Map<String, Object?> json) {
    final Object? min = json['minimum_supported_build'];
    final Object? latest = json['latest_build'];
    final Object? action = json['action'];
    final Object? messageKey = json['message_key'];
    if (min is! int || latest is! int || action is! String || messageKey is! String) {
      throw _malformed('version_policy');
    }
    // Wire 值是冻结 snake_case（docs/12 §5）；枚举名是 camelCase，须显式映射。
    final NebulaVersionAction? parsed = switch (action) {
      'none' => NebulaVersionAction.none,
      'upgrade' => NebulaVersionAction.upgrade,
      'forced_upgrade' => NebulaVersionAction.forcedUpgrade,
      _ => null,
    };
    if (parsed == null) throw _malformed('version_policy.action');
    return NebulaVersionPolicy(
      minimumSupportedBuild: min,
      latestBuild: latest,
      action: parsed,
      messageKey: messageKey,
    );
  }

  /// 安全关键（docs/12 §6.5）：forced_upgrade 不得无限期使用旧缓存。
  bool get isSecurityCritical => action == NebulaVersionAction.forcedUpgrade;
}

/// 服务端给出的缓存参数（docs/12 §6）。
final class NebulaCachePolicy {
  const NebulaCachePolicy({
    required this.ttlSeconds,
    required this.staleIfErrorSeconds,
  });

  final int ttlSeconds;
  final int staleIfErrorSeconds;

  factory NebulaCachePolicy.fromJson(Map<String, Object?> json) {
    final Object? ttl = json['ttl_seconds'];
    final Object? stale = json['stale_if_error_seconds'];
    if (ttl is! int || stale is! int) throw _malformed('cache_policy');
    return NebulaCachePolicy(ttlSeconds: ttl, staleIfErrorSeconds: stale);
  }
}

/// 单个可下发配置项（docs/12 §4）：value 为任意合法 JSON。
final class NebulaConfigItem {
  const NebulaConfigItem({required this.value, required this.updatedAt});

  final Object? value;
  final DateTime updatedAt; // Unix 秒
}

/// Feature 最终状态（docs/12 §4/§9）：enabled 已含服务端灰度分桶结果。
final class NebulaFeatureFlag {
  const NebulaFeatureFlag({
    required this.key,
    required this.enabled,
    required this.securityCritical,
  });

  final String key;
  final bool enabled;
  final bool securityCritical;
}

/// 单一版本快照（docs/12 §4）。revision 变化即缓存失效信号。
final class NebulaEffectiveConfig {
  const NebulaEffectiveConfig({
    required this.revision,
    required this.serverTime,
    required this.configs,
    required this.features,
    required this.versionPolicy,
    required this.cachePolicy,
  });

  final String revision;
  final DateTime serverTime;
  final Map<String, NebulaConfigItem> configs;
  final List<NebulaFeatureFlag> features;
  final NebulaVersionPolicy versionPolicy;
  final NebulaCachePolicy cachePolicy;

  /// 是否存在安全关键内容（docs/12 §6.5）：forced_upgrade 或任一
  /// security_critical feature → 不得从 stale 缓存提供。
  bool get hasSecurityCritical =>
      versionPolicy.isSecurityCritical ||
      features.any((f) => f.securityCritical);

  factory NebulaEffectiveConfig.fromJson(Map<String, Object?> json) {
    final Object? revision = json['revision'];
    final Object? serverTime = json['server_time'];
    final Object? configsRaw = json['configs'];
    final Object? featuresRaw = json['features'];
    if (revision is! String || revision.isEmpty) throw _malformed('revision');
    if (serverTime is! int) throw _malformed('server_time');
    if (configsRaw is! Map<String, Object?> || featuresRaw is! List) {
      throw _malformed('configs/features');
    }

    // 客户端硬上限（docs/12 §8.3）：超限整体拒绝，绝不部分信任。
    if (configsRaw.length > kMaxConfigItems ||
        featuresRaw.length > kMaxFeatureItems) {
      throw _malformed('snapshot exceeds delivery limits');
    }

    final Map<String, NebulaConfigItem> configs =
        <String, NebulaConfigItem>{};
    for (final MapEntry<String, Object?> entry in configsRaw.entries) {
      if (entry.key.length > kMaxKeyLength) throw _malformed('config key');
      final Object? item = entry.value;
      if (item is! Map<String, Object?>) throw _malformed('config item');
      final Object? value = item['value'];
      final Object? updatedAt = item['updated_at'];
      if (updatedAt is! int) throw _malformed('config item updated_at');
      if (value is String && value.length > kMaxValueBytes) {
        throw _malformed('config value exceeds 8 KiB');
      }
      configs[entry.key] = NebulaConfigItem(
        value: value,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt * 1000,
            isUtc: true),
      );
    }

    final List<NebulaFeatureFlag> features = <NebulaFeatureFlag>[];
    for (final Object? raw in featuresRaw) {
      if (raw is! Map<String, Object?>) throw _malformed('feature');
      final Object? key = raw['key'];
      final Object? enabled = raw['enabled'];
      if (key is! String || enabled is! bool) throw _malformed('feature');
      if (key.length > kMaxKeyLength) throw _malformed('feature key');
      features.add(NebulaFeatureFlag(
        key: key,
        enabled: enabled,
        securityCritical: raw['security_critical'] == true,
      ));
    }

    return NebulaEffectiveConfig(
      revision: revision,
      serverTime: DateTime.fromMillisecondsSinceEpoch(serverTime * 1000,
          isUtc: true),
      configs: Map<String, NebulaConfigItem>.unmodifiable(configs),
      features: List<NebulaFeatureFlag>.unmodifiable(features),
      versionPolicy: NebulaVersionPolicy.fromJson(
        (json['version_policy']! as Map).cast<String, Object?>(),
      ),
      cachePolicy: NebulaCachePolicy.fromJson(
        (json['cache_policy']! as Map).cast<String, Object?>(),
      ),
    );
  }
}

/// 客户端硬上限（docs/12 §8.3）——与 FC-02 fixture 测试同一定义。
const int kMaxConfigItems = 128;
const int kMaxFeatureItems = 256;
const int kMaxKeyLength = 64;
const int kMaxValueBytes = 8 * 1024;

NebulaHttpException _malformed(String detail) => NebulaHttpException(
      'runtime-config snapshot malformed: $detail',
    );
