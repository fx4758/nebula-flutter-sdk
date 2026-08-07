# MA0-S01 — Security Baseline 与后置加固输入

- Story：MA0-S01（EPIC-GOV / EPIC-SEC，SP=2）
- Owner Role：Security Architect Agent
- Task Pack：`docs/multi_agent/task_packs/MA0-S01-security-baseline.md`
- 产出日期：2026-08-07T11:40:21+08:00
- 性质：**DOCS-ONLY 审计**。未新增/修改任何安全代码，未扩展 Risk Engine / Factor / Provider，未执行任何测试或构建。

## 0. Authority 与基线

| 角色 | 仓库 / commit | 说明 |
|---|---|---|
| 唯一 Backend Authority | `flypost_backend` @ `8ec212f5233e815229965977dedfca7a1ca2ffd0`（2026-08-07 00:03:18 +0800） | 本报告全部后端安全事实来源 |
| SDK Authority | `nebula-flutter-sdk` @ `279ed5118f1162f461a9fdaa4528bca2c3ddaae2` | SDK 侧守卫与安全模型来源 |
| 废弃副本 | BE-Codex `de8cf94` 及任何其它 backend 复制树 | **本报告未引用，不作为现状、缺陷或决策来源** |

继承的既定事实（不推翻）：

- MA0-C01：Payment = **HIGH-RISK PARTIAL**；`Refund()` 仅本地；Provider 接口无 `Refund`/`Reconcile`；对账缺失；`module/file` 存在 owner 自声明风险；表已是 `asset_object`（017 改名已落地）。
- MA0-D01：首个 APK 切片为 **runtime-config only**；Asset / Notification / Payment / AI 不进入首切片。
- `task_board.json:316-320`：`Asset SDK` 与 `Upload API` 在 `ADR-ASSET-001` COMPLETED 前被禁止开工。

---

## 1. 已有安全能力清单与真实接入点

「已实现」不等于「已接入」。下表的 **接入点** 列是本 Story 的核心增量：只有出现在 `internal/router/router.go` 或具体 handler 链上的才算真实生效。

### 1.1 后端（flypost_backend）

| # | 能力 | 实现证据 | 真实接入点 | 生效判定 |
|---|---|---|---|---|
| C-01 | HMAC 请求签名（V1.3 规范串 + Nonce 防重 5 min） | `internal/middleware/signature.go:22-61` | `internal/router/router.go:90` 挂在 `/api/v1` 全组 | **已接入**（mobile 组刻意不挂，见 C-04） |
| C-02 | 每 App 独立密钥验签，吊销不回退全局密钥 | `internal/middleware/appauth.go:234-250` | 经 `router.go:59-74` 注入 `appidentity.ResolveAppSecret` | **已接入** |
| C-03 | App 凭据静态加密（AES-GCM 信封 + key version + 恒定时间比较 + 掩码展示） | `internal/core/appidentity/secret.go:30-94` | 创建/轮换/验签路径 | **已接入** |
| C-04 | 移动 Installation Proof（installation token → key status → ES256 → scoped replay → 可信上下文注入），proof 失败**绝不**回退 HMAC | `internal/middleware/installation_proof.go:119-208` | `router.go:143-152`（mobile/auth）、`router.go:155-165`（logout）、`router.go:171-180`（runtime-config） | **已接入** |
| C-05 | 粗 IP 限流（只用可信对端地址，忽略一切客户端头；后端异常 **fail-closed 503**） | `internal/middleware/ratelimit.go:91-120` | `router.go:134/145/157/173` | **已接入** |
| C-06 | 认证后可信限流（installation claims > user claims > device/IP 回退），后端异常 fail-open | `internal/middleware/ratelimit.go:25-59` | `router.go:90/148/161/176/186/234` | **已接入**（fail-open 见 D-05） |
| C-07 | 可信代理边界（默认谁都不信；非法配置 fail-closed 退回不信任） | `internal/router/router.go:279-294` | 启动期 | **已接入** |
| C-08 | 请求体硬上限（`http.MaxBytesReader`，chunked 也受限） | `internal/middleware/bodylimit.go:13-20` | mobile 32 KiB `router.go:39,134,146,158,174`；proof 二次 16 KiB `installation_proof.go:33,165-172`；支付回调 1 MiB `core/payment/handler.go:21,57-65`；上传 50 MiB `module/file/file.go:19,47-50` | **已接入** |
| C-09 | App Token（`X-App-Token`）+ 能力守卫（默认拒绝）+ **原子配额消费** | `internal/middleware/appauth.go:148-227` | **仅** `router.go:247` 的 `paymentApp` 组 | **部分接入**（见 D-01） |
| C-10 | 应急开关（DB backed，实例内 ≤5 s 生效） | `internal/module/admin/feature_switch.go:9,23-45`；端口 `middleware/appauth.go:104-119` | 组级：`router.go:247`（payment）；handler 内：`module/file/file.go:37,80`（upload）、`module/runtimeconfig/handler.go:35`（runtime-config） | **已接入** |
| C-11 | 成本账本 + 原子预算预留（80/95/100% 告警，100% 自动开应急开关） | `internal/core/cost/*`；调用点 `core/payment/service.go:164-179` | payment charge / 通知外部投递 / AI Gateway | **部分接入**（refund 无账本，见 §7） |
| C-12 | 管理面与用户面令牌彻底分离（AdminToken 只认 `token_type=admin && scope=admin`） | `internal/middleware/auth.go:44-51`、`admin_guard.go:20-40` | `router.go:232-237` | **已接入** |
| C-13 | RBAC 权限路由 + 首登整改 + 高危端点 TOTP | `internal/middleware/rbac.go:25-152`、`firstlogin.go:18`、`totp.go:16` | `router.go:237-249`（含 `payment.manage` `core/payment/handler.go:26-43`） | **已接入** |
| C-14 | 幂等键（作用域取可信 claims） | `internal/middleware/idempotent.go:28` | `router.go:186,236` | **已接入** |
| C-15 | 会话轮换 / refresh 复用即撤销家族 / proof 绑定 | `internal/core/identity/session_rotation_test.go:137-216`、`proof_bound_test.go:17-90`、`r9_security_test.go:32-227` | mobile auth 链 | **已接入** |
| C-16 | 第三方密钥静态加密与在线轮换（`SECRET_KEY_PREVIOUS`） | `internal/pkg/secretcrypto/secretcrypto.go:19-67` | AI / payment / storage provider 配置 | **已接入**（旧明文列未清，见 D-06） |
| C-17 | 支付渠道 live/sandbox 闸门：`mode` 缺省一律 sandbox；live 无真实 adapter 直接报错，**不静默降级** | `core/payment/service.go:56-61`、`core/payment/provider.go:88-108` | 下单/回调解析 | **已接入** |
| C-18 | 渠道回调验签（WeChat v3 / Stripe / Apple JWS，含时间窗口与伪造拒绝） | `core/payment/gateway_test.go:364-437,516-574,720-821` | `router.go:254-256` | **已接入**（存在空配置回退风险，见 D-04） |
| C-19 | 静态安全守卫 Sentinel（SR-001/002/003/004/006/011/012/013，全部 blocking） | `tools/sentinel/main.go:47-56` | `Makefile:44,52`；CI `.github/workflows/quality.yml:52-53` | **已接入** |
| C-20 | 架构守卫 ArchGuard + Secret Guard（禁 PEM/.env/长密钥字面量） | `tools/archguard`；`.github/workflows/secret-guard.yml:18-47` | CI | **已接入** |

