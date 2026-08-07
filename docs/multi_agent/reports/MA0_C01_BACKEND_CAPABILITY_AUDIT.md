# MA0-C01 Backend Asset / Notification / Payment 能力审计

> Owner：Backend Architect Agent（续接 MA0-A01 审计视角，doc-only）
> Status：IN_PROGRESS → REVIEW → CHANGES_REQUIRED → REVIEW rev2 → **DONE（2026-08-07 PASS，rev2 复验通过）**
> 取证方法：静态只读审计，未修改任何 backend 实现 / `sdk/dart/**` / router。

## 0. Authority 声明（修订，回应验收 CHANGES_REQUIRED）

- **唯一 Backend Authority = `flypost_backend`（BE-forAI，base `8ec212f`）**。本报告所有「现状基线」「缺陷来源」「迁移来源」「ADR 选项」均以此树为准。
- **`BE-Codex`（`de8cf94`）已废弃**，仅在本报告 §2 作为**历史对照**出现，用于说明 Asset 域的演进脉络；**不作为候选实现、迁移来源、缺陷来源或 ADR 选项**。

---

## 1. 取证口径与 authority 边界

本任务包要求判断「现有 Backend 能力哪些可适配为 Platform API，哪些只是产品或管理骨架」。
取证遵循 **MA0-A01 §1.2 authority 边界** 与 Task Pack Forbidden 第 3 条（不把管理端 API 当移动端契约）：

| 客户端面 | 信任主体（实际，按端点而异） | 是否 mobile authority | 审计中的定位 |
|---|---|---|---|
| `mobile` 组（`/api/v1/mobile*`） | **bootstrap 无 Proof**；login/refresh/logout = `InstallationProof`；logout 叠加 user `Token`。**当前 mobile 组无 AppToken** | ✅ 是 | 不在本任务范围（见 A01） |
| `authed` 组（`/api/v1/*` + HMAC + user Token） | user `Token()` | 否（legacy 客户端） | Asset(file)/Notification client 落点 |
| `paymentApp` 组（AppToken + EmergencySwitch + RequireCapabilityQuota） | `AppToken()` | 否 | Payment client 落点 |
| `adminG`（`/admin`，AdminGuard） | admin session | 否（管理端） | 仅作「骨架 / 产品」判定参考 |

> 修正（回应验收）：原版将 mobile 信任写作「`InstallationProof + AppToken`」不正确。当前 `/api/v1/mobile/*` 没有 AppToken——bootstrap 连 Proof 都没有；login/refresh 等仅用 `InstallationProof`；logout 再叠加 user Token。

**关键结论前置**：三域在**唯一 Authority `flypost_backend`** 上的现状如下；BE-Codex 的历史分叉仅作 §2 对照。Notification 与 Payment 在 Authority 上的注册面与能力结构已收敛（BE-Codex `router.go:250/280-281` 与 BE-forAI `router.go:218/248` 同构，但 BE-Codex 已废弃，不计为分叉事实）。故本报告以 `flypost_backend` 为唯一基线，Asset 域并陈历史对照。

---

## 2. Asset 域（核心，含历史对照）

### 2.1 `flypost_backend` `internal/module/file`（Authority 现状）

| 维度 | 证据 |
|---|---|
| 路由 | `file.go:36` `POST /files/upload`；`file.go:79` `POST /files/presign`；`file.go:114` `GET /files/:file_id/url` |
| 注册面 | `router.go:217` `fileH.Register(authed.Group("/files"))` → **legacy authed 组（HMAC + user Token），非 mobile、非 admin** |
| 大小上限 | `file.go:19` `maxUploadBytes = 50 << 20`（50MB） |
| 应急开关 | `file.go:37/80` `middleware.IsEmergencyDisabled("upload")` |
| 能力门 | **无** `RequireCapability*` |
| 存储 | `pkg/storage/factory.go:14` 工厂 → `S3CompatibleProvider`（AliOSS/R2/S3 同套 SigV4，`provider_s3.go:18`）＋ `LocalDisk`（仅开发/测试，`provider_local.go:12`） |
| 持久化 | Go 类型仍叫 `FileObject`，但**数据表已是 `asset_object`**（`model/file.go:21/44` TableName = `asset_object` / `asset_storage_config`）。`017_rename_batch7.sql:20-21` 已完成 `file_object → asset_object`、`storage_config → asset_storage_config` |
| 迁移 | 最新 `033_runtime_config_policy.sql`；**有 017 改名迁移，但无 asset 生命周期/配额迁移**（042/043 属已废弃的 BE-Codex，不计） |
| 测试 | **无 `file_test.go`** |

