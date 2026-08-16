# OBS-PLATFORM-API-V1-001 — Mobile Observability Platform API Freeze

- ID：OBS-PLATFORM-API-V1-001
- Owner：Mobile Observability Platform Contract Agent A
- Reviewer：Architecture Review Agent
- Governance state：`READY`; Task Board remains Coordinator-only.
- Execution repo：`.`
- Execution branch：`obs/platform-api-v1-001-mobile-observability-freeze`
- Platform API mode：`CONTRACT_CHANGE`
- SDK public API mode：`READ_ONLY`
- Production implementation authorized：**NO**

## Goal

Turn the already-approved mobile observability domain contracts into concrete, reviewable Platform API contracts for **two independent domains**:

1. Mobile Analytics ingest;
2. Error Reporting ingest.

This Story freezes endpoint/wire/error/trust/idempotency/limits/compatibility semantics only. It MUST NOT implement Backend routes/handlers/schema, SDK sender/transport, App wiring, or provider integration.

## Authority / prerequisites

- `S1-F04-001 = DONE / REVIEW PASS`
- `OBS-CONTRACT-V1-001 = DONE / REVIEW PASS`
- `ADR-MOBILE-OBSERVABILITY-001` canonical
- `MOBILE_ANALYTICS_CONTRACT_V1` canonical
- `ERROR_REPORTING_CONTRACT_V1` canonical
- second consumer evidence already accepted in S1-F04-001 / ACR: FlyPost release telemetry lane

## Required outputs

Exactly two concrete Platform API contract candidates plus task-local review evidence if needed:

- `docs/multi_agent/contracts/MOBILE_ANALYTICS_PLATFORM_API_V1.md`
- `docs/multi_agent/contracts/ERROR_REPORTING_PLATFORM_API_V1.md`

The two contracts MUST remain separate. Do not create a generic telemetry payload/schema/endpoint.

## Mandatory freeze decisions

For each domain independently, freeze at minimum:

- concrete mobile endpoint path + method;
- InstallationProof / trusted-installation authentication and trust sources;
- canonical request and response envelope;
- field mapping from the frozen domain contract;
- request/body ceiling and deterministic oversize behavior;
- durable identity semantics (`batch_id` / `report_id`), duplicate ACK and same-ID/different-payload conflict behavior;
- `occurred_at` versus server-owned `ingested_at`;
- concrete non-retryable / conflict / rate-limit or upload-reduction error semantics required by clients;
- retry acknowledgement semantics and request_id behavior;
- privacy/redaction boundary;
- compatibility/versioning/rollback behavior for existing clients;
- legacy `/api/v1/analytics/events` relationship: explicitly reused, adapted, versioned, or not used — no implicit equivalence;
- second-consumer applicability without NFC Writer-specific fields.

## Allowed

- the two required contract docs;
- task-local reports/evidence under `docs/multi_agent/reports/**` if needed;
- read-only inspection of SDK, FlyPostAPI, NFC Writer and FlyPost consumer evidence.

## Forbidden

- Backend production mutation;
- SDK production/public API mutation;
- App mutation;
- provider integration;
- database migration/schema implementation;
- NFC/product fields in Platform API;
- generic `MobileTelemetry` payload/endpoint abstraction;
- changing InstallationProof platform body ceiling inside this Story;
- marking contract `FROZEN` before independent review;
- Task Board state mutation by Agent A.

## Acceptance

- both contract candidates answer the Platform API Change Policy 10-question gate;
- no product-specific semantics leak upward;
- exact body/idempotency/error behavior is mechanically implementable;
- compatibility and rollback are explicit;
- second-consumer evidence remains valid;
- `git diff --check` PASS;
- production diff = 0;
- Formal Forgejo CI SUCCESS;
- independent Architecture Review APPROVED on exact candidate.

## Follow-up queue after closure

Coordinator should serially register, without requiring a new product-planning round:

1. `OBS-BACKEND-ERROR-V1-001` — Backend Error Reporting ingest implementation (`IMPLEMENT_FROZEN_CONTRACT`);
2. `OBS-SDK-ERROR-TRANSPORT-V1-001` — SDK Error Reporting concrete transport/sender;
3. `OBS-BACKEND-ANALYTICS-V1-001` — Backend Mobile Analytics ingest implementation (`IMPLEMENT_FROZEN_CONTRACT`);
4. `OBS-SDK-ANALYTICS-TRANSPORT-V1-001` — SDK `NebulaAnalyticsSender` concrete mobile transport;
5. fresh App capability audit; if both domains canonical-ready, Coordinator promotes `NEBULA-APP-001D` to READY.
