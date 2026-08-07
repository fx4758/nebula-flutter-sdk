# MA0-A01 — 平台 API 与跨仓契约事实审计

- Story：MA0-A01（EPIC-GOV / GOV-F1 真实基线，2 SP）
- Owner：Contract Agent（`workbuddy-contract-agent`）
- 审计时间：2026-08-07
- 状态：REVIEW（未验收，按 `reports/README.md` 不置 DONE）

本报告只陈述**代码事实**，不提出实现方案、不修改任何契约。所有结论均带可定位的
文件路径与行号；不使用任何无证据百分比。

---

## 1. 取证口径与事实源

### 1.1 被审计的工作树

| 代号 | 仓库路径 | 分支 | HEAD |
|---|---|---|---|
| **BE-forAI** | `~/Documents/project/forAI/flypost_backend` | `codex/fb-05-router-isolation` | `8ec212f5233e815229965977dedfca7a1ca2ffd0` |
| **SDK** | `~/Documents/project/forAI/nebula-flutter-sdk` | `architect/f0-02-mobile-session` | `279ed5118f1162f461a9fdaa4528bca2c3ddaae2` |
| **BE-Codex**（旁证） | `~/Documents/Codex/2026-08-02/http-192-168-1-3-8000/flypost` | `codex/dev-integration-f2r11` | `de8cf943f75f46bc6d65667fb5f9bd7210705905` |

BE-forAI 与 BE-Codex 是**同一 remote（`git://192.168.1.3:9419/flypost`）的两棵不同工作树**，
在 Asset 能力域上已经发生实质分叉（§7）。本报告以 Task Pack 指定的 `flypost_backend`
（BE-forAI）为 mobile authority；BE-Codex 仅作为「另一处已存在的实现事实」记录，
不作为契约依据。

### 1.2 authority 边界（Task Pack Forbidden 第 3 条）

- mobile authority = 挂在 `/api/v1/mobile/*` 上的路由。
- `/admin/*`（`middleware.AdminToken()` + RBAC）**不计入** mobile authority。
- `authed` 组（`/api/v1/*` + legacy HMAC `Signature()` + user `Token()`）为
  **legacy 客户端面**，与 mobile 组共存但不等价，单独在 §3 列出。

### 1.3 路由分组的中间件继承事实

`internal/router/router.go:89-90`：

```go
api := r.Group("/api/v1")
api.Use(middleware.Signature(), middleware.RateLimit(100, time.Minute))
```

`mobile*` 四个组均以 `r.Group(...)` 注册（`router.go:133 / 143 / 155 / 171`），
**不是** `api.Group(...)`，因此不继承 legacy HMAC `Signature()`。
该结论有机械化守卫：`internal/router/route_inventory_test.go:39-40` 断言
`POST /api/v1/mobile/bootstrap` 与 `GET /api/v1/mobile/runtime-config`
为 public target（不继承 legacy HMAC）。

---

## 2. `/api/v1/mobile/*` 全量路由枚举（BE-forAI）

真实路由表共 **6 个** mobile 端点，无遗漏。

