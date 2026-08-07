# S1-F03 SDK Release Workflow

## Story

- ID：S1-F03
- Epic / Feature：Sprint 1-A Foundation Integration / SDK Governance
- Owner Role：SDK Governance Agent
- Story Point：3
- Priority：P1
- Depends：MA0-A03, MA0-Q01

## Goal

建立 SDK development/beta/production 依赖和发布流程。

## Facts / Context

- SDK 当前 publish_to:none。
- 当前 path dependency 仅允许开发阶段。
- Release 不得携带 WIP dirty。

## Required Inputs

- reports/MA0_A03_DEPENDENCY_IMPACT_REVIEW.md
- contracts/SDK_PUBLIC_SURFACE_CHANGE_PROCESS.md

## Allowed Paths

- docs/multi_agent/**
- SDK governance workflow 文件
- CI 配置（仅本 Story）

## Forbidden Paths / Actions

- 禁止业务代码修改
- 禁止扩大 Public API
- 禁止绕过 api_surface gate

## Tasks

1. 定义 dev/beta/prod dependency strategy。
2. 定义 release checklist。
3. 接入 API surface verification gate。

## Quantified Acceptance

- [ ] path/git/package 三阶段策略明确。
- [ ] release checklist 可执行。
- [ ] API snapshot gate 有入口。

## Tests / Verification

```bash
flutter analyze
api_surface verification
```

## Deliverables

- SDK release workflow doc
- CI gate definition

## Exit / Handoff

由 Governance Review Agent 验收。
