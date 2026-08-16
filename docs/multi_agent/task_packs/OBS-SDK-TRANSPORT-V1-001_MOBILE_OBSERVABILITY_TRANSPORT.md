# OBS-SDK-TRANSPORT-V1-001 — Mobile Observability SDK Transport V1

- ID：OBS-SDK-TRANSPORT-V1-001
- Owner：SDK Observability Transport Agent A
- Reviewer：SDK Review Agent
- Execution repo：`.`
- Execution branch：`obs/sdk-transport-v1-001-mobile-observability`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`READ_ONLY`
- Governance state：`READY`; Task Board remains Coordinator-only.
- Required upstream：`OBS-BACKEND-V1-001 = DONE / REVIEW PASS`, `OBS-SDK-ERROR-API-V1-002 = DONE / REVIEW PASS`, and `OBS-SDK-ERROR-SEAM-V1-001 = DONE / REVIEW PASS`.
- Frozen Platform contracts：`contracts/MOBILE_ANALYTICS_PLATFORM_API_V1.md` + `contracts/ERROR_REPORTING_PLATFORM_API_V1.md`.
- Frozen internal Error Reporting seam：`contracts/ERROR_REPORTING_SDK_INTERNAL_SEND_SEAM_V1.md` (review #105; canonical closure through `e7f1df8de4795ad17f278874559917faac05f8b4`).
- Backend canonical：FlyPostAPI `Dev=a19bd52372370d4f2f551c06d18194df4f547681`.

## Goal
Implement concrete SDK-side mobile observability transport bindings for:

1. `POST /api/v1/mobile/analytics/batches`;
2. `POST /api/v1/mobile/error-reports`.

Reuse existing `NebulaTransport`, `buildAuthHeaders`, `RequestProofSigner`, installation-token callback and mobile request lifecycle. Do not create a generic telemetry transport/payload or second shared HTTP/proof abstraction.

## Authorized internal production scope
Expected minimal production write-set:

- `lib/src/analytics/analytics_client.dart` only if required for frozen assigned-batch identity/retry behavior without public signature change;
- new `lib/src/analytics/mobile_analytics_sender.dart`;
- `lib/src/error_reporting/client.dart` only for the reviewed send-outcome / retry / cooldown ordering seam;
- `lib/src/error_reporting/sender.dart` only for the reviewed internal outcome representation;
- new `lib/src/error_reporting/mobile_error_report_sender.dart`.

Focused tests under `test/analytics/**` and `test/error_reporting/**` plus one Delivery Note under `docs/multi_agent/reports/**` are allowed.

If the frozen contract cannot be satisfied without a public SDK or shared transport/foundation change, STOP and return a gap report. Do not expand scope.

## Must remain byte-identical
- `lib/nebula_sdk.dart`
- `lib/src/capabilities.dart`
- `lib/src/nebula.dart`
- `lib/src/analytics/analytics_sender.dart`
- `lib/src/analytics/event.dart`
- `lib/src/analytics/nebula_analytics.dart`
- `lib/src/transport.dart`
- `lib/src/transport/**`
- `lib/src/foundation/**`
- `governance/api_surface.snapshot`
- `governance/public_api.txt`

No public symbol/signature/export change is authorized.

## Analytics requirements
The sender must emit exact frozen wire `{batch_id, events[]}` with event mapping `timestamp -> occurred_at`.

Required invariants:
- select ordered candidate events;
- generate provisional `batch_id`;
- serialize complete body including that ID;
- measure exact UTF-8 JSON bytes and shrink while >16 KiB;
- bind identity only after final body fits;
- once assigned, payload is immutable and every retry uses the same ID;
- later queue additions receive a different ID;
- correctness must not depend on compression;
- legacy `/api/v1/analytics/events` is not used.

Existing public `NebulaAnalyticsSender` signature must remain unchanged. If that seam cannot mechanically preserve assigned identity across the complete existing retry lifecycle, STOP rather than generating a replacement ID per `send()` call.

Outcome mapping:
- `code=0` => success only after validating ACK belongs to assigned batch;
- HTTP 429 / `40002` => rate-limit/defer, no immediate retry loop;
- `12004` / `50001` / timeout / connection ambiguity => bounded retry with the same assigned batch ID;
- `30001` => non-retryable;
- `12001` => preserve the same assigned batch, enter bounded trust-recovery defer, and perform installation-trust recovery before the next network send; normal Analytics transient retry/backoff MUST NOT blindly resend while trust remains invalid;
- malformed/mismatched success data => never success.

## Error Reporting requirements
Emit exact `{reports:[...]}` using immutable `report_id` and `NebulaErrorReport.toDiagnosticMap()` semantics.

Required behavior:
- 1..10 reports and complete request <=16 KiB;
- preserve report IDs, occurred_at and nullable diagnostic facts exactly;
- no caller-authoritative app/install/platform/user identity fields;
- accepted/rejected IDs are disjoint subsets of request IDs;
- `invalid_payload` / `id_conflict` map to rejected;
- IDs omitted from both remain retryable;
- map `defer_remaining` / `retry_after_seconds` to existing cooldown seam;
- HTTP 429 defers complete unprocessed set with bounded local cooldown;
- `12004` / `50001` / transport ambiguity leave reports retryable;
- request-level `30001` never manufactures per-report ACK/rejection;
- `code=0` + `defer_remaining=true` applies accepted/rejected first, preserves omitted IDs without consuming normal retry-attempt budget, then applies bounded cooldown;
- HTTP 429 / `40002` preserves the complete unprocessed set without consuming normal retry-attempt budget;
- `12004` / `50001` / timeout / connection ambiguity use bounded transient retry and preserve immutable `report_id`;
- request-level `30001` is a deterministic local non-retryable drop with dedicated internal accounting, not server ACK/rejection and not retry exhaustion;
- `12001` preserves reports, does not consume normal delivery retry budget, enters bounded cooldown, and requires installation trust recovery before the next network send.

## Proof / trust
Both senders must use the existing installation-token callback, `RequestProofSigner`, `buildAuthHeaders` with exact resolved path/body, and existing `NebulaTransport`. User access token is not required. The exact body sent must be the body covered by proof and must fit the 16 KiB InstallationProof ceiling.

The concrete mobile senders may receive an **internal-only composition callback** semantically equivalent to `recoverInstallationTrust() -> Future<bool>` when required by their frozen `12001` handling. The callback delegates to the existing bootstrap/renewal lifecycle; it MUST NOT create a second bootstrap/proof/transport abstraction and MUST NOT become public SDK surface.

For Error Reporting, the reviewed `ERROR_REPORTING_SDK_INTERNAL_SEND_SEAM_V1.md` semantics remain authoritative: reports are preserved, normal delivery retry budget is not consumed, and no further network send occurs until recovery succeeds.

For Analytics, this callback is authorized **only inside `lib/src/analytics/mobile_analytics_sender.dart`** to satisfy the already-frozen `MOBILE_ANALYTICS_PLATFORM_API_V1.md` rule `12001 -> recover installation trust; no blind retry`. The same immutable assigned `batch_id`/body is retained. After `12001`, the sender enters bounded local defer; the next network send may occur only after the recovery callback succeeds. Recovery false/throw performs no network send and does not generate a replacement `batch_id`.

## Analytics trust-recovery scope correction

Independent SDK Review #108 on implementation candidate `5bd0939cc3ba91d8943cfec3e21098244def842a` correctly identified a governance mismatch: the frozen Analytics Platform contract already required `12001` trust recovery/no blind retry, but the prior reauthorization text granted the recovery callback only to Error Reporting.

This Coordinator correction authorizes **no new production path**. It only makes the existing Analytics sender path's internal composition seam explicit:

```text
lib/src/analytics/mobile_analytics_sender.dart
  may receive internal recoverInstallationTrust() -> Future<bool>
```

No change is authorized to Analytics public API, `analytics_client.dart` scope, shared `transport/**`, `foundation/**`, bootstrap/auth production files, Backend, App, or provider integration. If implementation requires recovery logic outside the already-authorized sender file, STOP and return a new gap.

## Reauthorization after reviewed scope gap

The prior `BLOCKED_SCOPE_GAP` delivery remains canonical audit evidence. Coordinator reauthorization is based solely on `OBS-SDK-ERROR-SEAM-V1-001 = DONE / REVIEW PASS`. The newly authorized production delta over the original M3 scope is exactly:

```text
lib/src/error_reporting/client.dart
lib/src/error_reporting/sender.dart
```

No public/shared/Backend/App/provider scope is added. If implementation requires any other production/public path beyond the complete authorized scope in this Task Pack and Task Board, STOP and return a new gap instead of expanding scope.

## Forbidden
- Backend/App/provider mutation;
- generic telemetry transport/payload/schema;
- `NebulaTransport` or proof/foundation changes;
- public SDK export/snapshot changes;
- Analytics public event/sender signature changes;
- changing frozen endpoint/path/field/error/trust/body-ceiling semantics;
- sensitive NFC/user-content ingestion;
- unrelated refactor.

## Required verification
- exact proof path/body for both endpoints;
- Analytics exact mapping, <=50 events when bytes fit, exact-byte split, same assigned batch ID across retries, error classification, defensive ACK validation;
- Error Reporting exact wire, <=10 reports, <=16 KiB, partial result mapping, retry/defer semantics, defensive ID validation;
- focused Analytics/Error Reporting tests PASS;
- full relevant SDK tests/analyzer/governance/secret scan PASS;
- API surface unchanged;
- `git diff --check` PASS;
- Backend/App/provider diff = 0.

## Delivery / review
Agent A returns one exact SDK candidate and Delivery Note. Agent A does not merge and does not edit Task Board. Formal CI and independent SDK Review must approve the exact candidate before Coordinator merge.

A PASS does not authorize App integration. After canonical closure, Coordinator performs a fresh `NEBULA-APP-001D` capability re-audit and only then decides whether that App Story may leave WAIT.