### 1.2 SDK（nebula-flutter-sdk）

| # | 能力 | 实现证据 | 真实接入点 | 生效判定 |
|---|---|---|---|---|
| S-01 | 移动端禁止共享密钥 / client_credentials 静态规则 | `governance/policy.json:38-54`（`SEC-MOBILE-SECRET`、`SEC-CLIENT-CREDENTIALS`） | CI `.github/workflows/governance.yml:21-22` | **已接入** |
| S-02 | 禁止请求体自报 `app_id` | `governance/policy.json:63-70`（`DATA-TRUST-BODY-APP-ID`） | 同上 | **已接入** |
| S-03 | 禁止直连 Provider | `governance/policy.json:55-62`（`ARCH-DIRECT-PROVIDER`） | 同上 | **已接入** |
| S-04 | 密钥字面量扫描 | `tool/secret_scan.dart:111` | `governance.yml:24` | **已接入** |
| S-05 | 日志脱敏（保留前 4 字符 + 长度标记；仅记录 rid/endpoint/result/耗时） | `lib/src/foundation/logging.dart:84-114` | `lib/src/transport/http_transport.dart` 日志出口 | **已接入** |
| S-06 | 本地存储命名空间强隔离（`environment/app_id[/user_id]/key`，段内禁 `/` 与 NUL） | `lib/src/storage/storage_namespace.dart:24-73` | token store / cache / consent | **已接入** |
| S-07 | Installation 私钥不出平台安全存储（只持 `privateKeyRef` 句柄） | `lib/src/auth/key_store.dart:14-50` | `lib/src/auth/auth_proof.dart` / `proof.dart` | **已接入**（宿主实现待接） |
| S-08 | access token 只在内存、不落盘、不记日志 | `lib/src/capabilities.dart:10-12` | `lib/src/auth/session_auth.dart` | **已接入** |
| S-09 | 安全关键配置**绝不** stale 兜底 | `lib/src/config/config_client.dart:277`（`if (cfg.hasSecurityCritical) return false;`） | 配置缓存路径 | **已接入** |
| S-10 | Asset / Notification / Payment / AI 均为**空 marker 接口** | `lib/src/capabilities.dart:46-56` | 无 | **未实现（刻意）**——是本 Story 不得提前设计 Asset Contract 的直接依据 |

---

## 2. MUST-WITH-STORY vs DEFER-TO-S7

判定原则：**能力必须与其第一个真实调用点同批落地**（MUST-WITH-STORY）；纵深防御、规模化与可观测性推迟到 S7（DEFER-TO-S7）。每个后置项都写明触发 Sprint 与验收。

### 2.1 MUST-WITH-STORY（共 6 项）

