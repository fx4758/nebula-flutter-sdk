# S1-F03-002 — API Surface + Platform Boundary CI Gate Delivery

- Story: `S1-F03-002`
- Fresh base: `1c2cbf9fb37e7f2f0549e28628fae605931675ec`
- Branch: `s1/f03-002-api-gate`
- Platform API mode: `NONE`
- SDK public API mode: `READ_ONLY`
- State: **READY FOR INDEPENDENT GOVERNANCE REVIEW**

## Reconciliation result

The core gates already existed on canonical main and were already blocking in `.github/workflows/governance.yml`: `platform_api_guard.dart --self-check`, Platform guard regression, governance regression, and `api_surface.dart`. This Story therefore does not duplicate guard implementations.

It adds only the missing release evidence:

1. explicit fail-closed unknown/legacy Story negative probe;
2. a CI-binding regression that fails if the Platform self-check, Platform negative probes, governance negative probes, or API-surface gate are removed from the governance workflow;
3. explicit proof that CI never invokes `api_surface.dart --update` and therefore cannot self-approve public API drift.

No `lib/**`, public API snapshot, Platform production API, Backend, App or Task Board mutation is included.

## Mechanical evidence

```text
unknown/legacy Story negative probe     FAIL-CLOSED / PASS
READ_ONLY Platform production mutation  BLOCKED / PASS
READ_ONLY router mutation               BLOCKED / PASS
READ_ONLY contract mutation             BLOCKED / PASS
Platform self-check                     PASS
CI binding regression                   PASS
API surface snapshot                    PASS / 127 symbols
Governance regression                   PASS / 30 cases
Task Source Guard                       PASS
Cross Repo Guard                        PASS
Secret scan                             PASS
Dart analyze                            PASS / 0 issues
Full SDK tests                          261 / 261 PASS
Smoke                                   PASS
```

CI is explicitly forbidden from calling `api_surface.dart --update`; public API drift therefore still requires reviewed compatibility authorization rather than self-updating the snapshot.