| # | Method | Path | 中间件链（自外向内） | Handler | Service | 路由装配证据 | 端点定义证据 |
|---|---|---|---|---|---|---|---|
| M1 | POST | `/api/v1/mobile/bootstrap` | `CoarseIPRateLimit(100,1m)` → `BodyLimit(maxMobileBodyBytes)` | `installation.Handler.bootstrap` | `core/installation/service.go` | `router.go:133-137` | `core/installation/handler.go:24-26` |
| M2 | POST | `/api/v1/mobile/auth/code/send` | `CoarseIPRateLimit(60,1m)` → `BodyLimit` → `InstallationProof()` → `RateLimit(240,1m)` | `identity.Handler.sendCode` | `core/identity` | `router.go:143-152` | `core/identity/auth_handler.go:38-42` |
| M3 | POST | `/api/v1/mobile/auth/login` | 同 M2 | `identity.Handler.login` | `core/identity` | `router.go:143-152` | `core/identity/auth_handler.go:38-42` |
| M4 | POST | `/api/v1/mobile/auth/refresh` | 同 M2 | `identity.Handler.refresh` | `core/identity` | `router.go:143-152` | `core/identity/auth_handler.go:38-42` |
| M5 | POST | `/api/v1/mobile/auth/logout` | `CoarseIPRateLimit(60,1m)` → `BodyLimit` → `InstallationProof()` → `Token()` → `RateLimit(480,1m)` | `identity.Handler.logout` | `core/identity` | `router.go:155-165` | `core/identity/auth_handler.go:45-47` |
| M6 | GET | `/api/v1/mobile/runtime-config` | `CoarseIPRateLimit(60,1m)` → `BodyLimit` → `InstallationProof()` → `RateLimit(240,1m)` | `runtimeconfig.Handler.GetRuntimeConfig` | `module/runtimeconfig/service.go` | `router.go:171-180` | `module/runtimeconfig/handler.go:22-25` |

### 2.1 中间件档位不变量（F0-R9 P0-1）

`router.go:141-142` 注释与实际 `Use()` 顺序一致：
粗 IP 限流 → body 硬限制 → InstallationProof → 可信 installation 限流 → handler。
即 **proof 通过前不消耗 DB / ES256 / Redis**。M5 在 proof 之后额外插入 `Token()`。

### 2.2 测试证据

覆盖 `/api/v1/mobile` 的测试文件（BE-forAI）：

- `internal/router/route_inventory_test.go` — 路由清单与 legacy HMAC 隔离断言（:39-40, :108-120）
- `internal/router/mobile_closure_http_test.go` — bootstrap → login → refresh → logout 全链路 HTTP 闭环（真实 router.Setup / 真实中间件 / 真实 ES256 验签，见文件头 :26-36）
- `internal/router/http_proof_flow_test.go` — proof 链负例
- `internal/router/runtime_config_http_test.go` — M6 HTTP 层
- `internal/router/mobile_contract_test.go`、`internal/router/abuse_isolation_test.go`、`internal/router/trusted_proxy_test.go`
- `internal/core/installation/handler_test.go`、`internal/core/identity/e2e_flow_test.go`
- `internal/middleware/abuse_isolation_test.go`、`internal/pkg/proof/proof_test.go`

**每个 mobile 端点均有 HTTP 层证据**，M1-M5 有成功路径闭环证据。

---

## 3. 相关客户端路由（非 mobile 组，legacy 客户端面）

以下端点客户端可达，但挂在 `api` 组（继承 legacy HMAC `Signature()`）+ `Token()`，
**不属于 mobile authority**。列出是为了避免 S1 误当作移动端可用面。

| # | Method | Path | 链路 | 证据 |
|---|---|---|---|---|
| L1 | POST | `/api/v1/app/token` | `Signature` + `RateLimit(100)`；client_credentials，服务端换取 `X-App-Token` | `router.go:103`；`core/appidentity/handler.go:44-49` |
| L2 | POST | `/api/v1/files/upload` | `Signature` → `Token` → `RateLimit(600)` → `Idempotent` | `router.go:213-217`；`module/file/file.go:29-32` |
| L3 | POST | `/api/v1/files/presign` | 同 L2 | 同上 |
| L4 | GET | `/api/v1/files/:file_id/url` | 同 L2 | 同上 |
| L5 | GET | `/api/v1/notifications` | 同 L2 | `router.go:218`；`core/notification/handler.go:45-50` |
| L6 | GET | `/api/v1/notifications/unread-count` | 同 L2 | 同上 |
| L7 | POST | `/api/v1/notifications/read` | 同 L2 | 同上 |
| L8 | POST | `/api/v1/notifications/read-all` | 同 L2 | 同上 |
| L9 | POST | `/api/v1/payments/orders` | 同 L2 **+** `AppToken()` + `EmergencySwitch("payment")` + `RequireCapabilityQuota("payment")` | `router.go:247-248`；`core/payment/handler.go:45-51` |
| L10 | GET | `/api/v1/payments/orders/:out_trade_no` | 同 L9 | 同上 |
| L11 | GET | `/api/v1/payments/subscriptions` | 同 L9 | 同上 |
| L12 | POST | `/api/v1/payments/subscriptions` | 同 L9 | 同上 |
| L13 | POST | `/api/v1/payments/callback/:channel` | 仅 `RateLimit(100)`，跳过 Signature（渠道自签名） | `router.go:253-256` |

