# MA0-D01 — APK Integration Baseline Audit

- Story：`MA0-D01`｜Epic：`EPIC-GOV`｜SP：2
- Owner：APK Integration Agent (`workbuddy-apk-integration-agent`)
- 状态：**REVIEW（报告就绪，待治理验收）**
- 审计对象 APK：`flutter NFC Writer` @ `b40a0bf61e69bb484eac816682a13d4899982339`
- SDK authority：`nebula-flutter-sdk` @ `279ed5118f1162f461a9fdaa4528bca2c3ddaae2`
- 代码改动：**无**（任务包禁止修改 App；本报告为纯只读审计）
- 关联已裁决事实：`MA0-A02`（ADR-026 / ADR-027，均 frozen 2026-08-07）、`MA0-A03`（path dependency P0）、`BLOCKER-PARSE-ENGINE`（P0）、`sprint1_entry.gate`（ADR-ASSET-001）

> **说明**：本文件取代早期最小切片技术草稿 `MA0_D01_NFC_APP_INTEGRATION_AUDIT.md`（后者保留为接入技术细节底稿）。本轮审计按治理验收口径重做：聚焦「真实 App 能否正确消费 SDK」与迁移阻塞，产出 Migration Map 与 Q1–Q5。
>
> **关键进展**：早期草稿 §6 标注的「URL 解析模块边界阻塞」已被 `MA0-A02`（ADR-026 / ADR-027）裁定解决——Q1=控制面上收/执行面保留，Q2=同域 `top22.top/v1/nebula/*`，Q3=首切片仅 runtime-config 只读旁路。因此 D01 不再阻塞，但出现两条新的 P0 阻塞（见 §6 B1/B2）约束首个真实接入 Sprint。

---

## 1. App baseline

| 维度 | 现状 | 证据 |
|---|---|---|
| 入口 | `lib/main.dart` `main()` → `await AppDependencies.bootstrap()` → `unawaited(deps.syncRulesFailSoft())` → `runApp(NfcWriterApp(deps))` | `main.dart:19,26,30,79` |
| 初始化 | 唯一组合根 `AppDependencies.bootstrap()` 异步装配全图 | `lib/app/dependency.dart:81,211` |
| 网络层 | **无统一 transport 抽象**；3 处直接发起点：`package:http`×1 + `dart:io HttpClient`×2；无 Dio、无拦截器、无 base-URL 抽象（域名走 `AppConfig`） | `http_rule_remote_source.dart:14`、`parsed_cover_downloader.dart:79`、`io_share_transport.dart:22` |
| 登录状态 | `AuthService` 为**全静态类**，仅 mock：`login()` 返回硬编码 `'mock_token'`，`logout()` 空实现；**无真实会话、无 token 落盘** | `lib/app/services/auth_service.dart:22,46-71` |
| 本地存储 | sqflite `AppDatabase`（DbSchema v3，28 表）+ **7 个互相独立的 `shared_preferences` 偏好类** + `InstallIdProvider` | `app_database.dart`、`legacy_preferences.dart`、`mifare_key_preferences.dart` 等 7 类 |
| 配置管理 | `AppConfig`（全应用唯一真源，host 锁 `top22.top`，受 `🔒 HOST` 守卫）+ `RemoteRuleSync`（Ed25519 验签远端规则链，LKG、灰度、kill switch）+ 7 偏好类 | `lib/shared/config/app_config.dart:31,37`、`lib/core/rule/remote/remote_rule_sync.dart` |
| 文件上传 | **lib 内无任何 OSS/云上传实现**；仅有分享传输 `IoShareTransport`（`dart:io`，非资产上传）与 UI 脚手架 `cloud_sync_screen.dart` / `Icons.cloud_upload`；`media_repository`/`asset_repository` 均为本地 Sqflite | `io_share_transport.dart`、`lib/feature/my/cloud_sync_screen.dart`、`asset_repository.dart` |
| 用户体系 | `RegionConfig.loginProviders` 驱动 `AuthService`（mock）；业务侧用 `AppDatabase.localUserId` 作本地用户 id；**无真实用户身份持久化** | `auth_service.dart:28`、`dependency.dart:247,253` |

