# OBS-SDK-TRANSPORT-V1-001 — Implementation Gap Report

Status: **STOP / AUTHORIZED SCOPE INSUFFICIENT**

This is an Agent A fail-closed delivery. It does not edit the Coordinator-owned Task Board and does not authorize production scope expansion.

## Canonical execution source

- canonical base: `e3881307991ea83a692330393edd818e70b35a47`
- registration candidate: `24711dee934321ec1f2660f2e1c1f8652a7c317e`
- registration PR: `#42`
- independent registration review: `#99 APPROVED / reviewer-agent / official=true / exact candidate`
- registration merge: `e3881307991ea83a692330393edd818e70b35a47`
- post-merge governance: `UI #133 / internal 683 SUCCESS`
- fresh `TASK-SOURCE-GUARD: PASS`
- execution branch: `obs/sdk-transport-v1-001-mobile-observability`

Frozen production scope:

```text
lib/src/analytics/analytics_client.dart
lib/src/analytics/mobile_analytics_sender.dart
lib/src/error_reporting/mobile_error_report_sender.dart
```

Public SDK, shared transport/foundation, Backend, App and provider mutations remain forbidden.

## Feasibility evidence

An exploratory implementation was produced as:

```text
eda89ef6a59c2a90a0a7223004e4d31edd2e6ce7
```

It was never submitted as a delivery candidate and is not authorized for merge. It was used only to test whether the frozen seams can satisfy the Platform contracts.

Analytics is mechanically feasible inside the authorized scope: exact `/api/v1/mobile/analytics/batches` wire, exact UTF-8 `<=16 KiB` shrink-before-bind, stable assigned `batch_id` across bounded retries and later re-flush, and exact proof path/body reuse via existing `NebulaTransport`, `buildAuthHeaders`, `RequestProofSigner` and installation-token callback.

The Error Reporting wire sender itself is also feasible: exact `/api/v1/mobile/error-reports` wire, exact `<=16 KiB` shrink, immutable `report_id`, defensive accepted/rejected subset validation and no manufactured accepted IDs.

On exact exploratory commit `eda89ef6...`, mac-mini-ci ran the new sender tests plus existing Analytics queue/consent and Error Reporting client/public-surface suites:

```text
49 / 49 PASS
dart analyze                         PASS / 0 issues
API surface                          PASS / 126 symbols
Task Source Guard                    PASS
Cross Repo Guard                     PASS
```

All frozen public/shared files remained byte-identical, including the public barrel/capabilities/facade, Analytics public sender/event/facade, `transport/**`, `foundation/**`, API snapshot and `public_api.txt`.

## Blocking gap 1 — HTTP 429 consumes Error Reporting retry budget

The frozen Platform contract requires HTTP 429 / `40002` to defer the complete unprocessed report set with bounded local cooldown. A rate limit must not become a false per-report rejection or an immediate retry loop.

The current seam is:

```text
ErrorReportSender.send(List<NebulaErrorReport>)
→ ErrorReportSendResult
```

`ErrorReportingClient.flush()` currently applies a valid sender result in this order:

```text
apply accepted/rejected IDs
→ compute every ID omitted from both
→ _scheduleRetry(omitted IDs)
→ only afterwards apply result.shouldDefer / retryAfter
```

So a sender can correctly return empty accepted/rejected sets plus `deferRemaining=true`, yet the client still increments `attemptCount` before cooldown.

A temporary mac-mini-ci probe on the exact exploratory tree proved the consequence with `maxAttempts=3`:

```text
429-style defer #1 → attemptCount = 1
429-style defer #2 → attemptCount = 2
429-style defer #3 → retryExhausted = 1 / report deleted
probe = 1 / 1 PASS
```

The probe was removed after execution. This cannot be corrected inside `mobile_error_report_sender.dart` without manufacturing false accepted/rejected IDs or false success.

## Blocking gap 2 — request-level 30001 cannot be represented as non-retryable

The frozen Error Reporting contract defines request-level `30001` as deterministic non-retryable construction/payload failure and forbids manufacturing per-report ACK/rejection for that request-level failure.

`ErrorReportingClient.flush()` currently catches every exception from `ErrorReportSender.send()` through the same generic path:

```text
sender throws
→ senderFailures++
→ _scheduleRetry(batch)
```

A second temporary mac-mini-ci probe made the sender throw exact `NebulaApiException(code=30001)` and proved:

```text
30001 #1 → attemptCount = 1
30001 #2 → attemptCount = 2
30001 #3 → retryExhausted = 1 / report deleted
probe = 1 / 1 PASS
```

The probe was removed after execution. Returning per-report rejected IDs would fabricate server acknowledgement; throwing `30001` is currently converted into ordinary retry scheduling.

## Required governance decision

The current M3 authorized scope is mechanically insufficient for the complete frozen Error Reporting retry/defer contract.

Architecture/Coordinator must explicitly review and authorize an internal Error Reporting seam change involving at least:

```text
lib/src/error_reporting/client.dart
```

and, depending on the chosen representation, potentially:

```text
lib/src/error_reporting/sender.dart
```

The internal design must distinguish:

```text
successful partial result
rate-limit defer without consuming retry-attempt budget
transient/ambiguous failure that consumes bounded retry budget
request-level deterministic non-retryable failure without fabricated per-report ACK/rejection
```

No public symbol/export change has been shown necessary, but Agent A is not authorized to add these paths to the current Story.

## Fail-closed disposition

Per the task pack, if the frozen contract cannot be satisfied inside the authorized surface, Agent A must STOP and report the gap instead of expanding scope.

The exploratory production/test commit was fully reverted by:

```text
e0f3c8c6924bf416b24b156430b00001ab13b86b
```

The final branch tree has zero production/test/API delta from canonical base except this docs-only report.

No M3 implementation PASS is claimed. No App integration is authorized. `NEBULA-APP-001D` capability re-audit must not start because M3 has not reached canonical closure. `S1-F01-002` remains untouched.