管理端（**非** authority，仅记录 entitlement 事实所在）：
`/admin/app-capabilities`、`/admin/apps/:app_id/credentials*`、
`/admin/apps/:app_id/entitlements*` — `core/appidentity/handler.go:27-42`，
全部 `permission.PermAppManage`。

### 3.1 关键约束：L1-L12 与 MB-01 冲突

`docs/08_MOBILE_BOOTSTRAP_SESSION_CONTRACT.md:32` 登记 MB-01（P0）：
「all `/api/v1/*` requests require an HMAC App Secret / a public mobile binary cannot
safely use the current entry chain」。
L2-L12 全部位于 HMAC `Signature()` 之下，L9-L12 还额外要求 `AppToken()`（由 L1 用
App Secret 换取）。**因此当前不存在任何一个移动端可安全直连的 Asset / Notification /
Payment 端点**。这是 §8 多个待决策项的根因。

---

## 4. SDK endpoints / fixtures 对账

### 4.1 SDK 侧显式端点常量

| SDK 常量 | 值 | Backend 对应 | 结论 |
|---|---|---|---|
| `SessionEndpoints.login` | `/api/v1/mobile/auth/login` | M3 | **aligned** |
| `SessionEndpoints.refresh` | `/api/v1/mobile/auth/refresh` | M4 | **aligned** |
| `SessionEndpoints.logout` | `/api/v1/mobile/auth/logout` | M5 | **aligned** |
| `ConfigEndpoints.runtimeConfig` | `/api/v1/mobile/runtime-config` | M6 | **aligned** |

证据：`lib/src/auth/session_endpoints.dart:12-14`、`lib/src/config/config_endpoints.dart:10`。

### 4.2 SDK 侧无常量但契约内的端点

| 契约端点 | SDK 常量 | Backend | 结论 |
|---|---|---|---|
| `POST /api/v1/mobile/bootstrap` | **无常量**（`lib/` 内 grep `'/api/v1` 仅命中上表 4 条） | M1 存在且实现完整 | **drift（SDK 侧路径未常量化）** |
| `POST /api/v1/mobile/auth/code/send` | 无常量 | M2 存在 | **drift（同上）** |

`lib/src/auth/installation.dart` 只定义 `BootstrapRequest` 数据结构（:69），
不承载路径；`lib/src/auth/session_auth.dart:76-77` 明确「auth capability does not
perform the bootstrap network call itself」。即 bootstrap 路径当前由调用方（App）
提供，SDK 未冻结。这是事实缺口，不是缺陷判定。

### 4.3 契约声明但 Backend 未注册

| 契约端点 | 声明位置 | Backend 事实 | 结论 |
|---|---|---|---|
| `POST /api/v1/mobile/auth/oauth/login` | `docs/08:83` | 显式**不注册**：`core/identity/auth_handler.go:33-37` 注释「oauth/login 不注册——占位 OAuth 默认关闭（F0-R9，评审 P0-2）」；`route_inventory_test.go:140` 有负例断言 | **placeholder** |
| `POST /api/v1/mobile/auth/device/bind` | `docs/08:86` | 未注册；契约自注「**F0 契约外**（ADR-F008 注记，F1 实现）」 | **missing（已声明为 F1）** |

