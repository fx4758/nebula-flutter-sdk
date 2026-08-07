# ADR-ASSET-OWNER-TRUST-001 — Backend Asset Owner Trust Fix

> Status：PROPOSED（属 S1/S2 阶段架构决策，非 MA0-C01 验收前置；由 MA0-B01 验收列 follow-up）
> Author：SDK Architect Agent（基于 MA0-C01 Backend Capability Audit §5 owner 自声明缺陷）
> Date：2026-08-07T09:46:48+08:00
> Related：ADR-ASSET-001、contracts/MOBILE_ASSET_CONTRACT.md

## 1. 背景与事实（实证）

MA0-C01 审计在 Backend `flypost_backend` `internal/module/file/file.go` 发现资源 owner 信任缺陷：

- `file.go:41` 取登录用户 `uid, _ := middleware.GetUserID(c)`；
- `file.go:62-63` 从请求体读取客户端传入的 `owner_type` / `owner_id`；
- `file.go:67` 实际用客户端 `owner_type/owner_id` 构造资源；
- `file.go:73` `_ = uid`（登录 uid 被显式丢弃）。

**结论**：当前实现允许客户端自行声明资源归属（owner），服务端未强制以登录身份作为 owner。这与 Mobile Asset Contract 的「owner 服务端强制」原则冲突。

## 2. 影响范围

- 当前 `module/file` 不能原样成为最终 Mobile Asset Contract 的 owner 模型（与 ADR-ASSET-001 演进路径选择无关，是独立的安全/信任缺陷）。
- 在 owner-trust 缺陷修复完成前，SDK 侧 S2-S01 **不能**沿用 client-declared owner（MOBILE_ASSET_CONTRACT 已要求 owner 服务端强制）。
- 已上传历史数据的 owner 字段可能不可信，迁移/演进时需审计或重算。

## 3. 决策选项（须 S1/S2 评审拍板，本报告不直接定方案）

- **Option A（最小修复）**：upload 路径强制以服务端登录 `uid` 作为 `owner_id`，忽略客户端 `owner_type/owner_id` 输入；保留字段但服务端覆盖。
- **Option B（输入裁剪）**：删除请求体中 `owner_type/owner_id` 客户端输入，后端完全从 session 推导 owner；上游 SDK/客户端调用点同步移除该字段。
- **Option C（域统一）**：结合 ADR-ASSET-001 的权威选型，在统一 `asset` 域（无论沿用 `module/file` 演进还是采纳 Codex `module/asset`）落地一致的 owner 模型，配套迁移历史 `asset_object` 的 owner 列。

## 4. 门禁（Gate）

- 该 ADR **批准并完成修复**前，SDK S2-S01 的 asset model 不得使用客户端声明的 owner 字段；MOBILE_ASSET_CONTRACT 的「owner 服务端强制」约束即本 ADR 的 SDK 侧落地要求。
- 修复须带回归测试：伪造客户端 owner 输入必须被服务端覆盖/拒绝。

## 5. 验收关联

- MA0-C01 §8 Follow-up（owner 自声明缺陷）
- MA0-B01 §6 S2-S01 依赖项④、§7 F3 准入 checklist「Backend `module/file` owner-trust 缺陷修复」
- contracts/MOBILE_ASSET_CONTRACT.md「资源 owner 服务端强制」