| ID | 项 | 归属 Story | 缺陷证据 | 与 Story 同批的验收 |
|---|---|---|---|---|
| M-01 | **Asset owner scope 可信化**（详见 §8） | Asset Story（ADR-ASSET-001 COMPLETED 之后） | `module/file/file.go:41,62-63,73`、`file.go:84-91`、`pkg/storage/storage.go:60-72,81-87` | `owner_id/owner_type` 只允许来自已验证 session/App 上下文；伪造 owner 的上传 100% 拒绝；`GET /files/:file_id/url` 对非 owner 100% 拒绝；新增 `go test ./internal/router -run TestAssetOwnerScope` 绿 |
| M-02 | Asset **capability + quota 守卫接入** | 同 Asset Story | `RequireCapabilityQuota` 仅挂在 `router.go:247` payment 组，`/files` 组无 App 守卫（`router.go:213-217`） | `/files/*` 进入 App 身份组；能力未授权默认拒绝；配额原子消费失败时**不**调用 Storage Provider |
| M-03 | Presign 绑定与输入净化 | 同 Asset Story | `pkg/storage/storage.go:101-129`（`filename` 直拼 objectKey、`mime` 被 `PresignPut` 丢弃 `provider_s3.go:74`、声明 size 未在 PUT 侧强制） | presign 绑定 user+app+asset+permission+expire（SR-004）；filename 白名单化；Content-Type 参与签名；服务端校验实际对象大小 |
| M-04 | Payment **live refund 闸门**（不实现真实退款，只加闸） | Payment Story（ADR-PAYMENT-REFUND-001） | `core/payment/service.go:187-208` 无 Provider 调用；`provider.go:16-23` 接口无 `Refund` | live 模式下 `Refund()` 必须 100% 拒绝并返回明确错误；sandbox 下保留本地标记但响应体显式标注 `channel_refunded=false` |
| M-05 | 回调**原子幂等**闭环 | Payment Story（ADR-PAYMENT-RECON-001 的前置） | `core/payment/service.go:230-249` 为「查→更新→插入」三段非事务 | 订单条件更新与唯一回调流水同事务；`channel_tx_no` 唯一约束；重复事件 N=10 只产生 1 条 CALLBACK 流水 |
| M-06 | 新公共方法必须回答 SR-020 / SDK §7 七问 | 任何新增能力 Story | `docs/CODING_RULES_SECURITY.md:272-282`；`nebula-flutter-sdk/docs/02_SECURITY_MODEL.md:70-81` | PR 模板中七问全部作答，否则不合入 |

### 2.2 DEFER-TO-S7（共 8 项，均带触发 Sprint 与验收）

| ID | 后置项 | 现状证据 | 触发 Sprint | 验收（可判定） |
|---|---|---|---|---|
| D-01 | 通知 / AI / 资源路由接入 App 身份组与配额 | `router.go:218,243-245` 未挂 `AppToken/RequireCapabilityQuota`；`PRODUCTION_READINESS_AUDIT_2026-08-03.md:58-68` P0-1 | **S7**（若 Notification/AI Story 提前落地，则随该 Story 提前为 MUST） | 每条高成本路由均可枚举其 capability；未授权 App 100% 403；配额耗尽时外部 Provider 调用次数 = 0 |
| D-02 | 凭据/能力撤销的跨实例即时性 | 进程内 60 s TTL cache（`AUDIT:134` P1-6）；App Token 能力快照最长陈旧 1 h（`AUDIT:135` P1-7） | **S7** | 撤销后 ≤5 s 在**全部**实例生效；高风险能力走实时版本校验；多实例回归用例覆盖 |
| D-03 | 高成本接口独立资源池 | 通知发送/重投与支付下单/回调共用 100/min 基线（`AUDIT:131` P1-3） | **S7** | 高成本池与普通池键空间隔离；打满高成本池时普通登录/配置路径成功率 ≥99% |
| D-04 | 回调空配置回退语义收紧 | `core/payment/service.go:213-218` 注释自承「拿空配置只会解析出沙箱 Provider，线上等于跳过验签」 | **S7**（live 渠道启用前必须先行） | live 渠道无启用配置时回调 **fail-closed**；sandbox/MOCK 行为不变；用例覆盖「配置被停用后回调必须拒绝」 |
| D-05 | 资金/高风险路径限流 fail-closed | `middleware/ratelimit.go:28-32` 限流后端异常时放行 | **S7** | 支付/退款/上传路径在限流后端不可用时返回 503；普通读路径保持 fail-open；两类路径各 1 条回归用例 |
| D-06 | 历史明文密钥列清理 | `AUDIT:84-94` P0-3；`internal/model/file.go:31-32` 旧 `access_key`/`secret_key` 列仍在 | **S7**（与 M3 发布候选同批） | 旧明文列全表为空并 DROP；管理端只返回 `*_set`/前缀；审计 before/after 不含明文 |
| D-07 | HTTP Server 超时与 liveness/readiness 分离 | `AUDIT:138-139` P1-10/P1-11 | **S7** | `ReadHeader/Read/Write/Idle` 超时全部配置；`/live` 只查进程、`/ready` 查依赖与迁移状态 |
| D-08 | 输入长度/数量上限治理补齐 | `AUDIT:130` P1-2（AI Prompt、支付 `subject`/`reason`、批量 IDs 仍缺；通知已补） | **S7**（AI/Payment Story 若提前则随之提前） | 每个客户端输入字段有显式上限；超限在业务与外部调用前拒绝；DTO 级用例覆盖 |

