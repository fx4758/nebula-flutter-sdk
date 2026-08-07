# AI Execution Entry

此文件是 AI 每轮唯一必读的任务路由页。不要默认加载 `docs/` 全部内容。

## 事实基线

- 本工程是新的独立客户端 SDK；现有实现仍在 `../flypost/sdk/dart`。
- `../flypost` 是平台数据面，`../server` 是管理后台 BFF。
- 当前阶段是 F0。新工程没有生产接入、没有发布、没有真实 Provider。
- 目标 App：Flypost、NFC Writer、Focus、StarSprout；它们是消费者，不是 SDK 模块。

## 按任务读取

| 任务 | 必读文件 |
| --- | --- |
| 修改公共 API/目录 | `01_ARCHITECTURE.md`、`06_API_CONTRACT.md` |
| 引导/会话/身份契约 | `02_SECURITY_MODEL.md`、`08_MOBILE_BOOTSTRAP_SESSION_CONTRACT.md` |
| 身份、网络、存储、日志 | `02_SECURITY_MODEL.md`、`06_API_CONTRACT.md` |
| 领取或关闭 Sprint 任务 | `03_IMPLEMENTATION_PLAN.md`、`04_ACCEPTANCE_CRITERIA.md`、`STATUS.md` |
| 从旧 SDK 迁移 | `05_MIGRATION_FROM_FLYPOST.md`、`02_SECURITY_MODEL.md` |
| 更改冻结决策 | `DECISIONS.md`，新增 ADR 后才能修改 |
| 修改治理规则/例外 | `07_AI_GOVERNANCE.md`、`governance/README.md` |

## 执行协议

1. 从 `STATUS.md` 领取一个状态为 `READY` 的任务。
2. 将任务状态改为 `IN_PROGRESS`，写执行者标识和基线 commit。
3. 只修改任务声明的 ownership 范围；跨范围先拆任务。
4. 实现代码、测试、必要文档。
5. 对照 `04_ACCEPTANCE_CRITERIA.md` 逐条给出证据。
6. 验证通过后标记 `DONE`；无法完成标记 `BLOCKED` 并说明可复现原因。

状态只允许：`READY / IN_PROGRESS / BLOCKED / DONE`。不得用“基本完成”“预计完成”代替证据。

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
