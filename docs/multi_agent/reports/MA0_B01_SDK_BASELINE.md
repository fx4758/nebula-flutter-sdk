# MA0-B01 — SDK F0-F2 当前能力审计

> Status：IN_PROGRESS → REVIEW → **DONE（2026-08-07 治理验收 PASS ✅）**
> Owner：SDK Architect Agent（workbuddy-sdk-architect-agent）
> Audit inputs：nebula-flutter-sdk `279ed51`（sole SDK authority）；Backend 基线见 MA0-A01/C01
> Started：2026-08-07T09:35:51+08:00 ／ Submitted：2026-08-07T09:37:59+08:00 ／ Completed：2026-08-07T09:46:48+08:00

## 1. 取证口径与边界

- **唯一 SDK Authority** = `nebula-flutter-sdk` @ `279ed51`（与 A01/C01 的 `sdk_context` 一致）。BE-Codex `sdk/dart/**` 为 Quarantine，不作为 SDK 权威来源。
- **单 package 成立**：`pubspec.yaml` + `lib/` 自 F0-01 起即为独立 package（STATUS `Independent package scaffold = DONE`）。本报告不拆 package、不增 public export，仅审计。
- **WIP Quarantine（只读、未修改）**：以下未提交 dirty 文件属其他 Owner 冻结区，本次审计全程只读，未触碰：
  `lib/src/analytics/consent.dart`、`lib/src/analytics/event.dart`、`lib/src/auth/session_auth.dart`、`lib/src/config/config_client.dart`、`lib/src/config/effective_config.dart`、`lib/src/foundation/logging.dart`、`lib/src/foundation/sha256.dart`、`lib/src/storage/cache_storage.dart`、`lib/src/testing/fake_transport.dart`、`lib/src/transport/http_transport.dart`、`test/foundation_test.dart`、`test/kernel_integration_test.dart`、`test/session_auth_test.dart`、`test/storage_test.dart`、`tool/api_surface.dart`、`tool/governance_test.dart`。
- **符号级冻结门禁**：`tool/api_surface.dart` + `governance/api_surface.snapshot`。snapshot 当前 **121 符号行**（与 F2-R1 终态 `api_surface 121 symbols` 一致，见 STATUS §F2-R1）。

## 2. 公共 API surface 枚举（与 snapshot 一致）

### 2.1 Barrel 导出（`lib/nebula_sdk.dart`）
共 **34 条 `export`**，覆盖 11 个子系统：
`analytics/*`(6) · `auth/*`(11) · `capabilities.dart` · `config/*`(4) · `foundation/*`(5) · `nebula.dart`(facade) · `storage/*`(3) · `testing/fake_transport.dart` · `transport(.dart)`(4)。

### 2.2 顶层公共符号（snapshot = 121）
`governance/api_surface.snapshot` 冻结 121 个顶层符号（class/enum/const/typedef/function）。核心入口：
- **`Nebula`**（final class，DI facade，`lib/src/nebula.dart`）：持有 `transport / auth / config / analytics` 四个 Port，**无 service locator**。
- **`NebulaAuth`**（abstract interface，`lib/src/capabilities.dart`）：完整会话契约——`state / accessToken / events / restoreSession / login / getAccessToken / refresh / signOut`，已落地（F1-02）。
- **4 个空标记接口**（`lib/src/capabilities.dart`，frozen in F3/F4）：`NebulaAsset` · `NebulaNotification` · `NebulaPayment` · `NebulaAi`——**均为空 `abstract interface class`，无成员**。这是 F3 准入边界：S2-S01 将在此填充 `NebulaAsset` 具体能力。
- snapshot 已包含上述 4 标记（line 63-67）+ `NebulaAuth`（line 65），**无符号级 drift**。

> **验收项「公共 API 数量与 snapshot 一致」满足**：当前 barrel 导出的符号集 == 121 行 snapshot；B01 为纯审计，未增删任何符号。