**重复实现（baseline 层面）**：7 个偏好类各自直连 `shared_preferences`（无统一 KV 端口）；2 个 `HttpClient` 传输 + 1 个 `package:http` 源（无统一 client）；`installId` 自管。

---

## 2. Current architecture

- **唯一组合根**：`AppDependencies`（`dependency.dart:81`），`bootstrap()`（`:211`）构造器注入全图；存在 `_instance` 单例逃生舱（`:123,126`，UI 只读，业务层走注入）。无 GetIt / Riverpod / Provider。
- **状态管理**：`StatelessWidget` + 构造器注入 + Controller（如 `HomeController`/`ReadController`），无全局容器。
- **启动链**：
  ```text
  main()
    → AppDependencies.bootstrap()        (await，天然 bootstrap 插入点)
    → unawaited(deps.syncRulesFailSoft()) (fail-soft 非阻塞，不阻塞首屏)
    → AppLifecycleListener(onResume: syncRulesFailSoft)
    → runApp(NfcWriterApp)
  ```
  红线 R2：「碰一下 100% 本地」——tag discovered → action executed 之间无网络（`main.dart:13-15`）。
- **机械守卫**（约束新代码）：`scripts/verify_governance.sh` 主链路 gate（`analyzer` 硬闸门 ERROR 0 / WARNING ≤49、`governance_lock`、`dependency_ledger`、`kernel_manifest`、`capability_scan`、`pubspec_drift` soft）；分层 `layering_guard_test`（R-LAY-1/2）；`static_arch_check_test` 11 类 AI 编码守卫 + `🔒 HOST` 域名守卫。
- **高频冲突区（接入须避开）**：`android/app/src`、`lib/feature/write`、`lib/feature/read`、`lib/core/parser`（近 14 天改动 478/132/115/36 次）。

---

## 3. SDK integration points

- **唯一允许接入目录**：`lib/platform/nebula/`（**新建**，零冲突）。ADR-027 §4 明令 Nebula adapter/transport/storage 只放此处；禁止散落注入。
- **组合根接线（最小）**：
  1. `pubspec.yaml` 加 `nebula_sdk: {path: ../nebula-flutter-sdk}`（SDK `dependencies:{}` 零依赖 ⇒ 不引入传递依赖，供应链面最小）；
  2. 新建 `lib/platform/nebula/nebula_http_transport.dart` — 实现 SDK 注入的 `NebulaTransport`（复用 `HttpRuleRemoteSource` 的 host 白名单/超时/`maxBytes=256KB` 模板）；
  3. 新建 `lib/platform/nebula/nebula_prefs_cache_storage.dart` — 用 `shared_preferences` 实现 `CacheStorage`/`SecureStorage`；
  4. 新建 `lib/app/nebula_bootstrap.dart` — 装配 `NebulaOptions` + `NebulaConfigClient`，host 取自 `AppConfig`（不硬编码）；
  5. `dependency.dart` 加 1 字段 `final NebulaConfigClient nebulaConfig;` + `bootstrap()` 内 1 处装配；
  6. `main.dart` 加 1 行 `unawaited(deps.syncNebulaConfigFailSoft())`，**完全复刻 `syncRulesFailSoft` 的 fail-soft 范式**（Nebula 初始化失败不得阻塞 NFC 读写与本地 Action）。
- **SDK 形态约束（决定接入方式）**：`NebulaTransport` / `CacheStorage` / `SecureStorage` / `ProofSigner` 全为宿主注入 Port；SDK 纯 Dart 零依赖 ⇒ App 以 **Adapter 层吸收差异**，SDK 保持平台通用（见 §8 Risk 2）。
- **V1 纳入**（ADR-027 §3.1）：Remote Config（runtime-config 只读旁路）、Analytics、Crash/Error Reporting、Bootstrap。
- **V1 明确排除**（ADR-027 §3.2）：Parser Rule、NFC Runtime、Action Execution、Asset/Notification/Payment/AI **空 marker**（禁止为假接入写假调用）。

