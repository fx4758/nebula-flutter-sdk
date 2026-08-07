# MA0-A03：依赖影响评审（Dependency Impact Review）

- Story：MA0-A03
- Owner：APK Integration Agent（`workbuddy-apk-integration-agent`）
- 日期：2026-08-07
- 上游裁定：`ADR-026`（Rule Execution Boundary）、`ADR-027`（Nebula Basic Capability Scope）、MA0-D01 §6.3 三问已裁定
- 关联：`MA0_D01_NFC_APP_INTEGRATION_AUDIT.md`、`ADR-026`、`ADR-027`

## 1. 评审范围与目标

本评审回答一个问题：**把 `nebula_flutter_sdk` 引入 Flutter NFC Writer 时，依赖图与 CI/治理闸门会受到什么影响，是否存在阻塞级风险。**

评审不涉及具体接入代码（属于 S3-D0x 实现 Story），只对「依赖引入方式」做影响判定与约束登记。

## 2. 事实证据（源码取证）

### 2.1 SDK 包当前可发布性

| 项 | 取值 | 证据 |
|---|---|---|
| 包名 | `nebula_sdk` | `nebula-flutter-sdk/pubspec.yaml:1` |
| `publish_to` | `none` | `nebula-flutter-sdk/pubspec.yaml:4` |
| `version` | `0.1.0-dev.1` | `nebula-flutter-sdk/pubspec.yaml:3` |
| git remote | **空**（无 origin / 任何 remote） | `git -C nebula-flutter-sdk remote -v` 输出空 |
| `dependencies` | `{}` | `nebula-flutter-sdk/pubspec.yaml:9` |

结论：SDK 当前**不可经 pub.dev 或私有 registry 解析**，且**无可达 git 源**。

### 2.2 App 仓 CI 对 `flutter pub get` 的依赖

两条主链路都强制 `flutter pub get`：

| 文件 | 行 | 步骤 |
|---|---|---|
| `.github/workflows/governance.yml` | 21 | `run: flutter pub get` |
| `.github/workflows/capability-guard.yml` | 31 | `run: flutter pub get` |

GitHub Actions `actions/checkout` 默认只拉**本仓库**（NFC Writer）。
Nebula 接入若采用 `path:` 依赖，`flutter pub get` 会解析到 `../nebula-flutter-sdk` 兄弟目录——
而 CI runner 上该目录**不存在**（未 checkout、无 git remote 可拉、且 `publish_to: none` 不可经 registry 回退）→ `pub get` 失败 → **两条主链路全部变红**。

### 2.3 既有依赖治理闸门

| 守卫 | 类型 | 对本次的语义 |
|---|---|---|
| `check_dependency_ledger.py` | 硬 gate | 仅校验 OSV/dependabot **接线在位** + 豁免 ≤5；不阻止新增依赖 |
| `check_pubspec_drift.py` | soft gate | `run_soft_gate`，report-only，**恒 return 0**，不阻断 |
| `check_analyzer.py` | 硬 gate | 基线 ERROR 0 / WARNING 49 / INFO 318；path dep 本身不新增 analyze 违规 |
| `osv-scanner.toml` | 依赖台账 | 当前**零豁免、零条目**（`cat` 为空）；无 `DEPENDENCY_LEDGER.yaml` 实体文件 |

SDK `dependencies:{}` ⇒ 引入 path dep **不带来任何传递依赖**，供应链扫描面不变（osv 仍只扫 App 既有依赖）。

## 3. 影响面评估

| 维度 | 影响 | 等级 |
|---|---|---|
| pubspec.yaml | 新增 `nebula_sdk: { path: ../nebula-flutter-sdk }`，本地可解析 | 低（本地） |
| `flutter pub get`（本地） | 兄弟目录存在时正常 | 低 |
| `flutter pub get`（CI） | checkout 无兄弟目录 + SDK 无 remote + publish_to:none ⇒ **解析失败** | **P0 阻塞** |
| capability-guard.yml | 因 pub get 红而整条链路红 | P0（衍生） |
| governance.yml | 因 pub get 红而整条链路红 | P0（衍生） |
| dependency-scan.yml（osv） | push 仅触发于 pubspec.yaml/pubspec.lock/osv-scanner.toml 路径；path dep 无传递依赖 ⇒ 扫描面不变 | 低 |
| architecture guard | `ADR-026/027` 已把接入面锁在 `lib/platform/nebula/`，守卫不阻止该目录接入 | 低 |
| dependency ledger | 零豁免台账不受 path dep 影响（无传递依赖）；若改 git/registry 方式需回填台账 | 低 |

## 4. 阻塞等级判定

**核心结论：采用 `path:` 依赖直接进主分支 CI 是 P0 级阻塞。**
根因不是代码改动，而是「CI 构建环境与依赖解析源不匹配」：
SDK 无 git remote、无 registry 发布能力，而 App CI 只 checkout 本仓。