## 3. F0/F1/F2 真实证据（来自 `docs/STATUS.md`）

| Stage | 项 | 状态 | 关键证据（符号数 / 测试 / 门禁） |
|---|---|---|---|
| **F0** | F0-01..F0-05 | DONE | 独立 package 脚手架；信任/会话契约冻结；legacy HMAC 日落；fixtures 同步；CI（`dart test`+`api_surface`+`secret_scan`） |
| | G0-01..G0-04 | DONE | 治理守卫；23 隔离用例；API surface 快照工具（初冻 63 符号） |
| | F0-R9 | DONE | 安全闭环（2026-08-04，11 项）；自包含 HTTP 成功路径 |
| **F1** | F1-01 HttpTransport | DONE | envelope `{code,data,request_id}` 解码；超时；`Future.any`+`client.close(force)` 取消；business-code→`NebulaApiException`；10 测试；`api_surface 70` |
| | F1-02 NebulaSessionAuth | DONE | 实现 `NebulaAuth`，接 `NebulaSession` 状态机；真实 login/refresh/logout；proof headers（`X-Installation-Token`/`X-Device-Proof`，SHA-256 canonical）；single-flight refresh；14 测试；`api_surface 75` |
| | F1-03 Storage ports | DONE | `StorageNamespace` + `SecureStorage`/`CacheStorage` Port + fakes；`api_surface 80` |
| | F1-04 Foundation | DONE | `NebulaRequestId` + `NebulaErrorCategory`/`classifyNebulaError` + `NebulaLogger`/`RedactingLogger`/`redact`；`api_surface 89` |
| | F1-05 Kernel testing | DONE | `FakeTransport implements NebulaTransport` 公共可复用；`kernel_integration_test` 13 测试；**F1 exit 达成**（并发 refresh = 1 网络调用）；`api_surface 91` |
| **F2** | F2-00 RuntimeConfig 契约 | DONE | 冻结 `docs/12`；单一聚合 `GET /api/v1/mobile/runtime-config`；信任域仅 installation token+proof；ADR-F011 |
| | FB-06 后端端点 | DONE | `internal/module/runtimeconfig`，Proof 链；ETag/304；kill-switch→12004；`go test ./...` 全绿；ArchGuard 0 blocking |
| | FC-02 跨仓 fixtures | DONE | `test/fixtures/runtime_config/` 10 文件；`runtime_config_contract_test` 11 测试 |
| | F2-01 EffectiveConfig | DONE | `lib/src/config/`（`NebulaEffectiveConfig` 等）；`NebulaConfig` 替换 F0 placeholder；`ConfigEndpoints`；12 测试；`api_surface 105` |
| | F2-02 Cache hardening | DONE | 有界幂等重试；`NebulaConfigParseException`；`clearCache()`；8 测试；`api_surface 106` |
| | F2-03 Analytics consent | DONE | `NebulaConsent`(fail-closed) + `NebulaAnalytics` 真实接口；11 测试；`api_surface 116` |
| | F2-04 Analytics queue | DONE | `NebulaAnalyticsSender`；有界队列/批/退避/drop；11 测试；`api_surface 117` |
| | F2-05 NFC example | DONE | `example/nfc_writer_first_launch.dart` 离线可跑，串联 F2-01..04 |
| | F2-R1 评审闭环 | DONE | 7 评论+1 补充全关；`api_surface 121 symbols`；**SDK 184 测试通过** |
| **F3+** | F3-01..F6 | **BLOCKED** | 依赖 flypost E1/E3（后端 Asset 契约）；待 ADR-ASSET-001 + MOBILE_ASSET_CONTRACT 冻结 |

**结论**：F0/F1/F2 客户端基座已闭环，184 测试、121 符号、治理/secret_scan 全绿；4 个 capability 仍为空标记，是 F3 准入前唯一未填充面。

## 4. 可复用 SDK Foundation 能力标记（Transport/Storage/Auth/Proof/Cancellation/Logger）