**owner 自声明缺陷（须进入 Asset 决策输入）**：
`file.go:41` 取登录 `uid`；`:62-63` 取客户端传入的 `owner_type/owner_id`；`:67` 用客户端值构造；`:73` `_ = uid`（登录身份被丢弃）。即**当前 upload 允许客户端自行声明资源 owner，服务端未强制以登录身份归属**。最终 Mobile Asset API **不能沿用**此行为。

### 2.2 `BE-Codex` `internal/module/asset`（历史对照，已废弃）

> ⚠️ 已废弃分支，仅作历史对照，**不作为候选实现 / 迁移来源 / 缺陷来源 / ADR 选项**。

| 维度 | 证据（仅供对照） |
|---|---|
| 路由 | `handler.go:27` `POST /assets/upload-ticket`；`handler.go:49` `POST /assets/:asset_id/commit`；`handler.go:32` `GET /assets/:asset_id/download-ticket` |
| 注册面 | `router.go:242` `assetG := api.Group("/assets")` + `:243` `AppToken()`；`:245` `uploadG.Use(RequireCapabilityQuota("asset.upload"))`；`:248` `downloadG.Use(RequireCapability("asset.download"))` |
| 生命周期 | `service.go:20-23` `PENDING → AVAILABLE / FAILED → DELETED`；reservation `COMMITTED`；ticket 15min 过期 |
| 配额 | `043_asset_quota.sql`：`asset_policy` / `asset_usage` / `asset_reservation` 三表 |
| 测试 | `asset_http_test.go` 等 4 个测试文件（属废弃分支，不计为 Authority 现状） |
| 迁移 | `042_asset_lifecycle.sql` ＋ `043_asset_quota.sql`（属废弃分支） |
| 数据表 | `asset_object`（与 Authority 当前表名一致，印证 017 改名方向） |

### 2.3 Asset 能力白名单缺口（Authority 现状）

`flypost_backend` `model.Capabilities()` 白名单（`identity / payment / notification / ai / storage / analytics`，`app.go:11-25`）**不含 `asset.*`**。
`core/appidentity/service.go:180` 的 `grantEntitlement` 经 `IsValidCapability` 拒绝白名单外能力 → 若未来 Mobile Asset Contract 引入 `asset.upload/asset.download` 能力并走 `RequireCapability*`，**该能力无法通过管理端授权**。

**修正（回应验收）**：此缺口是 Authority 自身白名单的**待补项 / 前置条件**，不是「BE-Codex 当前断链缺陷」。Authority 现有 `file` 模块并不使用 `asset.*` 能力，故当前没有端点因此断裂；但若 S1 决定以能力化方式落地 Mobile Asset Contract，则必须先把 `asset.*` 写入白名单。BE-Codex 曾使用 `asset.upload/asset.download`（其 `router.go:245/248`）的事实仅作历史佐证，BE-Codex 本身已废弃。

### 2.4 分类与 Asset Contract 决策输入

- **`flypost_backend` `module/file` 能否承载最终 mobile contract？** → **否，且不能简单判定为被某个候选取代**。理由：legacy 信任模型（HMAC+user Token，非 AppToken）、无 capability 门、无配额、无生命周期状态机、无测试、且存在 §2.1 owner 自声明缺陷。直接承载会复刻 A01 识别的「非 mobile authority」问题。
- **演进路径须由 ADR 决定**：当前 `module/file` 无法原样成为最终 Mobile Asset Contract，需要后续 ADR（即 ADR-ASSET-001，属下一阶段架构决策）决定如何演进（能力化改造 / 生命周期 / 配额 / 信任主体 / owner 归属）。**不预先断言「file 被 asset 取代」**。

