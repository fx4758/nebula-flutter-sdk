# Mobile Asset Contract（草案 / PROPOSED）

> 状态：PROPOSED（S1 阶段文档，ADR-ASSET-001 批准后冻结）
> 上游审计：MA0-C01 §2.1（owner 自声明缺陷）、§2.4（6 项决策输入）
> 上游 ADR：`adrs/ADR-ASSET-001.md`（权威演进选型 + 能力注册）
> 关联能力矩阵：`contracts/MOBILE_CAPABILITY_CONTRACT.md`

## 1. 范围

定义最终「移动端 Asset API」契约草案。本文件**不是已批准契约**，是 ADR-ASSET-001 决定后的冻结产物落点。在 ADR 批准前，任何字段/路由/信任模型均视为待定。

## 2. 强制约束（来自 MA0-C01 实证）

- **owner 归属必须服务端强制**：`flypost_backend` 现有 `internal/module/file` 的 upload 取登录 `uid` 后丢弃（`:73 _ = uid`），改用客户端传入的 `owner_type/owner_id`，属 **owner 自声明缺陷**。最终 Mobile Asset API **禁止沿用**——资源 owner 必须以服务端登录身份强制归属，客户端声明无效。
- **能力白名单前置**：`asset.upload` / `asset.download` 须先写入 `model.Capabilities()`（`app.go:11-25` 当前不含 `asset.*`），否则能力化授权链无法闭环。
- **信任主体待 ADR 定**：AppToken（历史 BE-Codex 方向）或 user Token（file 现状）二选一，不可并存。
- **演进来源唯一**：以 `flypost_backend` `module/file` 为演进基线；BE-Codex `module/asset` 已废弃，仅作历史对照。

## 3. 待冻结项（ADR-ASSET-001 拍板）

| 项 | 待定内容 |
|---|---|
| 权威实现 | 如何改造 `module/file` 承载 contract（能力化 / 生命周期 / 配额） |
| 信任主体 | AppToken vs user Token |
| owner 归属 | 服务端强制规则（必选，消除 C01 缺陷） |
| 生命周期 | PENDING/AVAILABLE/FAILED/DELETED 是否采用 |
| 配额 | asset_policy/usage/reservation 是否引入 |
| mobile 暴露面 | `mobile` 组新增 asset 端点 vs 独立组 SDK 直连 |

## 4. 验收门槛

ADR-ASSET-001 批准 + 白名单补 `asset.*` + owner 强制归属落实后，本契约方可冻结为正式 Mobile Asset Contract。
