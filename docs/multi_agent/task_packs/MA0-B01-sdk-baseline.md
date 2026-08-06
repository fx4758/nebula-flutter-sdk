# Task Pack — MA0-B01 SDK F0-F2 当前能力审计

- Epic：EPIC-GOV
- Owner：SDK Architect Agent
- SP：2

## Goal

确认可直接复用的 SDK kernel/config/auth/analytics 能力和 F3 准入边界，避免重复建设。

## Inputs

- `docs/STATUS.md`
- `docs/03_IMPLEMENTATION_PLAN.md`
- `docs/01_ARCHITECTURE.md`
- `lib/nebula_sdk.dart`
- `lib/src/**`
- `test/**`
- `governance/**`

## Allowed Paths

- `docs/multi_agent/reports/MA0_B01_SDK_BASELINE.md`
- 本 Story 状态字段

## Forbidden

- 不修改当前未提交的 SDK 文件。
- 不拆 package。
- 不增加 public export。

## Tasks

1. 枚举 public API surface 和 capability。
2. 记录 F1/F2 的真实测试、治理和示例证据。
3. 标记 Asset 实现可复用的 Transport/Storage/Auth/Proof/Cancellation/Logger。
4. 标记必须由 SDK Architect 串行修改的共享文件。
5. 给出 S2-S01/S02/S03 的依赖与风险。

## Acceptance

- [ ] 公共 API 数量与 snapshot 一致。
- [ ] 所有“可复用”结论有类/文件证据。
- [ ] 明确单 package 继续成立的判断。
- [ ] 列出当前 dirty files 并保持未修改。
- [ ] 输出 F3 准入 checklist。

## Deliverable

`docs/multi_agent/reports/MA0_B01_SDK_BASELINE.md`