**Asset Contract 决策输入（提交 S1-A01/A02 评审，属下一阶段，非 C01 验收前置）**：
1. 权威实现选型：如何演进 `flypost_backend` 现有 `module/file` 以承载 Mobile Asset Contract（能力化 / 生命周期 / 配额 / 信任主体）。互斥事实见 §2.1/§2.2。
2. 能力注册：须将 `asset.upload` / `asset.download` 写入 `model.Capabilities()` 白名单（§2.3），否则能力化授权链无法闭环。
3. 信任主体：asset 用 `AppToken`（历史 BE-Codex 方向）还是回退 `user Token`（file 现状）？两者不可并存。
4. owner 归属：**必须消除 §2.1 的 owner 自声明缺陷**——最终 Mobile Asset API 须以服务端登录身份强制归属资源，禁止客户端声明 owner。
5. 数据表迁移：当前表已是 `asset_object`（017 改名完成）；后续演进是否需追加生命周期/配额字段迁移（042/043 属废弃分支，不继承）。
6. mobile 暴露面：asset 当前**未进 mobile 组**（Authority 现状为 `authed` 下 `/files`），是否需要在 `mobile` 组下新增 asset 端点，还是维持独立组由 SDK 直连？

**文件所有权冲突（来自 `03_OWNERSHIP_MATRIX.md` §2）**：
- `internal/module/file/**` → Primary Owner = `Asset Audit/Transition Owner`（先审计，最终归属待 ADR）。
- `internal/core/asset/**` → Primary Owner = `Asset Platform Owner`，且矩阵规定「**目录不存在时先 ADR，不允许只搬文件**」。
- 冲突点：矩阵写 `internal/core/asset`，而历史 BE-Codex 实际为 `internal/module/asset`，Authority 当前为 `internal/module/file`。**在 ADR-ASSET-001 批准前，任何「搬文件 / 改 file / 建 asset」动作均违反矩阵**。Sprint 1 入口决议对 Asset SDK / Upload API 的禁止，正是为等 ADR-ASSET-001 这一**下一阶段架构决策**落地后解除。

---

## 3. Notification 域

### 3.1 路由与注册面（Authority `flypost_backend`）

| 面 | 路由 | 证据 |
|---|---|---|
| Client（`authed` 组，`router.go:218` `notifyH.RegisterClient(authed)`） | `GET /notifications`（listMine `handler.go:157`）、`GET /notifications/unread-count`（`:47`）、`POST /notifications/read`（`:48`）、`POST /notifications/read-all`（`:49`） | 真实**客户端 lifecycle**：列表（游标）/未读红点/批量已读/一键已读 |
| Admin（`adminG`，`router.go:243` `notifyH.Register(adminG)`） | 模板 CRUD（`:54/59/70/81`）、`send`（`:93`）、`preview`（`:112`）、投递记录 list/get/retry（`:124/140/145`） | 管理端产品骨架 |

### 3.2 渠道状态（判定骨架的关键）

`sender.go` 定义 6 渠道：`EMAIL / SMS / PUSH / WEBHOOK / INAPP / LOG`（`sender.go:24-29`）。
`Resolve`（`sender.go:74`）分发：
- **INAPP**：`InAppSender`，真实落库（`user_notification`）→ **production 真实**。
- **LOG**：`LogSender`，确定性 mock（测试/演练，无外部 IO）→ 非生产。
- **EMAIL / SMS / PUSH / WEBHOOK**：`GatewaySender`，注释明确「**sandbox 占位，真实服务商调用留待后续 adapter 接入**」（`sender.go:71/80-81`）→ **4 个外部渠道为 SKELETON**。

### 3.3 分类

- 客户端 lifecycle（INAPP 列表/未读/已读）：**Adapt**（真实可用，SDK 空接口可直接对接）。
- 多渠道外部投递（EMAIL/SMS/PUSH/WEBHOOK）：**Deferred / Replace**（当前为 sandbox 占位，需真实 adapter 接入后才算 Production）。
- 管理端模板/投递：产品骨架，**Refactor Later**（RBAC `notification.manage`，与 mobile contract 无关）。

**验收结论**：Notification 部分总体判断正确——**INAPP 客户端 lifecycle 是真实能力；EMAIL/SMS/PUSH/WEBHOOK 目前还是 sandbox adapter 骨架。**

---

## 4. Payment 域

### 4.1 路由与注册面（Authority `flypost_backend`）