### 4.4 Fixtures 对账

SDK fixtures 共 14 个文件（`test/fixtures/`）：

| Fixture | Backend 对应结构 | 结论 |
|---|---|---|
| `bootstrap_request.json` | `core/installation/service.go:60-70` `BootstrapRequest`（`app_id, installation_id, platform, app_version, build_number, os_version, locale, region, public_key, attestation, bootstrap_request_id`） | **aligned** |
| `bootstrap_response.json` | `core/installation/service.go:75-84` `BootstrapResult`（`installation_token, expires_at, renew_after, server_time, app_id, installation_id, proof_algorithm, attestation_state, minimum_supported_build, request_id`） | **aligned** |
| `runtime_config/success_snapshot.json` | `module/runtimeconfig/dto.go:21-47`（`revision, server_time, configs{}, features[], version_policy{}, cache_policy{}`） | **aligned** |
| `runtime_config/version_policy_{none,upgrade,forced_upgrade}.json` | `version_policy.action` 三态 | **aligned** |
| `runtime_config/over_limit_snapshot.json` | 快照超限 → 12004 fail fast（`handler.go:27-32` 注释） | **aligned** |
| `runtime_config/error_{12001,12003,12004,40002,50001}.json` | `pkg/errcode` + `response.Err`（HTTP 200 + `{code,data}`） | **aligned** |
| `error_mapping.json` | FB-01 分配 12001-12004 + legacy 10003/30001/40002/50001 | **aligned** |
| `proof_canonical.json` | `internal/pkg/proof`（`proof_test.go`） | **aligned** |

**fixtures 中不存在任何 Asset / Notification / Payment / Entitlement 条目。**

---

## 5. 四分类清单

分类判据：
- **Implemented** — 路由已注册 + handler + service + HTTP 层测试证据齐全。
- **Partial** — 后端已落地但**移动端不可用**（不在 mobile 组 / 需 App Secret / 能力未白名单化），或 SDK 侧无对应实现。
- **Placeholder** — 契约或代码中存在占位，被显式禁用或为空标记接口。
- **Missing** — 契约或 Sprint 计划中需要，但两侧均无实现。

### 5.1 Implemented（6）

M1 bootstrap、M2 code/send、M3 login、M4 refresh、M5 logout、M6 runtime-config。
四个有 SDK 常量的端点全部 aligned；bootstrap/code-send 后端实现完整、SDK 路径未常量化（§4.2）。

### 5.2 Partial（5）

| 项 | 事实 | 缺口 |
|---|---|---|
| Asset（BE-forAI，`module/file`） | L2-L4 三端点在线 | 不在 mobile 组；需 HMAC + user Token（与 MB-01 冲突）；`file.go` 直接 `c.JSON`，不走 `response.OK/Err` envelope；SDK 无实现 |
| Asset（BE-Codex，`module/asset`） | `/assets/upload-ticket`、`/assets/:asset_id/commit`、`/assets/:asset_id/download-ticket` 在线（`router.go:242-249`；`module/asset/handler.go:26-33`） | 不在 mobile 组；需 `AppToken()`；`asset.upload`/`asset.download` **不在** `model.Capabilities()` 白名单（§7.2）；裸 `c.JSON` 非 envelope；BE-forAI 树上不存在 |
| Notification | L5-L8 客户端四端点在线 | 不在 mobile 组；SDK `NebulaNotification` 为空标记接口 |
| Payment | L9-L13 在线，含 `EmergencySwitch` + `RequireCapabilityQuota("payment")` | 不在 mobile 组；强依赖 `AppToken()`；SDK `NebulaPayment` 为空标记接口 |
| Entitlement | 管理端 `GET/PUT/DELETE /admin/apps/:app_id/entitlements`（`core/appidentity/handler.go:39-42`） | 无任何移动端/客户端查询面 |

### 5.3 Placeholder（5）

