# Task Pack — MA0-Q01 并行开发冲突与门禁

- Epic：EPIC-GOV
- Owner：Quality/Governance Agent
- SP：2

## Goal

把三个 dirty 仓库变成可安全并行的多 Agent 工作环境，不丢失任何用户改动。

## Inputs

- 三个仓库 `git status`、branch、log
- `AGENTS.md`
- `governance/**`
- `03_OWNERSHIP_MATRIX.md`
- `04_DEFINITION_OF_DONE.md`

## Allowed Paths

- `docs/multi_agent/reports/MA0_Q01_PARALLEL_WORK_PLAN.md`
- 本 Story 状态字段

## Forbidden

- 不 reset、stash、clean、checkout 覆盖当前工作树。
- 不提交现有未知 WIP。
- 不修改 CI 或代码。

## Tasks

1. 记录每个仓库 dirty file 数量和高冲突目录。
2. 定义基线 commit、branch/worktree 创建流程。
3. 为 S1/S2/S3 分配不重叠写目录。
4. 定义共享文件串行 Integration Owner。
5. 定义每类 Story 最小测试矩阵。
6. 定义状态更新和合并顺序。

## Acceptance

- [ ] 不同 Agent 无共享可写文件。
- [ ] `nebula.dart`、public export、router、migration 有串行 Owner。
- [ ] 当前 WIP 有 quarantine 清单。
- [ ] 给出可复制的 worktree/branch 流程，但不实际执行破坏性操作。
- [ ] Merge Gate 可量化。

## Deliverable

`docs/multi_agent/reports/MA0_Q01_PARALLEL_WORK_PLAN.md`