`check_pubspec_drift.py` 是 soft gate（恒 return 0），不会因此提前报警，容易被误判为「无影响」——
**必须显式登记本 P0 阻塞**，不能依赖 soft gate 兜底。

## 5. 依赖引入方式对比

| 方式 | CI 可行 | 代价 | 判定 |
|---|---|---|---|
| A. `path: ../nebula-flutter-sdk` | ❌ 红（无兄弟目录） | 零传递依赖、本地开发顺手 | 仅限本地验证，禁入主分支 CI |
| B. `git:` 依赖（需 SDK 有可达 remote） | ✅ 需先给 SDK 加 remote 并 push | 引入对 SDK 仓库的 CI 耦合；SDK 仍 `publish_to:none` 不影响 pub | 可行，但需先解决 SDK 可达性 |
| C. 私有 registry 发布（hosted） | ✅ | 需私有 pub 服务 + 令牌；SDK 须可发布 | 长期方案，当前 SDK `0.1.0-dev.1` 未就绪 |
| D. 把 SDK 源码 vendor 进 App 仓 | ✅ | 背离「单一 SDK 真源」、双份维护、易漂移 | 不推荐 |
| E. CI 内 `checkout` SDK 兄弟目录后再 `pub get` | ✅ | 改动 workflow（新增 checkout step + 路径约定）；与 path dep 配合 | **推荐过渡方案**：path dep + CI 显式 checkout SDK |

## 6. 建议（最小接入的 dependency 引入方式）

1. **本地开发**：允许 `pubspec.yaml` 使用 `path:` 依赖，便于 S3-D0x 在本地验证接入；禁止把该 path 依赖直接 push 到触发 `capability-guard`/`governance` 的 ref 而不解决 CI 解析。
2. **进主分支前二选一**：
   - **方案 E（推荐过渡）**：在 `capability-guard.yml` / `governance.yml` 增加一步 `actions/checkout`（指向 `nebula-flutter-sdk` 指定 commit/分支）到兄弟目录，使 `flutter pub get` 可解析；或
   - **方案 B**：给 SDK 仓加可达 git remote 并 push，改为 `git:` 依赖。
3. **长期**：SDK 进入 `0.1.0` 稳定 + 私有 registry 发布后，迁移到 hosted 依赖，移除 CI checkout 特例。
4. **台账**：若采用 git/hosted，回填 `osv-scanner.toml` / 依赖台账登记，保持零豁免纪律。
5. **守卫**：`check_pubspec_drift.py` 为 soft gate 不阻断，P0 阻塞必须由本评审显式登记，不能被其「恒 return 0」掩盖。

## 7. 对 MA0 其余 Story 的约束

- **S3-D04 allowed paths 冻结**依据 `ADR-026 §4` / `ADR-027 §3.2`：`lib/core/rule/**`、`lib/data/rules/**`、`lib/core/parser/**`、`lib/resolver/**` 为 forbidden。
- 首切片仅 `lib/platform/nebula/` + 组合根装配点（见 `ADR-027 §4`）。
- 不接空 marker 接口（`NebulaAsset` 等），防假接入。

## 8. 验收（本评审 DONE 条件）

- [x] 已确认 SDK 无 git remote、publish_to:none、dependencies:{}；
- [x] 已确认 `governance.yml:21` 与 `capability-guard.yml:31` 的 `flutter pub get` 会因 path dep 在 CI 红；
- [x] 已判定 path dep 进主分支 CI = P0 阻塞；
- [x] 已给出替代方案对比与推荐（E/B）；
- [ ] S3-D0x 实现 Story 落地时必须按本评审选 E 或 B，否则 CI 闸门视为未通过。

## 9. Known Limitations

- 未实际在 CI runner 上复现 `pub get` 失败（依据源码与 checkout 行为推导，确定性高）；
- SDK 未来若增加 `dependencies`（当前 `{}`）会改变传递依赖面，需重评 osv 台账；
- 方案 E 的 workflow 改动细节（checkout 路径/ref 约定）留待 S3-D01 实现 Story 落地；
- 未评估鸿蒙/CI 矩阵其他 runner 的差异（当前仅 Android/Flutter 主链路）。

---

## 10. 复验补充（2026-08-07T13:04:31+08:00，Architecture Coordinator docs-only 复验）

本次复验对照用户验收标准，补 Three 处原报告未显性覆盖的维度，并给出复验 Verdict。结论：**原报告核心判定（path dep 进 CI = P0）成立且证据充分**，下述为补全项。

### 10.1 Dirty Dependency 风险（验收维度 4）

`path:` 依赖的致命特性是**直接解析兄弟目录的磁盘状态**，不经 registry 版本锁。实测 `git -C nebula-flutter-sdk status --short | wc -l = 33`，其中：

| 脏目录 | 文件数 | 含义 |
|---|---|---|
| `docs/multi_agent` | 15 | 治理文档（预期 dirty） |
| `lib/src` | 10 | **SDK Foundation WIP（Quarantine 中，未审查代码）** |
| `tool/governance_test.dart` / `tool/api_surface.dart` | 2 | 治理工具 |
| `test/*` | 4 | 测试 |

