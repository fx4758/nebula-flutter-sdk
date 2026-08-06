# Nebula Platform API + Flutter SDK 多 Agent 执行入口

> 状态：ACTIVE  
> 生效日期：2026-08-06  
> SSOT：本目录是跨 `nebula-flutter-sdk`、`flypost_backend`、`flutter NFC Writer` 的多 Agent 交付入口。

## 1. 每个 Agent 开始前必须读取

按顺序：

1. `../00_AI_HANDOFF.md`
2. `../STATUS.md`
3. 本文件
4. `00_MASTER_PLAN.md`
5. `01_WORK_BREAKDOWN.md`
6. `02_SPRINT_BOARD.md`
7. `03_OWNERSHIP_MATRIX.md`
8. `04_DEFINITION_OF_DONE.md`
9. 自己领取的 `task_packs/*.md`

不得把全部历史架构文档一次性注入上下文。领取任务后，只读取 Task Pack 明确列出的补充资料。

## 2. 当前事实基线

- Flutter SDK 的 F0、F1、F2 已完成；不是空仓库，也不重新搭建多 package 骨架。
- SDK 当前保持**单一发布包 `nebula_sdk`**，内部按 capability 分目录；在至少两个 App 实际接入前，不机械拆包。
- Backend 当前权威仓库为 `../flypost_backend`；mobile bootstrap、mobile auth、runtime-config 已形成真实实现。
- Asset 仍缺少冻结的移动端平台契约；现有 `internal/module/file` 只能作为审计输入，不能直接宣称为最终 Asset API。
- Payment、Notification 已有部分平台实现，但客户端契约与 SDK 闭环尚未完成。
- 首个接入目标是 `../flutter NFC Writer` 的 Flutter App；其内部嵌套旧 Android 工程 `NFCWriter/` 不是本轮 SDK 首接目标。
- Security 仍是重要 Epic，但不阻塞主链。基础安全随接口同步，系统性加固在真实业务链完成后执行。

## 3. 当前交付目标

### Milestone M1：SDK 可进入 APK

完成 Asset 主链后，Flutter NFC Writer 能通过本地 path dependency 接入 SDK，跑通：

`bootstrap → runtime-config → session restore/login → asset upload → asset query`

### Milestone M2：Platform API 基本成型

至少形成并有契约测试的能力：

- mobile bootstrap / installation
- mobile auth / session
- runtime-config
- asset upload / complete / query / delete
- notification device lifecycle
- entitlement query
- payment order/query/sandbox callback

### Milestone M3：安全与发布闭环

围绕真实 API 完成：

- 登录、短信、上传、分析、支付的成本与滥用保护
- emergency switch
- 审计
- contract/API compatibility
- 可安装 Staging APK 与回归报告

## 4. 领取任务规则

- 一次只能领取一个 Story ID。
- Story 的依赖未满足，不得先写实现。
- 一个 Story 一个 Owner，一个 PR/Commit 主题。
- 公共契约由 Contract Agent 冻结，其他 Agent 不得自行发明字段、路径、错误码或状态。
- 发现架构缺口时提交 `06_ARCHITECTURE_CHANGE_REQUEST_TEMPLATE.md`，不得边写边扩架构。
- 所有状态变更更新 `02_SPRINT_BOARD.md` 和 `task_board.json`。

## 5. 首批可立即领取任务

当前只开放 MA0 审计类 Story，不允许抢跑业务实现：

- `MA0-A01`：平台 API 与跨仓契约事实审计
- `MA0-B01`：SDK F0-F2 当前实现与可复用能力审计
- `MA0-C01`：Backend Asset/Notification/Payment 事实审计
- `MA0-D01`：Flutter NFC Writer SDK 接入点审计
- `MA0-Q01`：并行开发冲突、分支、门禁审计
- `MA0-S01`：安全 WIP 与最低安全门槛审计

对应 Task Pack 位于 `task_packs/`。

## 6. 禁止事项

- 不得覆盖当前工作树中他人的未提交变更。
- 不得将计划状态写成 DONE。
- 不得在 App 内绕过 SDK 直接调用 Nebula Platform API。
- 不得让 SDK 直连 OSS、支付、短信、AI Provider。
- 不得把产品业务模型放进公共 SDK。
- 不得为了保留已有安全代码扭曲业务和平台契约。
