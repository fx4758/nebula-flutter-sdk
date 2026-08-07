# Sprint Board

## 状态枚举

`BACKLOG | READY | IN_PROGRESS | REVIEW | BLOCKED | DONE`

只有验收证据完整才能进入 DONE。

## 当前 Sprint：MA0 — Rebaseline & Parallelization Safety（S1 进入已授权，带约束；见下方 Sprint 1 Entry Decision）

容量：12 SP  
状态：READY  
目标：不写业务代码，先让后续多 Agent 可以安全并行。

| Story | SP | Owner | State | Depends | Deliverable |
|---|---:|---|---|---|---|
| MA0-A01 | 2 | Contract Agent (workbuddy-contract-agent) | **DONE** | - | `reports/MA0_A01_PLATFORM_API_AUDIT.md` ✅ DONE（PASS WITH FOLLOW-UP） |
| MA0-B01 | 2 | SDK Architect Agent (workbuddy-sdk-architect-agent) | **DONE** | - | `reports/MA0_B01_SDK_BASELINE.md` ✅ DONE（PASS） |
| MA0-C01 | 2 | Backend Architect Agent (workbuddy-backend-architect-agent) | **DONE** | - | `reports/MA0_C01_BACKEND_CAPABILITY_AUDIT.md` ✅ DONE（PASS，rev2 复验通过） |
| MA0-D01 | 2 | APK Integration Agent (workbuddy-apk-integration-agent) | DONE ✅ | - | `reports/MA0_D01_APP_INTEGRATION_AUDIT.md` ✅ PASS WITH FOLLOW-UP（10 项 checklist 全 PASS；4 follow-up 落盘：S1-F01 Adapter / AuthService→NebulaAuth / A03 gate / S3 runtime-config） |
| MA0-A02 | 2 | APK Integration Agent (workbuddy-apk-integration-agent) | DONE ✅ | PASS WITH FOLLOW-UP（已验收） | `reports/MA0_A02_CAPABILITY_BOUNDARY_REVERIFICATION.md` ✅ 复验报告（ADR-026/027 代码层强制冻结；4 维验收全过；follow-up=CAP-F01 Capability Expansion Process） |
| MA0-A03 | 2 | APK Integration Agent (workbuddy-apk-integration-agent) | DONE ✅ | PASS WITH FOLLOW-UP（已验收） | `reports/MA0_A03_DEPENDENCY_IMPACT_REVIEW.md` ✅ Dirty Dependency + Version Strategy + CI Gate 已补；follow-up=DEP-F01 SDK Release Workflow |
| MA0-Q01 | 2 | Quality/Governance Agent | DONE ✅ | - | `reports/MA0_Q01_PARALLEL_WORK_PLAN.md` ✅ 已验收 DONE（PASS WITH FOLLOW-UP；GOV-D01 时间戳治理已修；follow-up GOV-F01/GOV-F02/Parse 同步） |
| MA0-S01 | 2 | Security Architect Agent | DONE ✅ | - | `reports/MA0_S01_SECURITY_BASELINE.md` ✅ 已验收 DONE（PASS；Payment NOT production-ready / Asset P0；follow-up SEC-F01/SEC-F02） |

### MA0-A01 状态记录

- owner：Contract Agent（`workbuddy-contract-agent`）
- branch/worktree：`nebula-flutter-sdk @ architect/f0-02-mobile-session`（未开新分支，docs-only）
- started_at：2026-08-07T07:20:00+08:00 ／ submitted_at：2026-08-07T07:33:00+08:00 ／ completed_at：2026-08-07T07:59:00+08:00（acceptance：PASS WITH FOLLOW-UP）
- changed paths：`reports/MA0_A01_PLATFORM_API_AUDIT.md`（新增）、`task_board.json`、`02_SPRINT_BOARD.md`（均仅本 Story 状态）
- test command/result：无（文档审计类 Story，Task Pack 禁止修改代码；证据为源码取证）
- review link/commit：报告 §10 Handoff Block（含三仓 base commit）
- known limitations：报告 §9（5 条）；S1 待拍板问题 12 项见报告 §8
- acceptance：PASS WITH FOLLOW-UP（2026-08-07 治理决议）；Story 关闭。
- follow-up：见 `adrs/ADR-ASSET-001.md`、`contracts/SDK_BOOTSTRAP_CONTRACT_FREEZE.md`、`contracts/MOBILE_CAPABILITY_CONTRACT.md`（均 MA0-A01 生成）