**不列入的项（避免为不存在的入口编造任务）**：`CODING_RULES_SECURITY.md:113-122` 的 SR-008「意见反馈防灌水」在 Authority 树中**无对应模块与路由**（`internal/module/` 下无 feedback 包，`router.go` 无 feedback 端点）。因此本报告**不**为其创建任何实现任务；SR-008 仅在未来真实新增反馈入口时按 M-06 走七问流程。

---

## 3. 最低安全门槛（8 项，全部当前可执行）

约束：≤8 项、可执行。以下命令均在 Authority 树中已存在且已进 CI，无需新建工具。

| Gate | 门槛 | 可执行命令 | 规则/证据 |
|---|---|---|---|
| G1 | 密钥不入码 | `cd flypost_backend && make sentinel`（SR-012）；`.github/workflows/secret-guard.yml`；`cd nebula-flutter-sdk && dart run tool/secret_scan.dart` | `tools/sentinel/main.go:54`；`secret-guard.yml:18-45`；`tool/secret_scan.dart:111` |
| G2 | 移动端无共享密钥、无 client_credentials | `dart run tool/governance.dart` + `dart run tool/governance_test.dart` | `governance/policy.json:39-54`；`tool/governance_test.dart:84-96` |
| G3 | 禁止直连 Provider（AI/OSS/渠道） | `make sentinel`（SR-003/SR-004）+ `dart run tool/governance.dart`（`ARCH-DIRECT-PROVIDER`） | `tools/sentinel/main.go:49,51`；`policy.json:55-62` |
| G4 | 可信 scope 不来自请求体 | `dart run tool/governance.dart`（`DATA-TRUST-BODY-APP-ID`）+ `go test ./internal/router -run 'TestRuntimeConfigPlatformFromInstallationTrustedRecord'` | `policy.json:63-70`；`router/runtime_config_http_test.go:260`；SR-014 `CODING_RULES_SECURITY.md:193-199` |
| G5 | 公网入口限流与中间件档位登记 | `make sentinel`（SR-006）+ `go test ./internal/router -run 'TestRouteInventoryMiddlewareClasses\|TestMobileAuthTargetChainMounted\|TestTrustedProxyMisconfigFailsClosed\|TestAbuseIsolation'` | `tools/sentinel/main.go:52,334`；`route_inventory_test.go:30,111`；`trusted_proxy_test.go:121`；`abuse_isolation_test.go:33` |
| G6 | 认证链闭环与越权隔离 | `go test ./internal/core/identity/... ./internal/core/installation/... ./internal/router -run 'Proof\|Rotation\|Refresh\|Isolation\|Closure\|AdminGuard'` | `r9_security_test.go:32-227`；`proof_bound_test.go:17-90`；`session_rotation_test.go:137-216`；`admin_isolation_http_test.go:60`；`mobile_closure_http_test.go:122,221`；`http_proof_flow_test.go:45,144,167`；`router_test.go:83` |
| G7 | 应急开关可无发版关闭 | `go test ./internal/router -run 'TestRuntimeConfigKillSwitch'` | `runtime_config_http_test.go:238`；`feature_switch.go:9,23-45`；SR-015 `CODING_RULES_SECURITY.md:203-212` |
| G8 | 无 SQL 拼接、无敏感日志 | `make sentinel`（SR-011/SR-013） | `tools/sentinel/main.go:53,55`；SR-011/SR-013 `CODING_RULES_SECURITY.md:157-189` |

> 门槛以外的一切安全工作都属于 §2 的 MUST-WITH-STORY 或 DEFER-TO-S7，不得以「安全」为由扩大到主链之外。

---

## 4. Asset / Auth / Payment 最低安全验收

### 4.1 Asset（**当前不实现**，仅定义验收；Story 开工前置 = `ADR-ASSET-001` COMPLETED）

| # | 最低验收 | 判定方式 |
|---|---|---|
| A-1 | `owner_id`/`owner_type` 只能来自已验证上下文，请求体/表单值一律忽略 | 伪造 owner 的上传/presign 100% 拒绝 |
| A-2 | 读路径按 owner 收敛 | 非 owner 请求 `GET /files/:file_id/url` 100% 拒绝（403/404），不得返回预签名 URL |
| A-3 | 私有资源不下发永久公开 URL；presign 有效期有界 | 现状 GET 3600 s（`provider_s3.go:70`）、PUT 900 s（`storage.go:125`）保持并显式登记 |
| A-4 | 上传/下载受应急开关与 App 配额双重约束 | 开关打开后 ≤5 s 上传/presign 100% 拒绝（现状已具备 `file.go:37,80`）；配额耗尽时 Storage Provider 调用次数 = 0（**待补**） |
| A-5 | 单文件大小上限在服务端与直传两侧一致生效 | 现状服务端 50 MiB（`file.go:19,47-50`）；直传侧仅校验声明值（`storage.go:96-99`）→ 必须补实际对象大小校验 |

### 4.2 Auth（**已基本达标**，验收为「不得回退」）