| 项 | 证据 |
|---|---|
| `POST /api/v1/mobile/auth/oauth/login` | `core/identity/auth_handler.go:33-37`（显式禁用，F0-R9 P0-2） |
| `NebulaAsset` 空标记接口 | `lib/src/capabilities.dart:46-47`（"frozen in Sprint F3"） |
| `NebulaNotification` 空标记接口 | `lib/src/capabilities.dart:49-50`（F3） |
| `NebulaPayment` 空标记接口 | `lib/src/capabilities.dart:52-53`（F4） |
| `NebulaAi` 空标记接口 | `lib/src/capabilities.dart:55-56`（F4） |

### 5.4 Missing（5）

| 项 | 说明 |
|---|---|
| `POST /api/v1/mobile/auth/device/bind` | `docs/08:86` 声明，F0 契约外 |
| `/api/v1/mobile/assets/*`（S1-A02 候选四端点） | 两棵树均无任何 `/api/v1/mobile/assets` 路由 |
| 移动端 Notification 面 | 无 `/api/v1/mobile/notifications*` |
| 移动端 Entitlement 查询面 | 无 `/api/v1/mobile/entitlements*` |
| SDK bootstrap / code-send 端点常量 | `lib/` 内无对应常量（§4.2） |

---

## 6. 四个能力域现状小结

### 6.1 Asset

**分叉状态。** BE-forAI 为 `internal/module/file`（`/files/upload|presign|:file_id/url`，
HMAC + user Token，`maxUploadBytes` 50MB，emergency disabled 检查，迁移止于
`033_runtime_config_policy.sql`，无 asset/file 相关迁移）。
BE-Codex 已**删除** `internal/module/file` 与 `/files` 路由（`ls internal/module/` 无 `file`；
`grep files internal/router/router.go` 无命中），替换为 `internal/module/asset` +
迁移 `042_asset_lifecycle.sql` / `043_asset_quota.sql`。
两者的信任主体、路径、响应格式、数据表**全部不同**。

### 6.2 Notification

后端最完整的客户端能力：列表（游标分页，读取即已读）/ 未读数 / 批量已读 / 一键已读，
另有管理端模板与投递记录（`core/notification/handler.go:20-42`）。
SDK 侧为空接口。无 mobile 组暴露。

### 6.3 Entitlement

无独立能力模块，寄居 `core/appidentity`。事实要点：
- 能力白名单单一事实源 `model.Capabilities()`（BE-forAI `internal/model/app.go:11-25`）：
  `identity, payment, notification, ai, storage, analytics`。
- 授权写入经 `IsValidCapability` 校验（`core/appidentity/service.go:180`）。
- 消费点在中间件 `RequireCapability` / `RequireCapabilityQuota`。
- 客户端**无法查询自身 entitlement**。

### 6.4 Payment

后端链路最完备（AppToken + 应急开关 + 能力配额 + 渠道回调），
`payment` 已在能力白名单内。SDK 侧为空接口。

---

## 7. 跨工作树分歧（S1 必须先解决的前置事实）

### 7.1 差异对照

| 维度 | BE-forAI `8ec212f` | BE-Codex `de8cf94` |
|---|---|---|
| 模块 | `internal/module/file` | `internal/module/asset`（无 `file`） |
| 路径 | `/api/v1/files/upload`、`/presign`、`/:file_id/url` | `/api/v1/assets/upload-ticket`、`/:asset_id/commit`、`/:asset_id/download-ticket` |
| 信任主体 | user `Token()`（HMAC 之下） | `AppToken()` |
| 能力校验 | 无 capability 门 | `RequireCapabilityQuota("asset.upload")` / `RequireCapability("asset.download")` |
| 响应格式 | 直接 `c.JSON` | 直接 `c.JSON` + `{"error":"invalid_request"}` 字符串 |
| 迁移 | 最新 `033` | `039`-`043`，含 `042_asset_lifecycle.sql`、`043_asset_quota.sql` |
| mobile 组 | 否 | 否 |

