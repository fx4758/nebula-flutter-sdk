# AI Execution Entry

> **GOV-P0 EXECUTION ROUTER** — 唯一可执行任务源：`docs/multi_agent/task_board.json`。

## 开工前强制顺序
1. 读 `multi_agent/task_board.json`，取得被分配的精确 Story ID。
2. 运行 `dart run tool/task_source_guard.dart --story <STORY_ID>`。
3. 只读 Guard 指向的 Task Pack 与 Required Inputs。
4. Guard 未通过：停止；不得从 `STATUS.md` / `03_IMPLEMENTATION_PLAN.md` / 历史 F0/F1/F2/F3 ID 自选替代任务。

## 当前阶段
- MA0 已关闭。
- 当前执行：**S1-A Foundation Integration**。
- 活跃 Story 以 `task_board.json -> story_tracking` 为准。
- 首个消费者：`../flutter NFC Writer`；Backend authority：`../flypost_backend`。
- SDK 保持单 package `nebula_sdk`；Parser/NFC Runtime/Action Execution 留在 App。
- Asset SDK / Upload API / Payment live refund / Advanced Risk Engine 仍禁止抢跑。

## 文档角色
- `multi_agent/task_board.json`：唯一可执行任务源。
- `multi_agent/task_packs/*`：Story 执行合同。
- `multi_agent/02_SPRINT_BOARD.md`：人类可读进度镜像，不用于自动选任务。
- `STATUS.md`：SDK 内部历史事实/能力完成记录，**NON-EXECUTABLE**。
- `03_IMPLEMENTATION_PLAN.md`：历史/长期路线参考，**NON-EXECUTABLE**。

## 验收
Agent 交付消息不算证据。Reviewer 必须检查实际 branch/worktree diff、文件、测试与治理命令后给出 PASS / PASS WITH FOLLOW-UP / CHANGES REQUIRED / FAIL。
