# MA0-A02 — Nebula V1 能力边界冻结复验（Capability Boundary Re-verification）

- Story：`MA0-A02`（EPIC-ARCH，frozen-boundary 裁定）
- 复验方：Architecture Coordinator（编排方，docs-only 复验，未改代码）
- 复验时刻（真实 Asia/Shanghai）：`2026-08-07T13:04:31+08:00`
- 原始交付物（被复验对象）：`flutter NFC Writer/docs/adr/ADR-026-rule-execution-boundary.md` + `ADR-027-nebula-basic-capability-scope.md`（均 `状态：frozen`，2026-08-07）
- 本文件：`reports/MA0_A02_CAPABILITY_BOUNDARY_REVERIFICATION.md`
- 类型：**复验报告**（确认 ADR 是否真冻结边界，而非仅写设计文档）

---

## 0. 复验结论（先行）

**推荐 Verdict：`PASS WITH FOLLOW-UP ✅`**

ADR-026 / ADR-027 **不是“设计文档”**，而是**代码层可强制的冻结裁定**：

- 两份 ADR 均显式 `状态：frozen`，带日期、Owner、关联裁定链（ADR-024 / ARCHITECTURE-BASELINE §6 / MA0-D01）；
- SDK 侧 4 个排除能力（Asset / Notification / Payment / AI）是**空 `abstract interface`**（`lib/src/capabilities.dart:47-56`，零成员），无可执行实现；
- SDK 中**不存在** `NebulaParser` / `NebulaActionEngine`（grep 全仓零命中）；
- SDK `pubspec.yaml` `dependencies: {}` —— 零传递依赖，引入 path dep 不扩大供应链面（与 ADR-027 §4 自洽）。

四项验收维度（V1 Scope / Runtime-Config 边界 / Parser 边界 / API Domain Ownership）**全部满足**。Follow-up 为治理卫生项（缺失 Task Pack、ADR-027 错误交叉引用文件名、APK `lib/platform/nebula/` 尚未创建），**不否定边界冻结本身**。

---

## 1. Nebula V1 Scope（验收维度 1）

### 1.1 纳入 V1（allowed）—— 与 ADR-027 §3.1 一致

| 能力 | 接入面 | 代码实证 |
|---|---|---|
| Bootstrap | 组合根 + `lib/platform/nebula/` | `dependency.dart` 组合根（D01 已确认） |
| Remote Config（runtime-config） | `lib/platform/nebula/` | ADR-027 §2.2 首切片定义 |
| Analytics | `lib/platform/nebula/` | marker 体系外的能力域 |
| Crash / Error Reporting | `lib/platform/nebula/` | 同上 |

### 1.2 明确排除（NOT in V1）—— 与 ADR-027 §3.2 一致

| 能力 | 排除原因 | 代码实证 |
|---|---|---|
| Parser Rule | App 产品安全域可执行语义包（Ed25519 链） | SDK 无 parser 实现；`lib/core/rule/**` 等在 APK forbidden |
| NFC Runtime | App 核心执行面 | SDK 无 `Nfc*` 会话/写卡实现 |
| Action Execution | 产品行为真源 | SDK 无 `NebulaActionEngine` |
| Asset / Notification / Payment / AI | SDK 仅为空 marker | `capabilities.dart:47-56` 空 interface |

### 1.3 一致性判定

- **SDK marker 一致性 ✅**：4 个排除能力均为空 interface，与“V1 不接”一致；不存在“假接入”成员。
- **API contract 一致性 ✅**：SDK `dependencies:{}` + 零业务实现，与 ADR 冻结范围无矛盾。
- **App 理解一致性 ✅**：ADR-026/027 **位于 APK 自身 `docs/adr/`**，由 App 架构侧持有并 frozen —— 不是外部强加文档，App 自身已认领该边界。

---

## 2. Runtime Config 边界（验收维度 2）

ADR-027 §2.2 / §3.1 明确：

- **允许**：只读键值开关 / 特性标志（`{"feature.dynamic_note":true,"music_parser_v2":false}`），旁路（bypass）模式；
- **禁止**（否则 SDK 变业务引擎）：
  - 业务规则下发（business rule delivery）
  - NFC action
  - parser rule
  - UI workflow

