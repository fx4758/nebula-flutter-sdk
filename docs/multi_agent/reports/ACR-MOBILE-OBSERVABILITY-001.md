# ACR-MOBILE-OBSERVABILITY-001 — Mobile Observability Foundation

- Publication type: **Coordinator Evidence Canonicalization**
- Source: S1-F04-001 audit evidence + Architecture Review R1–R5 record
- Publication owner: **Coordinator**
- Final Architecture Review: **APPROVED**
- ADR: **NOT CREATED**
- Contract v1: **NOT FROZEN**
- Implementation authorization: **FALSE**

## Decision

Reuse existing Nebula transport/trust foundations; later freeze two independent domain contracts:

```text
Existing Nebula transport / request lifecycle / trust foundation
                         |
              +----------+----------+
              |                     |
 Mobile Analytics Contract v1   Error Reporting Contract v1
```

No generic `Mobile Observability Contract v1` payload/schema and no new `MobileTelemetryTransport` abstraction are approved. Domains may share request lifecycle, request_id, auth foundation, error envelope and retry framework; they do not share payload, storage, retention, privacy or dedup identity.

## Canonical Platform policy answers

1. **Exact capability:** Mobile Analytics Ingest and Error Reporting V1, not a generic telemetry-event platform.
2. **Classification:** Error Reporting is a Platform capability candidate; Analytics remains Nebula-internal/pending Platform promotion until its own second consumer is verified.
3. **Second consumer:** Error Reporting **VERIFIED** by FlyPost Crash/Telemetry/request_id + S6-01 telemetry/release + `lib/core/telemetry/**` governance evidence. Analytics generic event ingest **NOT VERIFIED** at final review.
4. **Without NFC Writer:** Error Reporting still exists through FlyPost generic Flutter/Dart failure/release telemetry. Analytics Platform promotion remains unproven.
5. **Why Adapter is insufficient:** trust, wire, body budget, durable retry receipt, event-time and server-authoritative identity cross the App/SDK/Backend boundary.
6. **Why SDK-only is insufficient:** SDK sender abstraction exists while Backend legacy wire/trust/time/idempotency semantics differ; a frozen cross-boundary contract is required.
7. **Missing frozen contracts:** `Mobile Analytics Contract v1` and `Error Reporting Contract v1`; neither is frozen here.
8. **Affected surfaces:** future freeze must cover endpoint/wire, errors, InstallationProof trust, durable identity/idempotency, quota/body budget, occurrence/ingest time and lifecycle/retention.
9. **Compatibility/version/rollback:** mandatory freeze-stage subjects; no migration/implementation is approved here.
10. **Security/privacy/cost:** server-trusted installation identity, bounded payload/queue/upload/retention, deterministic over-limit handling, privacy-safe Error Reporting and provider compliance are mandatory; heavy observability infrastructure is outside this Story.

## Decision A — Mobile Analytics freeze direction

Existing `NebulaAnalyticsEvent` / `NebulaAnalyticsSender` remain the starting public domain boundary; this ACR does not authorize public-event-model mutation.

Future freeze direction:

- SDK/client-generated `batch_id`;
- stable `batch_id` across retries of the same queued batch;
- batch immutable once identity is assigned; same `batch_id` with changed events is invalid;
- durable server receipt must make `commit → response lost → same batch retry` return accepted/success without reinsertion;
- V1 does not require event-level `event_id` when immutable batch receipt is sufficient;
- `occurred_at` and `ingested_at` are distinct;
- proof-protected canonical request bytes fit current `maxProofReadBytes = 16 * 1024`;
- exact-byte splitting is required; gzip is optional/deferred and correctness cannot depend on compression.

No endpoint/table/unique-key/sender implementation is authorized here.

## Decision B — Error Reporting V1 freeze direction

Included: Flutter/Dart uncaught errors and explicit caught errors.

Deferred: native crash/process signals, minidump, ANR, breadcrumbs, screenshots and full/raw logs.

Client diagnostic facts may include immutable client-generated `report_id`, `occurred_at`, `error_type`, privacy-safe message, bounded stack, request_id and diagnostic app version/build snapshot. app_id/installation_id/platform authority is server-trusted via InstallationProof/trusted installation record, not caller authority.

`report_id` handles one report's persistence/retry identity. Server normalization/fingerprint/grouping is separate and server-authoritative. Raw reports are short-retention diagnostic instances; issue aggregation is a separate longer-lived projection/concept, not raw-report storage.

## Lifecycle / cost / provider direction

Approved lifecycle: `Error → normalize → bound check → local persistence(best effort) → bounded later upload → ACK → delete`. If later frozen, ErrorStore is host-injected, app-private, bounded by reports/bytes/age, must not log stored values and purges acknowledged reports. Fatal-path semantics are best-effort durable enqueue only.

Payload fields/local queues/upload budgets/retention must be bounded. Concrete numeric limits are runtime/implementation configuration unless separately frozen. Over-limit behavior must be deterministic. Client must support server-directed upload reduction policy; policy values may evolve. Unbounded startup history upload is forbidden.

Nebula owns contract/privacy/lifecycle/identity/budget. Provider adapters may own collection backend/dashboard/storage implementation. Provider selection must consider data residency, regional availability, legal requirements and export restrictions. App product code must not directly encode regional provider branching. Error Reporting V1 may later use third-party adapters; no provider integration or self-built full Crash platform is authorized. Analytics remains a Nebula-owned SSOT/product-data direction.

## Final governance disposition

```text
Architecture direction: APPROVED
S1-F04-001 implementation authority: NONE
ADR inside this Story: FORBIDDEN
Contract v1 freeze inside this Story: FORBIDDEN
Backend / SDK / App production mutation: FORBIDDEN
```

After this evidence is canonical and S1-F04-001 is Coordinator-closed, Coordinator may separately register ADR/contract-freeze governance. Implementation Stories remain downstream of approved frozen contracts.
