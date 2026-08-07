> **⚠️ SUPERSEDED** — 本文件为早期「最小切片技术草稿」。治理验收口径的权威报告已重写为 **`MA0_D01_APP_INTEGRATION_AUDIT.md`**（消费者侧审计 + Migration Map + Q1–Q5 + 三项风险核对）。早期 §6 标注的「URL 解析模块边界阻塞」已由 `MA0-A02`（ADR-026/027）裁定解决。本文件保留为接入技术细节底稿，不再作为 D01 验收交付物。

# MA0-D01 — Flutter NFC Writer 接入点审计（早期最小切片草稿，已 SUPERSEDED）

- Story：`MA0-D01`｜Epic：`EPIC-GOV`｜SP：2
- Owner：APK Integration Agent (`workbuddy-apk-integration-agent`)
- 状态：**IN_PROGRESS — 部分阻塞**（§6 URL 解析模块边界待 owner 补充说明）
- Base commits：
  - `nebula-flutter-sdk` @ `279ed5118f1162f461a9fdaa4528bca2c3ddaae2`
  - `flutter NFC Writer` @ `b40a0bf61e69bb484eac816682a13d4899982339`（工作树干净）
- 代码改动：**无**（任务包禁止修改 App；本报告为纯只读审计）

---

## 0. 结论摘要

| 结论 | 判定 |
|---|---|
| 接入可行性 | ✅ 可行，且冲突面小于预期 |
| 关键有利条件 | Nebula SDK `dependencies: {}` 纯 Dart + 全 Port 注入，**不引入任何传递依赖** |
| 唯一 composition root | ✅ 存在且唯一：`AppDependencies`（`lib/app/dependency.dart:81`） |
| 最小切片建议 | **只接 runtime-config 只读旁路**，不动登录、不动网络层、不动 NFC 主链路 |
| 最大风险 | 依赖台账/清单类守卫 + `lib/feature/write`、`lib/feature/read` 高频改动区 |
| 阻塞项 | URL 解析模块（Content Parse Engine / RemoteRuleSync）与 Nebula runtime-config 的职责边界 |

---

## 1. Nebula SDK 侧前置事实（决定接入形态）

| 事实 | 证据 |
|---|---|
| **零运行时依赖**（`dependencies: {}`），纯 Dart 包 | `nebula-flutter-sdk/pubspec.yaml:9` |
| Dart SDK 约束 `>=3.3.0 <4.0.0` | 同上 `:7` |
| Transport 是**抽象接口**，宿主必须注入实现 | `lib/src/transport.dart` — `abstract interface class NebulaTransport` |
| 存储是 Port（`CacheStorage` / `SecureStorage`） | `lib/src/storage/cache_storage.dart`、`secure_storage.dart` |
| 已有 NFC Writer 专属接入样例 | `example/nfc_writer_first_launch.dart:56-137` |
| `NebulaAsset` / `NebulaNotification` / `NebulaPayment` / `NebulaAi` 目前**只是 marker 接口**，无实现（F3/F4 才冻结） | `lib/src/capabilities.dart:48-58` |

> **推论 1**：SDK 零依赖 ⇒ 加入 path dependency **不会引入任何新的传递依赖**，`osv-scanner` / dependabot 面几乎不变，供应链守卫压力最小。
> **推论 2**：`NebulaAsset` 仍是空 marker ⇒ 任务包 Tasks §2 中的「**附件上传**」接入点，本 Sprint **没有可接的 SDK 能力**，只能定位候选宿主点，不能落地。

---

## 2. A · 工程与构建现状

