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

修改任何已冻结决策必须新增 ADR：背景、选项、决定、迁移、回滚和影响，禁止静默改写历史。
