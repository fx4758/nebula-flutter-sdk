# OBS-SDK-ERROR-SEAM-V1-001 — Error Reporting Internal Send/Retry/Trust-Recovery Seam Freeze

- ID：OBS-SDK-ERROR-SEAM-V1-001
- Owner：SDK Error Reporting Architecture Agent
- Agent：A
- Reviewer：Architecture Review Agent
- Execution repo：`.`
- Execution branch：`obs/sdk-error-seam-v1-001-internal-send-seam-freeze`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`READ_ONLY`
- Governance state：internal seam freeze only; no production/public mutation.
- Required upstream：`OBS-PLATFORM-API-V1-001 = DONE / REVIEW PASS`, `OBS-SDK-ERROR-V1-001 = DONE / REVIEW PASS`, `OBS-SDK-ERROR-API-V1-002 = DONE / REVIEW PASS`; plus canonical reviewed gap evidence from blocked `OBS-SDK-TRANSPORT-V1-001`.
- Gap authority：`reports/OBS-SDK-TRANSPORT-V1-001_GAP_REPORT.md`.
- Frozen authority：`contracts/ERROR_REPORTING_CONTRACT_V1.md` + `contracts/ERROR_REPORTING_PLATFORM_API_V1.md`.

## Purpose
Freeze the smallest SDK-internal Error Reporting send-result / retry / trust-recovery seam required to unblock the reviewed M3 gap. This Story does not repair `client.dart` or `sender.dart`.

The reviewed blockers are:
1. HTTP 429 / `40002` defer currently consumes retry-attempt budget before cooldown.
2. request-level `30001` currently falls into generic retry scheduling.
3. `12001` invalid installation trust has no recovery/no-blind-retry seam.

## Required output
Create exactly one independently reviewable internal freeze artifact:

- `docs/multi_agent/contracts/ERROR_REPORTING_SDK_INTERNAL_SEND_SEAM_V1.md`

It is an internal implementation contract, not a public SDK API.

## Mandatory decisions
The freeze MUST decide:
1. representation of successful partial accepted/rejected/omitted results and server-directed defer;
2. how 429/`40002` defers the unprocessed set without consuming normal retry-attempt budget;
3. how `12004`, `50001`, timeout and connection ambiguity map to bounded transient retry;
4. how request-level deterministic `30001` becomes non-retryable without fabricated per-report ACK/rejection;
5. deterministic local disposition/accounting for that request-level non-retryable outcome, with no infinite loop;
6. how `12001` becomes trust-recovery-required, stops blind resend, preserves reports, and does not burn normal delivery retry budget merely because trust is invalid;
7. whether a minimal SDK-internal trust-recovery callback/Port is required and its ownership/direction;
8. exact `ErrorReportingClient.flush()` ordering for accepted/rejected, omitted retry, defer, deterministic failure and trust recovery;
9. whether existing `ErrorReportSendResult` can be extended or a distinct internal outcome representation is needed;
10. exact future production write-set required to implement the freeze;
11. compatibility with existing internal Error Reporting core and public `NebulaErrorReporting` capability;
12. a Backend/Platform outcome -> internal SDK outcome -> client lifecycle mapping table.

At minimum semantics must distinguish:

```text
SUCCESS_PARTIAL
DEFER_NO_ATTEMPT
TRANSIENT_RETRY
DETERMINISTIC_NON_RETRYABLE_REQUEST
TRUST_RECOVERY_REQUIRED
```

These are semantic classes, not pre-authorized Dart symbol names.

## Hard boundaries
- no `lib/**` mutation in this Story;
- no public SDK symbol/signature/export/snapshot mutation;
- no Platform contract or Backend mutation;
- no App/NFC Writer/provider/Analytics mutation;
- no generic telemetry abstraction;
- no `NebulaTransport`, proof, or foundation redesign;
- no Task Board/Sprint Board mutation by Agent A.

## Verification
- Task Source Guard `OBS-SDK-ERROR-SEAM-V1-001` PASS;
- Cross Repo Guard PASS;
- `git diff --check` PASS;
- production/public API diff = 0;
- freeze consistent with canonical contracts, internal core and reviewed M3 gap;
- independent Architecture Review PASS on exact candidate.

## Exit
This Story closes only the internal seam freeze. It does not itself restore M3 production authorization. After canonical `DONE / REVIEW PASS`, Coordinator must explicitly reauthorize blocked `OBS-SDK-TRANSPORT-V1-001` (or register a narrowly scoped replacement) with the exact additional internal write-set frozen here.

`NEBULA-APP-001D` remains blocked until M3 implementation canonical closure. `S1-F01-002` is unrelated and must not be claimed from this lane.