| # | 最低验收 | 现状证据 |
|---|---|---|
| U-1 | proof 失败绝不回退 legacy HMAC | `installation_proof.go:27,119-208`（已达标） |
| U-2 | 未认证入口只用不可伪造的对端 IP 限流，且 fail-closed | `ratelimit.go:91-120`（已达标） |
| U-3 | refresh 单飞 + 复用即撤销家族 + refresh 不能当 access | `r9_security_test.go:32-134`（已达标） |
| U-4 | 管理面令牌与用户面令牌不可互换 | `auth.go:44-51`、`router.go:227-237`、`router_test.go:83`（已达标） |
| U-5 | proof replay 作用域 = `app_id + installation_id + nonce`，存储不可用时拒绝而非放行 | `installation_proof.go:189-200`（已达标） |
| U-6 | access token 内存态、不落盘、不入日志 | SDK `capabilities.dart:10-12`、`logging.dart:84-114`（已达标） |

### 4.3 Payment（**HIGH-RISK PARTIAL**，验收为「开通 live 前必须全绿」）

| # | 最低验收 | 现状 |
|---|---|---|
| P-1 | live 模式无真实 adapter 时下单直接报错，不静默降级 sandbox | **已达标** `provider.go:95-107` |
| P-2 | App scope 只从可信上下文注入 | **已达标** `handler.go:136-137,146-148,170-171` |
| P-3 | 回调 body 上限先于验签 | **已达标** `handler.go:57-65` |
| P-4 | 回调状态更新与流水写入原子幂等 + 渠道事件号唯一 | **未达标** `service.go:230-249`（M-05） |
| P-5 | live refund 必须调用渠道并走 `refund_pending → refunded/failed` 状态机 | **未达标** `service.go:187-208`、`provider.go:16-23`（M-04 先加闸） |
| P-6 | 存在可运行的对账作业与差异报表 | **未达标**：Provider 接口无 `Reconcile`，代码树中无对账作业（`core/payment/` 仅 `service/repository/handler/gateway/provider/{wechat,stripe,apple}`） |
| P-7 | refund 也进成本账本与审计 | **未达标** `service.go:188-208` 无 `cost.Record` |
| P-8 | 订阅授予与支付事实绑定 | **未达标** `service.go:259-272` 直接以 `Status:1` 写入并接受客户端 `expire_at`（当前 `Subscription` 无下游消费方，仅 `core/payment` 与 `model` 引用，故定级 P1 而非 P0） |

---

## 5. 旧安全 WIP 对账（Keep / Adapt / Review Later / Candidate Remove）

以下为两棵 Authority 树中当前**未提交**的改动与历史遗留安全实现的处置结论。

### 5.1 未提交改动（dirty files）

| # | 对象 | 事实 | 结论 |
|---|---|---|---|
| W-01 | `nebula-flutter-sdk` `lib/src/**` 共 10 个文件（含 `auth/session_auth.dart`、`foundation/logging.dart`、`foundation/sha256.dart`、`transport/http_transport.dart`、`analytics/consent.dart`、`storage/cache_storage.dart`、`config/*`） | 逐行 diff 核对：**全部为 `dart format` 换行重排，零语义变更**（例：`logging.dart` 仅 `redactValues` 签名折行；`sha256.dart` 仅 `s0/s1` 表达式折行） | **KEEP**。CI `governance.yml:25` 有 `dart format --set-exit-if-changed .` 门禁，不落盘反而挂 CI |
| W-02 | `nebula-flutter-sdk` `test/**` 4 个文件 + `tool/api_surface.dart` + `tool/governance_test.dart` | 同为格式重排；`governance_test.dart` 仅字符串续行缩进变化 | **KEEP** |
| W-03 | `flypost_backend` `sdk/dart/lib/src/{app,auth,client,notification,payment}.dart` | 同为格式重排（构造器初始化列表缩进、参数折行），零语义变更；但该目录处于 MA0-B01/C01 记录的 **Quarantine** 状态 | **REVIEW LATER**：格式改动本身无害，但该 SDK 的归属与去留须由 S1 Contract 决策后再处置 |

### 5.2 历史遗留安全实现

| # | 对象 | 事实 | 结论 |
|---|---|---|---|
| W-04 | `flypost_backend/sdk/dart` 在**客户端**持有 App Secret 并本地 HMAC 签名（`sdk/dart/lib/src/client.dart:19,43-53`） | 直接抵触 `nebula-flutter-sdk/docs/02_SECURITY_MODEL.md:17` 与 SDK 守卫 `SEC-MOBILE-SECRET` | **ADAPT**：明确重定位为「接入方**服务端** SDK」，禁止任何移动分发；若无服务端消费者则转 **CANDIDATE REMOVE** |
| W-05 | `module/file/file.go:73` 的 `_ = uid`（读取登录用户后丢弃） | 该行是 owner-trust P0 的直接载体 | **CANDIDATE REMOVE**：Asset Story 中必须删除并替换为可信 scope 注入 |
| W-06 | `core/payment/service.go:187-208` 本地 `Refund()` | 无渠道调用、无状态机、无账本 | **ADAPT**：保留为 admin-only 账务标记，但必须先加 live 闸门（M-04），不得以现状进入 live |
| W-07 | `core/payment/provider.go:144-181` `GatewayProvider` sandbox 占位 | 显式 sandbox，且 `Resolve` 不静默降级（`provider.go:95-107`） | **KEEP**：这是当前唯一防止「以为接了真网关」的护栏 |
| W-08 | `core/payment/service.go:213-218` 回调查不到启用配置时回退**空配置** | 注释自承 live 下等于跳过验签 | **ADAPT**（触发：D-04，S7 / live 渠道启用前） |
| W-09 | `middleware/ratelimit.go:28-32` 限流 fail-open | 普通路径可用性取舍合理，资金路径不可接受 | **REVIEW LATER**（触发：D-05，S7） |
| W-10 | 旧明文密钥列 `api_key`/`config_json`/`asset_storage_config.access_key|secret_key`（`internal/model/file.go:31-32`） | 信封字段已并行落地（`:33-38`），旧列仅作迁移读取 | **CANDIDATE REMOVE**（触发：D-06，S7） |
| W-11 | `middleware.RequireCapability` / `IncrementEntitlementUsage` 早期「定义了但没调用」的形态 | E1 已改为原子 check-and-consume 并接到 payment 组（`appauth.go:199-217`、`router.go:247`） | **KEEP**（已闭环，勿重复造轮子） |
| W-12 | SDK `NebulaAsset/NebulaNotification/NebulaPayment/NebulaAi` 空 marker（`lib/src/capabilities.dart:46-56`） | 契约冻结前刻意留空 | **KEEP**：在对应 Contract 冻结前**禁止**填充任何成员 |

