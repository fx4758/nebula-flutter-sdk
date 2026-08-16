# Error Reporting SDK Internal Send Seam V1

Status: **FREEZE CANDIDATE / INDEPENDENT ARCHITECTURE REVIEW REQUIRED**

Story: `OBS-SDK-ERROR-SEAM-V1-001`

This document freezes an SDK-internal transport outcome/retry/trust-recovery seam only. It introduces no public SDK API and changes no Platform contract.

## 1. Authorities and problem

Authority:
- `ERROR_REPORTING_CONTRACT_V1.md`;
- `ERROR_REPORTING_PLATFORM_API_V1.md`;
- reviewed `OBS-SDK-TRANSPORT-V1-001_GAP_REPORT.md`.

The current `ErrorReportSender -> ErrorReportSendResult` seam can represent successful partial results but cannot faithfully distinguish 429 defer, request-level `30001`, and `12001` trust recovery. `ErrorReportingClient.flush()` currently schedules retry for omitted/all reports before it can apply defer, and generic sender exceptions consume the same retry budget.

## 2. Frozen design

Extend the existing **internal** `ErrorReportSendResult` model with an internal disposition. Exact Dart spelling may vary only if independent review confirms identical semantics; public API delta remains zero.

Semantic dispositions:

```text
processed
rateLimitedDefer
transientFailure
deterministicRequestFailure
trustRecoveryRequired
```

The existing accepted/rejected ID sets and optional cooldown remain internal result facts. `processed` may additionally carry `deferRemaining=true` from a successful `code=0` envelope.

No expected frozen Platform outcome may depend on a generic exception path for lifecycle meaning. Unexpected programmer/parse failures may still throw; the client treats those conservatively as transient/ambiguous failure.

## 3. Result invariants

### processed
- accepted/rejected IDs are disjoint subsets of request IDs;
- accepted/rejected are server-authoritative and may be deleted locally;
- IDs omitted from both remain unprocessed/retryable;
- `deferRemaining=false`: omitted IDs enter normal bounded retry accounting;
- `deferRemaining=true`: apply accepted/rejected first, then keep omitted IDs queued **without incrementing attempt count**, and apply bounded global cooldown.

### rateLimitedDefer
Used for HTTP 429 / `40002` before report processing:
- accepted/rejected sets MUST be empty;
- complete attempted set remains queued;
- no attempt counter increment;
- no delete;
- bounded global cooldown;
- no immediate retry loop.

### transientFailure
Used for `12004`, `50001`, timeout, connection loss and ambiguous transport failure:
- accepted/rejected sets MUST be empty;
- same immutable `report_id` set is preserved;
- normal bounded retry accounting increments;
- existing retry exhaustion policy remains applicable.

### deterministicRequestFailure
Used for request-level `30001` or equivalent deterministic construction defect after proof succeeds:
- accepted/rejected sets MUST be empty;
- no per-report ACK/rejection is fabricated;
- same deterministically invalid request MUST NOT enter an infinite retry loop;
- attempted reports are removed as a **local non-retryable drop**, not as server ACK/rejection and not as retry exhaustion;
- internal stats count this separately from `acknowledged`, `rejected`, and `retryExhausted`.

This local-drop disposition is frozen because current ErrorStore has no quarantine state. A later quarantine feature requires separate review.

### trustRecoveryRequired
Used for `12001` invalid InstallationProof/token/key/replay:
- accepted/rejected sets MUST be empty;
- reports remain queued and retain immutable IDs;
- normal delivery retry count is not incremented merely because trust is invalid;
- client applies bounded cooldown and stops current flush;
- next concrete mobile sender attempt MUST perform installation trust recovery **before another network send**.

## 4. Trust-recovery ownership

Do not add a shared/public bootstrap or transport abstraction.

The concrete future `MobileErrorReportSender` owns an internal-only recovery callback supplied by composition, semantically:

```text
recoverInstallationTrust() -> Future<bool>
```

This callback delegates to the already-existing installation bootstrap/renewal lifecycle. It does not define a second bootstrap protocol and does not expose keys/tokens to App business code.

Concrete sender state rule:

```text
receive 12001
→ mark trust-recovery-required
→ return trustRecoveryRequired
→ client preserves reports + cooldown, no attempt burn
→ next sender invocation
→ run recovery callback BEFORE transport send
→ recovery false/throws: return trustRecoveryRequired again, no network send
→ recovery true: clear trust block, resolve fresh installation token/proof inputs, then send same report IDs
```