---

## 4. Existing duplicated capabilities（App 拥有本应属 SDK 的能力）

> 验收「禁止误区」逐条核对：App 当前是否拥有 HTTP / Token / Config / Upload。

| 能力 | ❌ App 当前是否拥有 | 证据 | 应迁移至 SDK（Port/能力） |
|---|---|---|---|
| **HTTP** | **是**（3 处直连：package:http ×1 + dart:io HttpClient ×2） | `http_rule_remote_source.dart:14`、`parsed_cover_downloader.dart:79`、`io_share_transport.dart:22` | `NebulaTransport`（宿主注入 Port） |
| **Token / 会话** | **部分**——当前为 mock（`'mock_token'`，不落盘）；无真实 token 存储，但**登录逻辑在组合根外的静态类**，若自建真实鉴权必重造 token 存储 | `auth_service.dart:22,46-71` | `NebulaAuth`（移动会话/bootstrap，见 MOBILE_CAPABILITY_CONTRACT） |
| **Config** | **是**——`AppConfig` + `RemoteRuleSync`（Ed25519 签名远端配置）+ 7 偏好类 | `app_config.dart`、`remote_rule_sync.dart` | `NebulaConfigClient`（仅 runtime-config；解析链留 App，ADR-026） |
| **Upload** | **否**——lib 内无 OSS/云上传实现，仅分享传输 + UI 脚手架 | `io_share_transport.dart`、`cloud_sync_screen.dart` | `NebulaAsset`（**BLOCKED by ADR-ASSET-001**，空 marker） |
| **Installation 身份** | **是**——`InstallIdProvider` 自管匿名 `ai-<16hex>` | `install_id_provider.dart:35` | SDK installation bootstrap（未来收敛，现可并存） |

**风险 1 定性（SDK 做好但 APK 不适配）**：**潜伏风险，尚未实化**。App 已自有 HTTP/Config/Auth(mock)/InstallId；若真实能力（鉴权、配置、上报）**未经 SDK 直接自建**，即触发「SDK 成摆设」。ADR-027 §4（禁止在 NFC Writer 内 reimplement Nebula 共享能力）+ `SPRINT-FREEZE.md`（冻结 Nebula 共享能力重实现）已将此类重实现列为 forbidden，但需在接入 PR 中持续校验——App 的网络/配置调用须经 `lib/platform/nebula/` 适配层，而非新增直连点。

---

## 5. Migration mapping

| 能力 | 当前 App | 目标 SDK | 迁移 Sprint | 状态 |
|---|---|---|---|---|
| Bootstrap | `AppDependencies.bootstrap()` | `Nebula.initialize` / installation | S3 | Ready（仅 adapter） |
| Runtime Config | `AppConfig` + `RemoteRuleSync` | `nebula_config`（runtime-config 只读旁路） | S3 | Ready（ADR-027） |
| Analytics | 无 | `nebula_analytics` | S3–S4 | Ready（空实现可接受） |
| Crash / Error | 无 | `nebula_crash` | S3–S4 | Ready |
| HTTP / Transport | App 直连 http | `nebula_http`（Transport Port） | S4 | 待 A03 path-dep 解除 |
| Login / Session | `AuthService` mock | `nebula_auth` | S5 | 待 SDK F-auth 冻结 |
| Config（解析链） | `RemoteRuleSync` | 控制面上收（Nebula） | S6+ | ADR-026 (b) 拆分 |
| Upload | 无 | `nebula_upload` | **BLOCKED（ADR-ASSET-001）** | 冻结 |
| Notification | `LocalNotificationService`（App） | `nebula_notification` | **BLOCKED（空 marker）** | 冻结 |
| Payment | 无 | `nebula_payment` | **BLOCKED（空 marker）** | 冻结 |
| AI | 无 | `nebula_ai` | **BLOCKED（空 marker）** | 冻结 |

---

