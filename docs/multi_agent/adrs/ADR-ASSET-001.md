# ADR-ASSET-001 — 移动端 Asset 能力域权威实现与能力注册

- **ADR ID**：ADR-ASSET-001
- **Title**：Mobile Asset API Authority & Capability Registration
- **Status**：PROPOSED（待 S1 Contract Story 评审 + Backend/SDK 双 Reviewer 批准）
- **Date**：2026-08-07
- **Raised by**：Contract Agent（`workbuddy-contract-agent`）— MA0-A01 follow-up
- **Related**：MA0-A01 §6.1 / §7（Q1, Q3, Q4, Q8, Q10, Q12）；S1-A01；S1-A02；`06_ARCHITECTURE_CHANGE_REQUEST_TEMPLATE.md`
- **Severity**：BLOCKING（阻断一切 Asset SDK / Upload API 工作，见 Sprint 1 Entry 门禁）

> 本 ADR 是 Sprint 1 Entry 决议中的「禁止项」解除门禁：ADR-ASSET-001 完成前，Asset SDK 开发 / Upload API 开发 一律禁止。本文件给出**明确推荐决策**，但按治理规则（DoD #8）须经 S1 Contract Story 双审批准后才升级为 APPROVED。

## 1. Context / Observed Fact（证据均来自 MA0-A01）

- **BE-forAI `8ec212f`**：`internal/module/file` → `/api/v1/files/{upload,presign,:file_id/url}`；信任主体 = user `Token()`（位于 legacy HMAC `Signature()` 之下）；`maxUploadBytes` 50MB；emergency disabled 检查；迁移止于 `033_runtime_config_policy.sql`，**无 asset/file 相关迁移**（§6.1）。
- **BE-Codex `de8cf94`**：**已删除** `internal/module/file` 与 `/files` 路由；替换为 `internal/module/asset` → `/api/v1/assets/{upload-ticket,:asset_id/commit,:asset_id/download-ticket}`；信任主体 = `AppToken()`；`RequireCapabilityQuota("asset.upload")` / `RequireCapability("asset.download")`；迁移 `039`-`043`，含 `042_asset_lifecycle.sql` / `043_asset_quota.sql`（§7.1）。
- **响应封装**：两套 Asset 实现均**绕过平台统一 envelope**（`HTTP 200 + {code,data}`），直接 `c.JSON` + HTTP 状态码（§5.2、§7.1）。
- **能力白名单缺口（实锤 DEFECT，§7.2）**：`internal/router/router.go:245/248` 使用 `asset.upload` / `asset.download`，但 `internal/model/app.go:11-25` 的白名单为 `{identity, payment, notification, ai, storage, analytics}`——**不含 asset.\***。`core/appidentity/service.go:180` 的 `grantEntitlement` 经 `IsValidCapability` 拒绝白名单外能力，故这两个能力**无法通过管理端授权**；当前仅由 `internal/testsupport/app_capability_fixture.go:18-36` 在测试中注入 → BE-Codex 的 asset 链在生产授权路径上是**断的**。
- **MB-01（docs/08:32, P0）**：所有 `/api/v1/*` 请求需 HMAC App Secret；公开移动端二进制无法安全使用当前 entry chain。两套 asset 实现分别依赖 HMAC（file）或 `AppToken`（asset）→ **当前不存在任一移动端可安全直连的 Asset 端点**（§3.1）。
- **mobile 组本身收敛（§7.3）**：BE-Codex 与 BE-forAI 的 mobile 四组结构一致；分歧**只在 Asset 域**。

## 2. Decision Drivers

- Master Plan §2.1：「Asset 上传必须由平台签发短期 Ticket/Presign，SDK 不持有 Bucket 密钥」；§2.2：「已有 `internal/module/file` … 先审计，再决定适配、收口或新增 Facade；**禁止只改目录名冒充平台化**」。
- 需要**单一权威移动端 Asset API**，基于 capability 鉴权，而非依赖 HMAC App Secret。
- SDK 必须只拿到短期 ticket/presign，绝不持有 bucket 密钥（Master Plan §2.1）。
- 须解决阻塞项 Q1（权威树）、Q3（信任主体）、Q8（能力标识/粒度）、Q10（迁移基线）。

## 3. Considered Options

### Option A — 采纳 BE-Codex `module/asset` 为权威，并注册能力

