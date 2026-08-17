# NEBULA-SDK-RELEASE-001 — RC1 Delivery

- Execution base: `310cc524f17a921b89ad9df467d81530a71531fb`
- Packaging core: `66a939b4853a3476de852864b953a34339a9f9fe`
- Version: `0.1.0-rc1`
- Planned immutable tag: `v0.1.0-rc1`
- Channel: Git-tag RC / no registry publication
- State: **READY FOR INDEPENDENT RC REVIEW**

## Exact packaging scope

```text
pubspec.yaml
CHANGELOG.md
docs/API_REFERENCE_RC1.md
docs/INTEGRATION_GUIDE_RC1.md
docs/MIGRATION_GUIDE_RC1.md
docs/releases/0.1.0-rc1.md
docs/releases/NEBULA-SDK-RELEASE-001-DELIVERY.md
```

The only package metadata mutation is `version: 0.1.0-dev.1 -> 0.1.0-rc1`. `publish_to: none` and dependencies are unchanged.

## Mechanical evidence

```text
SDK release gate self-check       PASS
SDK release regression            6 / 6 PASS
Task Source self-check             PASS / 27 Stories
Release Story source               PASS
Cross Repo self-check              PASS
Exact branch/repo check            PASS
Platform API self-check            PASS
Platform negative probes           PASS
API/Platform CI binding            PASS
API surface                        PASS / 127 symbols
Nebula Governance                  PASS
Governance regression              30 / 30 PASS
Secret scan                        PASS
Dart format                        PASS / 108 files unchanged
Dart analyze                       PASS / 0 issues
Full SDK tests                     261 / 261 PASS
Smoke                              PASS
git diff --check                   PASS
```

## Byte-identical release boundaries

```text
lib/nebula_sdk.dart              52191077bdcfeb08f104979b8ca26e9aec184db5
governance/api_surface.snapshot f8f215f0eb9259fa2eb1b97cfcf7023f853e3c83
governance/public_api.txt        8169be75428f0863d11634bab189d013d45292fe
lib/**                           0 diff
pubspec.lock                     0 diff
```

Public API remains `127 -> 127`. RC1 docs reflect current Bootstrap/Auth/Runtime Config/Analytics/Error Reporting/Mobile Observability composition + lifecycle; no internal sender/store is promoted.

## Publication gate

Agent C does not merge or create the release tag. Independent Review must bind the final PR head. Coordinator may merge only with `fast-forward-only` while canonical main still equals the execution base. After fresh main equals the exact reviewed candidate and post-merge governance succeeds, Coordinator may create immutable `v0.1.0-rc1` on that exact SHA. Tag-triggered `release-gate` CI must succeed before RC1 is declared released.