**A1 · pubspec** — `flutter NFC Writer/pubspec.yaml`
- 包名 `nfcwriter`，version `2.0.0+1`（`:1,4`）
- 约束：Dart `>=3.4.0 <4.0.0`、Flutter `>=3.22.0`（`:7-8`）→ **与 SDK 的 `>=3.3.0` 兼容**
- 网络：`http: ^1.2.0`（`:14`）——**无 dio**
- 存储：`sqflite: ^2.3.0`（`:15`）、`shared_preferences: ^2.3.0`（`:31`）、`path_provider`（`:16`）
- 加密：`crypto: ^3.0.7`（`:18`）、`cryptography: ^2.9.0`（`:37`）
- **现有 path dependency：不存在**。`:17` 的 `path: ^1.9.0` 是 pub.dev 上的 `path` 包，非本地路径。（搜索关键词：`path:`）

**A2 · Android 构建** — `android/app/build.gradle.kts`
- `applicationId = "com.shawn.nfcwriter"`（`:35`）、`namespace` 同值（`:10`）
- `minSdk/targetSdk/compileSdk` 全部继承 `flutter.*`（`:12,36-38`）——未硬编码
- **`isCoreLibraryDesugaringEnabled = true`**（`:18`），desugar 依赖 `:70`
- `buildConfig = true` 显式开启（`:29`）
- **`productFlavors`：不存在**（搜索 `productFlavors`、`flavorDimensions` 零命中）
- `buildTypes` 仅 `release`（`:46-62`）：`signingConfig = debug`（`:49`，TODO 未配正式签名）、`isMinifyEnabled = true`、`isShrinkResources = false`
- 原生依赖：`emvnfccard:3.1.0`、`protobuf-javalite`、`media3`、`camerax`（`:73-90`）

**A3 · flavor 源集** — **不存在**（`android/app/src/` 下无 `staging` 等 flavor 目录）

**A4 · 嵌套旧 Android 工程 `NFCWriter/`** — **独立 gradle 工程，与 Flutter 根项目无构建关系**
- 自带 `build.gradle`、`gradle/`、`gradle.properties`、`app/`、`core/`、`eventbus/`、`codeScanner/`
- `android/settings.gradle*` **未引用** `NFCWriter`（grep 零命中）
- 判定：它是**历史参考源**（原生代码已整迁至 `android/app/src`），**不参与 APK 产出，接入工作完全不应触碰**（任务包 Forbidden 已明列）

---

## 3. B · 启动入口与组合根

**B1 · `lib/main.dart`（33 行 main）**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppDependencies deps = await AppDependencies.bootstrap();   // ← 唯一 async 装配点
  unawaited(deps.syncRulesFailSoft());                              // ← 冷启动远端规则同步（非阻塞）
  AppLifecycleListener(onResume: () => unawaited(deps.syncRulesFailSoft()));
  runApp(NfcWriterApp(deps: deps));
}
```
- **存在 `runApp` 前的 `await`**（`main.dart:19`）→ Nebula bootstrap 有天然插入点
- 注释明确红线：**「Tap path is 100% local (V1.1 红线 R2)：tag discovered → action executed 之间无网络」**（`main.dart:13-15`）
- 现有远端同步用 `unawaited(...)` 非阻塞 + fail-soft 模式（`main.dart:26,30`）——**这就是 Nebula runtime-config 应当复刻的接入范式**

**B2 · `lib/app/dependency.dart` — 是组合根，且是唯一的**
- `class AppDependencies`（`:81`），`static Future<AppDependencies> bootstrap()`（`:211`）
- 通过**构造器注入**传递：`runApp(NfcWriterApp(deps: deps))` → `AppShell(deps: deps)`（`main.dart:32,70`）
- 装配分类（`:128-206`）：resolver/action runtime、NFC、permission、notification、**timer**、parser（`ParserEngine` `:149`、`ContentParseEngine` `:152`、`ContentParseAdapter` `:155`）、**`RemoteRuleSync` `:160`**、7 个 repository（`:181-186`）、delivery/publish/write、`ContentParseCoordinator` `:203`、`ShareService` `:206`

**B3 · 是否唯一 composition root** — ✅ 唯一，但有一个例外需注意
- `static AppDependencies? _instance` / `get instance`（`:123,126`）——存在**全局单例逃生舱**，但主路径是构造器注入
- 未使用 `GetIt`、无顶层 `Provider` 容器
- ⚠️ `AuthService` 是**独立静态类**（见 C1），不在组合根内 → 接入 Nebula 登录时需先把它收编，成本高于其它接入点

**B4 · 状态管理** — `StatelessWidget` + 构造器注入 + Controller（`HomeController` `:139`、`ReadController` `:140`）。无 Riverpod / Bloc / Provider。

---

## 4. C · 四类候选接入点

### C1 · 登录 / 会话 —— **纯 mock，且在组合根之外**
`lib/app/services/auth_service.dart`（72 行，唯一 auth 文件）
- `class AuthService { AuthService._(); ... }` — **全静态类**，未进 `AppDependencies`（`:22-23`）
- `static Future<AuthResult> login(...)`：`// TODO: 接入真实 SDK`，`Future.delayed(500ms)` 后返回硬编码 `token: 'mock_token'`（`:45-66`）
- `static Future<void> logout()`：**空实现**（`:69-71`）
- **token 不落盘**：全文无 shared_preferences / sqflite 引用 → 无 token 存储需要迁移
- 登录方式由 `RegionConfig.loginProviders` 驱动（`:1,27`）

