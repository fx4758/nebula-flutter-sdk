# S1-F02 Runtime Config First Slice

## Story

- ID：S1-F02
- Epic / Feature：Sprint 1-A Foundation Integration / Runtime Config
- Owner Role：Backend/SDK Agent
- Story Point：5
- Priority：P0
- Depends：S1-F01, MA0-A02

## Goal

完成 Nebula runtime-config 只读链路，不引入业务规则。

## Facts / Context

- Runtime Config 属 Nebula Foundation。
- NFC rule/parser/business workflow 不属于 SDK。
- 首切片禁止 Feature 扩张。

## Required Inputs

- ADR-027-nebula-basic-capability-scope.md
- F3_API_CONTRACT_FREEZE.md

## Allowed Paths

- SDK config client 相关目录
- Backend nebula config API 相关目录
- tests/**

## Forbidden Paths / Actions

- 禁止 parser rule 下发
- 禁止 card behavior 配置化
- 禁止 Asset/Payment/AI/Notification

## Tasks

1. 冻结 runtime-config contract。
2. 实现 SDK read client。
3. 增加 backend API test。

## Quantified Acceptance

- [ ] API contract 文档存在。
- [ ] SDK client 有测试。
- [ ] 缓存策略明确。
- [ ] 无业务字段混入。

## Tests / Verification

```bash
flutter test
go test
```

## Deliverables

- Contract
- Client implementation
- API tests

## Exit / Handoff

REVIEW 必须提供代码路径和测试证据。
