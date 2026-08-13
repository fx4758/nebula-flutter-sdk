# S1-F02-002 SDK Runtime Config Precheck

Status: **READ_ONLY PREFLIGHT EVIDENCE**  
SDK canonical base: `main@b1a9e2cb4e82f468aae73ae46e8b72709aac0f48`  
Backend audit baseline: `FlyPostAPI Dev@070500e2be02358f711552e5b88b00f784ed7389`  
Backend audit publication: `root/FlyPostAPI#13`, merged as `b091da1e4d1115310bae0e0e95865304124caaa1`  
Date: 2026-08-13

## Scope

This is a read-only preflight for `S1-F02-002`. It changes no SDK implementation, public API, Backend, App, frozen Runtime Config contract, or Task Board state.

## Questions and evidence

| Question | Result | Evidence |
| --- | --- | --- |
| Does the SDK already consume the canonical endpoint and trusted installation context? | PASS | `ConfigEndpoints.runtimeConfig` is `GET /api/v1/mobile/runtime-config`; `NebulaConfigClient` builds Installation Proof headers and carries no caller-controlled region/locale/platform selector. |
| Does the SDK implement required Runtime Config cache semantics? | PASS | Existing client covers TTL, ETag/304, bounded GET retry, single-flight, stale-if-error, security-critical no-stale, kill-switch non-caching, and optional persistent cache. |
| Are client-side response limits enforced? | PASS | `NebulaEffectiveConfig` rejects over-limit item counts, keys, values and revision; `NebulaConfigClient` rejects over-64 KiB snapshots and refuses over-64 KiB persistence. |
| Is an SDK production or public-API change required now? | NO | The App pin `ad2da9d36f6d2561bd9a5a5644c777d6e3ddffe4` and current main have byte-identical `lib/src/config/config_client.dart` and `lib/src/config/effective_config.dart`. |
| Is a Backend production change required before App consumption? | YES | S1-F02-001 proved that Backend lacks the frozen 8 KiB encoded-value check and final HTTP-envelope 64 KiB check. |
| Is contract reconciliation required? | YES, separately authorized | Frozen SDK contract text still names `X-App-Platform` as an optional policy selector, while canonical Backend trusts only `app_installation.platform`. This is a trust-source documentation drift, not an SDK client behavior defect. |
| Is App mutation authorized or required now? | NO / NOT AUTHORIZED | `NEBULA-APP-001C` remains blocked until Backend hardening and trust-source contract closure are separately reviewed. |

## Test evidence

On mac-mini CI shared exact checkout at SDK `b1a9e2c...`:

```text
dart test test/runtime_config_contract_test.dart \
  test/config_client_test.dart \
  test/config_client_hardening_test.dart

31 tests passed
```

The tests cover frozen snapshot parsing, limits, ETag/304, single-flight, stale-if-error, security-critical no-stale, kill-switch handling, bounded retry, and cache persistence.

## Precheck conclusion

```text
SDK Runtime Config implementation: READY / no code mutation required
SDK public API: unchanged
Backend hard limits: BLOCKING GAP
SDK/Backend platform trust-source contract: BLOCKING GOVERNANCE DRIFT
NEBULA-APP-001C: WAIT
```

The next authorized decision is not App integration. Architecture/Coordinator must first authorize a narrow Backend hardening Story for the already-frozen 8 KiB value and 64 KiB final-response limits, and separately select the authority/path for reconciling the frozen platform trust-source contract. Neither repair belongs in this read-only preflight.
