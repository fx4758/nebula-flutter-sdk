# OBS-SDK-COMPOSITION-V1-001 — Mobile Observability Public Composition + Durable Store Freeze

- ID：OBS-SDK-COMPOSITION-V1-001
- Owner：SDK Mobile Observability Composition Agent
- Agent：A
- Reviewer：Architecture Review Agent
- Execution repo：`.`
- Execution branch：`obs/sdk-composition-v1-001-mobile-observability-freeze`
- Execution remote：`hub`
- Execution worktree：`wt-obs-sdk-composition-v1-001-mobile-observability-freeze`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`READ_ONLY`
- Governance state：freeze-only; no SDK production/public mutation in this Story.
- Required upstream：`OBS-SDK-TRANSPORT-V1-001 = DONE / REVIEW PASS`, `OBS-SDK-ERROR-API-V1-002 = DONE / REVIEW PASS`, `OBS-SDK-ERROR-SEAM-V1-001 = DONE / REVIEW PASS`.
- Triggering consumer：NFC Writer `NEBULA-APP-001D` capability re-audit.

## Purpose

Freeze the smallest legal App-facing composition and persistence binding needed to consume the already-canonical Mobile Analytics + Error Reporting implementation without importing SDK `src/**`, duplicating transport/proof logic, or exposing internal sender/store/result types by accident.

Fresh re-audit facts:

1. NFC Writer current SDK pin `ad2da9d...` predates `NebulaErrorReporting` and M3 and must eventually repin.
2. Repin alone is insufficient: current public barrel exposes `NebulaErrorReporting` but not `MobileAnalyticsSender`, `MobileErrorReportSender`, `ErrorReportingClient`, or `ErrorReportStore`.
3. `ERROR_REPORTING_SDK_PUBLIC_SURFACE_V1.md` intentionally classifies client/store/sender/result internals as INTERNAL ONLY and directs product code to consume through `Nebula.errorReporting`.
4. Error Reporting currently has only the internal `ErrorReportStore` Port; production `implements ErrorReportStore` count is zero.
5. Existing `CacheStorage` is a non-sensitive replayable-cache abstraction with only an in-memory SDK implementation; it cannot be silently equated with the app-private durable Error Reporting queue.

## Required output

Create exactly one independently reviewable freeze artifact:

- `docs/multi_agent/contracts/MOBILE_OBSERVABILITY_SDK_COMPOSITION_V1.md`

This Story may recommend later public API change, but it MUST NOT implement or mutate that API itself.

## Mandatory decisions

The freeze MUST mechanically decide:

1. How App Adapter code obtains an SDK-owned `NebulaAnalytics` implementation backed by the canonical mobile Analytics sender without importing SDK internals or rebuilding the sender in the App.
2. How App Adapter code obtains an SDK-owned `NebulaErrorReporting` implementation backed by `ErrorReportingClient + MobileErrorReportSender` while keeping internal client/sender/result types private unless independent review explicitly changes that classification.
3. The minimal public composition surface: existing facade/member, factory, builder, or another bounded pattern. Exact new public symbol/member count must be stated if any.
4. Which existing public inputs are allowed at the composition boundary (for example `NebulaOptions`, existing transport/proof/installation lifecycle objects/callbacks) and which internal identity facts must never be App-authored.
5. How installation-token/proof/trust-recovery lifecycle is reused without exposing keys/tokens beyond existing public trust abstractions or creating a second bootstrap stack.
6. The production Error Reporting durable store strategy: concrete SDK-owned implementation vs host storage binding; persistence must be app-private, best-effort durable across process restart, and bounded by reports/bytes/age.
7. Whether existing `CacheStorage`, `SecureStorage`, or another already-public storage abstraction is semantically suitable. If not, freeze the smallest storage surface change required; product SQLite/database reuse is forbidden unless independently justified and frozen.
8. Environment/App namespace isolation and migration/reset behavior for the durable Error Reporting queue.
9. How ACK delete, next-launch retry, transient retry metadata, trust defer, and deterministic local drop survive persistence without changing frozen `report_id`/`occurred_at` semantics.
10. Whether Analytics requires any persistence beyond its already-frozen queue semantics for this composition slice; do not broaden into generic telemetry storage.
11. Exact future production/public write-set required to implement the composition freeze.
12. App repin sequencing: one immutable repin after composition implementation canonical closure, not an intermediate repin that remains unusable.
13. Privacy boundary: no NFC UID/dump/MRZ/full card/token/user content/raw logs/breadcrumbs/screenshots are added to observability payloads.
14. A consumer matrix proving NFC Writer can consume the frozen surface while FlyPost/other Apps are not forced into product-specific adapters.

## Hard boundaries

- no `lib/**` mutation in this Story;
- no public export/snapshot mutation in this Story;
- no Backend/App/provider mutation;
- no Analytics or Error Reporting wire/Platform contract change;
- no SDK `src/**` import workaround prescribed to Apps;
- no App-owned replacement sender/Crash transport;
- no silent reuse of product SQLite as SDK observability store;
- no generic telemetry super-abstraction;
- no Task Board/Sprint Board mutation by Agent A.

## Verification

- Task Source Guard `OBS-SDK-COMPOSITION-V1-001` PASS;
- Cross Repo Guard PASS;
- `git diff --check` PASS;
- production/public API diff = 0;
- existing API surface remains unchanged;
- freeze reconciles canonical public-surface contract, M3 implementation, Error Reporting lifecycle/store requirements and NFC Writer public Adapter boundary;
- independent Architecture Review PASS on exact candidate.

## Exit

This Story closes only composition/storage **freeze**. It does not authorize public API or production mutation.

After canonical `DONE / REVIEW PASS`, Coordinator must separately register the exact SDK implementation/public-surface Story with `CHANGE_APPROVED` only if the freeze requires API change. NFC Writer 001D remains WAIT until that implementation closes and a final immutable App SDK repin is reviewed.

`S1-F01-002` remains unrelated and MUST NOT be claimed from this lane.