---

## 6. S7 量化回归场景

全部场景给出**可判定的数字阈值**，阈值取自 Authority 树中的真实常量。

| ID | 场景 | 量化阈值 | 常量出处 |
|---|---|---|---|
| R-01 | 未认证入口粗 IP 限流 | `/api/v1/mobile/auth/*` 第 61 个请求/分钟必须 429；同 IP 携带 100 个不同 `X-Device-Id` / `X-Forwarded-For` 仍落同一桶（换头有效桶数 = 1） | `router.go:145`；`ratelimit.go:107-120` |
| R-02 | 认证后限流档位 | `/api/v1` authed 第 601 次 429；mobile proof 组第 241 次 429；logout 组第 481 次 429；`/api/v1` 设备层第 101 次 429 | `router.go:186,148,176,161,90` |
| R-03 | body 硬上限 | mobile 32 769 B 拒绝；proof 16 385 B 拒绝；支付回调 1 048 577 B 拒绝（HTTP 413）；上传 52 428 801 B 拒绝 | `router.go:39`；`installation_proof.go:33`；`payment/handler.go:21`；`file/file.go:19` |
| R-04 | 防重放 | 同 `(app_id, installation_id, nonce)` 第 2 次必须 12001；同 `X-Nonce` 在 5 min 窗口内第 2 次必须 40001 | `installation_proof.go:189-200`；`signature.go:53-58` |
| R-05 | fail-closed 语义 | Redis 不可用：粗 IP 限流返回 503（成功率 0%）、replay 存储不可用返回 12001（成功率 0%）；非法 `trusted_proxy_cidrs` 启动后信任代理数 = 0 | `ratelimit.go:94-97`；`installation_proof.go:191-195`；`router.go:288-293` |
| R-06 | 会话并发安全 | N=50 并发 refresh，成功恰好 1、其余全部撤销家族；refresh token 充当 access 的成功率 = 0% | `r9_security_test.go:32-134` |
| R-07 | 越权隔离 | user token 访问 `/admin/*` 成功率 = 0%；admin token 访问用户面成功率 = 0%；跨 App 同 `installation_id` 碰撞数 = 0 | `router_test.go:83`；`admin_isolation_http_test.go:60`；`installation/service_test.go:182` |
| R-08 | 流量舱壁 | 高成本入口打满时，bootstrap/登录/runtime-config 成功率 ≥99%（已有基线用例：AI 洪泛不消耗 bootstrap 桶） | `abuse_isolation_test.go:33` |
| R-09 | 应急开关时效 | 写入 `emergency.<name>_disabled=1` 后，单实例 ≤5 s 内对应入口拒绝率 = 100%（payment / notification / ai / upload / runtime-config 五个开关逐一验证） | `feature_switch.go:9`；`AUDIT:206`；`runtime_config_http_test.go:238` |
| R-10 | 资金一致性（**S7 新增，当前 0 覆盖**） | live 模式 1 000 笔订单：平台流水与渠道账单差异笔数 = 0、金额差 = 0；同一回调事件重投 10 次只产生 1 条 CALLBACK 流水；Provider 无 `Refund` 实现时 live refund 拒绝率 = 100%（当前 0%） | 目标态；缺口证据 `service.go:187-249`、`provider.go:16-23` |
| R-11 | Asset owner scope（**S7 新增，当前 0 覆盖**） | 用户 B 读用户 A 的 `file_id` 成功率 = 0%（当前 100%）；伪造 `owner_id` 上传拒绝率 = 100%（当前 0%） | 目标态；缺口证据 `file.go:41,62-63,73,114-126`、`storage.go:81-87` |
| R-12 | 成本止损 | 预算达 100% 后，对应资源的外部 Provider 调用次数 = 0，且应急开关自动置位 1 次（幂等，重复跨阈不重复告警） | `AUDIT:157`；`core/cost/*`；`payment/service.go:164-166` |

---

## 7. Payment 分项安全等级

> **本节明确声明：Payment 整体 = HIGH-RISK PARTIAL，禁止表述为 production-ready 或「已生产闭环」。** refund 为本地态、reconciliation 不存在。