## 6. Blocking issues

- **B1 — `BLOCKER-PARSE-ENGINE`（P0，已登记）**：Content Parse Engine V1 多处 P0/P1 缺陷须先收口，否则阻塞 S3 Nebula 接入（D04 allowed paths 已冻结 forbidden 域）。来源：`task_board.json` blockers。
- **B2 — `MA0-A03` path dependency（P0，REVIEW 中）**：引入 SDK `path:` 依赖可能触发 CI `flutter pub get` / `osv-scanner.toml` / `dependabot` 台账失败；首个真实接入 Sprint **S3-D01 依赖 A03 结论**。来源：`MA0_A03_DEPENDENCY_IMPACT_REVIEW.md`。
- **B3 — `ADR-ASSET-001` 未完成**：Upload / Asset SDK 在 `sprint1_entry.gate` 下**禁止**；SDK `NebulaAsset` 为空 marker。对应 D01-05。
- **B4 —（已解决）解析/配置边界**：早期草稿 §6 三问已由 `MA0-A02`（ADR-026/027）裁定——Q1=控制面/执行面拆分、Q2=同域 `top22.top/v1/nebula/*`、Q3=首切片仅 runtime-config。不再阻塞。
- **B5 — App 无环境变体隔离**：`applicationId = "com.shawn.nfcwriter"`（`build.gradle.kts:31,10`），**无 productFlavors、无 flavor 源集、仅 `release` buildType**。Dev/Staging/Prod 区分不能靠 APK 变体，须走 runtime-config / `buildConfigField`。影响 SDK `baseUri` 环境切换设计。

---

## 7. Recommended Sprint allocation

- **首个真实接入 Sprint = S3**，顺序：`S3-D01`（path 依赖 + 治理守卫全绿，依赖 A03）→ `S3-D02`（Port adapter，仅落 `lib/platform/nebula/`）→ `S3-D03`（组合根接线）→ `S3-D04`（runtime-config 消费，fail-soft）。
- **前置关闭**：B1（Parse Engine 收口）+ B2（A03 path-dep）。未关闭前 `nebula_sdk_state = WAIT`。
- **禁止在 D01/S3 范围内启动**（SPRINT-FREEZE + ADR-027 §3.2）：Asset/Notification/Payment/AI（空 marker）、Dynamic Note 扩张、云同步业务、Network Layer 大重构（禁 `NetworkManager`/`ApiService`）。

---

## 8. Acceptance result

### 验收重点逐项

- **D01-01 App Identity** ✅：`applicationId`/`namespace` = `com.shawn.nfcwriter`（`build.gradle.kts:31,10`）；无 flavor、无变体环境隔离 ⇒ 环境必须 runtime-config 化（见 B5）。
- **D01-02 Bootstrap** ✅：启动链存在干净插入点——`runApp` 前 `await bootstrap()` + 1 行非阻塞 `syncNebulaConfigFailSoft()`，不破坏 R2 本地红线。
- **D01-03 Storage 边界** ✅ 可定义：SDK 拥有 `token / installation / config cache`；App 拥有 `draft / business data / UI state`。当前 App 用 `shared_preferences`（7 类）+ sqflite；接入须新建 `lib/platform/nebula/` 适配层，**禁止混入既有偏好/数据库表**（受 `parse_rule_store.dart:16` 红线与 STORAGE 守卫约束）。
- **D01-04 API 调用入口** ✅（前向约束）：当前 App **无**任何 Nebula API 调用（SDK 未集成），故无绕过。风险为前向——接入后 App **不得**直连 Nebula API，须经 SDK（见 Risk 2）。
- **D01-05 Upload 迁移风险** ✅ 正确标注：`BLOCKED BY ADR-ASSET-001`；SDK `NebulaAsset` 为空 marker，本 Sprint 不设计 Upload。

