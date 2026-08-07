# F3 API Contract Freeze

> Status：PROPOSED（S1/S2 评审前草案，合规 DoD #8；非已批准契约）
> Author：SDK Architect Agent（基于 MA0-A01 Platform API Audit + MA0-C01 Backend Capability Audit）
> Date：2026-08-07T09:46:48+08:00
> Related：MA0-A01 §2/§4、MA0-C01、ADR-ASSET-001、contracts/SDK_BOOTSTRAP_CONTRACT_FREEZE.md、contracts/MOBILE_ASSET_CONTRACT.md

## 1. 冻结目标

F3（Feature SDK 开发）阶段开始前，明确**哪些 API 端点/路径/方法/错误码已冻结、不可擅自变更**，防止多 Agent 并行导致契约漂移。

## 2. 已冻结端点（基于 A01 实证，mobile 权威面）

| 端点 | 方法 | 状态 | 证据 |
|---|---|---|---|
| `/api/v1/mobile/bootstrap` | POST | FROZEN | MA0-A01 M1；`SDK_BOOTSTRAP_CONTRACT_FREEZE.md` |
| `/api/v1/mobile/code/send` | POST | FROZEN | MA0-A01 M2 |
| `/api/v1/mobile/login` | POST | FROZEN | MA0-A01 M3 |
| `/api/v1/mobile/refresh` | POST | FROZEN | MA0-A01 M4 |
| `/api/v1/mobile/logout` | POST | FROZEN | MA0-A01 M5 |
| `/api/v1/mobile/runtime-config` | GET | FROZEN | MA0-A01 M6 |

错误码占用（FB-01）：`12001` invalid_installation / `12002` session_revoked / `12003` client_outdated / `12004` temporarily_unavailable + legacy `10003/30001/40002/50001`。

## 3. 待 ADR 批准后冻结的 Asset 端点

以下端点**契约未冻结**，须 ADR-ASSET-001 批准 + Backend `module/file` owner-trust 修复（ADR-ASSET-OWNER-TRUST-001）完成后方可纳入冻结：

- `asset.upload` ticket 创建（路径待 ADR 定）
- `asset.commit`（`:asset_id/commit`）
- `asset.download` ticket（`:asset_id/download-ticket`）

冻结前 S2-S0x 不得对生产环境发出真实 Asset 写请求。

## 4. 变更闸门

任何对 §2/§3 端点的**路径 / 方法 / 请求体 / 响应 envelope / 错误码**变更，须同时满足：

1. API Contract Agent 评审通过；
2. SDK Architect 确认 SDK 侧影响（public export / snapshot）；
3. 更新对应 contract 文档与 `governance/api_surface.snapshot`（`--update` 由 surface Owner 执行）；
4. 回归 fixture 无漂移。

## 5. 关联

- MA0-B01 §7 F3 准入 checklist（「API endpoints frozen」）
- ADR-ASSET-001（Asset 权威选型与能力注册）
- ADR-ASSET-OWNER-TRUST-001（owner 信任修复）