### MA0-B01 状态记录

- owner：SDK Architect Agent（`workbuddy-sdk-architect-agent`）
- branch/worktree：docs-only（未开新分支，纯文档审计）
- started_at：2026-08-07T09:35:51+08:00 ／ submitted_at：2026-08-07T09:37:59+08:00 ／ completed_at：2026-08-07T09:46:48+08:00（acceptance：PASS）
- changed paths：`reports/MA0_B01_SDK_BASELINE.md`（新增）、`task_board.json`、`02_SPRINT_BOARD.md`
- audit inputs：sole SDK authority `nebula-flutter-sdk 279ed51`；Backend 基线 MA0-A01/C01
- test command/result：无（静态只读审计；未跑 dart test / api_surface，避免触碰 WIP Quarantine dirty 文件）
- known limitations：报告 §8（4 条，含未跑测试、未审 Quarantine、snapshot 仅静态核对、capability 标记空）
- open_decisions：0；S2 阻塞依赖见报告 §6（ADR-ASSET-001 / backend owner-trust 缺陷 / api_surface tool dirty）
- acceptance：PASS（2026-08-07 治理验收，8 项 Acceptance Checklist 全 PASS）；状态 REVIEW → **DONE**。
- follow-up：见 `adrs/ADR-ASSET-001.md`、`adrs/ADR-ASSET-OWNER-TRUST-001.md`、`contracts/F3_API_CONTRACT_FREEZE.md`、`contracts/SDK_PUBLIC_SURFACE_CHANGE_PROCESS.md`（均 MA0-B01 生成/引用）。

### MA0-C01 状态记录

- owner：Backend Architect Agent（`workbuddy-backend-architect-agent`）
- branch/worktree：docs-only（无代码分支；仅改治理文档）
- started_at：2026-08-07T08:25:44+08:00 ／ submitted_at：2026-08-07T08:27:42+08:00 ／ completed_at：2026-08-07T09:32:15+08:00（acceptance：PASS，rev2 复验通过）
- audit inputs（原 base commits，按验收建议改名以区分 Authority）：authority=`flypost_backend` `8ec212f`（唯一 Backend Authority）；historical_reference=`BE-Codex` `de8cf94`（已废弃，非候选/迁移/缺陷/ADR 来源）；sdk_context=`nebula-flutter-sdk` `279ed51`
- changed paths：`reports/MA0_C01_BACKEND_CAPABILITY_AUDIT.md`（新增）、`task_board.json`、`02_SPRINT_BOARD.md`（均仅本 Story 状态）
- test command/result：无（静态只读审计；未执行 backend 测试套件，Task Pack 禁止修改代码）
- 核心结论：三域在 BE-forAI/BE-Codex 唯一实质分叉在 Asset（file vs asset）；Notification client lifecycle 真实（INAPP），4 外部渠道为 sandbox 占位骨架；Payment 核心链路 production-capable，真实出金依赖 provider adapter+config；file 无法承载最终 mobile contract，asset 结构成熟但 `asset.*` 不在白名单致授权链断（A01 §7.2 复现）。
- known limitations：报告 §7（5 条）
- open_decisions：5（资产权威选型/能力注册/信任主体/表迁移/mobile 暴露面，见报告 §2.4，须 S1-A01/A02 拍板）
- 验收结果：**PASS（2026-08-07，rev2 快速复验）**；状态 REVIEW → **DONE**。详见 `reports/MA0_C01_ACCEPTANCE_REVIEW.md`（CHANGES_REQUIRED 阻塞项已全部满足）。
- 主要修订：唯一 Backend Authority=`flypost_backend`；移除 BE-Codex 作为候选/决策输入；修正 mobile trust、asset_object/017 migration、file owner trust、Payment maturity。
- follow-up：见 `adrs/ADR-ASSET-001.md`、`contracts/MOBILE_ASSET_CONTRACT.md`、`adrs/ADR-PAYMENT-REFUND-001.md`、`adrs/ADR-PAYMENT-RECON-001.md`（均 MA0-C01 生成/引用）。
- 验收前置：先完成本轮事实修订；ADR-ASSET-001 属后续架构决策，不是 MA0-C01 本身 DONE 的前置。