| 面 | 路由 | 证据 |
|---|---|---|
| Client（`paymentApp` = AppToken + EmergencySwitch + RequireCapabilityQuota("payment")，`router.go:248`/`280`） | `POST /payments/orders`（createOrder `handler.go:129`）、`GET /payments/orders/:out_trade_no`（getOrderClient `:145`）、`GET /payments/subscriptions`（listMySubscriptions `:151`）、`POST /payments/subscriptions`（createSubscription `:163`） | 客户端下单/查单/订阅 |
| Admin（`adminG`，`router.go:246`/`279`） | orders list/get、refund（`:119`）、subscriptions list/cancel（`:157/176`）、providers CRUD（`:76/80/90/100`）、渠道配置 | 管理端产品骨架 |
| Callback | `cb.POST("/payments/callback/:channel", ...)`（`router.go:256`/`290`）→ **无鉴权，依赖渠道签名** | 异步回调 |

### 4.2 渠道与状态（分项评价，非整体断言）

- Providers：`stripe.go`（SecretKey 支持 `sk_live_`/`sk_test_`，`:32`）、`wechat.go`、`apple.go`（Environment `Production/Sandbox` 环境错配拒绝，`:37`）。
- `Provider` 接口（`provider.go:16-23`）仅含 `Channel()` / `CreateCharge` / `VerifyCallback`——**无 `Refund` / 无 `Reconcile`**。
- `Refund()`（`service.go:187-208`）仅做 `UpdateOrderStatus(orderID, 2, ip)` + `CreateTransaction("REFUND")`，**不调用任何渠道退款**；注释明示「真实渠道退款由后续 adapter 在 Provider 接口下补齐」。
- 真实出金：`provider.go:154` `GatewayProvider.CreateCharge` / `:164` `VerifyCallback` 为真实代码；`provider.go:106` 非 mock 渠道若无真实 adapter 会报错「`%s 尚无真实网关 adapter，请将 mode 置为 sandbox`」——即真实出金依赖 provider config + 真实 adapter 接入。
- 幂等：`service.go:178` `IdempotencyKey: "payment:" + order.OutTradeNo + ":charge"`。

### 4.3 分类（逐项，整体为 HIGH-RISK PARTIAL）

现有生产就绪文档已将 Payment 标记为 **HIGH-RISK PARTIAL**，应分项评价而非整体称 production-capable：

| 子能力 | 状态 | 证据 |
|---|---|---|
| charge（下单） | **Partial / 可用（需 provider 配置）** | `CreateCharge` 真实；出金依赖 adapter（`provider.go:106`） |
| callback（回调） | **真实** | `VerifyCallback` + `HandleCallback`（`service.go:210`） |
| subscription（订阅） | **真实** | `createSubscription` / `listMySubscriptions`（`handler.go:151/163`） |
| refund（退款） | **LOCAL-ONLY（高危）** | `Refund()` 仅本地改状态+记流水，无渠道退款（`service.go:187-208`） |
| reconciliation（对账） | **MISSING** | `Provider` 接口无 `Reconcile`，无对账实现 |

- 订单 / 查单 / 订阅 / 回调 / 幂等：**Adapt**（链路具备，但整体受 refund/reconciliation 拖累）。
- 渠道 adapter（Stripe/WeChat/Apple 真实出金）：**Refactor Later**（需真实 adapter + 密钥配置才投产）。
- refund / reconciliation：**待建设**（当前不可投产）。
- 管理端 orders/refund/providers：**Refactor Later**（产品骨架，RBAC `payment.manage`）。

**验收结论**：Payment 被原版写成「production-capable」过度成熟，已修正。当前链路**不是纯骨架**（charge/callback/subscription 真实），但 **refund 仅本地、reconciliation 缺失**，整体应为 **HIGH-RISK PARTIAL**，后续须分项推进而非整体宣称生产就绪。

---

## 5. 四分类汇总

| 能力 | 子树/模块 | 分类 | 核心证据 |
|---|---|---|---|
| Asset | `flypost_backend` `module/file` | **Needs ADR**（不能原样承载最终 mobile contract） | legacy 信任、无 capability/配额/生命周期/测试、owner 自声明缺陷（`file.go`/`router.go:217`） |
| Asset 能力白名单 | `model/app.go` | **Precondition（待补 `asset.*`）** | 白名单无 `asset.*`（`app.go:11-25`），能力化须先补 |
| Notification client | `core/notification` (INAPP) | **Adapt** | 列表/未读/已读真实落库（`handler.go:47-49/157`） |
| Notification 外部渠道 | `sender.go` GatewaySender | **Deferred**（骨架） | EMAIL/SMS/PUSH/WEBHOOK 为 sandbox 占位（`sender.go:80-81`） |
| Payment charge/callback/subscription | `core/payment` | **Adapt（Partial）** | 真实链路（`handler.go`/`service.go:178`） |
| Payment refund | `service.go:187` | **LOCAL-ONLY（高危，待建设）** | 仅本地改状态+记流水，无渠道退款 |
| Payment reconciliation | `provider.go` | **MISSING（待建设）** | 接口无 `Reconcile` |
| Payment 渠道 adapter | `provider.go`/`stripe.go`… | **Refactor Later** | 真实出金需 adapter+config（`provider.go:106`） |

