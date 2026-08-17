# NEBULA-SDK-RELEASE-001 — Nebula SDK 0.1.0-rc1 Packaging

- ID：NEBULA-SDK-RELEASE-001
- Owner: SDK Release Agent
- Agent: C
- Reviewer: Governance Review Agent
- Execution repo：`.`
- Execution branch：`sdk-release/NEBULA-SDK-RELEASE-001-rc1`
- Execution remote: `hub`
- Execution worktree: `wt-nebula-sdk-release-001-rc1`
- Platform API mode：`NONE`
- SDK public API mode：`READ_ONLY`
- Required upstream: `S1-F03-001 = DONE / REVIEW PASS`, `S1-F03-002 = DONE / REVIEW PASS`.
- State write authority: Coordinator only.

## Goal
Publish the first immutable Git-tag RC of the current canonical SDK without changing SDK production/public API behavior.

## Exact authorized write-set
Only these packaging/documentation files may change:

1. `pubspec.yaml` — version only: `0.1.0-dev.1` -> `0.1.0-rc1`; `publish_to: none` stays unchanged.
2. `CHANGELOG.md`
3. `docs/API_REFERENCE_RC1.md`
4. `docs/INTEGRATION_GUIDE_RC1.md`
5. `docs/MIGRATION_GUIDE_RC1.md`
6. `docs/releases/0.1.0-rc1.md`
7. `docs/releases/NEBULA-SDK-RELEASE-001-DELIVERY.md`

No `lib/**`, API snapshot, public export, dependency, Platform API, Backend, App or governance-state mutation is authorized to Agent C.

## Release invariants
- API surface remains exactly `127` top-level symbols.
- `publish_to: none` remains intentional for RC1 Git-tag distribution.
- Tag must be exactly `v0.1.0-rc1`.
- Tag is immutable and must point to the exact independently reviewed canonical release commit.
- Release PR must land with `fast-forward-only`; if canonical main moves after review, STOP and rebase/review a new exact candidate rather than tagging a merge commit not reviewed.
- Tag publication is allowed only after candidate Formal CI SUCCESS, independent official APPROVED review, fast-forward canonical landing, and post-merge governance SUCCESS.

## Required verification
- `sdk_release_gate.dart --self-check` PASS.
- release regression tests PASS.
- Task Source / Cross Repo / Platform self-check PASS.
- API surface PASS at 127.
- governance / secret scan / format / analyze / full tests / smoke PASS.
- exact write-set check PASS.
- `lib/**`, `governance/api_surface.snapshot`, `lib/nebula_sdk.dart`, `governance/public_api.txt` byte-identical to execution base.
- release docs describe current Bootstrap/Auth/Runtime Config/Analytics/Error Reporting/Mobile Observability composition+lifecycle surface and do not claim registry publication.

## Exit
Delivery goes to independent RC Review. Agent C does not merge or create the tag. Coordinator performs an exact fast-forward-only canonical publication, verifies post-merge governance, then publishes immutable tag `v0.1.0-rc1` to that exact canonical SHA and verifies tag-triggered release-gate CI.