> **评估**：mock 无历史包袱是优势，但 `AuthService` 是静态类、不在组合根 ⇒ 接 `NebulaAuth` 需要**改调用方 + 收编进 `AppDependencies`**，改动面外溢到 UI 层。**建议不放进最小切片**。

### C2 · 本地存储 —— 抽象分散，无统一 KV 端口
| 用途 | 文件 | 形态 |
|---|---|---|
| 遗留读写偏好 | `lib/app/legacy_preferences.dart:15` | 静态类，`_loadBool/_saveBool` 包 shared_preferences（`:56,66-72`） |
| Mifare 密钥 | `lib/app/mifare_key_preferences.dart` | 同模式 |
| 其余 5 个偏好 | `lib/app/{music_onboard,only_read_id,read_action_behavior,read_mode,read_sound}_preference.dart` | 同模式，**各自独立** |
| 结构化存储 | `lib/data/local/app_database.dart` | sqflite 唯一接线点（`DbSchema.version=3`，28 表） |

- **统一 KV 抽象端口：不存在**（7 个 preference 类各写各的）
- ⇒ Nebula `CacheStorage` / `SecureStorage` 需要**新写 adapter**，但可放在新目录、零冲突

### C3 · 网络层 —— 无统一 transport 抽象，仅 3 处发起点
grep `package:http/http` + `HttpClient(`，全 `lib/` 命中 **3 个文件**：

| 文件 | 用途 |
|---|---|
| `lib/data/rules/remote/http_rule_remote_source.dart` | 解析规则包下载（见 §6） |
| `lib/data/remote/parsed_cover_downloader.dart` | 解析封面图下载 |
| `lib/data/remote/io_share_transport.dart` | 分享上传（`dart:io`） |

- **无统一 client / 无拦截器 / 无 base URL 抽象**；域名走 `AppConfig`
- `HttpRuleRemoteSource` 已实现的安全约束（`:21-49`）可作为 Nebula transport adapter 的**现成模板**：强制 `https` + host 白名单、ETag、连接超时、`maxBytes = 256KB` 响应上限
- ⇒ Nebula `NebulaTransport` 实现应新建 adapter 文件，**不改这 3 个既有文件**

### C4 · 附件 / 资产上传 —— **SDK 侧无能力，本 Sprint 不可落地**
- App 侧候选宿主：`lib/data/remote/io_share_transport.dart`（现有上传通路）、`lib/application/experience/create_cloud_snapshot.dart`、`lib/data/repository/media_repository.dart`
- SDK 侧 `NebulaAsset` 是空 marker（`lib/src/capabilities.dart:50`）
- ⇒ **仅登记候选点，不进最小切片**（依赖 SDK F3）

