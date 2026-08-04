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

## ADR-F009 — device/bind out of F0 scope

Background: ADR-F008 将 `/api/v1/mobile/auth/device/bind` 列入 target 端点，但该端点（用户与 installation 绑定）依赖 user access + installation proof 完整会话链，且当前无真实消费方（F0 聚焦 bootstrap/auth/refresh/logout 闭环）。评审 P1 要求：实现它，或经 ADR 正式移出 F0 契约。

Decision: 正式移出 F0 契约。`/api/v1/mobile/auth/device/bind` 标记为 F1 实现（docs/08 §3 target 表注记）；F0 不注册该路由，mobile_contract_test 的 not-implemented 断言保留至 F1。这不改变任何已冻结 wire 语义，仅调整 scope 边界。

Migration/Rollback: 无代码影响；F1 实现时恢复注册并按 docs/08 §3 语义落地。

## ADR-F010 — Public export budget raised to 40

Background: ADR-F002 决定 F0-F4 保持单 package，公共出口只有 `lib/nebula_sdk.dart`。F1 逐层落地 transport/auth/storage/foundation 的公共 Port 后，导出文件数在 F1-03 恰好达到 `max_public_exports=20`（policy.json 预算）；F1-04 新增脱敏日志/错误分类/request ID 三个 foundation 文件，导出数到 23，触发 API-BUDGET。F2-F4 还会继续增加 config/analytics/asset/notification/payment/ai 公共 Port，20 的上限与冻结路线图不匹配。docs/07 §4 的"一个任务不超过一个新的公共导出文件"约束是针对单任务作用域蔓延的，不应被解读为冻结整条路线图的导出总量。

Options:
- A. 将 `max_public_exports` 从 20 提升到 40（推荐）：容纳冻结的 F1-F4 公共 Port，API-BUDGET 仍作为公共面扩张的预警线；
- B. 维持 20，每加一个模块就拆独立 package：直接违反 ADR-F002 的单一 package 决策；
- C. 为 API-BUDGET 登记滚动例外：例外机制只解决临时放行（≤30 天），公共面增长是长期事实，用例外会制造永续豁免。

Decision: 采用 A。`governance/policy.json` 的 `limits.max_public_exports` 改为 40；公共 barrel 仍是唯一稳定出口，每个导出文件继续受 `governance/public_api.txt` allowlist 与 api_surface snapshot 双重门禁。

Consequences:
- API-BUDGET 从"总量封顶"退化为"公共面增长预警"，避免误伤冻结路线图；
- 导出准入成本不变：新增公共文件必须同时更新 barrel 与 allowlist，否则 API-EXPORT 失败；
- governance_test 的 API-BUDGET 反例自行把 temp policy 的 limit 改为 1 构造违规，不依赖真实上限值，无需改动。

Migration/Rollback: 纯配置变更；回滚 = 将 `max_public_exports` 还原为 20，若导出数继续超限会立即触发守卫。

## ADR-F011 — Mobile runtime config: single aggregate endpoint, server-trusted scope

Background: 移动端「配置/Feature 下发」在 `flypost/sdk/CONTRACT.md` 列为待办；已注册的 config/feature 路由均为管理端/产品控制面（`/products/:id/effective-configs` 等，`PermProductManage`），按 ADR-F005 不得进移动 SDK。F2-01 因此 BLOCKED（2026-08-04 核验）。架构决定以 F2-00 冻结移动端配置契约（docs/12），并以 FB-06/FC-02 落地。

Options:
- A. 单聚合端点 `GET /api/v1/mobile/runtime-config`，一次返回同一 revision 快照（configs+features+version_policy+cache_policy+revision+server_time）（推荐）；
- B. 双端点（effective-configs / effective-features 拆分）：跨 section 版本不一致，客户端需两段缓存与两次拉取；
- C. 复用管理端 DTO：违反 ADR-F005，且暴露 `rules_json`/`rollout_percentage`/`updated_by` 等控制面数据。

Decision: 采用 A。端点归入 ADR-F008 `/api/v1/mobile/*` 隔离组（Installation Token + Installation Proof，不挂 AdminToken/RBAC/legacy HMAC）。`app_id`/`installation_id` 只来自可信令牌；`environment` 由服务端部署决定；`region` 来自服务端可信绑定，**不信任** query/header——这是对 legacy §1「X-Region 透传」的定向豁免，仅适用于 `/api/v1/mobile/*` 配置类端点。Feature 灰度由服务端稳定分桶，客户端只收到最终 `enabled`；版本策略使用一等模型；安全关键字段（forced_upgrade/灾难开关）不得无限期使用旧缓存；配置经可下发字段白名单，密钥/Provider 配置/内部地址禁入响应；对 IP 与 installation 分别限流；响应大小/项数/长度有硬上限。

Consequences:
- 冻结契约落于 `docs/12_MOBILE_RUNTIME_CONFIG_CONTRACT.md`（端点/信任作用域/响应模型/版本策略/缓存语义/安全成本边界/FB-06/FC-02 验收）；
- FB-06 在 flypost 实现端点并登记 `sdk/CONTRACT.md`；FC-02 同步跨仓 fixture 与集成测试；之后解除 F2-01 BLOCKED；
- 管理端/产品控制面 DTO 继续禁止进入移动 SDK。

Migration/Rollback: 新端点无既有流量，直接发布；回滚 = 移除路由注册（legacy 不受影响）。契约任何字段变更须新增 ADR。
