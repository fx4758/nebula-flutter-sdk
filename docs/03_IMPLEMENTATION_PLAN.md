# Implementation Plan

Sprint ID 使用 `F` 前缀，避免与 flypost 生产化 `E0-E6` 冲突。一个任务一个 PR；任务的依赖未 DONE 时不得抢跑。

## F0 — Contract and security correction

目标：冻结新 SDK 边界，消除旧移动端 App Secret 模型。

| ID | 任务 | Ownership | Depends |
| --- | --- | --- | --- |
| F0-01 | 初始化工程、AI 文档和最小公共契约 | whole repo | - |
| F0-02 | 冻结 Mobile Bootstrap/User Session 契约 | docs, auth contracts | F0-01 |
| F0-03 | 设计旧 HMAC SDK 的兼容与下线计划 | docs | F0-02 |
| F0-04 | 建立 API contract fixture 与错误码映射 | contract tests | F0-02 |
| F0-05 | 建立 CI、API surface 和 secret scan | CI/tooling | F0-01 |

Exit：Flutter 无 App Secret/Admin API；契约与 flypost 事实逐项对账；兼容截止日期明确。

## F1 — SDK kernel

| ID | 任务 | Ownership | Depends |
| --- | --- | --- | --- |
| F1-01 | HTTP transport、信封、超时、取消 | network | F0 |
| F1-02 | 用户会话、single-flight refresh、退出 | auth | F1-01 |
| F1-03 | Secure/Cache Storage ports 与命名空间 | storage | F0 |
| F1-04 | 脱敏日志、错误分类、request ID | foundation | F1-01 |
| F1-05 | fake transport 与 kernel integration test | testing | F1-01..04 |

Exit：无真实后端也能用 fake transport 验证所有异常路径；并发 refresh 只有一次网络调用。

## F2 — Config and analytics

| ID | 任务 | Ownership | Depends |
| --- | --- | --- | --- |
| F2-01 | Effective config/feature/version API 契约 | config | flypost contract |
| F2-02 | TTL cache、stale fallback、刷新去重 | config | F1 |
| F2-03 | Consent 与事件 schema | analytics | F1 |
| F2-04 | 有界队列、批量、退避和丢弃策略 | analytics | F2-03 |
| F2-05 | NFC Writer 首个启动/配置接入样例 | example | F2-01..04 |

Exit：离线启动、缓存过期、强制升级、撤回同意均有自动测试。

## F3 — Asset and notification

| ID | 任务 | Ownership | Depends |
| --- | --- | --- | --- |
| F3-01 | Asset ticket/upload/download 契约 | asset | flypost E1/E3 |
| F3-02 | 进度、取消、文件约束和会话恢复 | asset | F3-01 |
| F3-03 | Push installation/token lifecycle adapter | notification | F1 |
| F3-04 | 站内信、未读、通用点击 payload | notification | flypost contract |

Exit：不存在永久 Bucket URL；退出/换用户不会串 Token；App 负责点击后的业务路由。

## F4 — Payment and AI

| ID | 任务 | Ownership | Depends |
| --- | --- | --- | --- |
| F4-01 | 用户态订单/查单/订阅/恢复购买 | payment | flypost E2/E5 |
| F4-02 | Idempotency 与支付状态映射 | payment | F4-01 |
| F4-03 | AI capability/task/cancel 契约 | ai | flypost AI Gateway |
| F4-04 | AI 超时、取消、降级和成本错误映射 | ai | F4-03 |

Exit：客户端不能决定可信金额、Provider 或预算；重复请求有幂等验证。

## F5 — Multi-App migration

顺序：NFC Writer -> Focus/StarSprout -> Flypost。每迁移一个 App 都需要灰度、指标和回滚版本。

Exit：至少两个 App 使用同一 SDK；不再复制网络/Auth/Config/Asset 基础代码；单 App 数据和配置隔离测试通过。

## F6 — Release governance and scale

- SemVer、Changelog、API compatibility、两小版本弃用窗口；
- 启动成功率、网络错误率、配置命中率、上传/支付/AI 指标；
- 故障注入、弱网、限流、应急开关和大规模 installation 测试；
- 有证据后再拆 package，不按模块数量机械拆分。