### C5 · 远端配置 —— **App 已有一套完整机制，与 Nebula runtime-config 职责重叠**
- 配置 SSOT：`lib/shared/config/app_config.dart:19` — `AppConfig`，铁律「域名/路径/端点只能写这里，禁止硬编码 host」；唯一域名 `top22.top`（`:37`），受 `static_arch_check_test.dart` 的 `🔒 HOST` 守卫拦截
- 远端下发：`RemoteRuleSync`（`lib/core/rule/remote/remote_rule_sync.dart:27`）——**详见 §6，为本报告阻塞点**

---

## 5. D · 冲突风险

**D1 · 工作树** — `flutter NFC Writer` 干净（`git status --short` 空），HEAD = `b40a0bf`

**D2 · 近 14 天高频改动区（前 8）**
| 改动次数 | 目录 |
|---:|---|
| 478 | `android/app/src` |
| 132 | `lib/feature/write` |
| 115 | `lib/feature/read` |
| 107 | `ui/ui_design/v2` |
| 89 | `lib/_archive/features` |
| 51 | `test/fixtures/content_parser` |
| 50 | `lib/feature/my` / `lib/app/widgets` |
| 36 | `lib/core/parser` |

> ⇒ 接入代码**必须避开** `lib/feature/write`、`lib/feature/read`、`lib/core/parser`、`android/app/src`。新建独立目录是唯一低冲突路径。

**D3 · 机械守卫（会限制新代码）**

`scripts/verify_governance.sh` 主链路 gate（`:67-129`）：

| Gate | 脚本 | 对接入的影响 |
|---|---|---|
| analyzer | `check_analyzer.py` | **硬闸门**：ERROR 0 / WARNING ≤49 / INFO ≤318，只减不增。新代码一条 unused import 就红 |
| governance_lock | `check_governance_lock.py` | 改受保护文件**必须伴随 ADR**（PR-GOV-06） |
| **dependency_ledger** | `check_dependency_ledger.py` | 供应链台账：校验 `osv-scanner.toml` / `dependabot.yml` / `dependency-scan.yml` 接线在位，豁免条目 ≤5 且带原因+到期日 |
| kernel_manifest | `check_kernel_manifest.py` | 包边界 + sha256 清单。**改任何 `tools/rule_guard/*.py` 后必须 `--update`** |
| remote_no_secret | `check_remote_no_secret.py` | git remote 禁明文令牌 |
| nfc_bridge_contract | `check_nfc_bridge_contract.py` | NfcBridge 跨端契约冻结 |
| capability_scan | `scripts/guard/scan_capability_violations.sh` | 能力复用扫描 |
| **pubspec_drift** | `check_pubspec_drift.py` | **soft gate**（`run_soft_gate`，report-only 不阻断）；跑 `flutter pub outdated`，无网络时跳过 |
| profile_tests | `flutter test` | 全量 4788 条 |

分层守卫 `test/arch/layering_guard_test.dart`：
- R-LAY-1：`lib/feature/` 只能经 `lib/nfc/` + `lib/core/capability/` 触达 NFC（`:10`）
- R-LAY-2：`lib/nfc/` 禁 import `lib/platform/`（`:11,117`）
- `lib/platform/ios` 与 `harmony` 禁 import Android 实现（`:175`）
- 未发现**禁止 `lib/` 引入外部 package** 的规则，也未发现禁止新建顶层目录的规则

`test/slice001/static_arch_check_test.dart`：11 类 AI 编码守卫（禁裸 Color / 禁裸中文 / 禁平台分支 / RAWPIXEL / RAWTOAST / PROMPTCARD / PROMPTTEXT / OVERLAYMATERIAL / RESPONSIVE / GOLDEN 分级）+ `🔒 HOST` 域名守卫

> **接入的三条硬约束**
> 1. 新增 path dependency → 触发 `dependency_ledger`（接线校验，非版本校验）+ `pubspec_drift`（soft）。因 SDK 零依赖，**预期均可通过**，但需确认 `osv-scanner.toml` 对 path dependency 的处理。
> 2. 任何用户可见中文 → 必须走 `AppStrings`（`lib/app/strings.dart`），否则守卫①红。
> 3. analyzer 基线只减不增 → 接入 PR 必须自带 `check_analyzer.py` 本地验证。

