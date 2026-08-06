# Sprint Board

## 状态枚举

`BACKLOG | READY | IN_PROGRESS | REVIEW | BLOCKED | DONE`

只有验收证据完整才能进入 DONE。

## 当前 Sprint：MA0 — Rebaseline & Parallelization Safety

容量：12 SP  
状态：READY  
目标：不写业务代码，先让后续多 Agent 可以安全并行。

| Story | SP | Owner | State | Depends | Deliverable |
|---|---:|---|---|---|---|
| MA0-A01 | 2 | Contract Agent | READY | - | `reports/MA0_A01_PLATFORM_API_AUDIT.md` |
| MA0-B01 | 2 | SDK Architect Agent | READY | - | `reports/MA0_B01_SDK_BASELINE.md` |
| MA0-C01 | 2 | Backend Architect Agent | READY | - | `reports/MA0_C01_BACKEND_CAPABILITY_AUDIT.md` |
| MA0-D01 | 2 | APK Integration Agent | READY | - | `reports/MA0_D01_NFC_APP_INTEGRATION_AUDIT.md` |
| MA0-Q01 | 2 | Quality/Governance Agent | READY | - | `reports/MA0_Q01_PARALLEL_WORK_PLAN.md` |
| MA0-S01 | 2 | Security Architect Agent | READY | - | `reports/MA0_S01_SECURITY_BASELINE.md` |

### MA0 Exit Gate

- 六份报告齐全。
- 真实 API、SDK、App、Security 状态完成交叉对账。
- 所有 dirty file 有 owner 或 quarantine 结论。
- S1-A01/S1-A02 的输入完整。
- 不存在两个 Agent 被分配同一可写目录。

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
