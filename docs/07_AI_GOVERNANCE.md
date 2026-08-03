# AI Governance System

Status: **ACTIVE / BLOCKING**

目标不是增加提示词，而是确保多轮、多 AI 协作后仍然可理解、可验证、可回滚。

## 1. 治理分层

| Gate | 解决问题 | 机器证据 |
| --- | --- | --- |
| G0 Work | AI 是否在做已登记任务 | `STATUS.md`、PR 交接块 |
| G1 Architecture | 边界、公共 API、复杂度是否漂移 | policy、public API allowlist、文件预算 |
| G2 Security/Cost | 密钥、Provider、App scope、重试成本 | source pattern guard、Security Review |
| G3 Release | 是否真的验证、兼容、可回滚 | analyze/test、Changelog、灰度证据 |

G0-G2 在每次 PR blocking；G3 在进入发布分支时 blocking。

## 2. 最小上下文原则

AI 默认只加载：

```text
AGENTS.md
docs/00_AI_HANDOFF.md
docs/STATUS.md
当前任务路由的 1-2 份文档
```

限制：

- `AGENTS.md` 不超过 120 行；
- `00_AI_HANDOFF.md` 不超过 160 行；
- 详细规则按主题分离，由路由页按需加载；
- 同一规则只允许一个权威定义，其他文档只链接，不复制全文；
- 机器规则放 `governance/policy.json`，不要求 AI 反复阅读实现细节。

## 3. 规则生命周期

规则状态：

```text
proposal -> warning -> blocking -> retired
```

进入 blocking 必须满足：

1. 有稳定 ID 和 owner；
2. 有正例、反例和误报探测；
3. 自动检查时间可接受；
4. 有安全修复路径；
5. 如需例外，例外可到期并可追踪。

规则数量不是 KPI。连续 90 天无命中、已被编译器覆盖或误报高于真实缺陷的规则，应合并或退役。

## 4. 变更预算

每个普通任务默认预算：

- 一个任务 ID；
- 一个 capability/层；
- 不超过一个新的公共导出文件；
- 不引入新 package；
- 不同时改变 API 契约和底层 Provider。

超过预算不自动禁止，但必须拆分任务或新增 ADR，说明为什么不可拆以及回滚边界。

## 5. AI 提交证据

每次交接必须回答：

```text
Task ID / baseline commit
Files owned and files changed
Public API diff
Security, privacy and worst-case cost
Commands executed and exact result
Known residual risk
Rollback method
Next task
```

没有命令输出不能标记 DONE；计划中的后端能力不能作为 SDK 已完成证据。

## 6. 自动守卫

运行：

```bash
dart run tool/governance.dart
```

当前检查：

- 治理和架构事实文件是否缺失；
- 任务状态是否使用冻结枚举；
- 公共 barrel 是否绕过 allowlist；
- 移动端 Secret、`client_credentials`、直连 Provider、body `app_id`；
- Dart 文件和 AI 入口是否突破复杂度/上下文预算；
- 临时例外字段和截止日期是否有效。

守卫是启发式防线，不替代代码审查和威胁建模。

## 7. 例外与技术债

- 例外登记在 `governance/exceptions.json`，最长默认 30 天；
- 例外只能精确到 rule/path，禁止 `*` 全局豁免；
- 架构债务登记在 `docs/DEBT_REGISTER.md`；
- 例外解决“守卫暂时放行”，技术债解决“设计尚未收口”，两者不得混用；
- 到期例外或 P0 债务使发布门禁失败。

## 8. 防止治理爆炸

- 不为每个 Sprint 新建一套规则；规则按 Architecture/Security/Data/Cost/API 五类稳定编号；
- 不把相同安全规则复制进模块 README；
- 不要求 AI 全量复述规则，只提交违规相关证据；
- 能由 analyzer/compiler/test 覆盖的规则，不在 Sentinel 重复实现；
- 每月审计规则命中、误报、执行时间和上下文行数。