### MA0-D01 状态记录

- owner：APK Integration Agent（`workbuddy-apk-integration-agent`）
- branch/worktree：`flutter NFC Writer @ dev`（未开新分支，docs-only 审计；App 零改动）
- started_at：2026-08-07T07:35:00+08:00 ／ submitted_at：2026-08-07T10:50:00+08:00 ／ **completed_at：2026-08-07T11:12:00+08:00**
- base commits：`nebula-flutter-sdk` `279ed51` ／ `flutter NFC Writer` `b40a0bf`（工作树干净）
- deliverable（现行）：`reports/MA0_D01_APP_INTEGRATION_AUDIT.md`（消费者侧审计 + Migration Map + Q1–Q5 + 三项风险核对；取代早期 `MA0_D01_NFC_APP_INTEGRATION_AUDIT.md` 最小切片草稿）
- changed paths：`reports/MA0_D01_APP_INTEGRATION_AUDIT.md`（新增）、`reports/MA0_D01_NFC_APP_INTEGRATION_AUDIT.md`（标 SUPERSEDED）、`task_board.json`、`02_SPRINT_BOARD.md`
- test command/result：无（文档审计类 Story，Task Pack 禁止修改 App；证据为源码取证 + ADR-026/027 + task_board 状态）
- 核心结论：唯一 composition root = `AppDependencies`（`lib/app/dependency.dart:81`，`bootstrap()` `:211`）；App 已自有 HTTP/Config/Auth(mock)/InstallId（Risk 1 潜伏未实化）；SDK 零依赖 ⇒ 引入 path 依赖供应链面不变；首个真实接入 Sprint = **S3**（runtime-config 只读旁路），非业务 Feature
- 构建命令：`flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk`（CI 三个 workflow 均不构建 APK）
- known limitations：报告 §6（B1 Parse Engine P0 / B2 A03 path-dep P0 / B3 ADR-ASSET-001 / B5 无 flavor 环境隔离）+ 构建未实际执行 + SDK WIP 未触碰
- ✅ **旧 blocked_on_input 已解决（MA0-A02）**：URL 解析模块与 Nebula runtime-config 边界三问由 `ADR-026`（控制面/执行面拆分）/`ADR-027`（同域 `top22.top/v1/nebula/*` + 首切片仅 runtime-config）裁定 frozen。
- ⏸ **新 P0 门（不阻塞 D01 验收，仅约束 S3 启动）**：(B1) `BLOCKER-PARSE-ENGINE` 须收口后 S3 才解 WAIT；(B2) `MA0-A03` path dependency P0 须解后 S3-D01 才可行。
- ✅ **验收结果（2026-08-07T11:12:00+08:00）：PASS WITH FOLLOW-UP**。10 项 Acceptance Checklist 全 PASS（架构基线 / Q1 唯一入口 / HTTP 自有但逐步迁移 / Token·Auth mock / Config 区分 App↔NebulaConfigClient / Upload BLOCKED by ADR-ASSET-001 / Q2 迁移列表含 Parser·NFC·Action 留 App / Q3 不能迁移 Asset·Notify·Payment·AI / Q4 减重复基建 / Q5 首切片 S3-RUNTIME-CONFIG）。
- 用户评价：早期草稿重做为正确方向——ADR-026/027 后 D01 由「SDK 接入不确定」转为「接入路径已冻结，剩余为迁移治理问题」。
- follow-up（4 项，非阻塞 DONE）：① S1-F01 NFC App Nebula Adapter Layer（禁业务页直连 SDK）；② AuthService→NebulaAuth migration Story（留 App Auth Port，mock 换 provider）；③ MA0-A03 Path Dependency Gate（SDK 接入前置 P0）；④ S3 Runtime Config First Integration Sprint（READY AFTER GATE，依赖 A02+A03+SDK WAIT 解除）。
- untracked docs 处置（非阻塞）：`docs/00-START-HERE.md`/`SPRINT-FREEZE.md`/`ADR-026`/`ADR-027` 属 APK 仓 Nebula 接入治理资产，建议不并入业务代码、后续统一整理到 `docs/architecture/` 或保持 handoff。