---

## 6. ⏸ URL 解析模块边界 —— **阻塞，待 owner 补充说明**

### 6.1 现状事实

App **已自建一套完整的「签名远端配置下发」链路**，与 Nebula `NebulaConfigClient` 职责高度重叠：

| 维度 | App 现有 `RemoteRuleSync` | Nebula `NebulaConfigClient` |
|---|---|---|
| 入口 | `lib/core/rule/remote/remote_rule_sync.dart:27`，组合根 `dependency.dart:160` | `lib/src/config/config_client.dart` |
| 调度 | `main.dart:26,30` 冷启动 + `onResume`，`syncRulesFailSoft()` fail-soft（`dependency.dart:171-177`） | 宿主自行调度 |
| 端点 | `https://top22.top/v1/parse-rules/manifest`、`/packages/{id}/{version}`（`http_rule_remote_source.dart:37-40`） | `config_endpoints.dart` |
| 传输安全 | 强制 https + host 白名单，越界抛 `ArgumentError`（`:44-49`）；ETag / If-None-Match；`maxBytes=256KB` | ProofSigner + installationToken |
| 节流 | 24h（`remote_rule_sync.dart:9,73-78`） | `cache_policy.ttl_seconds` |
| 离线 | LKG baseline 保留（`:8`） | `stale_if_error_seconds` + `CacheStorage` |
| 完整性 | **Ed25519 验签**（`ed25519_rule_verifier.dart` + `bundled_rule_keys.dart`）+ schema 校验 | 无等价的包签名链 |
| 灰度 | `PercentageRuleRolloutDecider`（FNV-1a，installId 种子） | `features[].enabled` 布尔开关 |
| Kill switch | `manifest.updatesEnabled=false` 立即停更、不下包（`:102-110`） | 无等价物 |
| 红线 | ADR-024：**禁云端任意代码**、禁页面解析 | — |

### 6.2 为什么必须停下来问

两者不是简单的「新旧替换」关系，存在三处不可自动裁定的冲突：

1. **信任模型不同** — 解析规则包是**可执行语义的 DSL**，App 用 Ed25519 签名 + schema 校验把它约束成「非任意代码」（ADR-024 红线）。Nebula runtime-config 目前是 **ProofSigner 认证的普通 JSON**，没有包级签名链。若把解析规则搬到 Nebula 下发，**等于降级了 ADR-024 的安全等级**。
2. **域名唯一真源冲突** — `AppConfig.universalLinkHost = 'top22.top'` 是被 `🔒 HOST` 守卫锁死的铁律，且**会印到物理卡片上、永不可变**。Nebula 用 `NebulaOptions.baseUri`（样例为 `api.example.com`）。App 内出现第二个 host 会撞守卫。
3. **红线 R2「碰一下 100% 本地」** — 任何 Nebula 网络调用都**绝不能进入 tap path**。

### 6.3 需要你补充说明的三个问题

**Q1｜职责边界怎么切？**
- (a) **完全隔离**：解析规则继续走 `top22.top` + Ed25519 自有链路；Nebula runtime-config 只管 App 级 feature flag / 版本策略，两套并存 —— 改动最小、安全等级不降，但 App 里存在两套远端配置机制
- (b) **控制面上收**：Nebula 下发「规则包 manifest 指针 + 灰度百分比 + kill switch」，包体下载与 Ed25519 验签仍留在 App —— 统一控制面，签名链不降级，但需要把 `RemoteRuleSync` 的调度决策外置
- (c) **完全迁移**：解析规则整体变成 Nebula 配置/资产 —— 与 ADR-024 冲突，需新增 ADR 并给 Nebula 补包签名能力

**Q2｜`top22.top` 与 Nebula `baseUri` 的关系？** 同域（Nebula 端点挂 `top22.top/v1/nebula/*`）还是双域（需要放宽 `🔒 HOST` 守卫 + ADR）？

