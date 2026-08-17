# OBS-SDK-COMPOSITION-V1-002 — Mobile Observability Composition + Durable Store Implementation

- ID：OBS-SDK-COMPOSITION-V1-002
- Owner：SDK Mobile Observability Composition Agent
- Agent：A
- Reviewer：SDK Review Agent
- Execution repo：`.`
- Execution branch：`obs/sdk-composition-v1-002-mobile-observability-implementation`
- Execution remote：`hub`
- Execution worktree：`wt-obs-sdk-composition-v1-002-mobile-observability-implementation`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`CHANGE_APPROVED`
- Required upstream：`OBS-SDK-COMPOSITION-V1-001 = DONE / REVIEW PASS / CLOSED_REVIEW_PASS`.
- Frozen authority：`docs/multi_agent/contracts/MOBILE_OBSERVABILITY_SDK_COMPOSITION_V1.md`.

## Goal
Implement exactly the reviewed Mobile Observability public composition + durable Error Reporting store needed by App Adapters, without exporting internal sender/store/result types, changing Platform contracts, or requiring product code to import `src/**`.

## Exact authorized production/public write-set
1. `lib/src/nebula.dart`
2. `lib/src/observability/mobile_observability_composition.dart`
3. `lib/src/error_reporting/cache_error_report_store.dart`
4. `governance/api_surface.snapshot`

Focused tests/evidence may change only under `test/observability/**`, `test/error_reporting/cache_error_report_store_test.dart`, and `docs/multi_agent/reports/**`. Any required fifth production/public path is a scope gap: STOP and return a Delivery Note.

## Frozen public surface
Add exactly one public top-level symbol in the already-exported `src/nebula.dart` library: `NebulaMobileObservability`, exposing `NebulaAnalytics analytics`, `NebulaErrorReporting errorReporting`, and the exact reviewed static `create(...)` factory using existing `NebulaOptions`, `NebulaTransport`, `RequestProofSigner`, installation-token callback, trust-recovery callback, and persistent `CacheStorage`.

API surface invariant: `126 -> 127`; only new top-level symbol is `src/nebula.dart class NebulaMobileObservability`.

## Required internal composition
- Analytics: existing `NebulaAnalyticsClient` + internal `MobileAnalyticsSender`.
- Error Reporting: existing `ErrorReportingClient` + internal `MobileErrorReportSender` + new internal `CacheErrorReportStore`.
- No public sender/store/result/budget/report/provider type.
- Factory never accepts App-authored trusted app/install/platform/user identity, report/batch IDs, proof policy, provider selection, or raw credentials.

## Durable store requirements
`CacheErrorReportStore` remains internal and implements existing internal `ErrorReportStore` over host persistent `CacheStorage` using App/environment namespace + fixed versioned queue key. It must preserve `report_id`, `occurred_at`, stored/retry metadata and ordering across restart; enforce count/bytes/age; persist exact ACK/rejection/drop deletion; bounded-purge only its own corrupt/unknown-version key; isolate App/environment; and never persist trusted identity, token/proof material, server `ingested_at`, provider credentials, or product content.

`InMemoryCacheStorage` is test/development only. V1 makes no cross-isolate multi-writer guarantee; one composition instance serializes queue read-modify-write operations.

## Analytics boundary
Composition may wire existing `CacheConsentStore` to the same persistent `CacheStorage`, but must not add durable Analytics event storage or mutate Analytics production files. Existing M3 16 KiB/stable `batch_id`/trust-recovery semantics remain authoritative.

## Must remain byte-identical
`lib/nebula_sdk.dart`, `governance/public_api.txt`, `lib/src/capabilities.dart`, `lib/src/analytics/analytics_sender.dart`, `lib/src/error_reporting/sender.dart`, `lib/src/transport.dart`, `lib/src/transport/**`, `lib/src/foundation/**`, `lib/src/auth/**`.

## Forbidden
Backend/App/NFC Writer/provider mutation; App SDK repin; Analytics production mutation; Platform wire/schema change; generic telemetry abstraction; product SQLite/database reuse; exporting internal M3/store/result types; new package dependency; native crash/minidump/ANR/breadcrumb/screenshot/full-log scope; Task Board mutation by Agent A.

## Verification
Task Source Guard and Cross Repo Guard PASS; exact write-set PASS; `git diff --check` PASS; public import can construct composition without `src/**`; API surface exactly 127; unchanged paths byte-identical; persistence restart/count/bytes/TTL/corrupt-version/ACK-subset/trust-defer/App-env isolation proofs PASS; focused tests + full analyzer/tests/governance/API surface/secret scan PASS; Delivery Note records exact base/candidate/symbol delta/hashes.

## Exit
Delivery goes to independent SDK Review. Agent A does not merge or mark DONE. After canonical implementation closure, Coordinator may register one immutable NFC Writer SDK repin/capability re-audit step for `NEBULA-APP-001D`. `S1-F01-002` remains unrelated.