### Q1 — Nebula SDK 接入 APK 的唯一入口在哪里？
**`lib/app/dependency.dart` 的 `AppDependencies.bootstrap()` 是唯一组合根**；`main.dart` 中 `runApp` 前的 `await` 是 bootstrap 插入点；所有 Nebula 接线（Transport/Storage/ProofSigner Port + `NebulaConfigClient`）**只经 `lib/platform/nebula/` 适配层注入此处**。除该组合根外**不存在**合法入口（静态 `AuthService` 模式是被纠正对象，不是入口）。

### Q2 — 哪些能力必须迁移到 SDK？
- 强制迁移（平台通用能力）：**HTTP/Transport → `NebulaTransport`**；**runtime-config → `NebulaConfigClient`**；**Installation 身份 → SDK bootstrap**；（后续）**Auth/Session → `NebulaAuth`**；**Analytics / Crash → Nebula**。
- **必须留在 App（不可迁移）**：Parser Rule、NFC Runtime、Action Execution（ADR-026 产品安全域）；解析规则链（Ed25519 验签/执行/离线，ADR-027 §3.2）。

### Q3 — 哪些能力当前不能迁移（平台契约未冻结）？
- **Upload / Asset**（ADR-ASSET-001 未完成 + `NebulaAsset` 空 marker）；
- **Notification / Payment / AI**（SDK 仅空 marker，F3/F4 才冻结）；
- **Auth 真实实现**（需 SDK F-auth 冻结 + 收编静态 `AuthService`）；
- **解析规则链**（ADR-026 裁定属 App 执行面，控制面才上收）。

### Q4 — 接入 SDK 后，APK 应减少哪些代码？
- 减少**散落直连 HTTP**：既有 3 处发起点中，平台语义调用改经 `NebulaTransport` adapter；仅 App 专属（分享/封面下载，若仍保留）维持，但不得新增直连点。
- 减少**重复 `shared_preferences` 偏好类**：收敛为 SDK 提供的 `CacheStorage` adapter + App 自有配置，杜绝 7 类各自直连。
- 减少**mock `AuthService` 重实现**：真实鉴权走 `NebulaAuth`，不另造 token 存储。
- 减少**自管 `installId`**：向 SDK installation bootstrap 收敛。
- **注意（Risk 2 纪律）**：仅「加 adapter / 加字段」，**禁止**借机 `NetworkManager`/`ApiService` 大重构（ADR-027 §4）。

### Q5 — 第一个真实接入 Sprint 选哪个 Feature？
**S3（首切片 = runtime-config 只读旁路）**，自 `S3-D01`（path 依赖 + 守卫全绿）起，**不是**业务 Feature。严禁以动态便签 / NFC 卡业务 / 云同步等业务 Feature 作为首个接入（属越界，见 Risk 3）。

### 三项风险核对

- **风险 1（SDK 做好但 APK 不适配）**：**潜伏未实化**。App 已自有 HTTP/Config/Auth(mock)/InstallId；缓解＝ADR-027 §4 + SPRINT-FREEZE 将「Nebula 共享能力重实现」列为 forbidden，且唯一接入目录 `lib/platform/nebula/` 强制适配层。需在 S3 各 PR 持续校验无新增直连点。
- **风险 2（为迁就 App 修改 SDK）**：**禁止，已架构化规避**。SDK 为纯 Dart 零依赖，Transport/Storage/ProofSigner 全为宿主注入 Port；差异由 **App Adapter 层吸收**，SDK 保持平台通用。接入任务不得改 SDK 公共面迁就 App。
- **风险 3（提前做业务 Feature）**：**已冻结越界**。Dynamic Note 扩张 / NFC 卡业务 / 云同步属 SPRINT-FREEZE 冻结项与 ADR-027 §3.2 排除项；若出现在接入 PR 中，验收应退回。

### 验收结论
报告就绪，判定 **REVIEW（建议 PASS，待治理验收）**。D01 早期阻塞（解析/配置边界）已由 MA0-A02 解决；残留两条 P0 阻塞（B1 Parse Engine、B2 A03 path-dep）仅约束**首个真实接入 Sprint 的启动时机**，不否定「APK 已具备接入路径」的结论。无代码改动，纯只读审计。