### MA0-A02 状态记录

- owner：APK Integration Agent（`workbuddy-apk-integration-agent`）
- branch/worktree：`flutter NFC Writer @ dev`（未开新分支，ADR 文档仅落在 NFC Writer 仓 `docs/adr/`）
- started_at：2026-08-07T11:13:35+08:00（原记录 22:00 未来时间戳已由 MA0-Q01 校正）／ submitted_at：2026-08-07T11:33:35+08:00（原 23:30 已校正）／ **re-verified_at：2026-08-07T13:04:31+08:00**（Architecture Coordinator docs-only 复验）
- base commits：`nebula-flutter-sdk` `279ed51` ／ `flutter NFC Writer` `b40a0bf`（工作树干净）
- changed paths（跨仓指针）：`flutter NFC Writer/docs/adr/ADR-026-rule-execution-boundary.md`（新增）、`flutter NFC Writer/docs/adr/ADR-027-nebula-basic-capability-scope.md`（新增）、`task_board.json`、`02_SPRINT_BOARD.md`
- test command/result：无（ADR 文档类 Story，零代码改动；证据为源码取证）
- 核心结论：裁定 (b) 控制面上收/执行面保留——Nebula 控制面（rollout/metadata/lifecycle/kill switch），App 执行面（验签/执行/本地缓存/离线运行）；域名冻结 `top22.top` = NFC Protocol Identity（受 `🔒 HOST` 守卫锁死）；forbidden 路径 `lib/core/rule/**`、`lib/data/rules/**`、`lib/core/parser/**`、`lib/resolver/**`；规则包=可执行语义包非普通 config。
- **复验实证（2026-08-07T13:04:31）**：4 个排除能力在 SDK 为**空 abstract interface**（`lib/src/capabilities.dart:47-56`，零成员）；全仓 grep `NebulaParser`/`NebulaActionEngine` = 0 命中；`pubspec.yaml` `dependencies:{}` 零依赖 → 边界在代码层被强制，非仅设计文档。
- known limitations：ADR 内容在 NFC Writer 仓，跨仓看板仅登记指针；空 marker 接口接入留待 SDK F3 冻结；APK `lib/platform/nebula/` 尚未创建（与 WAIT 一致，非缺陷）；Task Pack `MA0-A02-nebula-capability-boundary-adr.md` 文件缺失（board 引用）；ADR-027 §7 错引 A03 文件名。
- **复验 Verdict（推荐）：PASS WITH FOLLOW-UP**。4 维验收全过；follow-up 为治理卫生项（补 Task Pack / 修 ADR-027 交叉引用），不阻塞 Sprint 1 Capability Boundary 冻结。
- acceptance：PASS WITH FOLLOW-UP（2026-08-07 最终验收）。状态 REVIEW → DONE。

### MA0-A03 状态记录

