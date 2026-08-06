# AI Execution Entry

## Active Multi-Agent Delivery Plan (2026-08-06)

当前跨仓主计划已切换到 `docs/multi_agent/README.md`。新 Agent 必须先读取该入口并只领取一个 READY Story；当前仅开放 MA0 审计任务，不得抢跑业务实现。


此文件是 AI 每轮唯一必读的任务路由页。不要默认加载 `docs/` 全部内容。

## 事实基线

- 本工程是独立 Flutter SDK；F0、F1、F2 已完成，当前进入跨仓 MA0 重基线与 F3 Asset 准备阶段。
- `../flypost_backend` 是当前 Platform 数据面权威仓库；`../flypost_server` 是管理后台/BFF。
- SDK 当前保持单一发布包 `nebula_sdk`，至少两个 App 完成真实接入前不机械拆包。
- 首个接入目标是 `../flutter NFC Writer` 的 Flutter 根项目；嵌套旧 Android 工程默认只读。
- 当前三个仓库均存在预先未提交修改；Agent 必须遵守 `docs/multi_agent/03_OWNERSHIP_MATRIX.md` 的 Quarantine。
- 目标 App：FlyPost、NFC Writer、Focus、StarSprout；它们是消费者，不是 SDK 模块。

## 按任务读取

| 任务 | 必读文件 |
| --- | --- |
| 修改公共 API/目录 | `01_ARCHITECTURE.md`、`06_API_CONTRACT.md` |
| 身份、网络、存储、日志 | `02_SECURITY_MODEL.md`、`06_API_CONTRACT.md` |
| 领取或关闭 Sprint 任务 | `multi_agent/README.md`、`multi_agent/02_SPRINT_BOARD.md`、`multi_agent/04_DEFINITION_OF_DONE.md` |
| 从旧 SDK 迁移 | `05_MIGRATION_FROM_FLYPOST.md`、`02_SECURITY_MODEL.md` |
| 更改冻结决策 | `DECISIONS.md`，新增 ADR 后才能修改 |
| 修改治理规则/例外 | `07_AI_GOVERNANCE.md`、`governance/README.md` |
| Mobile Bootstrap/Auth Session | `08_MOBILE_BOOTSTRAP_SESSION_CONTRACT.md`；编码任务再读 `09_F0_02_IMPLEMENTATION_HANDOFF.md` |
| Mobile Runtime Config/Feature/Version | `12_MOBILE_RUNTIME_CONFIG_CONTRACT.md`（F2-00 冻结契约；FB-06/FC-02/F2-01 必读） |

## 执行协议

1. 从 `docs/multi_agent/02_SPRINT_BOARD.md` 领取一个状态为 `READY` 的 Story。
2. 将任务状态改为 `IN_PROGRESS`，写执行者标识和基线 commit。
3. 只修改任务声明的 ownership 范围；跨范围先拆任务。
4. 实现代码、测试、必要文档。
5. 对照 `04_ACCEPTANCE_CRITERIA.md` 逐条给出证据。
6. 验证通过后标记 `DONE`；无法完成标记 `BLOCKED` 并说明可复现原因。

状态只允许：`BACKLOG / READY / IN_PROGRESS / REVIEW / BLOCKED / DONE`。不得用“基本完成”“预计完成”代替证据。

## PR 交接块

```text
Task ID:
Scope:
Changed public API:
Security/cost impact:
Validation commands and results:
Known residual risk:
Next ready task:
```

## 禁止事项

- 不从设计文档臆造后端端点、字段或错误码。
- 不复制旧 SDK 后再声称迁移完成。
- 不把管理端能力放入移动端 SDK。
- 不在本工程保存任何真实密钥、Token、域名或用户数据。
- 不连接生产/内网服务，不执行数据库操作。
