# Error Reporting SDK Public Surface v1

- **Contract ID**: `ERROR_REPORTING_SDK_PUBLIC_SURFACE_V1`
- **Story**: `OBS-SDK-ERROR-API-V1-001`
- **Status**: FREEZE CANDIDATE / INDEPENDENT SDK SURFACE REVIEW REQUIRED
- **Canonical base**: `hub/main@cbfb4f5da000d7f8951b0093846eaf92c77b8e85`
- **Domain authority**: `ERROR_REPORTING_CONTRACT_V1.md`
- **Internal-core authority**: canonical `lib/src/error_reporting/**` from `OBS-SDK-ERROR-V1-001`
- **SDK public API mode for this Story**: `READ_ONLY`
- **Production implementation authorization**: NONE

## 1. Purpose and scope

This freeze defines the smallest App-facing SDK surface for **explicit caught-error reporting**. It does not publish the existing internal Error Reporting implementation and does not authorize any `lib/**`, facade, barrel, API snapshot, Backend, App, provider, or analytics mutation.

The internal core is implementation evidence only. Public V1 deliberately does not expose persistence, sender, retry, upload budget, provider, transport, report identity generation, normalization, or operational-statistics machinery.

The single App-facing use case frozen here is:

```text
App-owned adapter catches an error
        ↓
curates minimal safe diagnostic facts
        ↓
NebulaErrorReporting.reportCaughtError(...)
        ↓
Nebula-owned internal normalization / bounding / persistence / later delivery
```

Uncaught Flutter/Dart capture may be wired by a later authorized composition implementation, but this public surface does not expose global error-handler installation APIs. Native process crash/signal capture, minidump and ANR remain outside V1.

## 2. Public V1 capability

V1 adds exactly **one new public top-level symbol**:

```dart
abstract interface class NebulaErrorReporting {
  Future<void> reportCaughtError({
    required String errorType,
    required String safeMessage,
    required StackTrace stackTrace,
    DateTime? occurredAt,
    NebulaRequestId? requestId,
  });
}
```

This interface belongs in the already-public `lib/src/capabilities.dart` library.

### 2.1 Why there is no public input model

No separate `NebulaErrorReportInput` is frozen in V1. Named parameters are sufficient for the five caller-supplied diagnostic facts and avoid exporting the wider internal `ErrorReportInput` shape.

The public caller may supply only:

- `errorType`: a stable diagnostic type/category name; product adapters SHOULD normally derive this from the caught Dart error type rather than user content;
- `safeMessage`: minimal diagnostic text already selected by the App adapter as safe to submit; the SDK still applies its own redaction and byte bounds and callers MUST NOT treat that redaction as a general-purpose PII scrubber;
- `stackTrace`: the caught Dart stack trace;
- `occurredAt`: optional occurrence time; omitted means SDK capture time;
- `requestId`: optional existing `NebulaRequestId` for correlation when one is available.

The public method does **not** accept raw logs, breadcrumbs, screenshots, arbitrary context maps, user content attachments, tokens/secrets, `user_id`, provider metadata, or product-specific payloads.

### 2.2 Why there is no public result model

V1 returns `Future<void>` and exposes no `ErrorCaptureResult`, persistence state, upload state, report ID, retry state, ACK state, provider state, or queue statistics.

Completion means only that the SDK has consumed the best-effort reporting attempt. It does **not** promise:

- local persistence succeeded;
- the report survived process termination;
- an upload was attempted;
- the Backend/provider received it;
- an ACK was received;
- the issue was grouped or fingerprinted.

The implementation MUST be fail-soft with respect to Error Reporting subsystem failures: report drop, local persistence failure, sender failure, retry exhaustion, provider failure, or upload deferral MUST NOT become an App control-flow failure through this method.

Deterministic drop/failure accounting remains an internal observability responsibility; it is not promoted to product-code authority.

## 3. Nebula facade decision

The future surface implementation **does require** a `Nebula` facade member, but V1 must preserve existing constructor source compatibility.

Frozen target shape:

```dart
final class Nebula {
  Nebula({
    required NebulaOptions options,
    required NebulaTransport transport,
    required NebulaAuth auth,
    required NebulaConfig config,
    required NebulaAnalytics analytics,
    NebulaErrorReporting? errorReporting,
  });

  final NebulaErrorReporting? errorReporting;
}
```

Rules:

1. `errorReporting` is optional/nullable for the initial V1 surface addition so existing `Nebula(...)` construction does not gain a new required argument.
2. The SDK MUST NOT export a public `NoOpErrorReporting` concrete class merely to avoid nullability.
3. Product code consumes the capability through `Nebula.errorReporting`; it does not construct or select stores, senders, providers, retry policies, or transports.
4. Making the member required/non-null in a later version is a separately reviewed compatibility change.

## 4. Barrel export and API-surface decision

`lib/nebula_sdk.dart` already exports `src/capabilities.dart` and `src/nebula.dart`.

Therefore V1 requires:

```text
lib/nebula_sdk.dart
→ NO CHANGE

governance/public_api.txt
→ NO CHANGE
```

No new Error Reporting implementation library is barrel-exported.

The future public-surface implementation changes the symbol snapshot only by adding:

```text
src/capabilities.dart class NebulaErrorReporting
```

Current canonical API surface is **125 symbols**. The expected reviewed implementation surface is therefore **126 symbols**, assuming no unrelated drift. `Nebula.errorReporting` is a member-level change and the current snapshot tool records only top-level symbols.

Any additional top-level Error Reporting symbol is outside this freeze and requires a new surface review.

## 5. Existing internal-core type classification

Every current top-level Error Reporting type on canonical `hub/main` is classified below. **No existing internal-core type becomes PUBLIC V1.**

| Existing type | Current file | Classification | Freeze rationale |
|---|---|---|---|
| `ErrorReportingBudget` | `lib/src/error_reporting/budget.dart` | INTERNAL ONLY | Runtime count/byte/age/retry policy; App must not tune upload/storage storm controls per report. |
| `ErrorCaptureDisposition` | `lib/src/error_reporting/client.dart` | INTERNAL ONLY | Persistence/drop state is intentionally not a public App control-flow contract. |
| `ErrorCaptureResult` | `lib/src/error_reporting/client.dart` | INTERNAL ONLY | Contains internal disposition/report identity; public V1 returns `Future<void>`. |
| `ErrorReportingStats` | `lib/src/error_reporting/client.dart` | INTERNAL ONLY | Mutable operational accounting; not product analytics or App authority. |
| `ErrorReportingClient` | `lib/src/error_reporting/client.dart` | INTERNAL ONLY | Concrete orchestration implementation; future code may implement `NebulaErrorReporting` without exporting the class. |
| `ErrorNormalizationResult` | `lib/src/error_reporting/normalizer.dart` | INTERNAL ONLY | Normalization/truncation/redaction accounting is implementation detail. |
| `ErrorReportNormalizer` | `lib/src/error_reporting/normalizer.dart` | INTERNAL ONLY | Privacy/bounding machinery must stay behind capability boundary. |
| `_RedactionResult` | `lib/src/error_reporting/normalizer.dart` | INTERNAL ONLY | Library-private redaction helper; never part of public contract. |
| `NebulaErrorReport` | `lib/src/error_reporting/report.dart` | INTERNAL ONLY | Persisted/wire diagnostic entity contains report identity and serialization semantics not needed by App callers. |
| `ErrorReportInput` | `lib/src/error_reporting/report.dart` | INTERNAL ONLY | Wider raw internal capture shape; must not be promoted as the public input DTO. |
| `ErrorReportIdGenerator` | `lib/src/error_reporting/report_id.dart` | INTERNAL ONLY | Report identity generation is Nebula authority, not App-injected authority. |
| `SecureErrorReportIdGenerator` | `lib/src/error_reporting/report_id.dart` | INTERNAL ONLY | Concrete identity implementation. |
| `ErrorReportSendResult` | `lib/src/error_reporting/sender.dart` | INTERNAL ONLY | ACK/reject/defer/retry transport semantics must not leak to product code. |
| `ErrorReportSender` | `lib/src/error_reporting/sender.dart` | INTERNAL ONLY | Backend/provider transport binding remains hidden. |
| `StoredErrorReport` | `lib/src/error_reporting/store.dart` | INTERNAL ONLY | Queue persistence/retry record. |
| `ErrorStoreSaveResult` | `lib/src/error_reporting/store.dart` | INTERNAL ONLY | Store accounting contract. |
| `ErrorStoreReadResult` | `lib/src/error_reporting/store.dart` | INTERNAL ONLY | Store batch/read accounting contract. |
| `ErrorReportStore` | `lib/src/error_reporting/store.dart` | INTERNAL ONLY | Host/storage Port remains composition/internal infrastructure; it is not an App reporting API. |