- owner：APK Integration Agent（`workbuddy-apk-integration-agent`）
- branch/worktree：`nebula-flutter-sdk @ docs/multi_agent`（doc-only）
- started_at：2026-08-07T11:13:35+08:00（原记录 22:30 未来时间戳已由 MA0-Q01 校正）／ submitted_at：2026-08-07T11:33:35+08:00（原 23:30 已校正）／ **re-verified_at：2026-08-07T13:04:31+08:00**（Architecture Coordinator docs-only 复验）
- base commits：`nebula-flutter-sdk` `279ed51`
- changed paths：`reports/MA0_A03_DEPENDENCY_IMPACT_REVIEW.md`（新增+复验补充）、`task_board.json`、`02_SPRINT_BOARD.md`
- test command/result：无（静态依赖影响评审；证据为源码取证 + `git remote -v` / `pubspec.yaml` / workflow 行号）
- 核心结论：**path 依赖直接进主分支 CI = P0 阻塞**——`governance.yml:21` 与 `capability-guard.yml:31` 均 `flutter pub get`；CI 只 checkout 本仓，而 SDK 无 git remote + `publish_to:none` + `dependencies:{}`，runner 无兄弟目录可解析 ⇒ 两条主链路全红。`check_pubspec_drift.py` 为 soft gate（恒 return 0）不报警，P0 须显式登记。
- 替代方案：A path（仅本地）/ B git 依赖（需 SDK 加 remote）/ C 私有 registry（长期）/ D vendor（不推荐）/ **E path + CI 显式 checkout SDK（推荐过渡）**。
- **复验补全（2026-08-07T13:04:31）**：① Dirty Dependency 风险真实——`git -C nebula-flutter-sdk status --short | wc -l = 33`，其中 `lib/src/**` 10 个 WIP 脏文件，path dep 会直接纳入编译；APK 当前 pubspec **尚未**引入 nebula path 依赖（与 WAIT 一致）。② Version Strategy 已显式冻结（dev=path 允许 / release=git tag+pub 版本或 registry）。③ CI Gate 已定义（SDK API snapshot + `flutter analyze` + integration test 实现 Agent A/B 变更自动发现）。
- known limitations：未实际在 CI runner 复现 pub get 失败（确定性推导）；方案 E workflow 改动细节留待 S3-D01；未评估鸿蒙/其他 runner。
- **复验 Verdict（推荐）：PASS WITH FOLLOW-UP**。path dep P0 成立；三缺口已补；follow-up = **SDK Release Workflow**（V1 开发期 path 不泄漏进发布通道）。
- acceptance：PASS WITH FOLLOW-UP（2026-08-07 最终验收）。状态 REVIEW → DONE。

### MA0-Q01 状态记录

- owner：Quality/Governance Agent（`workbuddy` 编排派发，sub-agent `Q01-Governance` 占坑）
- branch/worktree：docs-only（未开新分支；三仓工作树零改动）
- started_at：2026-08-07T11:13:35+08:00 ／ submitted_at：2026-08-07T12:37:11+08:00 ／ completed_at：2026-08-07T12:52:08+08:00
- deliverable：`reports/MA0_Q01_PARALLEL_WORK_PLAN.md`（18 节，873 行）
- 核心结论：三仓 dirty 清单（54 文件：SDK 39 / BE 5 / APK 10）+ 高冲突目录 + 8 组 WIP Quarantine；可复制 worktree 流程（未执行）；S1/S2/S3 写集交集矩阵（全 ∅）；11 条串行文件 Integration Owner；6 类 Story 测试矩阵；8 层合并序 + MG-1..MG-12 量化 Merge Gate；Sprint 1 入口依赖图（A02/A03/Parse-Engine/SDK-WAIT 标 READY/AFTER-GATE/BLOCKED）。
- **治理缺陷 GOV-D01（P0，已修）**：A02/A03 时间戳为未来值（原 22:00/23:30、22:30/23:30，比真实当前晚 10–12h），已用真实 +08:00 时间校正（T0=11:13:35 / T1=11:33:35）。
- 共 21 项治理缺陷（P0×1 已修 / P1×10 / P2×10）。遗留开放问题见报告 §18，其中 **BLOCKER-PARSE-ENGINE 状态三处未同步** 已于 2026-08-07T12:52 由编排方统一冻结为 `RESOLVED_WITH_REMAINING_ACTION`（blocks=[]、main_flow_block_cleared=True、nebula_sdk_state=WAIT 不阻塞 foundation）；另：ADR-028 工作包 untracked 无 Story ID、三仓均无 CODEOWNERS、sdk/dart 判 Quarantine 却被 CI 主动维护。
- acceptance：**PASS WITH FOLLOW-UP**（2026-08-07T12:52 验收）。
- follow-up（非阻塞）：**GOV-F01** `docs/multi_agent/BOARD_WRITE_POLICY.md`（Story owner 可改自身状态字段；禁改他 Story/全局 release/依赖图，除非 Integration Owner）；**GOV-F02** 三仓 CODEOWNERS（进 Sprint 1，非 MA0 阻塞）；**GOV-F03** BLOCKER-PARSE-ENGINE 三处状态已统一冻结（本案收口）。

