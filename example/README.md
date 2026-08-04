# NFC Writer 首个启动/配置接入样例（F2-05）

演示一个假想的 NFC Writer 应用如何把 Nebula SDK 能力接进「首个启动」流程。

## 运行

```bash
dart run example/nfc_writer_first_launch.dart
```

样例**离线可运行**：全部使用注入 Port（`FakeTransport`、`InMemoryCacheStorage`、
`InMemoryConsentStore`、控制台 sender），无真实网络、无后端依赖。

## 演示的能力

| 步骤 | 能力 | 说明 |
| --- | --- | --- |
| 1 | runtime-config（F2-01） | 拉取单一版本快照：feature 开关、一等版本策略、缓存策略 |
| 2 | 版本策略（F2-01/F2-05） | `X-App-Build` → `upgrade`（build 101 < latest 120）；`forced_upgrade` 分支已写，安全关键不做 stale 兜底 |
| 3 | analytics 同意门控（F2-03） | 默认 revoked（fail-closed）：未同意时可识别事件被丢弃；同意后收集；撤回时 purge |
| 4 | 有界队列 + 批量发送（F2-04） | `flush` 按批投递（控制台 sender），失败退避、限流尊重、丢弃计数 |
| 5 | 离线启动（F2-01/F2-02） | `CacheStorage` 持久化 + stale-if-error：断网重启仍能出配置 |

## 真实接入时替换的 Port

- `FakeTransport` → `HttpTransport`（`dart:io`，SDK 内置）；
- `InMemoryCacheStorage` → 平台持久化 `CacheStorage` 实现（如 shared_preferences 适配）；
- `InMemoryConsentStore` → `CacheConsentStore` 或平台同意存储；
- 控制台 sender → 实现 `NebulaAnalyticsSender` 的 ingest 客户端（后端契约冻结后，
  参考 `sdk/CONTRACT.md` 与 `docs/12_MOBILE_RUNTIME_CONFIG_CONTRACT.md`）；
- `installationToken` provider → 真实 installation token（bootstrap 产物，FS-01）。

约束：本样例不包含生产实现，仅演示接线；不连接真实后端（docs/01 §6）。
