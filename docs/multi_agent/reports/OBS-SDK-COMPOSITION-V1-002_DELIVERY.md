# OBS-SDK-COMPOSITION-V1-002 Delivery Note

- Story: `OBS-SDK-COMPOSITION-V1-002`
- Execution base: `b9076204646ef05e094e2c93105fcf3c3ba9a65c`
- Core implementation: `54287e488772c1c7b8a1b95cc3fc84e3c6f90cb3`
- Branch: `obs/sdk-composition-v1-002-mobile-observability-implementation`
- State: **READY FOR INDEPENDENT SDK REVIEW**

## Exact production/API write-set

```text
lib/src/nebula.dart
lib/src/observability/mobile_observability_composition.dart
lib/src/error_reporting/cache_error_report_store.dart
governance/api_surface.snapshot
```

No fifth production/public path was required.

## Public surface proof

Before snapshot update, `tool/api_surface.dart` reported exactly one addition:

```text
src/nebula.dart class NebulaMobileObservability
```

After the authorized update, the snapshot is exactly `127` symbols: `126 -> 127`, with no second top-level addition.

The public factory returns existing `NebulaAnalytics` and `NebulaErrorReporting` capabilities and accepts only existing public infrastructure/lifecycle inputs. Product code does not need `src/**` imports.

## Durable Error Reporting store

The new internal `CacheErrorReportStore` uses host persistent `CacheStorage` with existing App/environment namespace and a fixed versioned queue key. It persists normalized report facts plus local delivery metadata only. It preserves stable report identity/occurrence/retry metadata across restart; applies deterministic count/bytes/age eviction; persists exact delete/retry mutations; isolates App/environment scopes; and bounded-purges only its own queue key on corruption/unknown version.

It does not persist trusted App/installation/platform/user identity, proof/token material, server `ingested_at`, provider credentials, or product content. No product database or SecureStorage queue backing was introduced.

## Composition / trust proof

Focused tests prove:

- public-barrel-only construction of `NebulaMobileObservability`;
- restart persistence of `report_id`, `occurred_at`, retry count/time and queue ordering;
- ACK deletion remains deleted after restart;
- count/bytes/TTL bounds;
- corrupt/unknown-version queue purges only Error Reporting queue key;
- App/environment isolation and serialized local RMW;
- `12001` trust defer preserves the same durable report before recovery;
- after cooldown/recovery, the later network send uses the same `report_id` and ACK durably deletes it.

## Verification

```text
Task Source Guard          PASS
Cross Repo Guard           PASS
Coordinator State Guard    PASS
Platform API Guard         PASS
Nebula Governance          PASS
Governance regression      30/30 PASS
API surface                PASS / 127 symbols
Secret scan                PASS
dart analyze               PASS / 0 issues
dart test                  258/258 PASS
smoke                      PASS
git diff --check           PASS
```

## Required unchanged paths

All required frozen/shared paths are byte-identical to `b9076204646ef05e094e2c93105fcf3c3ba9a65c`, including:

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

Backend, NFC Writer/App, Provider, Analytics production, App SDK repin and Task Board mutation are all zero. `S1-F01-002` remains unrelated.

## Exit

Agent A delivers this exact implementation to independent SDK Review only. Agent A does not merge or mark the Story DONE. NFC Writer repin/capability re-audit remains blocked until canonical implementation closure.