---

## 6. Asset Contract 决策输入与文件所有权冲突（Task 5 专节）

> 详列于 §2.4。要点复述：
> - **`flypost_backend` `module/file` 无法原样承载最终 Mobile Asset Contract**，演进路径须由 ADR-ASSET-001 决定（不预先断言「file 被 asset 取代」）。
> - **6 项决策输入**（权威演进选型 / 能力注册 / 信任主体 / owner 归属 / 表迁移 / mobile 暴露面）均互斥、须 S1-A01/A02 拍板。其中 **owner 归属（消除客户端自声明）** 为本次新增必须项。
> - 所有权冲突：矩阵规定 `file`→Transition Owner、`asset`→Platform Owner 且「先 ADR 后动」；路径命名（`internal/core/asset` vs `internal/module/asset` vs 现状 `internal/module/file`）须 ADR 澄清。Sprint 1 对 Asset SDK/Upload API 的禁止，是为等 ADR-ASSET-001 这一**下一阶段架构决策**落地后解除。

---

## 7. 已知限制（本审计范围）

1. 纯静态只读取证，**未运行任何测试**（BE-Codex asset 4 测试已随分支废弃不计入；BE-forAI notification/payment `*_test.go` 未跑）。
2. Payment 真实出金路径未端到端验证；`provider.go:106` 的 sandbox 闸门仅静态确认；refund/reconciliation 缺失为静态读码确认。
3. **BE-Codex 已废弃**，其 `internal/module/asset` 与矩阵 `internal/core/asset` 路径命名差异仅作历史对照，不向仓库方核实（不影响 Authority 结论）。
4. 未审 `sdk/dart/**`（quarantine 冻结，Task Pack 禁止），SDK 空接口对接可行性不在本任务。
5. Notification/Payment 在 BE-Codex 的细微实现差异未逐函数 diff（BE-Codex 已废弃，不计为 Authority 分叉）。

---

## 8. Handoff Block（DoD §7 模板）

- **Deliverable**：`reports/MA0_C01_BACKEND_CAPABILITY_AUDIT.md`（本报告）。
- **C01 验收前提**：本审计为**事实审计**，验收前提是把上述 6 项事实修正准确（Authority 唯一性 / mobile 信任模型 / `asset_object` 表名与 017 改名 / file 非「被 asset 取代」 / owner 自声明缺陷 / Payment HIGH-RISK PARTIAL 分项）。事实准确即可 DONE。
- **Decisions required（下一阶段，非 C01 DONE 前置）**：
  - S1-A01：Asset 演进选型（如何改造 `module/file`）+ 白名单注册（§2.4）。
  - S1-A02：mobile Asset 暴露面与 capability 契约冻结。
- **Follow-up dependencies**（验收结论 4 项）：
  1. `adrs/ADR-ASSET-001.md`（Asset 权威演进选型 + 能力注册，下游 `contracts/MOBILE_ASSET_CONTRACT.md`）
  2. `contracts/MOBILE_ASSET_CONTRACT.md`（移动端 Asset 契约草案，owner 强制服务端归属，待 ADR 冻结）
  3. `adrs/ADR-PAYMENT-REFUND-001.md`（真实渠道退款能力，消除 LOCAL-ONLY 高危）
  4. `adrs/ADR-PAYMENT-RECON-001.md`（支付对账能力，消除 MISSING）
- **Architecture Change Request**：ADR-ASSET-001（Pending，属 S1 阶段决策，非本审计产出前置）；Payment refund/reconciliation 两项 ADR 同属待决。
- **Known risks if merged without review**：若误将 `module/file` 当作 mobile Asset 权威并沿用其 owner 自声明行为，会导致资源归属被客户端操纵；若直接启用能力化 Asset 而不补白名单，授权链无法闭环；若整体宣称 Payment production-capable，会掩盖 refund/reconciliation 缺失的高危项。