- **Change**：BE-Codex `internal/module/asset`（AppToken + RequireCapabilityQuota + ticket/commit 上传通道 + 042/043 迁移）成为规范移动端 Asset 后端；在 `model.Capabilities()` 注册单一 `asset`（涵盖 upload + download）；BE-forAI 退役 `/files`（或别名兼容）。
- **Benefit**：已具备 quota/lifecycle 迁移（042/043）、capability 门控、ticket+commit 通道与 Master Plan presign 模型一致；天然移动端友好（AppToken 而非 user-Token）。
- **Cost**：BE-forAI 须收敛到 asset 模块（或保留 `/files` 兼容窗口，见 Q12）；SDK 须面向 `/assets/*` 而非 `/files/*` 实现。
- **Compatibility**：会破坏 legacy `/files` 客户端 → 需兼容窗口（Q12）。
- **Security**：移除 asset 路径对 HMAC App Secret 的依赖，向 MB-01 收敛。

### Option B — 采纳 BE-forAI `module/file` 为权威

- **Change**：扩展 `module/file` 暴露 mobile 组 + capability 门；弃用 BE-Codex asset 模块。
- **Benefit**：BE-forAI 是 Master Plan §2.2 指定的「权威仓库」。
- **Cost**：须在 BE-forAI **新增** lifecycle/quota 迁移（当前没有）；须新增 capability 门（当前无）；user-Token 信任与 InstallationProof 链冲突。
- **Compatibility**：legacy `/files` 客户端继续可用。
- **Security**：须从 user-Token 迁移到 capability/app 作用域，返工量大。

### Option C — 新建统一 Facade 包住两套

- **Rejected**：违反「禁止只改目录名冒充平台化」；扩大表面积与风险；无额外清晰度收益。

## 4. Recommended Decision

**Option A。** 指定 BE-Codex `internal/module/asset`（AppToken + RequireCapabilityQuota + ticket/commit 上传通道 + 042/043 迁移）为权威移动端 Asset 后端。在 `model.Capabilities()` 注册**单一 `asset` 能力**（覆盖 upload + download），并统一 `router.go:245/248` 现有 `asset.upload` / `asset.download` 标识（二选一，保持一致，解 Q8）。BE-forAI `/files` 在 S1-A02 冻结移动 `/assets/*` 面后进入兼容退役窗口（Q12）。

## 5. Consequences

- **已解决**：Q1（权威树 = BE-Codex asset）、Q3（信任主体 = AppToken；移动端面将由 S1-A02 置于 InstallationProof + AppToken 链之下）、Q8（单一 `asset` 能力）、Q10（承认 042/043 为 Asset 表基线，但 Q11 等价性须 MA0-C01 补证）。
- **递延至 S1-A02**：Q2（是否进 `/api/v1/mobile/*` 隔离组）、Q4（owner scope app vs user）、Q5（路径命名）、Q6（envelope 采纳）、Q7（错误码）、Q9（上传通道语义）、Q12（`/files` 兼容窗口）。
- **MB-01 收敛要求**：现存 asset 端点均不在 mobile 组（§7.3 注：仅 Asset 域分歧）；S1-A02 必须将其置于 mobile 隔离组，方能满足 MB-01（移动端不持 App Secret）。

## 6. Scope Impact

- **API**：新增/变更 asset 端点路径（S1-A02 冻结）、envelope 采纳。
- **SDK public API**：`NebulaAsset` 填充（当前为空标记接口）。
- **Database/migration**：042/043 基线；S1 前不新增迁移。
- **App integration**：SDK 仅拿 ticket/presign，无 bucket 密钥。
- **Security**：移除 asset 路径对 HMAC App Secret 的依赖。
- **Sprint dependency**：**阻断** S1-A01（状态机）与 S1-A02（路径）直到批准；按 Sprint 1 Entry 门禁，**阻断 Asset SDK 开发 + Upload API 开发**，直到本 ADR COMPLETED。

## 7. Temporary Workaround

默认不允许绕过。Asset SDK / Upload API 工作在本 ADR COMPLETED 且经 S1 Contract Story 批准前**一律禁止**。

## 8. Decision

- **Status**：PROPOSED
- **APPROVED / REJECTED / DEFERRED**：待 S1 Contract Story（S1-A01/A02）双审
- **ADR**：ADR-ASSET-001
- **Contract version**：v0.1-proposed（S1 批准后为 v1.0）
- **Follow-up Story**：S1-A01、S1-A02、MA0-C01（补 Q11 列级事实）、MA0-Q01（dirty file 归属）
