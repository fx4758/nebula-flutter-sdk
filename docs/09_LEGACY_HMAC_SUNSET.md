# Legacy HMAC App Secret — Compatibility & Sunset Plan (F0-03)

Status: **FROZEN (client plan, 2026-08-07)**

Source（已逐文件通读 2026-08-07）：`flypost/sdk/dart/lib/src/{client,auth,payment,app,notification,analytics}.dart`、`flypost/sdk/CONTRACT.md` §2/§3、`docs/05_MIGRATION_FROM_FLYPOST.md`、`docs/DEBT_REGISTER.md` DEBT-F001、`docs/DECISIONS.md` ADR-F004/F005。

本文件**不修改后端**，只规划旧 `sdk/dart` 的兼容与下线。新 SDK 永不携带 App Secret。

---

## 1. 问题（DEBT-F001）

旧 `sdk/dart` 在移动端内嵌共享密钥 `appSecret`（`client.dart:20,46`），用于 HMAC-SHA256 请求签名，并用它做 `client_credentials` 换取应用令牌（`auth.dart:63-68`）。把共享密钥打进不可信的移动二进制是核心风险。新 SDK（ADR-F004）禁止移动端出现 App Secret / `client_credentials`。

---

## 2. 两套签名世界

| 通道 | 机制 | 适用端点 | 客户端是否需密钥 |
| --- | --- | --- | --- |
| Legacy HMAC | `HMAC-SHA256(appSecret, "METHOD\nPATH\nX-Timestamp\nX-Nonce\nBODY_HASH")` → `X-Signature` | legacy `/api/v1/*`（非 mobile 组） | 需要 AppSecret（禁止） |
| Installation Proof（新） | 设备生成 ES256 密钥对，私钥仅存 Secure Storage port；`installation_token`(JWT, scope=installation) 作为 Proof | `/api/v1/mobile/*` 组 | 不需要 AppSecret |

关键点：新 mobile 组**不继承** HMAC Signature 中间件（见 `docs/08` §3），因此新 SDK 根本不需要 AppSecret。两套世界长期并存是迁移窗口，不是新能力。

---

## 3. 能力清单：keep / adapt / remove

全部 13 个公共符号已分类（`sdk/dart` 完整枚举）：

