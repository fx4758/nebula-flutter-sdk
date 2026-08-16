# OBS-BACKEND-V1-001 — Mobile Observability Backend Ingest V1

- ID：OBS-BACKEND-V1-001
- Owner：Backend Observability Agent A
- Reviewer：Backend Review Agent
- Execution repo：`../flypost_backend`
- Execution branch：`obs/backend-v1-001-observability-ingest`
- Platform API mode：`IMPLEMENT_FROZEN_CONTRACT`
- SDK public API mode：`NONE`
- Governance state：`READY`; Task Board remains Coordinator-only.
- Required upstream：`OBS-PLATFORM-API-V1-001 = DONE / REVIEW PASS`.
- Frozen contracts：`contracts/MOBILE_ANALYTICS_PLATFORM_API_V1.md` + `contracts/ERROR_REPORTING_PLATFORM_API_V1.md`.

## Goal

Implement the two independently frozen mobile observability ingest APIs in one Backend release milestone to remove governance serialization overhead while preserving strict domain separation:

1. `POST /api/v1/mobile/analytics/batches`;
2. `POST /api/v1/mobile/error-reports`.

This is one execution Story because both changes are in the same Backend repository and share only existing mobile trust/envelope infrastructure. It is **not** permission to create a generic telemetry endpoint, payload, table, service or repository.

## Frozen architecture

```text
/api/v1/mobile/analytics/batches
  -> InstallationProof
  -> Analytics mobile handler/service/repository
  -> Analytics durable batch receipt + event persistence

/api/v1/mobile/error-reports
  -> InstallationProof
  -> Error Reporting handler/service/repository
  -> durable report receipt + diagnostic report persistence
```

Allowed shared infrastructure is limited to already-existing generic mobile request lifecycle/trust/error/rate-limit helpers and genuinely generic persistence helpers that do not encode Analytics/Error semantics.

## Required implementation — Analytics

Implement the frozen Analytics Platform API exactly:

- endpoint/method/trust headers and InstallationProof chain;
- exact 16 KiB proof-covered body ceiling semantics;
- trusted app/install/platform only from proof context;
- canonical `{batch_id, events[]}` request DTO and strict unknown-field rejection;
- `occurred_at`, `identifiable`, `properties` preservation;
- atomic durable acceptance of the complete ordered batch;
- durable identity `(app_id, installation_id, batch_id)`;
- same ID + same payload => original success/no reinsertion;
- same ID + different payload => deterministic `30001`, no insertion;
- original `ingested_at` returned on duplicate ACK;
- `X-Request-Id` response correlation;
- rate-limit/transient/error behavior exactly as frozen;
- legacy `/api/v1/analytics/events` remains compatible and is not silently rewired to mobile trust semantics.

Backend may reuse the existing Analytics authority/aggregation storage only where mobile occurrence time, privacy classification, trusted installation scope and durable batch receipt remain lossless. If the legacy table cannot represent the frozen facts, add additive mobile persistence rather than weakening the contract.

## Required implementation — Error Reporting

Implement the frozen Error Reporting Platform API exactly:

- endpoint/method/trust headers and InstallationProof chain;
- strict `{reports:[...]}` wire with canonical diagnostic fields;
- request-level invalid conditions and per-report `invalid_payload` / `id_conflict`;
- trusted app/install/platform only from proof context;
- preserve client `occurred_at`, record server `ingested_at`;
- durable identity `(app_id, installation_id, report_id)`;
- same ID + same payload => duplicate accepted with original receipt time;
- same ID + different payload => non-retryable report conflict;
- partial accepted/rejected response semantics exactly as frozen;
- no provider/fingerprint IDs in public wire;
- bounded fields/request size and privacy/redaction boundary;
- `X-Request-Id` response correlation;
- rate-limit/transient/error behavior exactly as frozen.

## Persistence requirements

Persistence must be durable enough to prove commit -> response lost -> retry without duplicate logical insertion. Required uniqueness/dedup state MUST be database-durable; request nonce/Redis TTL alone is not sufficient.

Migrations must be additive and rollback-safe. Do not mutate unrelated product tables to avoid creating observability schema. Existing legacy Analytics data must remain readable/compatible.

Concrete table/model naming is implementation detail, but Analytics receipt/event facts and Error Reporting receipt/report facts MUST remain independently queryable and must not be stored as one generic telemetry JSON bucket.

## Allowed Backend write scope

Only changes necessary for these two frozen APIs, including:

- `internal/router/**` focused route wiring/tests;
- `internal/core/analytics/**` mobile-ingest additions while preserving legacy behavior;
- a dedicated Error Reporting core/module directory;
- required model/repository files;
- additive migrations and migration tests;
- focused middleware/helper changes only when required by the frozen new endpoints (for example response request-id echo), with regressions proving no legacy behavior drift;
- focused tests and delivery evidence.

## Forbidden

- SDK/App/provider mutation;
- changing either frozen endpoint/path/method/field/error/trust semantic;
- changing InstallationProof body ceiling;
- legacy HMAC fallback on mobile endpoints;
- generic `/mobile/telemetry` endpoint or shared telemetry payload/schema;
- NFC Writer/Nearvia/StarSprout/FlyPost product fields;
- raw logs/screenshots/content/tokens/NFC UID or dump/MRZ/card data ingestion;
- provider SDK integration, issue dashboard, BI feature work;
- rewriting legacy Analytics endpoint clients;
- unrelated Backend cleanup/refactor.

## Required tests / mechanical evidence

At minimum prove:

### Route/trust
- both exact routes registered under mobile trust plane;
- no legacy Signature middleware requirement/fallback;
- forged caller identity ignored/not accepted;
- valid InstallationProof succeeds; invalid/replayed proof fails;
- exact body over 16 KiB follows frozen proof-layer rejection with zero commit;
- response request-id correlation is present.

### Analytics
- first insert success;
- commit + response-lost equivalent retry -> duplicate ACK, zero duplicate events;
- same batch ID/different payload -> `30001`, zero new insert;
- ordered payload and occurred/ingested clocks preserved;
- malformed/unknown fields/empty batch rejected atomically;
- legacy `/api/v1/analytics/events` regressions PASS.

### Error Reporting
- accepted/rejected partial result semantics;
- same report retry -> duplicate ACK, no second logical report;
- same report ID/different payload -> `id_conflict`;
- duplicate/missing invalid report IDs at request level;
- per-report invalid payload does not reject independent valid reports;
- privacy/bounds enforced;
- occurred/ingested clocks preserved.

### Migration / regression
- forward migration PASS on clean + existing schema;
- rollback or rollback-plan verification PASS;
- full Backend focused quality suite + race/static/governance required by repository policy;
- `git diff --check` PASS;
- cross-repo SDK/App diff = 0.

## Delivery / review

Agent A returns one exact Backend candidate and Delivery Note. It does not edit SDK Task Board. Formal Backend CI and independent Backend Review must approve the exact candidate before merge.

After canonical Backend closure, Coordinator immediately promotes `OBS-SDK-TRANSPORT-V1-001` as the next M3 Release Milestone; do not create separate Error-vs-Analytics registration/closure cycles.
