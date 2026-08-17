# Mobile Observability SDK Composition V1

Status: **FREEZE CANDIDATE / INDEPENDENT ARCHITECTURE REVIEW REQUIRED**

Story: `OBS-SDK-COMPOSITION-V1-001`

This contract freezes the minimal legal public composition + durable Error Reporting persistence boundary needed by product Apps after Mobile Observability M3. It does not authorize implementation by itself.

## 1. Authorities and consumer evidence

Authorities:

- `MOBILE_ANALYTICS_CONTRACT_V1.md` + `MOBILE_ANALYTICS_PLATFORM_API_V1.md`;
- `ERROR_REPORTING_CONTRACT_V1.md` + `ERROR_REPORTING_PLATFORM_API_V1.md`;
- `ERROR_REPORTING_SDK_PUBLIC_SURFACE_V1.md`;
- `ERROR_REPORTING_SDK_INTERNAL_SEND_SEAM_V1.md`;
- canonical `OBS-SDK-TRANSPORT-V1-001 = DONE / REVIEW PASS`.

Triggering consumer evidence is NFC Writer `NEBULA-APP-001D` capability re-audit, canonical App `dev@f4de60146998693fac7133817202d18675397e10`, post-merge capability guard #279 SUCCESS. The App remains `WAIT / SDK COMPOSITION + PERSISTENCE GAP`.

Mechanical facts:

1. App immutable pin `ad2da9d36f6d2561bd9a5a5644c777d6e3ddffe4` predates `NebulaErrorReporting` and M3.
2. Current SDK public API exposes `NebulaAnalyticsClient`, `NebulaAnalyticsSender`, `NebulaErrorReporting`, and nullable `Nebula.errorReporting`, but M3 mobile senders and `ErrorReportingClient/ErrorReportStore` remain internal.
3. Current production SDK has no concrete `implements ErrorReportStore`; only test fake(s).
4. Product code MUST NOT import `package:nebula_sdk/src/**` or rebuild the transport/store stack in the App.

## 2. Public composition decision

Freeze exactly **one new public top-level symbol** in the already-exported `src/nebula.dart` library:

```dart
final class NebulaMobileObservability {
  NebulaAnalytics get analytics;
  NebulaErrorReporting get errorReporting;

  static NebulaMobileObservability create({
    required NebulaOptions options,
    required NebulaTransport transport,
    required RequestProofSigner proofSigner,
    required Future<String> Function() installationToken,
    required Future<bool> Function() recoverInstallationTrust,
    required CacheStorage persistentStorage,
  });
}
```

The exact implementation constructor may be private. The public contract is the two capability getters plus the static `create` entry above.

API surface invariant:

```text
before: 126 top-level symbols
after:  127 top-level symbols
only new top-level symbol:
src/nebula.dart class NebulaMobileObservability
```

`lib/nebula_sdk.dart` does not need a new export because `src/nebula.dart` is already exported. `governance/public_api.txt` does not need a new path. `governance/api_surface.snapshot` must gain exactly the one symbol above in the later CHANGE_APPROVED implementation.

No new public sender/store/result/budget/report DTO or generic telemetry abstraction is authorized.

## 3. Capability ownership

`NebulaMobileObservability.create(...)` returns SDK-owned implementations behind existing public interfaces:

```text
analytics
  -> NebulaAnalytics
  -> internal NebulaAnalyticsClient
  -> internal MobileAnalyticsSender

errorReporting
  -> NebulaErrorReporting
  -> internal ErrorReportingClient
  -> internal MobileErrorReportSender
  -> internal durable ErrorReportStore
```

Product code sees neither concrete mobile sender nor Error Reporting client/store/result types.

This preserves `ERROR_REPORTING_SDK_PUBLIC_SURFACE_V1.md`: product code consumes Error Reporting through the capability interface, not by constructing internal pipeline pieces.

## 4. Allowed composition inputs

The public factory may accept only existing public infrastructure/lifecycle abstractions plus host persistence:

- `NebulaOptions`: public App/environment configuration;
- `NebulaTransport`: the existing transport abstraction;
- `RequestProofSigner`: the existing proof-signing abstraction;
- `installationToken()`: obtains the current installation token from the already-owned installation lifecycle;
- `recoverInstallationTrust()`: asks the existing bootstrap/renewal lifecycle to recover invalid installation trust; it does not return App/installation identity facts and does not define a second bootstrap protocol;
- `CacheStorage persistentStorage`: host-provided app-private persistent byte storage used by SDK-owned composition internals.

Forbidden factory inputs include caller-authored `app_id`, `installation_id`, platform, user ID, proof nonce/timestamp policy, provider choice, report/batch IDs, or raw credentials beyond the already-frozen trust abstractions.

The factory MUST NOT accept an App-owned `NebulaAnalyticsSender`, `ErrorReportSender`, or `ErrorReportStore` as a production escape hatch.

## 5. Trust lifecycle reuse

Both capability pipelines reuse exactly the M3 InstallationProof lifecycle:

```text
installationToken()
+ RequestProofSigner
+ existing NebulaTransport
+ recoverInstallationTrust()
```

The factory owns only composition; it does not issue installation tokens or keys.

On `12001`, the already-frozen M3 sender behavior remains authoritative:

```text
preserve immutable batch/report identity
→ bounded local defer
→ no blind network retry
→ recoverInstallationTrust()
→ only after success obtain fresh token/proof inputs and resend
```

Recovery false/throw causes no network send and no replacement `batch_id` / `report_id`.

## 6. Error Reporting durable store decision

Keep `ErrorReportStore` **INTERNAL ONLY**.

Add an SDK-internal concrete store backed by the existing public `CacheStorage` Port. Semantic name for the implementation is:

```text
CacheErrorReportStore
```

The exact class name may vary only if independent review confirms identical ownership and behavior. It is not exported.

Why `CacheStorage` is selected:

- Error Reporting persists only normalized/redacted/bounded diagnostic facts; sensitive NFC/card/token/user content is forbidden before persistence;
- Error Reporting durability is explicitly best-effort, not a secret-vault or financial ledger guarantee;
- bulk bounded diagnostic queue data is a poor fit for Keychain/Keystore-style `SecureStorage` semantics;
- the public `CacheStorage` byte Port already provides the correct host/SDK dependency direction without exposing `ErrorReportStore`;
- the queue remains app-private and device-local; a host release binding MUST provide persistent app-private storage rather than the SDK reference `InMemoryCacheStorage`.

`SecureStorage` is therefore **not** the V1 Error Reporting queue backing. It remains for secret/token material.

`InMemoryCacheStorage` is allowed only in tests/development. A release integration using it does not satisfy the durable-store gate.

## 7. Durable queue namespace and encoding

The internal store derives its namespace from the existing `StorageNamespace.app(environment, appId)` mechanism and uses one fixed versioned internal queue key, conceptually:

```text
namespace = StorageNamespace.app(environment, appId)
key       = error_reporting_queue_v1
```

Do not create a user-scoped namespace: Error Reporting identity is trusted App + installation scoped, and user sign-out must not silently discard installation-scoped pending diagnostics.

Persist a versioned SDK-private envelope containing only the normalized report plus delivery metadata required by current `StoredErrorReport` semantics:

```text
version
records[]:
  report_id
  occurred_at
  error_type
  safe_message
  stack
  request_id?
  reported_app_version?
  reported_build_number?
  stored_at
  encoded_bytes
  attempt_count
  next_attempt_at?
```

Trusted `app_id / installation_id / platform`, provider IDs, access/refresh/installation tokens, proof material and server `ingested_at` MUST NOT be persisted in this queue.

All read-modify-write operations MUST be serialized within one SDK composition instance so capture/flush cannot overwrite one another. V1 does not promise cross-isolate multi-writer coordination.

## 8. Bounded persistence semantics

The concrete internal store and `ErrorReportingClient` MUST share the same effective runtime budget for:

```text
max stored reports
max stored encoded bytes
max stored age / TTL
max upload reports
max upload bytes
retry attempts / backoff
```