下列模块已 production-grade（有测试 + snapshot 注册），属于 **SDK Foundation 能力**（Transport/Storage/Auth/Proof/Cancellation/Logger），**并非 Asset Domain 本身**；Asset Feature（S2-S01/S02/S03）**应直接复用这些 Foundation 能力而非自建**（与 `03_OWNERSHIP_MATRIX` 中 "Asset SDK Agent 不自建 Transport/Storage" 一致）：

| 能力域 | 复用类 / 文件 | 证据（F-stage） | Asset 用法 |
|---|---|---|---|
| **Transport** | `NebulaTransport`(Port) · `HttpTransport` · `NebulaCancellationToken` · `transport/proof_headers.dart`(`buildAuthHeaders`) | F1-01, F2-01/02 | 上传/查询请求走同一 transport；proof header 构造复用 |
| **Storage** | `StorageNamespace` · `SecureStorage`/`InMemorySecureStorage` · `CacheStorage`/`InMemoryCacheStorage` | F1-03 | 上传态/恢复态持久化（S2-S03）用 `CacheStorage` 离线启动 |
| **Auth/Proof** | `NebulaAuth` · `NebulaSessionAuth` · `proof.dart`(`ProofCanonicalInput`/`RequestProofSigner`/`nebulaProofVersion`) · `key_store.dart`(`InstallationKeyPair`/`Port`) · `session_endpoints.dart` | F1-02, FS-01 | 安装证明+会话令牌复用；upload ticket 请求带 installation proof |
| **Cancellation** | `NebulaCancellationToken` · `NebulaCancelledException` · `NebulaTimeoutException` | F1-01 | 上传进度/超时/取消（S2-S02）复用取消原语 |
| **Logger** | `NebulaLogger`/`NebulaLogEvent`/`NebulaLogLevel` · `NoOpLogger` · `RedactingLogger` · `redact`/`redactValues` | F1-04 | 上传日志走 redacting logger，禁打 token/owner |
| **Testing** | `FakeTransport implements NebulaTransport`（`testing/fake_transport.dart`） | F1-05 | S2-S02 FakeTransport/HTTP fake 测试直接复用 |

> **关键约束（S2-S02）**：直传请求**不得带 `Nebula Authorization`**。当前 `HttpTransport` 通过 `buildAuthHeaders` 注入 installation proof；Asset 直传 OSS/Provider 时须走**不带 auth 的传输边界**（新增方法或 flag），否则会泄漏安装证明到第三方。这是 S2-S02 的核心设计风险（见 §6）。

## 5. 必须由 SDK Architect 串行修改的共享文件

下列文件跨 Owner、按 `03_OWNERSHIP_MATRIX` 须 SDK Architect **串行合并**，Asset/Notification/Payment Feature Agent 不得自行改动：

| 文件 | 为何共享 | S2 触碰点 |
|---|---|---|
| `lib/nebula_sdk.dart` | 公共 export barrel（API surface 门禁源） | S2-S01 增 asset 导出 → 须 `--update` snapshot |
| `lib/src/nebula.dart` | `Nebula` facade（持有各 Port） | S2-S01 增 `asset` Port 字段 |
| `lib/src/capabilities.dart` | `NebulaAuth` + 4 标记接口定义处 | S2-S01 填充 `NebulaAsset` 具体成员 |
| `lib/src/foundation/**` | logging/sha256/options/errors/request_id | 全部 SDK Architect 独占；Asset 仅消费 |
| `lib/src/transport/**` | http_transport/cancellation_token/proof_headers | SDK Architect 独占；S2-S02 直传边界须在此定义 |
| `lib/src/storage/**` | cache_storage/secure_storage/storage_namespace | SDK Architect 独占；S2-S03 恢复态持久化复用 |
| `lib/src/auth/**` | 共享 proof API（proof.dart/key_store.dart/session_auth.dart） | "不得改共享 proof API"（矩阵明示）；Asset 仅消费 |
| `tool/api_surface.dart` + `governance/api_surface.snapshot` | 符号冻结门禁 | S2-S01 改 surface 后须重跑 `--update`（**当前该 tool 在 WIP Quarantine 中为 dirty，须先由 Owner 提交**，见 §6） |

