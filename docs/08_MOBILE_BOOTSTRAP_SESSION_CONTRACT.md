# Mobile Bootstrap & User Session Contract (F0-02)

Status: **FROZEN (client side, 2026-08-07)**

单一事实来源（后端）：`flypost/sdk/CONTRACT.md` §2/§3/§4.7，以及 `flypost` 实际路由（已核对 2026-08-07）：

- `internal/router/router.go:150-154`（mobile 组，不继承 HMAC Signature）
- `internal/router/router.go:160-182`（`/api/v1/mobile/auth/*`）
- `internal/core/installation/*`（bootstrap/token）
- `internal/core/.../auth/*`（`/mobile/auth/*` handler）

本文件冻结 **客户端** Mobile Bootstrap 与 User Session 流程。它**不修改 flypost**。凡后端尚未可用的能力，一律标记为 `[BLOCKED]` / `[RESERVED]`，不提供假实现。

---

## 1. 范围与前提

- 本契约只覆盖「设备引导（Bootstrap）」与「用户会话（Session）」两条流。
- **不**包含 runtime-config（F2，独立契约 `docs/12_MOBILE_RUNTIME_CONFIG_CONTRACT.md`）、payment（F4）、notification（F3）、asset（F3）、ai（F4）。
- 移动 SDK **不得**携带 `appSecret` / `clientSecret` / `providerSecret`，**不得**使用 `client_credentials` 授权（应用令牌仅服务端到服务端，见 `sdk/CONTRACT.md` §3）。
- 移动鉴权组（`/api/v1/mobile/*`）使用 **Installation Proof**（由设备持有的 ES256 私钥签名），**不**使用 legacy 组的 HMAC AppSecret 签名。legacy HMAC 通道是迁移兼容通道，由 F0-03 设计与下线。

---

## 2. 身份边界（移动端）

```text
设备生成 ES256 密钥对（私钥存 Secure Storage port，不出设备）
   public_key ──POST /mobile/bootstrap──▶ installation_token (JWT HS256, scope=installation, 24h)
installation_token (Proof) + 用户凭证 ──POST /mobile/auth/login──▶ access_token + refresh_token (JWT)
access_token (Bearer) ──▶ 用户态端点（/mobile/auth/* 之外的 authed 组）
installation_token (Proof) ──▶ /mobile/* 组
```

可信作用域（服务端解析，**不**信请求头/请求体）：

- `app_id` / `installation_id`：来自 `installation_token` claims；
- `user_id`：来自 `access_token`；
- `environment` / `region` / `platform`：来自服务端记录（deployment config、`ProductApp.default_region_code`、`app_installation` 可信记录）；客户端 header 不参与作用域。

---

## 3. Bootstrap 序列

- **端点**：`POST /api/v1/mobile/bootstrap`（mobile 组，**无** HMAC Signature 中间件）。
- **密钥**：客户端每个 installation 一次性生成 ES256（P-256）密钥对；私钥存 Secure Storage port；发送 `public_key` 为 DER base64url（后端强制 P-256 SPKI）。
- **请求体（冻结）**：`app_id`(app_key)、`installation_id`、`platform`(ios/android/harmony/web)、`app_version`、`build_number`、`os_version`、`locale`、`region`、`public_key`、`attestation`(≤16KiB，可选)、`bootstrap_request_id`。
- **响应**：`installation_token`、`expires_at`、`renew_after`、`server_time`、`app_id`、`installation_id`、`proof_algorithm`("ES256")、`attestation_state`、`minimum_supported_build`、`request_id`。
- **生命周期**：TTL 24h；`renew_after = expires_at − TTL*0.2`（80% 阈值），客户端须在 `renew_after` 前续期。
- **续期**：同端点，相同 `(app_id, installation_id)` + 新 `bootstrap_request_id` + 公钥指纹一致 → Touch（刷新 last_seen/expires_at，重签令牌）。指纹不同 → 冲突拒绝（防身份劫持）。同一 `bootstrap_request_id` 网络重试幂等命中，不再延长 `expires_at`。
- **错误码**：`12001` 安装失效（需重新 bootstrap）；`12004` 服务暂不可用 / 应急关闭 / 快照超限（有界退避）；`30001` 参数错误 / 唯一键冲突。

