# OBS-CONTRACT-V1-001 Mobile Observability Contract Freeze
- ID：OBS-CONTRACT-V1-001
- Owner: Mobile Observability Contract Agent A
- Execution repo：`.` (`nebula-flutter-sdk`)
- Execution branch：`obs/contract-v1-001-mobile-observability-freeze`
- Platform API mode：**`READ_ONLY`**
- SDK public API mode：**`READ_ONLY`**
- Governance state: contract-documentation only; Task Board / Sprint Board remain Coordinator-only.
- Required upstream: `S1-F04-001 = DONE / REVIEW PASS`.
- Architecture authority: canonical `docs/multi_agent/reports/ACR-MOBILE-OBSERVABILITY-001.md` (R5 approved boundary).
- Implementation authorization: **NONE**.

## Purpose
Freeze the architecture decision record and two V1 observability contract boundaries. This Story does not implement Backend, SDK, App, provider, persistence, endpoint, or ingest behavior.

## Required outputs
1. `ADR-MOBILE-OBSERVABILITY-001` — Mobile Observability Architecture Boundary.
2. `Mobile Analytics Contract v1`.
3. `Error Reporting Contract v1`.

Exact canonical filenames/locations may follow the repository's existing ADR/contract convention, but all three artifacts must be independently reviewable and canonical before this Story can close.

## Frozen architecture inputs
### Shared foundation
Analytics and Error Reporting are separate contracts sharing the approved observability foundation: transport/lifecycle/identity/budget boundaries where applicable. Shared transport does not collapse their domain semantics.

### Analytics classification
- `Mobile Analytics Contract v1` is a **Nebula-owned capability**.
- Platform API classification remains **PENDING**.
- Crash/error/telemetry evidence MUST NOT be relabeled as Analytics second-consumer evidence.
- Any future Platform promotion requires a separate Platform API Review with real second-consumer evidence.

### Error Reporting classification
- `Error Reporting Contract v1` is a Platform-capability candidate supported by verified generic FlyPost error/release telemetry evidence.
- The contract must remain domain-neutral and reusable across Apps.

### Payload boundary
- Observability payloads MUST be bounded.
- Exact byte limits are runtime/implementation budgets, not architecture invariants in this Story.
- Over-limit behavior MUST be deterministic and may reject, sanitize, truncate, or drop.
- The outcome MUST be observable/statistically accountable; silent unbounded retention is forbidden.

### Provider strategy
Provider selection MUST consider data residency, regional availability, legal requirements, and export restrictions. No concrete vendor is frozen by this Story.

### Error fingerprint authority
Nebula/server contract authority remains the long-term fingerprint/issue aggregation SSOT. Third-party provider fingerprints may aid diagnostics/display but MUST NOT replace Nebula authority.

## ADR boundary
The ADR records architecture decisions only:
- why Analytics and Error Reporting are separated;
- why they may share approved foundation/transport boundaries;
- why providers remain replaceable;
- why Crash/Error Reporting is not a product-owned bespoke platform;
- why Analytics SSOT remains Nebula-owned.

The ADR MUST NOT freeze concrete providers, database tables, API endpoints, migrations, or implementation topology.

## Forbidden
- Backend API/router/DTO/database/migration mutation.
- SDK production code/public API/export mutation.
- App/NFC Writer production mutation or repin.
- Provider SDK integration or initialization.
- Analytics ingest rewrite.
- Concrete vendor freeze.
- Registration or implementation of `OBS-001` through `OBS-005` (or equivalent implementation Stories).
- Treating this Story's `READY` state as implementation authorization.
- Agent modification of Task Board / Sprint Board.

## Exit gate
The Story may close only after the ADR and both V1 contracts are canonical, independently reviewed, and explicitly frozen by governance. Only after canonical `DONE / REVIEW PASS` may Coordinator separately register Backend/SDK/provider/cost-control implementation Stories. No implementation authorization is inherited automatically.
