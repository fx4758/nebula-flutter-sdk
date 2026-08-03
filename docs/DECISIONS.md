# Architecture Decisions

## ADR-F001 — Independent SDK workspace

Decision: 新工程与 `flypost/sdk/dart` 分离初始化，旧 SDK 作为迁移事实和兼容实现。

Reason: 避免安全模型纠偏时破坏现有 App，并允许独立版本和灰度。

## ADR-F002 — Logical modules, single package first

Decision: F0-F4 使用一个 package，内部逻辑分层；达到客观准入条件后才拆包。

Reason: 控制依赖、版本、AI 规则和上下文数量，避免 package 爆炸。

## ADR-F003 — Pure Dart kernel

Decision: Foundation/Network/Auth/Config/Analytics 契约保持纯 Dart；原生能力经 adapter 注入。

Reason: 提升可测试性并避免公共内核绑定特定 Flutter 插件。

## ADR-F004 — No mobile App Secret

Decision: 新 SDK 不接受 App Secret 或 `client_credentials`；移动身份使用 public app ID、用户令牌、installation 和可选平台证明。

Reason: 安装包无法保护共享 Secret。

## ADR-F005 — Admin surface excluded

Decision: 凭据、Entitlement、退款、模板管理等控制面 API 不进入移动端 SDK。

Reason: 权限最小化和职责隔离。

## ADR-F006 — Routed AI governance

Decision: AI 默认只读取任务路由页；blocking 规则集中在机器策略中，例外必须登记并到期。

Reason: 保持多轮协作一致性的同时，限制规则复制、上下文增长和 Token 成本。

## ADR-F007 — Installation proof replaces mobile App Secret

Decision: 新移动端采用 public App ID、installation identity、ES256 proof 和 App/installation-bound user session；旧 HMAC 只保留隔离的迁移链路。

Reason: 移动二进制无法保护共享 Secret；App、installation、user、session 四个作用域必须来自可验证的服务端信任链。

修改任何已冻结决策必须新增 ADR：背景、选项、决定、迁移、回滚和影响，禁止静默改写历史。

## ADR-F008 — Target auth routes under /api/v1/mobile/auth

Background: 冻结契约（docs/08 §10）要求 legacy 与 target 两套认证中间件链完全隔离、可共存，且 proof 失败绝不 fallback 到 HMAC。Gin 无法对同一 method + path 注册两套独立中间件链；此前实现用"不注册 target"回避了冲突，导致 target 认证链未装配（评审 P0-1/P0-5）。

Options:
- A. target 认证路由放 `/api/v1/mobile/auth/*`，legacy 保持 `/api/v1/auth/*`（推荐）；
- B. target 放 `/api/v2/auth/*`，引入 API 版本维度；
- C. 同一路由按请求头自动降级（proof → HMAC）。

Decision: 采用 A。target 认证端点全部挂在 `/api/v1/mobile/auth/*`（与 `/api/v1/mobile/bootstrap` 同组、同隔离语义：不挂 legacy HMAC Signature，仅 InstallationProof + 可信限流）；legacy `/api/v1/auth/*` 原样保留至 F0-03 cutoff。C 被否决：自动降级会让 proof 失败静默回退 HMAC，直接违反冻结契约。

Consequences:
- 新客户端路径：`/api/v1/mobile/bootstrap` → `/api/v1/mobile/auth/{code/send,login,oauth/login,refresh,logout,device/bind}`；
- legacy 客户端路径不变（`/api/v1/auth/*`），兼容期无感；
- route inventory 测试按路径前缀断言中间件类别，杜绝两链混淆；
- 契约 fixture（docs/08 §3 target 表）路径同步更新。

Migration/Rollback: 新路径无既有流量，直接发布；回滚 = 还原 target 注册（legacy 不受影响）。
