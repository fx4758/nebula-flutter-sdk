# S1-F03-001 — SDK Release Workflow Delivery

```text
Story: S1-F03-001 SDK Release Workflow
Execution branch: s1/f03-001-release
Base: 2577ebd4775f467e649f167e41171a0524960f68
Owner: SDK Governance Agent C
Platform API mode: NONE
SDK public API mode: READ_ONLY
```

## Delivered boundary

This candidate adds release governance only: a three-channel policy, an executable release gate with regression tests, and a tag-triggered release CI gate.

Frozen channels:

```text
Development = local path / never a release artifact
Beta / RC   = prerelease SemVer rc* / publish_to:none / immutable Forgejo Git tag
Production  = stable SemVer / explicit HTTPS package registry
```

The gate requires exact `v<pubspec version>` tag identity, clean tree, exact HEAD/approved-commit equality, tag→HEAD equality, frozen Task authority and API-surface match. It rejects `0.1.0-dev.*` as a beta RC.

## Explicit non-delivery

No `lib/**`, public exports, API snapshot, Bootstrap wire, App, Backend, Task Board, Sprint Board or `pubspec.yaml` change is included. The canonical package remains `0.1.0-dev.1` / `publish_to:none`; no RC tag is created by this implementation candidate.

`v0.1.0-rc1` is only the intended first RC tag shape once a separately authorized canonical release commit carries package version `0.1.0-rc1`.

Implementation Agent does not mark S1-F03-001 DONE and does not create a release tag. Independent Governance Review and Coordinator publication remain required.

## Mechanical evidence

Executed in canonical CI image `flypost/nebula-sdk-ci:20260810-v1` with Dart `3.12.0`:

```text
CI dependency guard regression   PASS
CI dependency resolution         PASS (47 packages / Dart 3.12.0)
Release gate self-check          PASS
Release regression tests         PASS
Task Source Guard                PASS
Platform API Guard               PASS
API surface snapshot             PASS (125 symbols)
Nebula Governance                PASS
Secret scan                      PASS
Dart format                      PASS
Dart analyze                     PASS / no issues
Full SDK tests                   211 / 211 PASS
Smoke                            PASS
Forbidden production/API/state   0 diff
```

The developer-host Dart `3.11.4` was intentionally not used to waive or weaken the CI runtime pin; canonical image validation used the required Dart `3.12.0` runtime.