### MA0-S01 状态记录

- owner：Security Architect Agent（`workbuddy` 编排派发，sub-agent `S01-Security` 占坑）
- branch/worktree：docs-only（两棵树 dirty 仅 `dart format`，未触碰）
- started_at：2026-08-07T11:30:00+08:00 ／ submitted_at：2026-08-07T11:46:46+08:00 ／ completed_at：2026-08-07T12:52:08+08:00
- deliverable：`reports/MA0_S01_SECURITY_BASELINE.md`（10 节）
- 核心结论：后端 20 + SDK 10 安全能力清单（file:line）；MUST-WITH-STORY 6（M-01..M-06）/ DEFER-TO-S7 8（D-01..D-08），每项含触发 Sprint + 验收；8 个 ≤8 分钟安全门槛 G1-G8；旧 WIP 对账 W-01..W-12；S7 回归 R-01..R-12。
- Payment 分项：下单 PARTIAL-OK / 回调 HIGH-RISK PARTIAL（非事务）/ 订阅 NOT-CLOSED / 退款 LOCAL-ONLY（无 Provider 调用）/ 对账 MISSING → **整体 NOT production-ready**。
- Asset：**P0 越权**——`internal/module/file/file.go:41,73` 取可信 `uid` 后 `_ = uid` 丢弃，改用客户端 `owner_type`/`owner_id`（:62-63）；`file.go:114-126`→`storage.go:81-87` 全链无 owner 校验，presigned URL 可跨用户取。
- 阻塞判定：**未发现阻塞 S1–S3 的 P0**。两项 P0 均被既有闸门围栏（Asset 由 ADR-ASSET-001 未完成前禁止 Asset SDK/Upload API + 首切片仅 runtime-config + NebulaAsset 空 marker；退款由 admin-only RBAC + sandbox 默认 + live 无 adapter 直接报错围栏）。S1 Contract 不新增前置条件。
- acceptance：**PASS**（2026-08-07T12:52 验收）。
- follow-up（非阻塞）：**SEC-F01** Security Minimum Gate Matrix（Auth owner scope / Asset owner validation / Payment idempotency / Upload quota / Analytics PII filter，供 Feature Agent 直接引用）；**SEC-F02** Payment 后续进 `S7 Payment Hardening`（不混入 S1）。

## MA0 Parallel Release Decision — 2026-08-07

- **MA0-Q01** 与 **MA0-S01** 正式允许并行领取；二者均保持 `READY`，由实际 Agent 领取时自行置 `IN_PROGRESS`。
- 两者只允许修改各自 report + 本 Story 状态字段；不得修改业务代码、CI、公共契约或他人 WIP。
- Q01 最新必审：唯一 Backend Authority、A02/A03、`BLOCKER-PARSE-ENGINE`、SDK WAIT、Board 时间戳一致性、worktree/merge gate。
- S01 最新必审：唯一 Backend Authority、Asset owner-trust、Payment HIGH-RISK PARTIAL、refund local-only、reconciliation missing、MUST-WITH-STORY vs DEFER-TO-S7。
- **禁止抢跑**：Asset SDK / Upload API / Payment live refund / 高级 Risk Engine 均不得因本次并行放行开始编码。

