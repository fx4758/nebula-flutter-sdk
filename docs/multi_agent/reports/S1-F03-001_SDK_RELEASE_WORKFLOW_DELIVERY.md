# S1-F03-001 — SDK Release Workflow Delivery

- Story: `S1-F03-001 SDK Release Workflow`
- Execution branch: `s1/f03-001-release`
- Fresh execution base: `afd6471d483e993efb7cc13dcb95007e2576d97b`
- Owner: SDK Governance Agent C
- Platform API mode: `NONE`
- SDK public API mode: `READ_ONLY`
- State: **READY FOR INDEPENDENT GOVERNANCE REVIEW**

## Delivered boundary

Release-governance only. No `lib/**`, public exports, API snapshot, Platform API, Backend, App, Task Board, Sprint Board or `pubspec.yaml` mutation.

Frozen channels:

```text
Development = local path / never a release artifact
Beta / RC   = prerelease SemVer rc* / publish_to:none / immutable Forgejo Git tag
Production  = stable SemVer / explicit HTTPS package registry
```

The release gate requires exact `v<pubspec version>` tag identity, clean tree, exact HEAD/approved-commit equality, tag-to-HEAD equality, frozen Task authority and API-surface match. It rejects `0.1.0-dev.*` as a beta RC.

Current canonical package remains `0.1.0-dev.1` / `publish_to:none`; no tag is created by this Story. `v0.1.0-rc1` requires a separately reviewed canonical version-release commit after S1-F03-001 and S1-F03-002 close.

## Fresh-main reconciliation

The release mechanics were originally authored as candidate `8b686efe2fbc186836f15b46aa085009428f6679`. This delivery reapplies only those release-governance files onto fresh canonical `afd6471d483e993efb7cc13dcb95007e2576d97b`; it does not carry the obsolete Task Board or production tree from the old parent.

## Verification required

```text
CI dependency guard             PASS
Release gate self-check         PASS
Release regression tests        PASS
Task Source Guard               PASS
Cross Repo Guard                PASS
Platform API Guard              PASS
API surface snapshot            PASS / 127 symbols
Nebula Governance               PASS
Secret scan                     PASS
Dart format                     PASS
Dart analyze                    PASS
Full SDK tests                  261 / 261 PASS
Smoke                           PASS
Forbidden production/API/state  0 diff
```

Agent C does not mark DONE and does not create a release tag. Independent Governance Review and Coordinator closure remain required.