### 7.2 BE-Codex 侧的能力白名单缺口（实锤）

`internal/router/router.go:245/248` 使用 `asset.upload` / `asset.download`，
但 `internal/model/app.go:11-25` 的白名单为
`identity / payment / notification / ai / storage / analytics`，**不含 asset.\***。
`core/appidentity/service.go:180` 的 `grantEntitlement` 用 `IsValidCapability` 拒绝白名单外
能力，因此这两个能力**无法通过管理端授权**；当前仅由
`internal/testsupport/app_capability_fixture.go:18-36` 在测试中注入。
即 BE-Codex 的 asset 链在生产授权路径上是断的。

### 7.3 mobile 组本身无分歧

BE-Codex `router.go:154/164/176/192` 与 BE-forAI `router.go:133/143/155/171`
的 mobile 四组结构一致。**mobile authority 在两棵树上是收敛的**，分歧只在 Asset 域。

---

## 8. S1-A01 / S1-A02 待冻结问题（12 项，均可决策）

按 Task Pack「输出必须拍板的问题，不直接给实现方案」——以下只陈述**决策点 + 冲突证据 +
现存互斥事实**，不含推荐方案。

| # | 决策点 | 现存互斥事实 | 归属 |
|---|---|---|---|
| Q1 | Asset 能力域的权威实现树 | BE-forAI `module/file` vs BE-Codex `module/asset`（§7.1） | S1-A01 |
| Q2 | 移动端 Asset 是否进入 `/api/v1/mobile/*` 隔离组 | 现存两套实现均不在 mobile 组；S1-A02 候选路径带 `/mobile` 前缀 | S1-A02 |
| Q3 | Asset 的信任主体 | `user Token`（file）/ `AppToken`（asset）/ `InstallationProof`（mobile 组既定链）三者互斥；MB-01 禁止移动端持有 App Secret（§3.1） | S1-A01 |
| Q4 | Asset owner scope 维度 | file 按 user 归属；asset 按 app 归属；mobile 组可提供 app + installation + user 三维可信 claims | S1-A01 |
| Q5 | 端点路径与资源命名 | 候选 `/mobile/assets/uploads` + `/{id}/complete` vs 现存 `/assets/upload-ticket` + `/:asset_id/commit` vs `/files/upload` + `/presign` | S1-A02 |
| Q6 | 响应封装格式 | 平台统一 envelope 为 HTTP 200 + `{code,data}`（`pkg/response/response.go:20-28`）；两套 Asset 实现均绕过 envelope，直接 `c.JSON` + HTTP 状态码 | S1-A02 |
| Q7 | Asset 错误码归属 | 现存 asset/file 不产出数字 errcode；SDK `error_mapping.json` 无 asset 条目；FB-01 已占用 12001-12004 | S1-A02 |
| Q8 | 能力标识与粒度 | 白名单现有 `storage` 单能力；代码实际使用未登记的 `asset.upload` / `asset.download`（§7.2）；二者需二选一或合并 | S1-A01 |
| Q9 | 上传通道语义 | 三条互斥现存路径：服务端中转（`/files/upload`，50MB 上限）、预签名（`/files/presign`）、ticket+commit（`/assets/upload-ticket` + `/commit`） | S1-A02 |
| Q10 | 数据表基线 | `042_asset_lifecycle.sql` / `043_asset_quota.sql` 只存在于 BE-Codex；BE-forAI 迁移止于 `033`。是否承认这两个迁移为 Asset 表基线 | S1-A01 |
| Q11 | 状态集合与现存实现的关系 | S1-A01 计划冻结 8 态（reserved…deleted）；BE-Codex `042_asset_lifecycle.sql` 已落地一套状态字段，二者是否等价需 MA0-C01 补证后拍板 | S1-A01 |
| Q12 | `/files` 下线与兼容窗口 | BE-Codex 已删除 `module/file` 与 `/files` 路由；BE-forAI 仍在线且被 legacy 客户端使用。是否需要兼容期 | S1-A02 |