### MA0 Exit Gate

- 六份报告齐全。
- 真实 API、SDK、App、Security 状态完成交叉对账。
- 所有 dirty file 有 owner 或 quarantine 结论。
- S1-A01/S1-A02 的输入完整。
- 不存在两个 Agent 被分配同一可写目录。

### MA0 Exit Gate 补充（2026-08-07 架构裁定收口）

- **S0 Architecture Preparation：FROZEN**。MA0-D01 §6.3 三问已由用户裁定，产物 `ADR-026`（Rule Execution Boundary）/ `ADR-027`（Nebula Basic Capability Scope）均 frozen。
- **✅ BLOCKER 已降级：Parse Engine Stability（P0 → `RESOLVED_WITH_REMAINING_ACTION`）**。核心解析阻塞已关闭：ADR-028 I/O 冻结（6/6 DoD 达标）+ 实扫 `eacdbf3` 复核，8 条 P0/P1 中 6 已修/1 缓解/仅剩 P0-2（音乐卡分享+教程按钮空实现，feature 层 UI 债，非解析契约）。剩余 P0-2 拆 `PR-PARSER-UI-001`（仅 `screen_create.dart`，不碰 `core/parser`/`resolver`/`database`）。不阻塞 Architecture Freeze。S3-D04 allowed paths 仍冻结 forbidden 域。
- **优先级重排**：`P0/P1 Parse Engine 收口 → Architecture Freeze（已完成）→ Nebula Basic Integration（S3，WAIT）`。原「Nebula SDK → 功能开发」顺序作废。
- **Nebula SDK 状态：WAIT**。受 Parse Engine `RESOLVED_WITH_REMAINING_ACTION`（主流程阻塞已解除，剩余 PR-PARSER-UI-001 不阻塞 foundation）与 MA0-A03 path dependency P0 约束；首切片仅 runtime-config 只读旁路，排除解析模块，不接空 marker 接口。
- **MA0 当前看板状态**：`MA0-A01 DONE ✅` / `MA0-B01 DONE ✅` / `MA0-C01 DONE ✅` / `MA0-D01 DONE ✅`（PASS WITH FOLLOW-UP）/ `MA0-A02 DONE ✅`（PASS WITH FOLLOW-UP，已验收）/ `MA0-A03 DONE ✅`（PASS WITH FOLLOW-UP，已验收）/ `MA0-Q01 DONE ✅`（PASS WITH FOLLOW-UP）/ `MA0-S01 DONE ✅`（PASS）/ `Parse Engine RESOLVED_WITH_REMAINING_ACTION`（P0-2 feature debt → PR-PARSER-UI-001）/ `Nebula SDK WAIT`。

### Sprint 1 Entry Decision（2026-08-07 治理决议）

> 来源：MA0-A01 最终验收裁决。机器可读版本见 `task_board.json` → `sprint1_entry`。

- **决议**：允许进入 Sprint 1，但带前置约束。
- **允许继续的 Agent**：API Contract Agent、SDK Core Agent、Backend Auth Agent。
- **禁止（直到 ADR-ASSET-001 完成）**：Asset SDK 开发、Upload API 开发。
- **门禁**：ADR-ASSET-001 必须 **COMPLETED** 后，Asset SDK / Upload API 工作方可启动。
- **MA0-A01 最终验收**：PASS WITH FOLLOW-UP ✅，允许关闭 Story。
- **生成 Follow-up**（实体见 `adrs/`、`contracts/`）：
  - `adrs/ADR-ASSET-001.md`
  - `contracts/SDK_BOOTSTRAP_CONTRACT_FREEZE.md`
  - `contracts/MOBILE_CAPABILITY_CONTRACT.md`