The callback is required for the concrete mobile sender. The generic `ErrorReportSender` interface does not gain bootstrap knowledge. Client `flush()` remains single-flight; no new shared single-flight foundation is required.

## 5. Bounded cooldown

For defer/trust-recovery cooldown, normalize runtime policy as:

```text
selected = domain hint when present, otherwise retryBaseDelay
bounded = clamp(selected, minimum=retryBaseDelay, maximum=retryMaxDelay)
```

A zero/null hint therefore cannot create an immediate retry loop. Numeric defaults remain runtime implementation policy, not architecture constants.

## 6. Frozen flush ordering

```text
read bounded ready batch
→ sender.send(report IDs unchanged)
→ validate outcome + ID subsets
→ switch disposition
```

For `processed`:

```text
apply accepted deletes + acknowledged stats
→ apply rejected deletes + rejected stats
→ compute omitted IDs
→ if deferRemaining:
     preserve omitted IDs without attempt increment
     set bounded cooldown
  else:
     schedule normal retry for omitted IDs
```

For `rateLimitedDefer`:

```text
preserve entire batch
→ no scheduleRetry
→ set bounded cooldown
```

For `transientFailure`:

```text
scheduleRetry(entire affected batch)
```

For `deterministicRequestFailure`:

```text
delete attempted batch as local non-retryable drop
→ increment dedicated internal deterministic-drop stat
→ do not increment acknowledged/rejected/retryExhausted
```

For `trustRecoveryRequired`:

```text
preserve entire batch
→ no scheduleRetry
→ set bounded cooldown
→ next sender call performs recovery before network
```

Any invalid sender result (overlapping IDs, foreign IDs, or IDs on a non-processed disposition) is transient/ambiguous and never success.

## 7. Platform mapping

| Backend/transport outcome | Internal disposition | Attempt budget | Local action |
|---|---|---|---|
| HTTP 200 / `code=0`, no defer | `processed` | omitted IDs consume retry | delete accepted/rejected; retry omitted |
| HTTP 200 / `code=0`, `defer_remaining=true` | `processed` + defer | omitted IDs do not consume attempt | delete accepted/rejected; preserve omitted; cooldown |
| HTTP 429 / `40002` | `rateLimitedDefer` | no | preserve full set; cooldown |
| `12004` / `50001` | `transientFailure` | yes | bounded retry full affected set |
| timeout/connection ambiguity | `transientFailure` | yes | bounded retry same immutable IDs |
| request-level `30001` | `deterministicRequestFailure` | no retry | local deterministic drop; no fabricated ACK/rejection |
| `12001` | `trustRecoveryRequired` | no | preserve; cooldown; recover before next network send |
| malformed/mismatched success data | transient/invalid-result path | yes | never success; bounded retry |

## 8. Future exact production write-set

This freeze authorizes **no production mutation now**. A later Coordinator M3 reauthorization may add only these Error Reporting production paths for this gap:

```text
lib/src/error_reporting/client.dart
lib/src/error_reporting/sender.dart
lib/src/error_reporting/mobile_error_report_sender.dart
```

Focused tests may use `test/error_reporting/**`. No new shared file is required. Existing M3 Analytics-authorized paths remain separate and are unchanged by this freeze.

## 9. Must remain unchanged unless separately authorized

```text
lib/nebula_sdk.dart
lib/src/capabilities.dart
lib/src/nebula.dart
lib/src/transport.dart
lib/src/transport/**
lib/src/foundation/**
governance/api_surface.snapshot
governance/public_api.txt
Backend
App / NFC Writer
Provider integration
Analytics public surface
```

The already-public `NebulaErrorReporting.reportCaughtError(...)` signature remains unchanged.

## 10. Compatibility and privacy

- no new public symbol/export;
- no caller authority over app/install/platform identity;
- no raw logs/breadcrumbs/screenshots/user content;
- no provider identifiers;
- no native crash/minidump/ANR promise;
- immutable `report_id` and `occurred_at` remain unchanged through retry/defer/trust paths.

## 11. M3 unblock rule

This freeze does not itself make `OBS-SDK-TRANSPORT-V1-001` READY.

Required sequence:

```text
this freeze candidate
→ independent Architecture Review APPROVED
→ Coordinator canonical closure
→ explicit Coordinator reauthorization of blocked M3 with exact additional write-set
→ Agent A resumes M3 implementation
```

Until then, `OBS-SDK-TRANSPORT-V1-001` stays BLOCKED and `NEBULA-APP-001D` capability re-audit stays blocked. `S1-F01-002` remains unrelated.