**Q3｜本次最小切片是否应完全绕开解析模块？** 我倾向 **是**（见 §7 方案 A）——先只做「零业务影响的 runtime-config 旁路」验证接入可行性，把解析模块的归并放到后续 Story。

> 上述三问未获答复前，§7 的最小切片方案按「**绕开解析模块**」给出；`S3-D01..D04` 的 allowed paths 建议中，涉及 `lib/core/rule/**`、`lib/data/rules/**` 的部分**暂缓冻结**。

---

## 7. 最小接入切片建议（不迁移业务）

### 方案 A（推荐）：runtime-config 只读旁路

**原则**：不改任何既有文件的行为，只做 4 件事——加依赖、写 3 个 adapter、组合根多装 1 个字段、`main()` 多 1 行非阻塞调用。

| 步骤 | 落点 | 改动性质 |
|---|---|---|
| 1 | `pubspec.yaml` 加 `nebula_sdk: {path: ../nebula-flutter-sdk}` | 新增 3 行 |
| 2 | **新建** `lib/platform/nebula/nebula_http_transport.dart` — 实现 `NebulaTransport`，复用 `HttpRuleRemoteSource` 的 host 白名单/超时/maxBytes 模板 | 新文件 |
| 3 | **新建** `lib/platform/nebula/nebula_prefs_cache_storage.dart` — 用 shared_preferences 实现 `CacheStorage` | 新文件 |
| 4 | **新建** `lib/app/nebula_bootstrap.dart` — 装配 `NebulaOptions` + `NebulaConfigClient`，host 取自 `AppConfig`（不硬编码） | 新文件 |
| 5 | `lib/app/dependency.dart` — 加 1 个 `final NebulaConfigClient nebulaConfig;` 字段 + `bootstrap()` 内 1 处装配 | 改 2 处 |
| 6 | `lib/main.dart` — 加 1 行 `unawaited(deps.syncNebulaConfigFailSoft())`，**完全复刻现有 `syncRulesFailSoft` 的 fail-soft 范式** | 加 1 行 |

**为什么这是最小的**
- ✅ 不碰 `lib/feature/**`（全部高频冲突区）
- ✅ 不碰 `lib/core/**`（ARCH-001/002 冻结为纯业务/协议层）
- ✅ 不碰 `AuthService`（避开静态类收编的外溢改动）
- ✅ 不碰 NFC tap path（红线 R2 不受影响）
- ✅ SDK 零依赖 ⇒ 供应链面不变
- ✅ 首屏不阻塞（`unawaited` + fail-soft，与现有规则同步同构）

**不做**：登录（C1，需先收编静态类）、资产上传（C4，SDK 无能力）、解析规则归并（§6 阻塞）

### 方案 B（备选）：仅 bootstrap 不落地网络
只装配 `NebulaOptions` + `FakeTransport`，验证依赖引入与守卫全绿，**零网络**。若 Q2 域名问题未定，可用此方案先解耦「依赖引入」与「端点确定」两个风险。

---

## 8. 构建验证

**E1 · CI 现状：三个 workflow 均不构建 APK**
- `.github/workflows/`：`capability-guard.yml`（push dev 主路径）、`governance.yml`（PR/main）、`dependency-scan.yml`
- `capability-guard.yml` 步骤：Checkout → Setup Flutter → `flutter pub get`（`:31`）→ `bash scripts/verify_governance.sh push`（`:41`）→ 上传报告 → Secret scan
- grep `flutter build` / `apk` 在 workflows 中**零命中**（唯一 `apk` 相关命中是 `:50` 的 artifact 路径 `build/governance-reports/`）

**已验证的构建命令（来自项目文档，非 CI）**
```bash
flutter build apk --debug
```
证据：`docs/nfc_p1_incremental_prd.md:90`、`docs/s3_publish_prd.md:281`、`docs/s3_publish_design.md:87`、`docs/nfc_integration_assessment.md:581`（T1.19 验收项 `docs/nfc_integration_assessment.md:1212`）