**关键风险**：若 APK 现在用 `pubspec.yaml: nebula_sdk: { path: ../nebula-flutter-sdk }`，`flutter pub get` 会把它**兄弟目录的 10 个 `lib/src/**` WIP 文件直接纳入编译**，即在无 review、无版本锁的前提下把未审查 Foundation 代码引入 App 构建。

**实证当前状态**：APK `pubspec.yaml` **尚未**出现 `nebula_sdk` path 依赖（`grep path:` 命中的是普通 `path: ^1.9.0` pub 包，非 SDK 依赖）。即该风险是**前瞻风险**，与 `nebula_sdk_state: WAIT`、首切片未启动一致 —— 但若 S3-D0x 直接加 path dep 进主分支而不解决 CI 解析，则 33 个脏文件（含 10 个 WIP）会一键进构建。

**结论**：Dirty Dependency 风险**真实存在**，必须随“path dep 仅限本地、禁入 CI”纪律一并登记。

### 10.2 Version Strategy 冻结（验收维度 3）

原报告 §5/§6 隐含但未显式冻结版本策略。复验补强制约定：

| 阶段 | 依赖方式 | 约束 |
|---|---|---|
| **V1 开发阶段** | `path: ../nebula-flutter-sdk` | 允许（本地 S3-D0x 验证用）；**禁止 push 到触发 `capability-guard`/`governance` 的 ref** |
| **Release / 进主分支 CI** | 二选一： | (E) CI 显式 `checkout` SDK 指定 commit 到兄弟目录 + path dep；或 (B) SDK 加可达 git remote + `git:` 依赖（commit-pinned） |
| **长期稳定** | 私有 registry（hosted）发布 | SDK 须 `publish_to` 改为私有源 + 可达 `version`；移除 CI checkout 特例 |

**硬性冻结**：Release 通道**不得**使用无锁 path dep；SDK 进入 `0.1.0` 稳定后必须 `git tag` + 语义版本（或 registry），由依赖台账（`osv-scanner.toml` / `DEPENDENCY_LEDGER.yaml`）登记，保持零豁免纪律。V1 开发期允许 path 不构成“无版本锁可发布”的例外。

### 10.3 CI Gate（验收维度 5）

原报告识别了“SDK 改 → APK 自动发现”的需求但未定义具体闸门。复验补最小 CI Gate（须在 S3-D01 实现 Story 落地）：

1. **SDK API Snapshot**：SDK 维护 `governance/api_surface.snapshot`（既定 121 符号）；APK 侧 CI 比对“APK 实际消费的 SDK 符号”是否落于快照允许集，防止 SDK 破坏性变更静默传入。
2. **`flutter analyze`**：APK `capability-guard.yml` / `governance.yml` 既有 analyze 步须覆盖 `lib/platform/nebula/`（接入面），path dep 引入的 SDK 符号变动须在此暴露。
3. **Integration Test**：S3-D0x 须带 `lib/platform/nebula/` 的最小集成测试（bootstrap fail-soft + runtime-config 读取），作为 SDK↔APK 契约回归；Agent A 改 SDK、Agent B 的 APK 须能被该测试发现 break。

**交叉 Agent 发现机制**：上述三项合为“SDK 变更 → APK CI 红”的自动发现链；配合方案 E 的 CI checkout，使 Agent A/B 的并发修改在 merge 前被 Gate 拦截（呼应 MA0-Q01 MG 系列）。

### 10.4 复验 Verdict

```text
MA0-A03
PASS WITH FOLLOW-UP ✅
（由用户最终裁定 REVIEW → DONE）
```

- **通过**：path dep 进主分支 CI = P0（governance.yml:21 / capability-guard.yml:31 `flutter pub get` 红，根因 SDK 无 git remote + publish_to:none + CI 仅 checkout 本仓）；Package Resolution 本地稳定、CI 失败确定性高；Dirty Dependency 风险真实（SDK `lib/src` 10 脏文件）；Version Strategy 已显式冻结（dev=path / release=git tag+pub 或 registry）；CI Gate 已定义（API snapshot + analyze + integration test）。
- **Follow-up（非阻塞，用户指定）**：
  - **FOLLOW-UP: SDK Release Workflow** —— 在 SDK 进入 `0.1.0` 前，先落地“本地 path / CI checkout / 长期 registry”三段式 release 工作流，避免 V1 开发期 path dep 泄漏进发布通道。
  - S3-D01 实现 Story 必须按本评审选 E 或 B 解决 CI 解析，并实现 §10.3 三项 Gate，否则 CI 闸门视为未通过。

### 10.5 交叉引用修正

ADR-027 §7 引用的 `MA0_A03_APP_EXTERNAL_DEPENDENCY_ASSESSMENT.md` 与实际 A03 交付物 `reports/MA0_A03_DEPENDENCY_IMPACT_REVIEW.md` 文件名不符；建议统一（或补别名），避免评审链断点。
