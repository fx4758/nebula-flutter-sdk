# S1-F04-001 — Mobile Observability Contract Gap Audit

- Publication type: **Coordinator Evidence Canonicalization**
- Source: existing S1-F04-001 read-only audit evidence + Architecture Review record through R5
- Publication owner: **Coordinator**
- This is **not** an Agent A implementation delivery.
- Production / SDK public API / Backend / App mutation: **NONE**

## Scope and evidence discipline

This report canonicalizes evidence already collected and reviewed under `S1-F04-001`. It does not reconstruct missing implementation work or promote unsupported design statements into code facts. The registration Task Pack remains the source for original observations; later Architecture Review corrections below supersede registration observations where explicit.

## Mechanical gap summary

### SDK Analytics

The reviewed audit established that the SDK already has the F2-03/F2-04 analytics domain pipeline: `NebulaAnalyticsEvent`, `NebulaAnalyticsSender`, bounded queue/batch behavior, retry/backoff and failure requeue. `flush()` is a no-op only when no sender is configured. Event wire is `name / timestamp / identifiable / properties`.

The gap is therefore not an unimplemented Analytics queue/sender Port; production mobile ingest contract/wiring remains unclosed.

### Backend legacy Analytics

The reviewed audit established that existing `POST /api/v1/analytics/events` differs from SDK/mobile requirements: legacy fields include `name / user_id / props / region_code`; its trust path is the existing Signature/Token/Idempotent path rather than the frozen InstallationProof mobile trust chain; `analytics_event` has no durable `batch_id`/`event_id` receipt identity; and server `created_at` does not preserve client occurrence time as a separate field.

The legacy endpoint is reference evidence only. This Story does not declare it mobile-ready or mutate it.

### Proof/body budget correction

The registration Task Pack recorded a 32 KiB mobile-body observation. Architecture Review later mechanically corrected the proof-protected effective ceiling to `InstallationProof maxProofReadBytes = 16 * 1024`. Final reviewed requirement: canonical proof-protected request bytes must remain within the existing InstallationProof accepted-body ceiling; correctness must not depend on gzip. Changing that ceiling requires a separate Platform contract change.

### Existing idempotency is not durable receipt semantics

Architecture Review mechanically confirmed existing Backend `Idempotent()` uses Redis `SETNX`, TTL 60 seconds, and is not a durable receipt ledger/prior-success response replay mechanism. It therefore does not by itself close `server commit → response lost → SDK retry`.

### Error Reporting

The reviewed inventory found no canonical SDK Error Reporting public capability and no canonical Backend Error Reporting ingest contract/implementation in the audited surface. Generic transport/error/request-id foundations are not equivalent to Error Reporting.

Approved V1 direction is Flutter/Dart uncaught errors plus explicit caught errors. Native process crash, minidump, ANR, breadcrumbs, screenshots and full logs remain deferred.

## Reviewed contract gaps carried forward

Time semantics must separate `occurred_at` (client occurrence) from `ingested_at` (server receipt). Offline uploads must not substitute ingest time for behavioral occurrence time.

Analytics freeze direction uses stable client-generated `batch_id` for an immutable queued batch across retries. Error Reporting uses immutable client-generated `report_id` for one report instance; server-side fingerprint/grouping authority is separate. These are later freeze-stage decisions, not implementation here.

## Second-consumer evidence

Error Reporting second-consumer evidence was accepted from FlyPost governance: `FLUTTER_P0_SPRINT_PLAN.md` Crash/Telemetry/request_id requirement, `AGENT_TASK_BOARD.md` S6-01 telemetry/release lane, and `TASK_REGISTRY.json` `lib/core/telemetry/**`. Reviewed semantics are generic Flutter/Dart failure/release telemetry and do not depend on NFC UID/card type or FlyPost letter-content schema.

Analytics second-consumer evidence was not allowed to borrow Error Reporting evidence. At final review it remained insufficient to prove a second consumer for generic analytics-event ingest. Analytics therefore remains internal/pending Platform promotion until mechanically established otherwise.

## Cost/privacy/lifecycle/provider boundaries accepted for later freeze

Payload fields, local queues, upload budgets and retention must be bounded; concrete numeric limits are runtime/implementation configuration unless separately frozen; over-limit behavior must be deterministic. ErrorStore, if frozen, is host-injected/app-private, bounded by reports/bytes/age, does not log stored values, and purges acknowledged reports. Fatal-path persistence is best-effort durable enqueue only. Client must support server-directed upload reduction policy whose values may evolve. No user_id/raw logs/breadcrumbs/user content by default and no heavy observability stack are authorized here.

Nebula owns contract/privacy/lifecycle/identity/budget. Provider adapters may own collection backend/dashboard/storage implementation. Provider selection must consider data residency, regional availability, legal requirements and export restrictions. No provider integration is authorized here.

## Audit disposition

```text
S1-F04-001 audit evidence: CLOSED
Architecture direction: APPROVED through R5
Production implementation authorized: false
ADR created: false
Contract v1 frozen: false
```

After canonical Story closure, Coordinator may separately register ADR/contract-freeze governance. Backend/SDK/App implementation remains downstream of an approved frozen contract.