Q1、Q3、Q8、Q10 是阻塞项：未拍板前 S1-A01 无法定义状态机 owner scope，S1-A02 无法冻结 header 要求。

---

## 9. 已知限制（不用「后续优化」掩盖）

1. 本报告未运行任何测试命令（Task Pack 为文档审计类，Forbidden 禁止修改 Go/Dart 代码）。
   测试证据来自源码与断言内容，非本次执行结果。
2. `042_asset_lifecycle.sql` / `043_asset_quota.sql` 的**表结构字段未逐列展开**，
   Q11 的等价性判定需 MA0-C01（Backend Capability Audit）补齐。
3. 未审计 `flutter NFC Writer` 仓（属 MA0-D01 范围）。
4. 两棵后端工作树均存在未提交改动（BE-forAI `sdk/`、`*.dart` 若干；SDK 仓 `lib/` 若干）。
   本审计**只读**，未触碰，dirty file 归属由 MA0-Q01 裁定。
5. BE-Codex 的 `codex/dev-integration-f2r11` 尚未 fast-forward 进 `Dev`，
   其 asset 实现是否会进入主线未定，Q1/Q10 的答案可能因主线推进而改变。

---

## 10. Handoff Block

```text
Story ID: MA0-A01
Owner: Contract Agent (workbuddy-contract-agent)
Base commit:
  - nebula-flutter-sdk 279ed5118f1162f461a9fdaa4528bca2c3ddaae2 (architect/f0-02-mobile-session)
  - flypost_backend    8ec212f5233e815229965977dedfca7a1ca2ffd0 (codex/fb-05-router-isolation)
  - flypost (Codex wt) de8cf943f75f46bc6d65667fb5f9bd7210705905 (codex/dev-integration-f2r11)
Branch/worktree: nebula-flutter-sdk @ architect/f0-02-mobile-session（未开新分支，docs-only）
Changed paths:
  - docs/multi_agent/reports/MA0_A01_PLATFORM_API_AUDIT.md（新增）
  - docs/multi_agent/task_board.json（仅本 Story 状态行）
  - docs/multi_agent/02_SPRINT_BOARD.md（仅本 Story 状态行）
Deliverables: docs/multi_agent/reports/MA0_A01_PLATFORM_API_AUDIT.md
Contract/API changes: 无（只读审计）
Database changes: 无
Tests executed: 无（文档审计类 Story，Forbidden 禁止改代码；证据为源码取证）
Test result: N/A
Acceptance evidence:
  - 每个 endpoint 有代码路径证据 → §2 表（含 router.go 与 handler 行号）、§3 表
  - 每个 SDK endpoint 有 backend 对应结论 → §4.1（4/4 aligned）、§4.2（2 项 drift）、§4.3（1 placeholder + 1 missing）
  - 区分四类 → §5.1 Implemented 6 / §5.2 Partial 5 / §5.3 Placeholder 5 / §5.4 Missing 5
  - Asset 待冻结问题 ≤12 且均可决策 → §8 共 12 项，每项附互斥事实
  - 无无证据百分比 → 全文使用计数与路径，未出现百分比
Known limitations: §9（5 条）
Security minimum checks:
  - 未引入输入面 / 未改鉴权链 / 未记录任何密钥或令牌值
  - 报告内不含 App Secret、token 明文或 Provider 凭据
Follow-up dependencies:
  - MA0-C01 需补 042/043 表结构逐列事实（解 Q11）
  - MA0-Q01 需裁定两棵后端工作树的 owner 与 dirty file 归属（解 Q1 的前置）
  - S1-A01 阻塞于 Q1/Q3/Q4/Q8/Q10；S1-A02 阻塞于 Q2/Q5/Q6/Q7/Q9/Q12
Architecture Change Request: 无（本 Story 不提出变更，仅登记待拍板问题）
```