### 5.1 PUBLIC V1 classification

Existing internal types classified `PUBLIC V1`: **none**.

The only PUBLIC V1 addition is the new capability interface `NebulaErrorReporting` defined in §2.

### 5.2 DEFERRED classification

Existing internal types classified `DEFERRED` for public exposure: **none**. They are intentionally INTERNAL ONLY rather than provisional public APIs.

Deferred Error Reporting **capability increments**, not existing public-type candidates, are:

- native process crash/signal capture;
- minidump;
- ANR;
- breadcrumbs;
- screenshots;
- raw/full logs;
- public queue/store management;
- public flush/retry/provider selection;
- public operational statistics/report IDs;
- public fingerprint/issue-grouping controls;
- public user identity attachment.

Each requires a separately reviewed capability/contract increment if ever promoted.

## 6. Trusted identity and diagnostic metadata authority

The public caught-error method MUST NOT accept caller-authoritative:

```text
app_id
installation_id
platform
user_id
service_region
provider/vendor identity
fingerprint / issue group
```

Trusted `app_id`, `installation_id`, and platform remain derived from the existing InstallationProof/trusted installation chain. Error Reporting must reuse that trusted context internally when later delivery is implemented.

`reported_app_version` and `reported_build_number` remain optional internal diagnostic snapshots. They are deliberately **not per-call public parameters in V1**. A future authorized composition implementation may source them once from host/package metadata and supply them to the internal core without giving each App reporting call new identity authority. Missing values remain valid because the frozen domain contract makes them optional.

No `user_id` is added by default.

## 7. Privacy boundary

The public surface preserves `ERROR_REPORTING_CONTRACT_V1` privacy rules:

- no raw application logs;
- no breadcrumbs;
- no screenshots;
- no user content/attachments;
- no authentication tokens or secrets;
- no product-specific sensitive payload fields;
- no default `user_id`;
- no provider-specific fields.

`safeMessage` is intentionally named to make the App adapter's responsibility explicit: callers choose minimal diagnostic text rather than passing an unrestricted exception/context object. The SDK internal normalizer still MUST redact known secret patterns, bound every field and bound the total report payload.

The SDK MUST NOT write stored `safeMessage` or stack values into its own operational logs.

## 8. Lifecycle and non-promises

The public API must not imply any of the following capabilities:

```text
reportCaughtError
≠ native crash handler
≠ signal handler
≠ minidump capture
≠ ANR capture
≠ guaranteed post-termination persistence
≠ guaranteed delivery
≠ synchronous network upload
≠ provider dashboard availability
```

V1 fatal-path durability remains **best-effort durable enqueue**. Only successfully persisted reports can be eligible for a later launch/flush. The public API provides no public `flush()` because upload scheduling, bounded backlog processing, retry/backoff and server-directed reduction remain Nebula-owned orchestration.

## 9. Provider and transport invisibility

Product/App code MUST NOT select Sentry, Crashlytics, another provider, self-hosted transport, region-specific SDK, or Backend endpoint through this surface.

The following remain invisible behind Nebula:

- `ErrorReportSender`;
- `NebulaTransport` binding;
- InstallationProof headers/signing;
- provider adapters/SDK initialization;
- region/provider routing;
- ACK/reject/defer mapping;
- batching, byte budgets, retry/backoff and backlog scheduling.

Provider selection remains infrastructure/platform policy and must not become product branching.

## 10. Compatibility and versioning

The V1 public compatibility contract is intentionally small:

1. `NebulaErrorReporting` is the only new public top-level symbol.
2. `reportCaughtError` is the only public Error Reporting operation.
3. No public input/result/store/sender/provider/budget/retry type is frozen.
4. Existing `Nebula(...)` constructors remain source-compatible by adding only an optional nullable facade member.
5. Adding public fields such as user identity, attachments, arbitrary metadata/context maps, provider controls, queue controls, flush controls, fatal/native capture, or public delivery results requires a separately reviewed public-surface change.
6. Changing the meaning of trusted identity, privacy defaults, report identity/dedup, fingerprint authority or durability promises requires the reviewed domain-contract/versioning path as well as SDK surface review when applicable.

## 11. Product-name erasure proof

The frozen symbols/parameters are generic platform concepts only:

```text
NebulaErrorReporting
reportCaughtError
errorType
safeMessage
stackTrace
occurredAt
requestId
```

There are no product-specific names, protocols, content models, feature names, or fields in the frozen public surface.

## 12. Exact future SDK Public Surface Implementation write-set

This Story does **not** authorize the following mutations. After this freeze is canonical `DONE / REVIEW PASS`, a separate Story may set `sdk_public_api_mode = CHANGE_APPROVED` and authorize only the exact serial production/API paths below:

### 12.1 Production/API paths allowed for that future Story

```text
lib/src/capabilities.dart
lib/src/nebula.dart
lib/src/error_reporting/client.dart
governance/api_surface.snapshot
```

Intended deltas are exactly:

- `lib/src/capabilities.dart`: add `NebulaErrorReporting` with the §2 signature;
- `lib/src/nebula.dart`: add optional nullable `NebulaErrorReporting? errorReporting` constructor/member wiring;
- `lib/src/error_reporting/client.dart`: keep `ErrorReportingClient` internal while adapting/implementing the public capability and mapping the five public diagnostic inputs into the already-frozen internal capture pipeline;
- `governance/api_surface.snapshot`: reviewed symbol count `125 → 126`, adding only `src/capabilities.dart class NebulaErrorReporting`.

### 12.2 Focused test path allowed for that future Story

```text
test/error_reporting/error_reporting_public_surface_test.dart
```

The test must prove at minimum:

- public barrel can reference `NebulaErrorReporting` through existing `capabilities.dart` export;
- the facade member is optional/source-compatible;
- caught-error input reaches the internal capture seam without exposing trusted identity parameters;
- internal persistence/provider failures do not escape as App control-flow failure;
- no extra Error Reporting top-level symbol is exported;
- API snapshot changes by exactly one symbol.

### 12.3 Explicitly forbidden even in that narrow future surface Story unless separately authorized

```text
lib/nebula_sdk.dart
governance/public_api.txt
lib/src/error_reporting/budget.dart
lib/src/error_reporting/normalizer.dart
lib/src/error_reporting/report.dart
lib/src/error_reporting/report_id.dart
lib/src/error_reporting/sender.dart
lib/src/error_reporting/store.dart
Backend / schema / migration
consumer App / consumer repin
provider SDK integration
Analytics implementation
```

`lib/nebula_sdk.dart` and `governance/public_api.txt` must remain byte-identical because the required public declarations live in already-exported `capabilities.dart` / `nebula.dart`.

If implementation proves any path outside §12.1/12.2 is genuinely necessary, the implementation Story must STOP and obtain a revised independently reviewed freeze; it must not expand the write-set opportunistically.

## 13. Verification gates for this freeze Story

This freeze candidate is valid only when all are true on the exact candidate:

```text
Task Source Guard OBS-SDK-ERROR-API-V1-001          PASS
Cross Repo Guard                                    PASS
git diff --check                                    PASS
lib/** diff                                           0
authoritative public API files diff                  0
api_surface.snapshot diff                            0
public_api.txt diff                                   0
API surface validation                               PASS / 125 unchanged
ERROR_REPORTING_CONTRACT_V1 consistency              PASS
internal-core type classification                    COMPLETE
product-name erasure                                 PASS
Independent Architecture/SDK Surface Review          PASS
```

This Story ends at reviewed public-surface freeze. It does not authorize production surface implementation, Coordinator state mutation by Agent A, merge by Agent A, or registration of the implementation Story by Agent A.
