# OBS-SDK-ERROR-V1-001 Error Reporting Internal Core
- ID：OBS-SDK-ERROR-V1-001
- Owner：SDK Error Reporting Agent A
- Execution repo：`.`
- Execution branch：`obs/sdk-error-v1-001-internal-core`
- Platform API mode：`NONE`
- SDK public API mode：`READ_ONLY`
- Governance state：Implementation Agent may change only the authorized SDK-internal Error Reporting core/test surface; Task Board remains Coordinator-only.
- Required upstream：`OBS-CONTRACT-V1-001 = DONE / REVIEW PASS`, `contract_v1_frozen = true`.
- Frozen architecture：`docs/multi_agent/adrs/ADR-MOBILE-OBSERVABILITY-001.md`.
- Frozen contract：`docs/multi_agent/contracts/ERROR_REPORTING_CONTRACT_V1.md`.

## Goal
Implement the smallest SDK-internal Error Reporting V1 core that realizes the frozen domain/lifecycle semantics without exposing a new public SDK API and without depending on a concrete Backend endpoint or provider.

This Story deliberately precedes public-surface publication and Backend ingest implementation. It MUST NOT create a duplicate generic telemetry transport abstraction; existing `NebulaTransport` / request lifecycle / proof foundation remains authoritative.

## Allowed production scope
Only SDK-internal Error Reporting domain code, preferably under a dedicated internal module such as:

- `lib/src/error_reporting/**`

Allowed semantics include:

- immutable report model carrying the frozen V1 diagnostic facts;
- collision-resistant/stable `report_id` lifecycle abstraction;
- `occurred_at` preservation;
- normalization/redaction seam for `safe_message` / stack;
- deterministic bounded over-limit handling;
- domain-specific internal sender Port for later transport binding;
- internal bounded `ErrorStore` Port/lifecycle with count/bytes/age policy boundaries;
- best-effort durable enqueue semantics;
- ACK -> delete lifecycle;
- bounded retry/backlog orchestration seam;
- tests/fakes/fixtures required to prove the frozen contract behavior.

Implementation may define runtime-configurable budget values for tests/defaults, but concrete numeric budgets MUST NOT be promoted into architecture invariants.

## Required invariants
1. Same persisted report retains the same immutable `report_id` across retries.
2. `occurred_at` is never overwritten by upload/receipt time.
3. No caller field becomes authority for trusted app/installation/platform identity.
4. Stored diagnostic values are never emitted into SDK operational logs by the Error Reporting core/store plumbing.
5. Error capture is best effort; no guarantee is claimed after process termination.
6. Local persistence is bounded by count, bytes, and age/TTL policy.
7. Over-limit handling is deterministic and observable/accountable; silent unbounded retention is forbidden.
8. ACK removes the accepted report; transient failure preserves retry identity subject to bounded policy.
9. No native crash/minidump/ANR/breadcrumb/screenshot/raw-log collection is introduced.
10. No generic `MobileTelemetryTransport` or equivalent duplicate shared transport is introduced.

## Forbidden
- `lib/nebula_sdk.dart` mutation.
- `lib/src/nebula.dart` mutation.
- `lib/src/capabilities.dart` mutation.
- `governance/api_surface.snapshot` / public API snapshot mutation.
- Any new public export or public capability exposure.
- `lib/src/foundation/**`, `lib/src/transport/**`, or shared storage foundation mutation unless a separately authorized owner Story exists.
- Backend endpoint/router/DTO/schema/migration/error-code mutation.
- App/NFC Writer mutation or SDK repin.
- Provider SDK integration/initialization.
- Analytics ingest/sender implementation.
- Native crash/minidump/ANR support.
- Task Board/Sprint Board mutation by Implementation Agent.

If the internal implementation cannot satisfy the frozen contract without changing a shared/public SDK surface, STOP and return a Delivery Note describing the exact gap. Do not expand scope.

## Verification
- Task Source Guard `OBS-SDK-ERROR-V1-001` PASS.
- Cross Repo Guard PASS.
- `git diff --check` PASS.
- Production diff restricted to the authorized internal Error Reporting module.
- `lib/nebula_sdk.dart`, `lib/src/nebula.dart`, `lib/src/capabilities.dart`, public API snapshot: byte-identical to execution base.
- Focused Error Reporting tests PASS.
- `dart analyze` PASS or no regression against the canonical repository gate.
- Full relevant SDK tests/governance gates required by CI PASS.
- Delivery Note records exact candidate, base, changed paths, invariants, tests, and confirms Backend/App/provider/public-surface mutation = 0.

## Exit
Delivery goes to independent SDK Review only. A PASS does not authorize public SDK export, Backend ingest, provider integration, App release, or any other OBS Story. Coordinator must publish canonical closure separately.
