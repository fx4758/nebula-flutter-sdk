# SDK Bootstrap Contract Freeze

- **Contract ID**：CONTRACT-SDK-BOOTSTRAP
- **Status**：FROZEN（基线取自既有的 aligned 实现 + fixtures，非新发明）
- **Frozen at**：2026-08-07
- **Frozen by**：Contract Agent（`workbuddy-contract-agent`）— MA0-A01 follow-up
- **Authority source**：MA0-A01 §2 M1、§4.4 fixtures、`00_MASTER_PLAN.md` §2.3/§2.4
- **Audience**：SDK Core Agent、Backend Auth Agent（Sprint 1 允许 Agent）

> 本契约冻结的是**已落地且证据齐全**的 `POST /api/v1/mobile/bootstrap`。任何字段/类型/错误码变更须走 `06_ARCHITECTURE_CHANGE_REQUEST_TEMPLATE.md` 并由 Contract Agent 重新冻结。

## 1. Endpoint

- **Method + Path**：`POST /api/v1/mobile/bootstrap`
- **Group**：mobile bootstrap group（`router.go:133-137`）
- **Middleware chain（外→内）**：`CoarseIPRateLimit(100,1m)` → `BodyLimit(maxMobileBodyBytes)` → handler
  - ⚠️ **bootstrap 运行于 installation 建立之前，故不带 `InstallationProof` / `Token`**（与 M2-M6 不同）。此行为**已冻结**，属设计意图。
- **Envelope**：平台标准 `HTTP 200 + {code,data}`（`pkg/response/response.go:20-28`）。

## 2. Request（冻结字段）

来源：`BootstrapRequest`（`core/installation/service.go:60-70`）、`lib/src/auth/installation.dart:69`、fixture `bootstrap_request.json`。

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `app_id` | string | ✅ | 应用标识 |
| `installation_id` | string | ✅ | 安装标识 |
| `platform` | string | ✅ | ios / android / … |
| `app_version` | string | ✅ | |
| `build_number` | string | ✅ | |
| `os_version` | string | ✅ | |
| `locale` | string | ✅ | |
| `region` | string | ✅ | |
| `public_key` | string | ✅ | installation 密钥对公钥，用于 proof |
| `attestation` | object | ✅ | 平台 attestation 载荷 |
| `bootstrap_request_id` | string | ✅ | **幂等键**；服务端写入 `app_installation_bootstrap` 账本（唯一键 `(app_id, bootstrap_request_id)`） |

## 各类字段语义冻结约定

- 所有字符串字段非空（`required`）。
- 时间字段（`expires_at` / `renew_after` / `server_time`）为 **unix 秒级整数**，由服务端授时。
- `bootstrap_request_id` 必须为调用方生成的稳定幂等标识；重复提交返回既有 `BootstrapResult`，不产生新 installation。

## 3. Response（冻结字段）

来源：`BootstrapResult`（`core/installation/service.go:75-84`）、fixture `bootstrap_response.json`。

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `installation_token` | string | ✅ | 短期 installation 作用域令牌 |
| `expires_at` | int64 (unix) | ✅ | |
| `renew_after` | int64 (unix) | ✅ | |
| `server_time` | int64 (unix) | ✅ | |
| `app_id` | string | ✅ | |
| `installation_id` | string | ✅ | |
| `proof_algorithm` | string | ✅ | 取值集合由 S1 冻结（见 Open Items） |
| `attestation_state` | string | ✅ | 取值集合由 S1 冻结 |
| `minimum_supported_build` | string | ✅ | |
| `request_id` | string | ✅ | |

## 4. Idempotency

- **Key**：`bootstrap_request_id`。相同 `(app_id, bootstrap_request_id)` 重复提交返回既有 `BootstrapResult`（账本去重，不新建 installation）。

## 5. Error codes（冻结 — 来源 `error_mapping.json`，FB-01）

| code | 含义 |
|---|---|
| `12001` | invalid_installation |
| `12003` | client_outdated（`minimum_supported_build` 违例） |
| `12004` | temporarily_unavailable（over_limit，fail fast） |
| `10003` / `30001` / `40002` / `50001` | legacy |

全部经 envelope `{code,data}` + `HTTP 200` 返回。

## 6. Scope

- **app + installation（pre-user）**。此时尚无 user 身份。

## 7. SDK obligation（冻结）

- SDK **必须**定义常量 `BootstrapEndpoints.bootstrap = "/api/v1/mobile/bootstrap"`，解决 MA0-A01 §4.2 的 drift（当前路径未常量化，由调用方提供）。
- SDK **不得**硬编码 bucket / provider / App Secret。
- `BootstrapRequest` / `BootstrapResponse` 结构已存在于 `lib/src/auth/installation.dart`，冻结为 wire contract。

## 8. Open Items（**未冻结** — 路由至 S1）

- 枚举 `proof_algorithm` 取值集合。
- 枚举 `attestation_state` 取值集合与状态迁移。
- `minimum_supported_build` 比较语义（`>=` vs `==`）。
- SDK 常量新增属 SDK Core Agent 实现任务（Sprint 1 允许）。

## 9. Change control

字段/类型/错误码的任何变更须提交新 ACR（`06_ARCHITECTURE_CHANGE_REQUEST_TEMPLATE.md`）并由 Contract Agent 重新冻结；本文件版本随之递增。