---

## 4. User Session 序列

- **组**：`/api/v1/mobile/auth/*`（mobile 组，需 Installation Proof；**非** HMAC AppSecret）。legacy `/api/v1/auth/*`（HMAC AppSecret）仅迁移兼容，见 F0-03。
- **登录**：`POST /mobile/auth/login`，body `{provider:"PHONE", phone, code}`。响应 `{access_token, refresh_token, user}`，令牌为 JWT（`token_type=access`）。
- **刷新**：`POST /mobile/auth/refresh`，body `{refresh_token}`。并发 401 的 single-flight 刷新是 **F1-02** 客户端职责（一次网络调用，其余等待同一结果）。
- **登出**：`POST /mobile/auth/logout`（Proof + Token）。清除 Secure Storage port 中用户级 secret。
- **错误码**：`10003` 鉴权失败（HTTP 200 + 信封 code）；`12002` 刷新重用 / 登出（mobile 组）；`10004` legacy 登出。
- **[RESERVED]** `oauth/login`：handler 已注册但默认关闭；在后端启用前 SDK 不调用，不进入契约。

---

## 5. 客户端禁止项

- 移动端不得含 `appSecret` / `clientSecret` / `providerSecret`。
- 移动 App 不得使用 `client_credentials` 换取应用令牌（应用令牌仅服务端到服务端）。
- 不得信任请求体 `app_id`；`app_id` 来自 `installation_token` claims。
- 不得臆造后端不存在的端点 / 字段 / 错误码（见 §6 依赖）。

---

## 6. 依赖与占位（后端尚未对客户端可用）

- **[BLOCKED] 真实平台证明（attestation）**：flypost 当前 `attestation` 为 no-op（仅 `limited` / `not_supported`，从不产出 `verified`；真实 Provider 校验未实现）。客户端**仍应**在可用时携带 `attestation`，但**不得**把 `attestation_state` 当作设备可信证明。SDK 提供字段，不提供验证。后端补齐验证后再补充客户端语义。
- **[RESERVED] oauth/login**：后端 handler 存在但默认 OFF；SDK 不调用直至启用。
- **[FUTURE] runtime-config 契约**：`GET /mobile/runtime-config` 后端已实现，其客户端契约位于 `docs/12_MOBILE_RUNTIME_CONFIG_CONTRACT.md`（F2），本文件不重复。

---

## 7. 契约到代码映射（SDK 侧）

| 阶段 | 责任 | 备注 |
| --- | --- | --- |
| F0 | 仅 marker `NebulaAuth` 接口（`lib/src/capabilities.dart`），无实现 | 本契约冻结形状 |
| F1-01 | HTTP transport + 信封 + 超时/取消（mobile 组用 Proof，无 AppSecret 签名） |  |
| F1-02 | 用户会话、single-flight refresh、signOut（用 `/mobile/auth/*`） |  |
| F3 | bootstrap 实现：用 `/mobile/bootstrap` + Secure Storage port 存 ES256 私钥 |  |
| F0-03 | legacy HMAC AppSecret 兼容与下线计划 | 见 `docs/05_MIGRATION_FROM_FLYPOST.md` + DEBT-F001 |

---

## 8. 验收证据（F0 验收对照）

- [x] 公共构造器无 `appSecret/clientSecret/providerSecret`（`lib/src/foundation/options.dart` 仅 `appId`）。
- [x] Flutter 公共 API 无凭据签发 / 轮换 / Entitlement 管理。
- [x] 客户端—服务端身份边界有 sequence/contract 说明（本文 §2/§3/§4）。
- [x] 契约与 flypost 事实逐项对账：`router.go:150-154,160-182`、`internal/core/installation/*`、`sdk/CONTRACT.md` §2/§3/§4.7。
- [x] 未落地的后端能力标记为 `[BLOCKED]`/`[RESERVED]`（§6），不提供假实现。
- [~] 旧 SDK 每个公共能力的 keep/adapt/remove 结论 → 属于 **F0-03**，不在本任务范围。
