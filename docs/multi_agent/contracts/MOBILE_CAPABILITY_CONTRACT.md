# Mobile Capability Contract

- **Contract ID**：CONTRACT-MOBILE-CAPABILITY
- **Status**：FROZEN baseline（权威能力集 + 矩阵）；asset 缺口标注待 ADR-ASSET-001 解决
- **Frozen at**：2026-08-07
- **Frozen by**：Contract Agent（`workbuddy-contract-agent`）— MA0-A01 follow-up
- **Source**：MA0-A01 §6.3、§7.2；`00_MASTER_PLAN.md` §2.1/§2.4；`lib/src/capabilities.dart:46-56`

> 本契约是移动端能力矩阵的唯一事实源。能力标识符由 Contract Agent 拥有；其他 Agent **不得**自行发明新能力字符串（README §4）。

## 1. Authority

- **单一事实源**：能力白名单 `model.Capabilities()`（backend）。
- **共享移动端 scope claims**（来自 `InstallationProof` / `Token` 链）：`app_id` + `installation_id` + `user_id`（适用时）。
- 能力授予为 **app 作用域（entitlement）**，经 `RequireCapability` / `RequireCapabilityQuota` 中间件消费。
- **MB-01 约束**：移动端二进制**不得**持有 App Secret；能力经 `InstallationProof` / app-token 链消费，而非 legacy HMAC `Signature()`。

## 2. Canonical Capability Matrix

状态图例：**Production**（线上且具备移动端安全面）/ **Partial**（后端就绪，移动端面或 SDK 未完成）/ **Contract-only**（已声明未交付）/ **Deferred**（明确不在当前范围）/ **DEFECT**（声明与使用不一致，须修复）。

| Capability | 白名单(BE-forAI) | 移动端面 | SDK 标记 | 矩阵 | 备注 |
|---|---|---|---|---|---|
| `identity` | ✅ | ✅ M2-M5 mobile 组 | （已使用） | Production | code/login/refresh/logout |
| `payment` | ✅ | ⚠️ L9-L13，非 mobile 组 | `NebulaPayment`（空） | Partial | 能力存在；移动端面递延至 S4/S5 |
| `notification` | ✅ | ⚠️ L5-L8，非 mobile 组 | `NebulaNotification`（空） | Partial | 后端完整；移动端面递延 |
| `ai` | ✅ | ❌ | `NebulaAi`（空） | Contract-only | F4 空标记 |
| `storage` | ✅ | ⚠️ 映射到 file/asset（见 asset 行） | — | Partial | legacy `storage` 与 asset 域重叠 |
| `analytics` | ✅ | ❌ | — | Contract-only | |
| `asset.upload` | ❌ **不在白名单** | ❌ | `NebulaAsset`（空） | **DEFECT** | `router.go:245` 使用但被 `IsValidCapability` 拒 → 见 ADR-ASSET-001 |
| `asset.download` | ❌ **不在白名单** | ❌ | `NebulaAsset`（空） | **DEFECT** | 同上 |

## 3. Resolutions（ADR-ASSET-001 批准后绑定）

- ADR-ASSET-001（推荐 Option A）在 `model.Capabilities()` 注册**单一 `asset` 能力**覆盖 upload + download。
- 批准前，`asset.upload` / `asset.download` 维持 **DEFECT**，生产环境**不得**授予（仅 `testsupport` fixture 注入，§7.2）。
- SDK `NebulaAsset` 空标记须在 S-epoch 由 asset 契约（S1-A02）冻结路径/envelope/错误码后填充。

## 4. SDK Marker Interface Contract

- `lib/src/capabilities.dart` 定义：`NebulaAsset`、`NebulaNotification`、`NebulaPayment`、`NebulaAi` —— 当前均为**空标记接口**（"frozen in F3/F4"，§5.3）。
- **契约义务**：这些标记是 SDK 公共能力面；Contract Agent 在各自 S-epoch 契约 Story 冻结其方法签名（asset→S1-A02、notification/entitlement→S4、payment→S5）。任何 Agent 未经 Contract Agent 重新冻结**不得**改动这些签名。

## 5. Prohibitions（冻结）

- 任何移动端端点**不得**要求 legacy HMAC `Signature()`（MB-01）。
- SDK **永远不得**接收 bucket / provider / App Secret。
- 能力标识符由 Contract Agent 拥有；其他 Agent 不得发明新能力字符串。

## 6. Open Items（路由至 S1）

- asset 能力最终标识（单一 `asset` vs `asset.upload`+`asset.download`）—— ADR-ASSET-001。
- 枚举 asset 能力 quota 的取值/状态集合。
- 厘清 `storage` 与 `asset` 能力关系（避免重复计数）。
- `asset.upload` / `asset.download` DEFECT 修复随 ADR-ASSET-001 + S1-A01 落地。