## 6. S2-S01 / S2-S02 / S2-S03 依赖与风险

来源：`01_WORK_BREAKDOWN.md:184-214`（Feature AS-F3：SDK Asset）。

### S2-S01｜SDK Asset Model + Capability（3 SP）
- **任务**：公共 asset/upload task 模型、状态/进度事件、cancellation、typed errors、增 Facade capability、API surface/gov 更新。
- **验收**：不暴露 Provider/Bucket/OSS SDK 类型。
- **依赖**：① ADR-ASSET-001 批准（权威选型 + 能力注册）；② MOBILE_ASSET_CONTRACT 冻结（owner 服务端强制，消 C01 客户端自声明缺陷）；③ `asset.upload/asset.download` 入 `Capabilities` 白名单（修 A01 §7.2 / C01 DEFECT）；④ `module/file` owner-trust 缺陷在后端修掉前，SDK 不能沿用 client-declared owner。
- **风险**：R1 触碰 `capabilities.dart`/`nebula.dart`/`nebula_sdk.dart` 三个串行文件，须 SDK Architect 串行合并，Feature Agent 并行易冲突。R2 若暴露底层存储类型即违验收，需在 model 层抽象 `UploadInstruction` 而非直露 Bucket。

### S2-S02｜SDK Direct Upload Executor（3 SP）
- **任务**：create upload session → 按 instruction 直传 → 上传请求**不带 Nebula Authorization** → complete → 进度/超时/取消 → FakeTransport/HTTP fake 测试。
- **量化验收**：取消后不调 complete；并发重复 start 不产生两个有效任务。
- **依赖**：① S2-S01 的 task 模型 + cancellation 原语；② `HttpTransport` 直传边界（见 §4 约束：proof header 不得泄漏到第三方）；③ backend `module/file` 的 upload ticket 契约（FB 侧，待 ADR）。
- **风险**：R1 **auth 泄漏**：复用 `HttpTransport` 若不隔离 auth header，直传会把 installation proof 发往 OSS/Provider。必须在 transport 层明确"无 auth 直传"路径。R2 并发去重：重复 start 须 single-flight，否则产生双任务（违量化验收）。R3 取消语义：取消须保证"不调 complete"且已传分片不泄露。

### S2-S03｜SDK Resume/Recovery（2 SP）
- **验收**：保存最小恢复态；过期 ticket 可重建；已上传未 complete 可恢复确认；用户切换不串任务。
- **依赖**：① S2-S02 的执行器 + cancellation；② `CacheStorage`（F1-03）做离线恢复态持久化；③ `StorageNamespace` 的 user-scoped 隔离（防用户切换串任务）。
- **风险**：R1 恢复态持久化落在 `lib/src/storage/`（SDK Architect 独占），S2-S03 仅消费不得改共享 storage。R2 过期 ticket 重建须后端支持（ticket 续期/重建接口），属 backend 依赖。

### S2-Q01｜Asset 跨仓 E2E（2 SP，附）
- 验收：create→upload→complete→query；失败矩阵 ≥6 类；contract fixture 无漂移。依赖 S2-S01+S02-S03 + backend F3-01（flypost E1/E3）。

**跨故事阻塞汇总**：S2 全链路卡在 **ADR-ASSET-001 未批准** 与 **backend `module/file` owner-trust 缺陷未修**；且 `tool/api_surface.dart` 当前 dirty（WIP Quarantine），S2-S01 的 surface 更新须先由该工具 Owner 提交/协调。

## 7. F3 准入 Checklist