**预期 APK 产物路径**（Flutter 标准输出，项目未自定义 `outputs`）
```
build/app/outputs/flutter-apk/app-debug.apk
```

**Kotlin 侧单测**：`./gradlew :app:testDebugUnitTest`（`docs/nfc_p1_incremental_prd.md:90`）

**接入 PR 的完整验收命令序列**
```bash
flutter pub get
python3 tools/rule_guard/check_analyzer.py     # ERROR 0 / WARNING ≤49 / INFO ≤318
bash scripts/verify_governance.sh push          # 全 gate
flutter build apk --debug                       # 编译验证
```
> ⚠️ 环境限制：项目**无真机无模拟器**（`docs/nfc_integration_assessment.md:144`），接入验收只能覆盖「编译通过 + headless 测试」，真实网络联调需另行安排。

---

## 9. S3-D01..D04 allowed paths 建议

| Story | 范围 | 建议 allowed paths |
|---|---|---|
| **S3-D01** 依赖引入与骨架 | path dependency + 守卫全绿 | `pubspec.yaml`、`pubspec.lock`、`osv-scanner.toml`（如台账需登记） |
| **S3-D02** Port adapter | transport / storage 适配 | `lib/platform/nebula/**`（新目录）、`test/platform/nebula/**` |
| **S3-D03** 组合根接线 | bootstrap + 装配 | `lib/app/nebula_bootstrap.dart`（新）、`lib/app/dependency.dart`（**仅允许新增字段与装配，禁止改既有装配顺序**）、`lib/main.dart`（**仅允许新增 1 行非阻塞调用**） |
| **S3-D04** runtime-config 消费 | feature flag 读取 | 待 §6 Q1 定案后冻结。**当前暂缓** |

**全局 forbidden（建议写入各 Story）**
- `flutter NFC Writer/NFCWriter/**`（独立旧工程）
- `lib/feature/write/**`、`lib/feature/read/**`、`android/app/src/**`（高频冲突区）
- `lib/core/rule/**`、`lib/data/rules/**`、`lib/core/parser/**`（§6 阻塞未解前禁改）
- `docs/governance/ANALYZER_BASELINE.yaml`（放宽基线属放松治理红线）

---

## 10. 验收自检

| Acceptance | 状态 | 依据 |
|---|---|---|
| 明确 Flutter 根项目与旧 Android 子工程边界 | ✅ | §2 A4：`NFCWriter/` 为独立 gradle 工程，`android/settings.gradle` 未引用 |
| 给出最小接入切片，不迁移所有业务 | ✅ | §7 方案 A（6 步，仅 3 个新文件 + 3 行既有文件改动） |
| 给出构建命令和预期 APK 输出位置 | ✅ | §8：`flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk` |
| 所有接入点均有文件路径 | ✅ | §4 C1–C5 全部带路径与行号 |
| 不产生代码修改 | ✅ | 本 Story 仅写本报告 + 更新看板状态字段 |

## 11. Known limitations / Open decisions

1. **§6 三问未决** — URL 解析模块与 Nebula runtime-config 的边界，阻塞 S3-D04 的 allowed paths 冻结
2. **资产上传无法落地** — `NebulaAsset` 仍是空 marker（SDK F3 前置），本 Sprint 只登记候选宿主点
3. **登录接入未评估细节** — `AuthService` 为组合根外的静态类，收编成本需单独 Story 评估
4. **未实际执行构建** — 任务包 Forbidden + 构建耗时，`flutter build apk --debug` 的证据来自项目文档而非本次执行
5. **`osv-scanner.toml` 对 path dependency 的处理未验证** — 需在 S3-D01 实际引入时确认
6. **`nebula-flutter-sdk` 工作树有 17 个未提交修改**（`lib/src/**`、`test/**`、`tool/**`），归属 Contract/SDK Architect Agent，本 Story 未触碰
