# Task Pack — MA0-S01 Security Baseline 与后置加固输入

- Epic：EPIC-GOV / EPIC-SEC
- Owner：Security Architect Agent
- SP：2

## Goal

保留安全重要性，同时明确哪些安全必须随主链同步、哪些进入 S7，避免再次阻塞 SDK/API 主流程。

## Inputs

- 唯一 Backend Authority：`/Users/sean/Documents/project/forAI/flypost_backend`；BE-Codex/其他副本不作为现状或缺陷来源
- `nebula-flutter-sdk/docs/02_SECURITY_MODEL.md`
- `flypost_backend/docs/CODING_RULES_SECURITY.md`
- `flypost_backend/docs/PRODUCTION_READINESS_AUDIT_2026-08-03.md`
- identity/appidentity/file/payment/notification/security 相关实现
- MA0-C01 DONE 输出：Payment = HIGH-RISK PARTIAL；Refund local-only；Reconciliation missing；当前 `module/file` 存在 owner 自声明风险；表已是 `asset_object`
- MA0-D01 DONE 输出：首个 APK slice 为 runtime-config only；Asset/Notification/Payment/AI 暂不进入首切片

## Allowed Paths

- `docs/multi_agent/reports/MA0_S01_SECURITY_BASELINE.md`
- 本 Story 状态字段

## Forbidden

- 不新增或修改安全代码。
- 不自行扩展 Risk Engine/Factor/Provider。
- 不阻塞 S1 Contract，除非发现会导致密钥泄露、越权或资金错误的 P0。

## Tasks

1. 列出已有安全能力及真实接入点。
2. 分类 MUST-WITH-STORY 与 DEFER-TO-S7。
3. 为 Asset/Auth/Payment 定义最低安全验收。
4. 记录已有 WIP 的 Keep/Adapt/Review Later/Candidate Remove。
5. 定义 S7 的量化回归场景。
6. 对 Payment 按 charge/callback/subscription/refund/reconciliation 分项定安全等级，禁止整体写成 production-ready。
7. 对 Asset 明确当前 owner-trust P0 与未来 capability/quota/emergency 的最低门槛，但不得提前设计未冻结的 Asset Contract。

## Acceptance

- [ ] 最低安全门槛不超过 8 项且可执行。
- [ ] 每个后置项有触发 Sprint 和验收。
- [ ] 只有 P0 才能阻塞 S1-S3，且有证据。
- [ ] 不为不存在的反馈/业务入口编造实现任务。
- [ ] 输出旧安全 WIP 对账策略。
- [ ] 不引用废弃 backend 副本作为当前安全事实。
- [ ] Payment refund/reconciliation 不得被误判为已生产闭环。
- [ ] Asset owner scope 必须列入 MUST-WITH-STORY，但不得因此自行实现 Asset。

## Deliverable

`docs/multi_agent/reports/MA0_S01_SECURITY_BASELINE.md`
