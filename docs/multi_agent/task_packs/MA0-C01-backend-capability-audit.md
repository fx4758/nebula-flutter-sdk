# Task Pack — MA0-C01 Backend Asset/Notification/Payment 审计

- Epic：EPIC-GOV
- Owner：Backend Architect Agent
- SP：2

## Goal

确定现有 Backend 能力哪些可适配为 Platform API，哪些只是产品或管理骨架。

## Inputs

- `flypost_backend/internal/module/file/**`
- `flypost_backend/internal/pkg/storage/**`
- `flypost_backend/internal/core/notification/**`
- `flypost_backend/internal/core/payment/**`
- `flypost_backend/internal/core/appidentity/**`
- `flypost_backend/internal/router/**`
- 相关 migrations/models/tests/docs

## Allowed Paths

- `nebula-flutter-sdk/docs/multi_agent/reports/MA0_C01_BACKEND_CAPABILITY_AUDIT.md`
- 本 Story 状态字段

## Forbidden

- 不修改 backend 实现。
- 不移动目录。
- 不把管理端 API 作为移动端契约。
- 不把 sandbox/provider skeleton 标记为 Production。

## Tasks

1. Asset：记录路由、模型、Provider、状态、配额、emergency、测试。
2. Notification：记录移动端/管理端入口、App scope、渠道状态。
3. Payment：记录订单、查单、callback、refund、subscription、幂等和 live/sandbox 状态。
4. 对每项给出 Adapt / Refactor Later / Replace / Deferred 分类。
5. 给出 Asset Contract 决策输入和文件所有权冲突。

## Acceptance

- [ ] 三个领域均有分层证据。
- [ ] 明确现有 file module 是否能承载最终 mobile contract。
- [ ] 明确 payment 哪些仅是骨架。
- [ ] 明确 notification 是否存在真实 client lifecycle。
- [ ] 不修改 dirty `sdk/dart/**`。

## Deliverable

`docs/multi_agent/reports/MA0_C01_BACKEND_CAPABILITY_AUDIT.md`
