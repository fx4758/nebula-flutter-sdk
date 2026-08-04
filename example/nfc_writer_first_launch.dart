// NFC Writer 首个启动/配置接入样例（F2-05，依赖 F2-01..04）。
//
// 演示一个假想的 NFC Writer 应用在「首个启动」流程里如何接线 SDK 能力：
//   1. runtime-config 拉取（F2-01）：feature 开关 + 一等版本策略 + 缓存策略；
//   2. 缓存与离线启动（F2-01/F2-02）：CacheStorage 持久化，断网也能出配置；
//   3. analytics 同意门控（F2-03）：未同意丢弃可识别事件、撤回 purge；
//   4. 有界队列 + 批量发送（F2-04）：flush 按批投递、失败退避。
//
// 样例全部使用注入 Port（FakeTransport / InMemory 存储 / 控制台 sender），
// 无真实网络、无后端依赖，`dart run example/nfc_writer_first_launch.dart`
// 即可运行。真实接入时替换这些 Port 为 HttpTransport + 持久化存储 + 真实
// ingest（后端契约冻结后）。
// ignore_for_file: avoid_print
library;

import 'package:nebula_sdk/nebula_sdk.dart';

/// 控制台 sender：把每批事件打印出来，模拟 ingest 投递。
final class _ConsoleSender implements NebulaAnalyticsSender {
  int _batches = 0;

  @override
  Future<bool> send(List<NebulaAnalyticsEvent> batch) async {
    _batches++;
    print('      [ingest] 批次 $_batches：${batch.map((e) => e.name).join(', ')}');
    return true;
  }
}

/// 与 docs/12 §4 一致的冻结快照（transport 层 data 部分）。
Map<String, Object?> _snapshotData() => <String, Object?>{
      'revision': 'rev-42-1785770000000000000',
      'server_time': 1785770000,
      'configs': <String, Object?>{
        'nfc_export_interval_seconds': <String, Object?>{
          'value': 30,
          'updated_at': 1785769000,
        },
      },
      'features': <Object?>[
        <String, Object?>{'key': 'nfc_export', 'enabled': true},
        <String, Object?>{'key': 'payment_v2', 'enabled': true},
      ],
      'version_policy': <String, Object?>{
        'minimum_supported_build': 100,
        'latest_build': 120,
        'action': 'upgrade',
        'message_key': 'upgrade_prompt_v3',
      },
      'cache_policy': <String, Object?>{
        'ttl_seconds': 300,
        'stale_if_error_seconds': 86400,
      },
    };

Future<void> main() async {
  print('=== NFC Writer 首个启动（F2-05 样例，离线可运行）===');

  // ---- 1. 组装（composition root）----
  final NebulaOptions options = NebulaOptions(
    appId: 'com.example.nfcwriter',
    baseUri: Uri.parse('https://api.example.com'),
    environment: NebulaEnvironment.staging,
  );
  final InMemoryCacheStorage cache = InMemoryCacheStorage();
  final NebulaConfigClient config = NebulaConfigClient(
    options: options,
    transport: FakeTransport()..enqueue(FakeTransport.ok(_snapshotData())),
    proofSigner: RecordingProofSigner(),
    installationToken: () async => 'inst-token-1',
    cacheStorage: cache,
    appBuild: 101, // < latest 120 → upgrade（演示版本策略分支）
  );
  final NebulaAnalyticsClient analytics = NebulaAnalyticsClient(
    consentStore: InMemoryConsentStore(), // 默认 revoked（fail-closed）
    sender: _ConsoleSender(),
  );

  // ---- 2. 启动拉取 effective config（F2-01）----
  print('\n[1] 拉取 runtime-config…');
  final NebulaEffectiveConfig cfg = await config.getEffectiveConfig();
  print('    revision=${cfg.revision}');
  print(
      '    feature nfc_export=${cfg.features.firstWhere((f) => f.key == 'nfc_export').enabled}');
  print('    导出间隔=${cfg.configs['nfc_export_interval_seconds']!.value}s');

  switch (cfg.versionPolicy.action) {
    case NebulaVersionAction.forcedUpgrade:
      print('    [版本策略] 强制升级：引导用户前往应用商店（安全关键，不做 stale 兜底）');
    case NebulaVersionAction.upgrade:
      print('    [版本策略] 检测到新版本（build 101 < latest 120）：非阻塞提示升级');
    case NebulaVersionAction.none:
      print('    [版本策略] 无升级要求');
  }

  // ---- 3. analytics 同意门控（F2-03）----
  print('\n[2] analytics 同意门控…');
  await analytics.track(NebulaAnalyticsEvent(
    name: 'app_launch',
    privacy: NebulaEventPrivacy.anonymous, // 匿名事件始终可收集
  ));
  await analytics.track(NebulaAnalyticsEvent(
    name: 'purchase_attempt',
    privacy: NebulaEventPrivacy.identifiable, // 可识别事件：未同意 → 丢弃
    properties: <String, Object?>{'user_id': 'u-9'},
  ));
  print('    未同意时 pending=${analytics.pendingCount}（可识别事件已被丢弃）');

  await analytics.setConsent(NebulaConsent.granted);
  await analytics.track(NebulaAnalyticsEvent(
    name: 'purchase_attempt',
    privacy: NebulaEventPrivacy.identifiable,
    properties: <String, Object?>{'user_id': 'u-9'},
  ));
  print('    同意后 pending=${analytics.pendingCount}');

  // ---- 4. 批量 flush（F2-04）----
  print('\n[3] 批量发送…');
  await analytics.flush();
  print('    sent=${analytics.sentCount} dropped=${analytics.droppedCount}');

  // ---- 5. 离线启动（F2-01/F2-02：CacheStorage 持久化）----
  print('\n[4] 离线启动（模拟断网重启）…');
  final NebulaConfigClient offline = NebulaConfigClient(
    options: options,
    transport: FakeTransport()
      ..enqueueError(const NebulaHttpException('offline', statusCode: 503))
      ..enqueueError(const NebulaHttpException('offline', statusCode: 503)),
    proofSigner: RecordingProofSigner(),
    installationToken: () async => 'inst-token-1',
    cacheStorage: cache,
    appBuild: 101,
  );
  final NebulaEffectiveConfig cached = await offline.getEffectiveConfig();
  print('    离线可用：revision=${cached.revision}（来自持久化缓存）');

  print('\n=== 首个启动完成 ===');
}
