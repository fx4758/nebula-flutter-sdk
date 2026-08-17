# Mobile Observability SDK Lifecycle V1

Status: **FREEZE CANDIDATE / INDEPENDENT ARCHITECTURE REVIEW REQUIRED**

Story: `OBS-SDK-COMPOSITION-LIFECYCLE-V1-001`

## 1. Problem and authority

`OBS-SDK-COMPOSITION-V1-002` closed public construction and durable Error Reporting persistence, but final NFC Writer consumer preflight exposed one missing lifecycle bridge:

```text
NebulaErrorReporting.reportCaughtError(...)
→ normalize + durable local capture

internal ErrorReportingClient.flush()
→ upload lifecycle exists but is not public

NebulaMobileObservability
→ no lifecycle trigger
```

Apps must not import SDK internals, downcast the capability, or rebuild a sender/store. The missing operation belongs to the already-public composition object, not to the Error Reporting domain capability.

Existing Analytics, Error Reporting, send-seam, Platform API and Composition contracts remain authoritative.

## 2. Public lifecycle decision

Add exactly one public instance member to the existing public class:

```dart
final class NebulaMobileObservability {
  NebulaAnalytics get analytics;
  NebulaErrorReporting get errorReporting;
  Future<void> flush();
}
```

`flush()` is the V1 composition lifecycle trigger. It is not an Error Reporting queue API.

Public API invariants:

```text
top-level symbol count before = 127
top-level symbol count after  = 127
new top-level symbols          = 0
existing class member delta    = NebulaMobileObservability.flush only
NebulaErrorReporting           = unchanged
```

The current API snapshot is top-level-symbol based, so it is expected to remain byte-identical unless the mechanical generator proves otherwise.

## 3. Flush semantics

One call means a best-effort lifecycle opportunity to flush both independently owned observability domains:

```text
NebulaMobileObservability.flush()
  ├─ NebulaAnalytics.flush()
  └─ internal ErrorReportingClient.flush()
```

Required semantics:

1. Both domains are attempted independently.
2. Failure/throw from one domain must not suppress the other domain's attempt.
3. The composition operation is fail-soft and completes normally after both attempts settle.
4. It exposes no cross-domain result DTO and no queue IDs, report IDs, batch IDs, retry counts, accepted/rejected IDs, server codes or provider details.
5. Existing per-domain retry/defer/trust/ACK/budget behavior remains authoritative.
6. Existing per-domain in-flight guards remain authoritative; composition must not manufacture duplicate delivery identities.
7. V1 does not promise ordering between the two domain attempts.
8. Empty queues are successful no-ops.

## 4. Network and lifecycle ownership

Construction remains zero-network:

```text
NebulaMobileObservability.create(...) != network I/O
```

`flush()` is explicitly network-capable. Product Apps may invoke it only from an already-authorized post-bootstrap/post-first-frame lifecycle boundary, for example first-frame completion or foreground/resume.

The SDK does not create a Timer, background worker, isolate, stream subscription or platform lifecycle listener in V1. The host signals a lifecycle opportunity; the SDK owns what delivery work that signal causes.

Calling `flush()` is not a second bootstrap protocol. Existing sender trust-recovery/defer behavior and the frozen composition input contract remain authoritative.

## 5. Error Reporting public boundary remains frozen

`NebulaErrorReporting` stays exactly the V1 capture capability:

```dart
Future<void> reportCaughtError(
  String errorType,
  String safeMessage,
  StackTrace stackTrace,
);
```

Do not add `NebulaErrorReporting.flush`, queue/result/retry/store/sender/client types, or accepted/rejected report IDs. Product code captures safely; composition owns upload orchestration.

## 6. Analytics boundary remains frozen

The lifecycle trigger reuses existing public `NebulaAnalytics.flush()` behavior. It changes no event DTO, consent rule, assigned batch identity, retry policy, endpoint or privacy contract. No generic telemetry abstraction is introduced.

## 7. Privacy and error handling

`flush()` accepts no payload arguments. It cannot add product facts to queued records.

Composition must not log or throw raw payloads, report contents, tokens, proof material or server bodies when a domain flush fails. Existing SDK-safe accounting may be used only inside the already-frozen privacy boundary.

Fail-soft composition does not mutate domain retry semantics: domain clients remain sole authority for retry exhaustion, defer, trust recovery and ACK deletion.

## 8. Exact future implementation write-set

After independent approval and canonical closure, a CHANGE_APPROVED implementation may authorize only:

```text
lib/src/nebula.dart
lib/src/observability/mobile_observability_composition.dart

test/observability/**
test/error_reporting/** only if needed for composition delegation proof
docs/multi_agent/reports/OBS-SDK-COMPOSITION-LIFECYCLE-V1-002*.md
```

Expected governance delta:

```text
governance/api_surface.snapshot = zero diff
lib/nebula_sdk.dart             = zero diff
governance/public_api.txt       = zero diff
```

Forbidden: Backend/App/provider mutation, transport/auth/proof changes, ErrorReportingClient retry changes, Analytics queue/retry changes, new top-level symbol/export, new public Error Reporting API, Timer/background worker/platform lifecycle listener.

## 9. Implementation acceptance

Implementation must mechanically prove:

1. `NebulaMobileObservability.flush()` compiles through `package:nebula_sdk/nebula_sdk.dart`;
2. top-level API count stays 127 and only the intended existing-class member is added;
3. construction remains zero-network;
4. one lifecycle call attempts Analytics and Error Reporting delivery;
5. Analytics failure does not suppress Error Reporting;
6. Error Reporting failure does not suppress Analytics;
7. empty queues are no-op success;
8. repeated/concurrent lifecycle calls do not create duplicate domain delivery identities beyond existing client semantics;
9. existing Error Reporting send-seam/retry/trust tests remain green;
10. existing Analytics queue/batch/retry tests remain green;
11. API surface, Task Source, Cross Repo and static architecture guards pass;
12. full SDK tests and analyzer pass.

## 10. Consumer unblock rule

After implementation closure, NFC Writer must repin its embedded SDK one final time to the new canonical SHA and re-run the public composition preflight. Only then may `NEBULA-APP-001D` return to `READY / APP CHANGE_APPROVED` and invoke `NebulaMobileObservability.flush()` from its post-first-frame/resume lifecycle.