| 分项 | 等级 | 判据（证据） | 可否进 live |
|---|---|---|---|
| **charge（下单）** | **PARTIAL-OK** | 渠道白名单先于 DB 访问（`service.go:127-130`）；live 无 adapter 直接报错不静默降级（`provider.go:95-107`）；App/User scope 来自可信上下文（`handler.go:136-137`）；预算预留 + 成本账本（`service.go:164-179`）；外呼 15 s timeout + 响应 1 MiB 上限（`AUDIT:45`）。**缺口**：`context.Background()` 不传播请求取消（`service.go:167`）；`subject` 无长度上限（`service.go:35`） | 补齐 D-08/P1-5 后可评估 |
| **callback（回调）** | **HIGH-RISK PARTIAL** | 验签能力真实存在且能拒伪造（WeChat/Stripe/Apple，`gateway_test.go:364-437,516-574,720-821`）；body 上限先于验签（`handler.go:57-65`）；错误码映射避免自我 DDoS（`handler.go:187-198`）。**阻断缺口**：①「查→更新→插入」三段非事务，并发回调可重复记账或半完成（`service.go:230-249`）；② 无渠道事件号唯一约束；③ 查不到启用配置时回退空配置 → live 下等于跳过验签（`service.go:213-218`，注释自承） | **否** |
| **subscription（订阅）** | **NOT-CLOSED** | scope 已可信注入（`handler.go:170-171`）；`cancelSubscription` 仅注册在 admin RBAC 组，客户端无取消入口（`handler.go:42` vs `handler.go:46-51`）。**缺口**：`CreateSubscription` 直接以 `Status:1` 授予且接受客户端 `expire_at`，与支付事实无绑定（`service.go:259-272`）；`CancelSubscription` 未校验 app/user scope（`service.go:273-279`）。当前 `Subscription` 无任何下游权益消费方（全库引用仅 `core/payment/*` 与 `model/payment.go`），故实际影响限于数据污染与归因错误 → **定级 P1，非 P0** | **否** |
| **refund（退款）** | **LOCAL-ONLY / NOT-CLOSED（最高风险项）** | `Refund()` 全部行为 = `UpdateOrderStatus(2)` + `CreateTransaction("REFUND")`，**无任何 Provider 调用**（`service.go:188-208`）；`Provider` 接口根本没有 `Refund` 方法（`provider.go:16-23`）；无 live/sandbox 闸门、无 `refund_pending` 状态机、无重试/查询、无成本账本记录。后果：**平台显示已退款而资金未退**（`AUDIT:96-102` P0-4） | **否**（M-04 先加硬闸） |
| **reconciliation（对账）** | **MISSING（能力不存在）** | `Provider` 接口无 `Reconcile`（`provider.go:16-23`）；`core/payment/` 下无任何对账作业或差异表；`AUDIT:151` 明确「退款/对账闭环未完成」 | **否** |

**结论**：Payment 可用于 sandbox 联调与契约验证；**任何 live 资金流开通都必须先关闭 P-4/P-5/P-6 三项**，并通过 R-10 量化回归。

---

## 8. Asset：当前 owner-trust P0 与未来最低门槛

### 8.1 P0-ASSET-OWNER-TRUST（证据链）

| 环节 | 证据 | 缺陷 |
|---|---|---|
| 取到了可信身份 | `module/file/file.go:41` `uid, _ := middleware.GetUserID(c)` | — |
| 却丢弃了它 | `module/file/file.go:73` `_ = uid` | 可信身份未参与任何决策 |
| 改用客户端自报 | `module/file/file.go:62-63` `c.PostForm("owner_type")` / `c.PostForm("owner_id")` | 上传归属可任意伪造 |
| presign 同样自报 | `module/file/file.go:84-91`（`owner_type`/`owner_id` 来自 JSON body） | 直传凭证归属可任意伪造 |
| 原样落库 | `pkg/storage/storage.go:60-72`（Upload）、`:109-121`（Presign） | 伪造值成为持久事实 |
| 读路径无任何 owner 校验 | `module/file/file.go:114-126` + `pkg/storage/storage.go:81-87`（`GetURL` 只按 `file_id` 查后直接返回预签名 URL） | 任意登录用户可读**任意** `file_id` 的私有对象（水平越权 / IDOR） |
| 数据模型缺字段 | `internal/model/file.go:6-19`：`asset_object` 只有 `owner_id`/`owner_type`，**无** `app_id`/`visibility`/`expire_at`/`status` | 无法表达 SR-005 要求的访问策略 |
| 规则依据 | SR-014 `CODING_RULES_SECURITY.md:193-199`（禁止信任 body 自报 scope）；SR-004/SR-005 `:59-82`（presign 必须绑定 user/tenant/product + permission + expire） | 明确违规 |
| 现有缓解 | `/files/*` 挂在 `authed` 组（`router.go:186,213-217`），需登录 + 600/min 限流 + 幂等；上传受 50 MiB 与 `upload` 应急开关约束（`file.go:19,37,47-50`） | 仅将风险从「匿名」降为「已登录用户之间」，**不改变 P0 定级** |
| 无回归覆盖 | `internal/router/*_test.go` 与 `internal/module/file/` 下**无任何** owner scope / IDOR 用例 | 缺口不可被 CI 发现 |

**定级：P0（水平越权 + 归属伪造）。** 不是密钥泄露，不是资金错误，但属于「越权」类。

### 8.2 未来最低门槛（capability / quota / emergency）

