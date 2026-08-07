# AI Collaboration Rules

本文件对整个 `nebula-flutter-sdk` 生效。

## GOV-P0：任务来源唯一性
1. **任何改动前第一步读取 `docs/multi_agent/task_board.json`。**
2. 只能执行其中 `story_tracking` 注册的精确 Story ID。
3. 必须运行：`dart run tool/task_source_guard.dart --story <STORY_ID>`。失败立即停止，不得从 `docs/STATUS.md`、`03_IMPLEMENTATION_PLAN.md`、旧 F0/F1/F2/F3 路线或聊天记录替代领取任务。
4. Guard 输出的 `task_pack` 是该 Story 唯一 Task Pack；一个 Story 一个 Task Pack。
5. `docs/STATUS.md` 是 SDK 内部历史状态，不是执行任务板。

## 每轮开始
1. 读 `task_board.json`、`docs/00_AI_HANDOFF.md`、`docs/multi_agent/README.md`。
2. 运行 Story guard，只读其 Task Pack 明确列出的补充资料。
3. 检查工作树，保留他人修改；一次只处理已分配 Story。
4. 修改代码前运行 `dart run tool/governance.dart`。

## 硬边界
- 公共 SDK 不得出现 FlyPost/NFC Writer/Focus/StarSprout 业务模型。
- 移动端不得保存 App Secret、Provider Secret 或 `client_credentials`。
- SDK 不得直连 OSS、AI、短信、邮件、支付 Provider。
- 服务端资源作用域来自可信令牌，不信任请求体 `app_id`。
- 未冻结公共 API 不得从 `lib/nebula_sdk.dart` 导出。

## 状态与验收
- 实现 Agent：仅自身 Story `READY -> IN_PROGRESS -> DELIVERED`。
- Reviewer/Coordinator：`REVIEW -> DONE`、全局依赖/Sprint/Blocker。
- Agent 回复不是验收证据；Reviewer 必须独立读 diff/代码/配置并跑验证。
- 每个提交必须包含 Story ID；发现架构缺口提交 ACR，不得自行换任务。
