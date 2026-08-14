# S1-F04-001 Mobile Observability Contract Gap Audit
- ID：S1-F04-001
- Owner：Mobile Observability Contract Agent A
- Execution repo：`.` (`nebula-flutter-sdk`)
- Execution branch：`s1/f04-001-mobile-observability-gap-audit`
- Governance state：`READ_ONLY`; Task Board / Sprint Board 仅 Coordinator 可写
- Delivery：SDK governance repo 内只提交 audit / ACR evidence；不得跨仓 implementation claim
- Platform API mode：**`READ_ONLY`**
- SDK public API mode：**`READ_ONLY`**
- Triggering product：NFC Writer `NEBULA-APP-001D`
- Required upstream：`S1-F01-004 = DONE`、`S1-F02-002 = DONE / REVIEW PASS`
- SDK authority baseline：fresh canonical `hub/main` at execution start; registration evidence observed `4af7b5d8bfb74ad65a81c3dfe72750fa59807379`
- Backend authority baseline：fresh authenticated FlyPostAPI `Dev` at execution start; registration evidence observed `c8c6cdc7413ffef1b63729b6b3de54596a3a9ed9`
- App evidence baseline：fresh NFC Writer `origin/dev` at execution start; registration evidence observed `f1f3b616c3246d075298fffc6a1b2b3bf63c04a5`
- Goal：机械审计 Analytics + Crash/Error Reporting 的 mobile capability gap，产出可独立评审的 ACR preparation；**不是在本 Story 实现 endpoint / sender / Crash SDK**。

## Frozen observed facts at registration
1. SDK F2-03 / F2-04 已存在：`NebulaAnalyticsEvent`、`NebulaAnalyticsSender`、有界队列/批量/退避/失败回队均已实现。`flush()` 仅在 `sender == null` 时 no-op；禁止把 F2-04 描述成“未实现”。
2. SDK `NebulaAnalyticsEvent.toJson()` wire = `name / timestamp / identifiable / properties`。
3. Backend legacy client ingest 存在 `POST /api/v1/analytics/events`，DTO = `name / user_id / props / region_code`。这不是现成 mobile contract。
4. Backend legacy endpoint 位于 `/api/v1` 的 `Signature()` + Token/Idempotent 链；`CONTRACT-MOBILE-CAPABILITY` 明确 MB-01：移动二进制不得持有 App Secret，mobile capability 必须走 InstallationProof / app-token 安全面。
5. Backend mobile request body 当前硬上限 32 KiB；SDK analytics 单事件上限 8 KiB、队列 64 KiB、batchSize 默认 50。必须机械处理 wire/body-budget 关系，不能默认兼容。
6. SDK event 有 client timestamp，Backend legacy analytics 当前按 server `created_at` 落库；离线队列/延迟 flush 的发生时间语义必须显式裁定。
7. canonical SDK 当前无 Crash/Error Reporting public API / implementation。历史 ADR-027 与 MA0 ownership 已冻结 Crash 为 SDK-owned V1 generic capability，但没有冻结具体 wire/schema/lifecycle。
8. NFC Writer `NEBULA-APP-001D` 明确 WAIT：禁止 App 自建 Crash transport、禁止绕过 SDK、禁止把 no-sender Analytics 伪装 production ready。

## Second-consumer evidence to verify
Platform contract change gate必须机械验证至少一个第二消费者。Registration 已观察到 FlyPost App 自身 release governance 存在：
- `docs/sprints/FLUTTER_P0_SPRINT_PLAN.md`：Release 要求 `Crash/Telemetry/request_id`；
- `docs/sprints/AGENT_TASK_BOARD.md`：`S6-01` telemetry/release lane；
- `docs/sprints/TASK_REGISTRY.json`：`lib/core/telemetry/**`。
Agent 必须 fresh 复核这些证据，并判断是否与 NFC Writer 使用**同一通用语义**；不得只写“StarSprout/FlyPost 未来可能需要”。

## Mandatory audit questions
Q1：现有 Backend `/analytics/events` 哪些字段/认证/错误/限流/时间语义与 SDK F2-04 不一致？逐项 file:line + test evidence。
Q2：能否完全通过 SDK-internal / App Adapter 解决而不改变 Platform contract？若不能，说明为何 MB-01 / wire / trust source 阻止复用。
Q3：Analytics mobile capability 的最小 domain-neutral contract 需要冻结哪些：path、auth/proof、request envelope、event fields、server-trusted identity、body/batch caps、timestamp、privacy、error/retry/idempotency/rate-limit？
Q4：Crash/Error Reporting 最小 V1 是否可以复用同一 mobile telemetry transport，还是必须独立 endpoint/schema？必须比较安全、持久化、crash-next-launch、隐私和运维成本；不要预设答案。
Q5：Crash capability 的 SDK lifecycle 最小语义是什么（fatal/non-fatal、bounded persistence、next-launch flush、redaction/data scope）？不得引入产品字段或 NFC 专属模型。
Q6：`NEBULA-APP-001D` 所需的 App Adapter 是否在 contract-ready 后可以保持薄映射，不需要 App 自建 HTTP/transport？
Q7：CONTRACT_CHANGE 10 问是否全部可回答；若任一缺失，ACR Decision 必须 DEFERRED/REJECTED。

## Required outputs
- `docs/multi_agent/reports/S1-F04-001_MOBILE_OBSERVABILITY_GAP_AUDIT.md`
- `docs/multi_agent/reports/ACR-MOBILE-OBSERVABILITY-001.md`（ACR preparation；不得由 Implementation Agent 自批）
- exact cross-repo contract matrix：SDK ↔ Backend legacy ↔ Mobile Capability Contract ↔ NFC Writer 001D ↔ second consumer
- recommended follow-up split（仅建议，不自行注册/施工）：Contract Freeze、Backend implementation、SDK public capability implementation、App 001D release。

## Allowed
- SDK repo `docs/multi_agent/reports/**` 下本 Story audit / ACR evidence
- 只读检查 SDK / Backend / NFC Writer / FlyPost consumer evidence
- contract tests 的**提案/fixture 草案作为报告内容**，但不得修改 frozen contract surface

## Forbidden
- ❌ Backend production mutation
- ❌ 新增/修改 endpoint、router、DTO、DB migration、error code、trust scope
- ❌ SDK production/public API mutation，包括 sender implementation、Crash API、exports
- ❌ NFC Writer / FlyPost / StarSprout production mutation
- ❌ Task Board / Sprint Board 由 Agent A 修改
- ❌ 把 legacy HMAC `/analytics/events` 直接宣布为 mobile-ready
- ❌ 恢复/要求移动端持有 App Secret
- ❌ 把 `NebulaAnalyticsSender` host-injected Port 当作 production sender 已存在
- ❌ 在 ACR 未批准前创建 CONTRACT_CHANGE / IMPLEMENT_FROZEN_CONTRACT implementation
- ❌ 上报 NFC UID/dump/MRZ/完整卡号/Token/信件正文等产品敏感数据

## Verification
- fresh SDK main / Backend Dev / NFC Writer dev / FlyPost consumer evidence
- Task Source Guard for `S1-F04-001`
- Cross Repo Guard
- `git diff --check`
- production source diff must be 0
- report must explicitly distinguish：F2-04 queue/sender Port readiness vs production ingest transport readiness

## Exit / authority
Story 只能交付到 Independent Architecture Review。若 ACR 被 APPROVED，仍必须由 Coordinator **另行注册** contract-freeze / Backend / SDK implementation Story；Agent A 不得从本 Story 直接扩 scope。
