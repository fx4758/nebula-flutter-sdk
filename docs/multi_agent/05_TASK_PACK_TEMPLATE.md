# Task Pack Template

## Story

- ID：
- Owner Role：
- Reviewer：
- Depends：

## Execution Boundary（必填 / Blocking）

- Execution repo：`<exact repo path>`
- Execution branch：`<one Story one feature branch>`
- Execution remote：
- Governance state：`READ_ONLY` for Implementation Agent
- Platform API mode：`NONE | READ_ONLY | IMPLEMENT_FROZEN_CONTRACT | CONTRACT_CHANGE`
- SDK public API mode：`NONE | READ_ONLY | CHANGE_APPROVED`

Rules:

1. 一个 Story 只能有一个 `execution_repo`。
2. 跨仓依赖只读；第二仓需要实现改动时停止并由 Coordinator 拆新 Story。
3. Implementation Agent 不得修改 `task_board.json` / Sprint Board / assignment / dispatch。
4. shared `main/dev/release` 不得作为 implementation delivery branch。
5. Agent 结束只提交 Delivery Note；Coordinator 更新 DELIVERED/REVIEW/DONE。

## Goal

一个可独立验收的结果，不写“顺便”跨 Feature 工作。

## Facts / Context

只列已验证事实与冻结契约，不把计划当事实。

## Required Inputs

- Contract / ADR / Audit
- Baseline commit（IN_PROGRESS 时由 Coordinator 冻结）

## Allowed Paths

精确到目录/文件。

## Forbidden Paths / Actions

至少包含：

- Coordinator-owned governance state
- 其他 repository 的写入
- 未授权 public API / Platform API change
- 产品业务越界

## Tasks

1. ...

## Quantified Acceptance

- [ ] execution repo/branch 正确
- [ ] Coordinator-owned state diff = 0
- [ ] 所有验收条件有代码/测试证据
- [ ] Relevant guards PASS

## Tests / Verification

```bash
dart run tool/task_source_guard.dart --story <ID>
dart run tool/cross_repo_guard.dart --story <ID> --repo <execution_repo> --check-branch
# plus repo/task-specific tests
```

## Delivery Note（Agent 输出，不改 Task Board）

```text
Story ID:
Execution repo:
Branch:
Base commit:
Delivery commit:
Changed paths:
Tests/results:
Known limitations:
Platform/API changes:
ACR/ADR if any:
```

## Exit / Handoff

Agent 停在 Delivery Note。Coordinator/Reviewer 独立读取 diff/代码/测试后更新状态。