Exact numeric defaults remain implementation/runtime policy; this freeze does not create new architecture constants.

Store behavior:

- `save`: persist the normalized report before it is considered queued; best-effort persistence failure remains fail-soft and increments internal persistence-failure accounting;
- count/bytes overflow: evict oldest records deterministically until within bounds;
- age/TTL expiry: purge expired records before `readReady`/save accounting;
- `readReady`: return only records whose retry time is ready, oldest first, bounded by count/bytes;
- `updateRetry`: persist incremented attempt count + next-attempt timestamp;
- ACK/rejected/local deterministic drop: delete exact affected IDs and persist the resulting queue before returning from the operation;
- malformed/corrupt/unknown-version queue: fail-soft purge **only the Error Reporting queue key**, never clear unrelated CacheStorage namespace data;
- environment/App change naturally isolates a different namespace; no cross-environment migration;
- product user sign-out does not purge the queue;
- uninstall/app data clear follows platform storage semantics and may remove the best-effort queue.

A future queue schema change requires versioned migration or bounded purge; silent reinterpretation of old bytes is forbidden.

## 9. Analytics composition and persistence

Composition creates the existing internal `NebulaAnalyticsClient` with:

- SDK internal `MobileAnalyticsSender` from M3;
- `CacheConsentStore` over the same host `persistentStorage`, preserving existing consent semantics and App/environment namespace isolation.

This Story does **not** add a durable Analytics event queue. Existing Analytics bounded queue/TTL semantics remain authoritative. Assigned `batch_id` must still remain immutable across the retry lifecycle while the batch exists; process death may lose best-effort unsent Analytics events as already permitted by the frozen Analytics design.

Do not introduce a generic telemetry store shared with Error Reporting.

## 10. Factory lifecycle and multiplicity

One product composition root SHOULD create one `NebulaMobileObservability` instance per `(environment, appId)` SDK composition lifecycle and reuse it.

Creating multiple instances against the same persistent queue concurrently is outside V1 guarantees and SHOULD be prevented by App composition. The SDK factory remains instance-scoped; it introduces no global mutable singleton.

The returned `analytics` and `errorReporting` capability objects may be injected into the existing public `Nebula` facade or consumed through the product's Adapter layer. Product code must not downcast them to internal implementations.

No new public `dispose()` is required by V1 because the composition owns no mandatory background worker/stream. Upload remains explicit/lifecycle-triggered through existing capability/client behavior.

## 11. Privacy and data residency

Before any Error Reporting record reaches persistent storage or transport, existing normalization/redaction/bounds apply.

Forbidden payload/persistence examples include:

```text
NFC UID
NFC dump / sector data
MRZ
full card/account number
access/refresh/installation token
private/public signing key material
raw request/response bodies
letter/note/user content
screenshots
breadcrumbs/full logs
provider credentials
```

`safe_message` and stack remain bounded diagnostic facts only. Provider routing/data-residency decisions remain outside this composition slice.

## 12. Consumer matrix

| Consumer | Composition after implementation | Product-specific SDK API needed? |
|---|---|---|
| NFC Writer | App Nebula Adapter supplies existing options/transport/proof/token/recovery + persistent `CacheStorage`; consumes returned `NebulaAnalytics` / `NebulaErrorReporting` | NO |
| FlyPost | Same generic composition boundary when/if it adopts Mobile Observability | NO |
| StarSprout / future App | Same generic composition boundary | NO |

No NFC-specific model, storage schema, event name, provider branch or Adapter type enters the SDK public contract.

## 13. Exact future SDK implementation write-set

If this freeze is independently APPROVED and canonical-closed, the later Coordinator implementation Story may authorize exactly:

```text
lib/src/nebula.dart
lib/src/observability/mobile_observability_composition.dart
lib/src/error_reporting/cache_error_report_store.dart
governance/api_surface.snapshot

test/observability/**
test/error_reporting/cache_error_report_store_test.dart
docs/multi_agent/reports/**
```

Expected public delta:

```text
src/nebula.dart class NebulaMobileObservability
```

Expected unchanged public/governance paths:

```text
lib/nebula_sdk.dart
governance/public_api.txt
lib/src/capabilities.dart
lib/src/analytics/analytics_sender.dart
lib/src/error_reporting/sender.dart
lib/src/transport.dart
lib/src/transport/**
lib/src/foundation/**
lib/src/auth/**
```

The later implementation MUST STOP if it needs a sixth SDK production/public path beyond the three production files plus snapshot listed above. A new reviewed scope change is required rather than expanding opportunistically.

No new package dependency is frozen by this design.

## 14. Implementation proof requirements

The later SDK implementation must mechanically prove:

1. public import through `package:nebula_sdk/nebula_sdk.dart` can construct `NebulaMobileObservability` without any `src/**` import;
2. API surface changes exactly `126 -> 127` with only `NebulaMobileObservability`;
3. `lib/nebula_sdk.dart` and `governance/public_api.txt` remain byte-identical;
4. returned Analytics uses internal `MobileAnalyticsSender`, including exact 16 KiB proof body and stable `batch_id` semantics;
5. returned Error Reporting uses internal `ErrorReportingClient + MobileErrorReportSender + CacheErrorReportStore`;
6. release-path persistent-store tests recreate a second SDK/store instance against the same persistent `CacheStorage` fake/fixture and recover queued records with identical `report_id`, `occurred_at`, retry metadata and ordering;
7. count/bytes/TTL eviction and corrupt-version bounded purge are tested;
8. ACK/rejection/subset deterministic drop delete exactly affected IDs across restart;
9. `12001` trust defer preserves records/IDs and performs recovery before a later network send;
10. factory body/API never accepts trusted App/install/platform/user identity;
11. App/environment namespaces are isolated;
12. user sign-out does not purge installation-scoped pending reports;
13. public API/analyzer/full tests/governance/secret scan remain green.

## 15. NFC Writer sequencing

Do not repin NFC Writer to an intermediate SDK commit merely because M3 is complete.

Required release sequence:

```text
OBS-SDK-COMPOSITION-V1-001 freeze
→ independent Architecture Review
→ canonical freeze closure
→ separately registered CHANGE_APPROVED composition implementation
→ independent SDK Review
→ implementation canonical closure
→ Coordinator registers one NFC Writer immutable SDK repin to that final canonical SHA
→ NFC Writer NEBULA-APP-001D becomes eligible for READY re-audit
→ App Adapter implements persistent CacheStorage binding + composition root wiring + privacy tests
→ 001D independent review / closure
→ REL-RC-001 may proceed
```

The final App repin must include both M3 and composition/store implementation in one reviewed immutable SDK snapshot. No floating ref/path dependency is allowed.

## 16. Explicit non-decisions / deferred

Not authorized by this V1 freeze:

- exporting `MobileAnalyticsSender`, `MobileErrorReportSender`, `ErrorReportingClient`, `ErrorReportStore`, retry/result/budget types;
- generic observability/telemetry provider APIs;
- provider selection or regional provider branching;
- native crash/minidump/ANR/breadcrumb/screenshot/full-log collection;
- durable Analytics event storage;
- shared product database schema;
- background worker/service APIs;
- user-scoped Error Reporting identity;
- Backend wire/schema changes.

## 17. Freeze verdict

Proposed V1 composition is:

```text
PUBLIC:
  NebulaMobileObservability
    .analytics       -> existing NebulaAnalytics
    .errorReporting  -> existing NebulaErrorReporting
    .create(...)     -> existing public infrastructure + persistent CacheStorage

INTERNAL:
  MobileAnalyticsSender
  ErrorReportingClient
  MobileErrorReportSender
  CacheErrorReportStore
  sender results / retry / budget / queue encoding

PUBLIC TOP-LEVEL DELTA:
  exactly +1 symbol (126 -> 127)
```

This is a freeze candidate only. `NEBULA-APP-001D` remains WAIT until a separately authorized implementation is canonical and the final App repin is reviewed.