| 文件 | 符号 | 端点 | 结论 | 新归宿 | 备注 |
| --- | --- | --- | --- | --- | --- |
| client.dart | `NebulaClient` 构造(含 `appSecret`) | — | **REMOVE** | — | AppSecret 不得存在于移动端（ADR-F004） |
| client.dart | `doRequest`（HMAC 签名+发送） | 全部 legacy | **ADAPT→F1-01** | network transport | 去掉 AppSecret，改 Installation Proof 头；**Bug**：`client.dart:95` 读取 `env['msg']`，但契约 M020 禁止 `msg`，错误必须只按 `code` 映射 |
| client.dart | `appToken` 字段 + `appToken()` | POST /app/token | **REMOVE** | 服务端 SDK | `client_credentials` 仅服务端到服务端（ADR-F004/F005） |
| auth.dart | `login(username,password,totp)` | POST /auth/login | **REMOVE** | F1-02（新） | 旧 body `{username,password,totp_code}` + 响应 `{access_token,must_change_pwd,totp_enrolled}` 是**管理员**形态，与新的 `/mobile/auth/login` `{provider,phone,code}`→`{access_token,refresh_token,user}` 不符；不要移植 |
| auth.dart | `appToken()` | POST /app/token | **REMOVE** | 服务端 SDK | 发送 `client_secret`(=appSecret) |
| payment.dart | `createOrder`/`getOrder`/`listMySubscriptions` | /payments/*（用户态） | **ADAPT→F4** | payment | 保留用户支付；改用最小货币单位 int + string ID；加幂等（F4-02） |
| payment.dart | `listProviders`/`refundOrder` | /admin/payment/* | **REMOVE** | Admin/Go SDK | 管理面高权限（ADR-F005） |
| app.dart | `NebulaApp`（全部 9 方法） | /admin/apps/* | **REMOVE** | Admin/Go SDK | 凭据签发/轮换/吊销、entitlement：控制面（ADR-F005） |
| notification.dart | `listMine`/`unreadCount`/`markRead`/`markAllRead` | /notifications/*（用户态） | **ADAPT→F3** | notification | 增加 App scope、令牌生命周期、分页模型 |
| notification.dart | `listTemplates`…`retryDelivery`（9 方法） | /admin/notification/* | **REMOVE** | Admin/Go SDK | 管理面（ADR-F005） |
| analytics.dart | `trackEvents` | POST /analytics/events | **ADAPT→F2** | analytics | 加同意门禁 + 有界队列 + 批量 + TTL（F2-03/04） |
| analytics.dart | `overview`/`timeSeries`/`byApp`/`queryEvents` | /admin/analytics/* | **REMOVE** | Admin/Go SDK | 管理面（ADR-F005） |

**分类汇总**：ADAPT 3 个模块（payment-user、notification-user、analytics-track）；REMOVE 4 类（client 的 AppSecret+HMAC、appToken、legacy auth.login、app 管理面、notification 管理面、analytics 管理面）。即：只有用户态 payment/notification/analytics 上报进入新 SDK；其余 admin/secret/credential 全部移除。

---

## 4. 兼容姿态

- 新 `nebula_sdk` **永不**接受 AppSecret。旧 `sdk/dart` 继续作为未迁移 App 的 HMAC 持有方，按 `docs/05` §1 保持只读兼容。
- 新 App **必须**用 Installation Proof（`/mobile/*`）；不再向任何移动端签发 AppSecret。
- 平台在 sunset 日期前继续在 legacy `/api/v1/*` 接受 HMAC，这是迁移窗口，不是新功能。

---

## 5. 下线计划（DEBT-F001 退出路径）

平台停止接受移动端 HMAC / 吊销 legacy 密钥前，必须同时满足：

1. 至少两个生产 App 已迁移到 `nebula_sdk`（Installation Proof）且灰度稳定（见 `docs/05` §2 step 4-6、F5）。
2. 迁移指标达标：启动成功率、登录成功率、错误率、成本在预算内；回滚开关已就绪。
3. 本文 sunset 日期已发布；已迁移 App 的 legacy App Secret 已轮换/吊销。

**目标 sunset 日期：`[由 Platform Identity owner 填写]`** —— 推荐策略：F5 完成最后一个在册 App 迁移后再经历 2 个小版本，并设硬性最迟日期（TBD）。新 SDK 的功能不依赖该日期（它从不使用 AppSecret）。

Sunset 之后：
- 平台可停止接受移动端 HMAC 签名请求并吊销 legacy App Secret。
- 仍停留在 legacy `sdk/dart` 的 App 在 sunset 后禁止发版（F6 门禁）。

---

## 6. 新 SDK 必须强制（与守卫对齐）

- 移动端无 `appSecret`/`clientSecret`/`client_credentials`（SEC-MOBILE-SECRET、SEC-CLIENT-CREDENTIALS 守卫）。
- 不依赖 `env['msg']`；错误只按 `code` 映射（M020）。
- 管理/控制面端点不进入移动端 barrel（ADR-F005）；它们属于服务端/Admin SDK。

---

## 7. 验收证据（F0）

- [x] 旧 `sdk/dart` 每个公共能力均有 keep/adapt/remove 结论（§3 表，13 个符号全分类）。
- [x] 无任何 App Secret 路径被移植进新 SDK（ADR-F004）。
- [x] 已下线 gates + 日落日期占位已定义（DEBT-F001 退出路径）。
- [x] 未修改后端；仅客户端规划。

## 8. 残留 / 依赖

- sunset 日期是 owner 必填字段（此处不臆造）。
- 真实平台 attestation 仍为 no-op（见 `docs/08` §6），影响 bootstrap 信任，不影响 HMAC 下线。
- 迁移测试（`docs/05` step 1-2：contract fixture + 安全等价实现）仍属 F5；DEBT-F001 在那些测试通过前保持 OPEN。