以下是 Asset Story 开工时**必须同批满足**的最低门槛，**不构成 Asset Contract**（接口形态、DTO、路由命名一律留给 `ADR-ASSET-001` 与后续 Contract Story）：

| 维度 | 最低门槛 | 现状 |
|---|---|---|
| capability | `/files/*`（或其继任路由）必须进入 App 身份组，能力未授权默认拒绝；能力名须进入 `appidentity` 白名单（`appidentity/service_test.go:267` 已有白名单一致性用例） | 缺失（`router.go:213-217` 无 App 守卫） |
| quota | 采用现成的原子 check-and-consume（`middleware/appauth.go:199-217`），配额失败时 **Storage Provider 调用次数 = 0** | 缺失 |
| emergency | 复用现成 `upload` 开关，且下载/presign 也纳入；开关生效 ≤5 s | **上传/presign 已具备**（`file.go:37,80`）；**下载 `url` 未接入**（`file.go:114-126` 无开关判断） |
| 生命周期 | 依 SR-019（`CODING_RULES_SECURITY.md:259-268`）声明临时对象 7 天清理策略与孤儿 `asset_object`（presign 后未真实上传）回收 | 缺失 |
| 可观测 | 下行流量/派生文件成本归因（`AUDIT:150` 明确无） | 缺失（S7，D-01 同批） |

**明确不做**：本报告不定义 Asset 的接口签名、字段、错误码或 SDK 成员。SDK 侧 `NebulaAsset` 保持空 marker（`lib/src/capabilities.dart:47`），在 `ADR-ASSET-001` COMPLETED 前**禁止**填充。

---

## 9. 阻塞判定：只有 P0 才能阻塞 S1–S3

### 9.1 判定规则

依 Task Pack「Forbidden」：不阻塞 S1 Contract，除非发现会导致**密钥泄露 / 越权 / 资金错误**的 P0，且有证据。P1 及以下一律进入 §2 的分类，不得阻塞主链。

### 9.2 本次发现的 P0 级缺陷及其阻塞面

| P0 | 类别 | 是否阻塞 S1–S3 | 理由（证据） |
|---|---|---|---|
| **P0-ASSET-OWNER-TRUST**（§8） | 越权 | **否** | ① `task_board.json:316-320` 已存在硬闸：`ADR-ASSET-001` COMPLETED 前禁止 `Asset SDK` 与 `Upload API` 开工；② MA0-D01：首个 APK 切片仅 runtime-config，Asset 不入切片；③ SDK `NebulaAsset` 为空 marker（`capabilities.dart:47`），S1–S3 交付面不含任何 Asset 调用路径。→ 该 P0 **不在 S1–S3 的交付面上**，且已被既有 gate 围栏。它阻塞的是 **Asset Story 本身**（列为 M-01 MUST-WITH-STORY）与 `/files/*` 的任何生产启用 |
| **P0-PAYMENT-REFUND-LOCAL**（§7 refund 行） | 资金错误 | **否** | ① 触发面仅 admin RBAC `payment.manage`（`payment/handler.go:38`），无客户端入口（`handler.go:46-51`）；② 渠道默认 sandbox 且 live 无 adapter 直接报错（`service.go:56-61`、`provider.go:95-107`），当前不存在真实出金路径；③ Payment 不在首个 APK 切片，SDK `NebulaPayment` 为空 marker（`capabilities.dart:53`）。→ 阻塞的是 **live refund 开通与 M3（S8 发布候选）**，不是 S1–S3 |

### 9.3 结论

> **未发现任何阻塞 S1 Contract 或 S1–S3 的 P0。** S1 Contract 可按 `task_board.json:307-323` 的 `ALLOWED_WITH_CONSTRAINTS` 继续，本 Story 不新增任何 S1 前置条件。两项 P0 级缺陷均已被既有 gate（ADR-ASSET-001 / live-refund 未开通 / 首切片范围）围栏，并已在 §2 转化为带触发点与验收的 MUST-WITH-STORY 项。

---

## 10. 已知限制

1. **未运行任何测试或守卫命令**（Task Pack 为 docs-only）。§3 的 8 个门槛为静态核对命令存在性与 CI 挂载点（`quality.yml:50-53`、`secret-guard.yml`、`governance.yml:21-28`），未验证其当前是否全绿。
2. **未审计 live 渠道 adapter 的密码学细节**（`wechat.go` / `stripe.go` / `apple.go` 仅通过其测试用例名与 `gateway_test.go` 断言确认能力存在，未逐行复核签名实现）。
3. **未做端到端渗透验证**：§8 的 IDOR 结论由 `file.go:114-126` + `storage.go:81-87` 的静态调用链推导（`GetURL` 全路径无任何 owner 参数），未实际发起跨用户请求。
4. **未覆盖 server BFF 与 Admin SPA**：`AUDIT:135-139` 的 BFF 相关 P1（内存限流分裂、key 无清理）已登记为 D-03/D-07 的一部分，但 BFF 仓库不在本 Story 的 Authority 范围内。
5. **两棵树的 dirty 文件未做任何改动**（含 §5 判定为 KEEP 的格式化改动），归属仍待 MA0-Q01 处置。
6. **SR-008（反馈防灌水）刻意留空**：Authority 树无 feedback 模块与路由，按验收要求不编造实现任务。