复验判定：**边界清晰且被 ADR-026 §4 forbidden 路径（`lib/core/rule/**`、`lib/data/rules/**`、`lib/core/parser/**`、`lib/resolver/**`）+ ADR-027 §3.2 双重锁定**。Runtime Config 被显式定性为“普通键值配置，非可执行语义包”，与 Parser Rule 的可执行语义包严格区分。✅

---

## 3. Parser Boundary（验收维度 3）

ADR-026 §4 + ADR-027 §3.2 冻结：

- Parser Rule / NFC Runtime / Action Execution **属于 App**；
- SDK **不应出现** `NebulaParser` / `NebulaActionEngine`。

复验实证（grep `lib/src` 全仓）：

```
NebulaAsset        -> abstract interface class (empty)   capabilities.dart:47
NebulaNotification -> abstract interface class (empty)   capabilities.dart:50
NebulaPayment      -> abstract interface class (empty)   capabilities.dart:53
NebulaAi           -> abstract interface class (empty)   capabilities.dart:56
NebulaParser       -> 0 hits
NebulaActionEngine -> 0 hits
```

判定：**SDK 无任何 parser / action-engine 实现**，4 个排除项均为空 marker。Parser 边界在代码层被强制。✅

---

## 4. API Domain Ownership（验收维度 4）

| 能力 | Owner | 依据 |
|---|---|---|
| Installation | SDK | ADR-027 §3.1 bootstrap / D01 Q2 |
| Transport | SDK | ADR-027 §4 adapter 注入 `Transport` Port |
| Runtime Config | SDK | ADR-027 §3.1 |
| Analytics | SDK | ADR-027 §3.1 |
| Crash | SDK | ADR-027 §3.1 |
| NFC Parse | APK | ADR-026 §2.2 执行面 |
| NFC Write | APK | ADR-027 §3.2 NFC Runtime |
| Card Business | APK | ADR-027 §3.2 Action Execution |

判定：**Owner 矩阵与 ADR-026 §2.3 强制边界表、ADR-027 §3 完全一致**，无能力错位。✅

---

## 5. 复验 Checklist（A02 验收标准映射）

| # | 验收要求 | 结果 |
|---|---|---|
| 1 | V1 允许 bootstrap/runtime-config/analytics/crash | ✅ ADR-027 §3.1 |
| 2 | V1 排除 Asset/Notification/Payment/AI | ✅ ADR-027 §3.2 + 空 marker 实证 |
| 3 | SDK marker 一致 | ✅ 空 interface，无假成员 |
| 4 | API contract 一致 | ✅ `dependencies:{}`，无矛盾实现 |
| 5 | App 理解一致 | ✅ ADR 在 APK `docs/adr/` 且 frozen |
| 6 | Runtime Config 非万能远程配置 | ✅ 只读 KV + forbidden 业务/parser/UI |
| 7 | Parser 边界：无 `NebulaParser`/`NebulaActionEngine` | ✅ grep 0 命中 |
| 8 | API Domain Ownership 表正确 | ✅ 与 ADR-026/027 一致 |

---

## 6. Findings（Follow-up，非阻塞）

1. **缺失 Task Pack（治理缺口）**：`task_board.json` 引用 `task_packs/MA0-A02-nebula-capability-boundary-adr.md`，但该文件**不存在**（task_packs 目录仅有 A01/B01/C01/D01/Q01/S01）。建议补建或修正 board 指针。
2. **ADR-027 §7 错误交叉引用**：原文引用 `MA0_A03_APP_EXTERNAL_DEPENDENCY_ASSESSMENT.md`，但实际 A03 交付物为 `reports/MA0_A03_DEPENDENCY_IMPACT_REVIEW.md`（文件名不匹配）。建议统一。
3. **APK `lib/platform/nebula/` 尚未创建**：当前 `find` 返回空。这与 `nebula_sdk_state: WAIT` + “首切片未启动”一致（ADR-027 §4 标注“新建”），非缺陷；仅记录。
4. **边界裁定回滚纪律**：ADR-026 §7 要求“扩展 Nebula 到规则/解析域须回到本 ADR 重新裁定，不得由普通实现任务静默改写”——建议在 S3-D01 任务卡中显式引用此约束。

---

## 7. 推荐 Verdict

```text
MA0-A02
PASS WITH FOLLOW-UP ✅
（由用户最终裁定 REVIEW → DONE）
```

边界冻结真实有效（代码层强制），4 维验收全过；Follow-up 为治理卫生项，不阻塞 Sprint 1 Planning 的 Capability Boundary 冻结。
