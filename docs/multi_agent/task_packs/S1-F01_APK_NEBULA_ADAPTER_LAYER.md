# S1-F01-001 APK Nebula Adapter Layer

## Story

- ID：S1-F01-001
- Epic / Feature：Sprint 1-A Foundation Integration / APK SDK Adapter
- Owner Role：Flutter Integration Agent
- Story Point：5
- Priority：P0
- Depends：MA0-D01, MA0-A02, MA0-A03

## Goal

建立 APK 到 Nebula SDK 的唯一适配入口，不迁移业务逻辑。

## Facts / Context

- App 已有 Composition Root：AppDependencies。
- SDK Foundation 边界已冻结。
- Parser/NFC Runtime/Action Execution 继续由 App Owner。

## Required Inputs

- reports/MA0_D01_APP_INTEGRATION_AUDIT.md
- reports/MA0_A02_CAPABILITY_BOUNDARY_REVERIFICATION.md
- reports/MA0_A03_DEPENDENCY_IMPACT_REVIEW.md

## Allowed Paths

- lib/platform/nebula/**
- test/**（新增适配测试）
- docs/**（必要更新）

## Forbidden Paths / Actions

- 禁止修改 core/parser/**
- 禁止修改 NFC Runtime
- 禁止新增业务 API
- 禁止 Asset/Upload/Payment/AI 接入

## Tasks

1. 创建 Nebula Adapter Layer。
2. 将 SDK 初始化接入唯一 Composition Root。
3. 增加 startup integration test。

## Quantified Acceptance

- [ ] 无业务页面直接调用 SDK。
- [ ] SDK 入口只有一个。
- [ ] flutter analyze 通过。
- [ ] integration test 可验证 bootstrap。

## Tests / Verification

```bash
flutter analyze
flutter test
```

## Deliverables

- Adapter source
- Integration test
- Handoff report

## Exit / Handoff

提交 REVIEW，由 Architecture Coordinator 基于代码证据验收。