- **备注**：MA0 其余审计 Story（B01/C01/D01/Q01/S01）仍可并行推进；S1 进入仅对上列被允许 Agent 开放。

## Sprint 1-A Foundation Integration（Execution Epoch 2）

状态：**IN PROGRESS / GOVERNED**。S1-F01-001 已有独立 App delivery commit，当前处于 REVIEW；其余 Story 受依赖和单仓执行规则控制。

唯一任务源：`task_board.json`。Implementation Agent 只读，不得自行 claim/DELIVERED/DONE 落盘。

**Cross-Repo Blocking Rule**：一个 Story 只能有一个 `execution_repo` + 一个 feature branch；需要第二仓实现时必须拆 Story。shared `main/dev` 禁止直接作为 delivery branch。

**Platform API Blocking Rule**：S1-A 默认 Platform API READ_ONLY。S1-F02-001 仅审计/补测试；任何 production API diff 均 CHANGES REQUIRED。真实缺口必须 ACR 后另建授权 Story。

| Story | Owner | State | Execution Repo | Execution Branch |
|---|---|---|---|---|
| S1-F01-001 Adapter Boundary | Agent A | **REVIEW** | Flutter NFC Writer | `s1/f01-001-adapter` |
| S1-F01-002 Bootstrap Lifecycle | Agent A | READY (blocked by 001) | Flutter NFC Writer | `s1/f01-002-bootstrap` |
| S1-F02-001 Backend Runtime Config Audit | Agent B | READY | flypost_backend | `s1/f02-001-runtime-config-audit` |
| S1-F02-002 SDK Runtime Config Closure | Agent B | READY (after F02-001) | nebula-flutter-sdk | `s1/f02-002-sdk-config` |
| S1-F03-001 SDK Release Workflow | Agent C | READY | nebula-flutter-sdk | `s1/f03-001-release` |
| S1-F03-002 API Surface CI Gate | Agent C | READY (after F03-001) | nebula-flutter-sdk | `s1/f03-002-api-gate` |

### GOV-P0 incident closures

- `GOV-P0-EXEC-SSOT`：旧 LAN main/F0 任务源漂移已关闭；main/guard/SSOT 已统一。
- `GOV-P0-CROSS-REPO-STATE`：发现 App Agent 同时改 App 仓 + SDK Task Board，并把交付直接推 LAN dev。根因是治理仓/施工仓未拆分。已冻结 GOV-CROSS-REPO-001；Task Board 改为 Coordinator-only；S1-F01-001 正式 review branch 为 App `s1/f01-001-adapter`。
- 禁止抢跑：Asset SDK / Upload API / Payment live refund / Advanced Risk Engine。

## 后续 Sprint 摘要

| Sprint | SP | Stories | Exit |
|---|---:|---|---|
| S1 Asset Contract | 15 | S1-A01/A02/A03/A04/Q01/Q02 | 状态机、API、fixture 冻结 |
| S2 Asset Delivery | 17 | Backend/SDK/E2E 选取 6-7 个 Story | Backend/SDK asset E2E |
| S3 APK Integration | 14 | S3-D01..D05/Q01 | 可安装 Staging APK |
| S4 Common Platform | 16 | Notification + Entitlement | 通用能力闭环 |
| S5 Payment | 15 | Payment contract/backend/sdk/sandbox | Sandbox payment+entitlement |
| S6 API Consolidation | 13 | Registry/error/gates/matrix | Platform API 基本成型 |
| S7 Security | 16 | Auth/SMS/Asset/Payment/Emergency/Regression | 真实链路安全闭环 |
| S8 RC | 13 | SDK/API/APK audit & drills | Release Candidate |

## Story 状态更新要求

每次状态变化必须记录：

- owner
- branch/worktree
- started_at / completed_at
- changed paths
- test command/result
- review link or commit
- known limitations

机器可读状态见 `task_board.json`。
