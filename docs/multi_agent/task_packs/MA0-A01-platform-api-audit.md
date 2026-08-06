# Task Pack — MA0-A01 平台 API 与跨仓契约事实审计

- Epic：EPIC-GOV
- Feature：GOV-F1 真实基线
- Owner：Contract Agent
- SP：2
- Depends：无

## Goal

形成 mobile Platform API 的事实清单，为 Asset Contract 冻结提供唯一输入。

## Inputs

- `nebula-flutter-sdk/docs/06_API_CONTRACT.md`
- `nebula-flutter-sdk/docs/08_MOBILE_BOOTSTRAP_SESSION_CONTRACT.md`
- `nebula-flutter-sdk/docs/12_MOBILE_RUNTIME_CONFIG_CONTRACT.md`
- `nebula-flutter-sdk/test/fixtures/**`
- `flypost_backend/internal/router/**`
- `flypost_backend/internal/core/identity/**`
- `flypost_backend/internal/core/installation/**`
- `flypost_backend/internal/module/runtimeconfig/**`
- `flypost_backend/internal/module/file/**`

## Allowed Paths

- 只新增/修改 `docs/multi_agent/reports/MA0_A01_PLATFORM_API_AUDIT.md`
- 可更新 `02_SPRINT_BOARD.md` 和 `task_board.json` 的本 Story 状态

## Forbidden

- 不修改 Go/Dart/Kotlin 代码。
- 不修改现有 API 契约。
- 不将 admin/BFF API 当 mobile authority。

## Tasks

1. 从真实 router 枚举 `/api/v1/mobile/*` 与相关客户端路由。
2. 对每个 endpoint 记录 method/path/middleware/handler/service/test。
3. 对照 SDK endpoints/fixtures，标记 aligned/drift/missing。
4. 单独列出 Asset、Notification、Entitlement、Payment 的现状。
5. 输出 S1-A01/S1-A02 必须拍板的问题，不直接给实现方案。

## Acceptance

- [ ] 每个 endpoint 有代码路径证据。
- [ ] 每个 SDK endpoint 有 backend 对应结论。
- [ ] 至少区分 Implemented/Partial/Placeholder/Missing 四类。
- [ ] Asset 待冻结问题不超过 12 个且均可决策。
- [ ] 报告不使用无证据百分比。

## Deliverable

`docs/multi_agent/reports/MA0_A01_PLATFORM_API_AUDIT.md`