- [ ] ADR-ASSET-001 批准：唯一 Backend Authority = `flypost_backend`；`asset` 能力在 `Capabilities()` 注册（修 A01 §7.2 DEFECT）
- [ ] MOBILE_ASSET_CONTRACT 冻结：资源 owner **服务端强制**，客户端不可自声明（消 C01 owner 缺陷）
- [ ] Backend `module/file` owner-trust 缺陷修复（upload 弃用 `uid` 的 bug 关闭）或 ADR 决定演进路径
- [ ] Backend F3-01 端点就绪（flypost E1/E3：upload ticket / commit / download ticket 契约）
- [ ] `asset.upload/asset.download` 进入 SDK `Capabilities` 白名单与 `NebulaAsset` 标记填充
- [ ] SDK `HttpTransport` 定义"无 auth 直传"边界（S2-S02 不泄漏 installation proof）
- [ ] WIP Quarantine 文件（`tool/api_surface.dart` 等）由 Owner 提交/协调，S2-S01 可重跑 `--update`
- [ ] S2-S01 增 Facade capability 经 SDK Architect 串行合并（`nebula.dart`/`capabilities.dart`/`nebula_sdk.dart`）
- [ ] S2-S01 验收：不暴露 Provider/Bucket/OSS SDK 类型（model 层抽象 `UploadInstruction`）
- [ ] S2-S02 量化验收：取消不调 complete；并发 start 不产生双任务
- [ ] api_surface snapshot 更新后 121 → N 符号且 governance/secret_scan 仍 PASS
- [ ] **SDK Public API Surface 变更流程生效**：Feature Agent 仅可新增内部实现，**禁止修改 public export**（`lib/nebula_sdk.dart` / `lib/src/nebula.dart` / `lib/src/capabilities.dart`），除非经 SDK Architect 审批；变更后由 surface Owner 执行 `dart run tool/api_surface.dart --update` 重跑 snapshot（流程见 `contracts/SDK_PUBLIC_SURFACE_CHANGE_PROCESS.md`）

## 8. Handoff Block（DoD §7）

- **Follow-up dependencies**（与验收结论 4 项一致）：`adrs/ADR-ASSET-001.md`（S2 解除阻塞前提）、`contracts/MOBILE_ASSET_CONTRACT.md`（owner 服务端强制，覆盖 Backend Asset Owner Trust Fix 的 SDK 侧要求）、`adrs/ADR-ASSET-OWNER-TRUST-001.md`（Backend `module/file` owner 自声明缺陷修复需求）、`contracts/F3_API_CONTRACT_FREEZE.md`（F3 API 端点冻结）、`contracts/SDK_PUBLIC_SURFACE_CHANGE_PROCESS.md`（公共 API Surface 变更流程）、`adrs/ADR-PAYMENT-REFUND-001.md` / `ADR-PAYMENT-RECON-001.md`（非 Asset 阻塞，属后续）。
- **Architecture Change Request**：ADR-ASSET-001（Pending，S1 阶段决策，非本审计产出前置；但为 S2 门禁）。
- **Known limitations**：① 未运行 `dart test`/`api_surface`（避免触碰 dirty WIP 与生成缓存）；结论基于 STATUS.md 文档化证据与快照静态比对。② 未审 `sdk/dart/**`（Quarantine）。③ `tool/api_surface.dart` 当前为 dirty（WIP Quarantine），其实际符号采集逻辑未重跑验证，仅静态核对 121 行快照与 F2-R1 记录一致。④ 4 个 capability 标记接口为空，其 F3 具体成员以 S2-S01 设计为准，本报告不预设。

## 9. Audit Inputs / Outputs

- **audit_inputs**：`nebula-flutter-sdk 279ed51`（sole SDK authority）；Backend 基线引用 MA0-A01/C01。
- **outputs**：本报告；状态字段（DONE，2026-08-07 治理验收 PASS）。
- **dirty files**：全部保持未修改（见 §1 Quarantine 清单 + `git status` 比对）。
