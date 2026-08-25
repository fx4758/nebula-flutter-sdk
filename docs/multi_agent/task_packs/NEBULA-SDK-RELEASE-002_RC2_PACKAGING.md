# NEBULA-SDK-RELEASE-002 — Nebula SDK 0.1.0-rc2 Packaging

- ID：NEBULA-SDK-RELEASE-002
- Owner: SDK Release Agent
- Agent: C
- Reviewer: Governance Review Agent
- Execution repo：`.`
- Execution branch：`sdk-release/NEBULA-SDK-RELEASE-002-rc2`
- Execution remote：`hub`
- Execution worktree：`wt-nebula-sdk-release-002-rc2`
- Platform API mode：`NONE`
- SDK public API mode：`READ_ONLY`
- Required upstream: `S1-F03-001 = DONE`, `S1-F03-002 = DONE`, `NEBULA-SDK-RELEASE-001 = DONE / CLOSED_RELEASE_PASS`, `AUTH-V2-SDK-002 = DONE / CLOSED_REVIEW_PASS`, `NEBULA-SDK-RELEASE-GATE-002 = DONE / CLOSED_REVIEW_PASS`.
- Execution baseline: resolve **fresh `hub/main` at packaging start**. The resolved exact must contain `84852208681e73a1fbe62100fde6d1d85b8a1de9` (reviewed release-gate implementation) and `dbacd7fa60065e2fe2a868532695ef344833bf16` (reviewed RC2 authority publication) as ancestors, must have API surface `131`, and must be recorded verbatim in the Delivery note. If `hub/main` moves after baseline resolution, STOP and rebuild from the new fresh canonical baseline.
- State write authority: Coordinator only.

## Goal
Publish the current canonical SDK as the next immutable Git-tag RC for consumer App adoption. RC2 packages the already-canonical Auth V2 SDK surface; it does not create new SDK behavior.

## Exact authorized write-set
Only these packaging/documentation files may change:

1. `pubspec.yaml` — version only: `0.1.0-rc1` -> `0.1.0-rc2`; `publish_to: none` stays unchanged.
2. `CHANGELOG.md`
3. `docs/API_REFERENCE_RC2.md`
4. `docs/INTEGRATION_GUIDE_RC2.md`
5. `docs/MIGRATION_GUIDE_RC2.md`
6. `docs/releases/0.1.0-rc2.md`
7. `docs/releases/NEBULA-SDK-RELEASE-002-DELIVERY.md`

No `lib/**`, `governance/api_surface.snapshot`, public export, dependency, Platform API, Backend, consumer App, provider credential/acquisition, or provider migration mutation is authorized.

## Release invariants
- API surface remains exactly `131` top-level symbols relative to the resolved execution baseline.
- The four Auth V2 additions already canonical before this Story remain: `NebulaOAuthProvider`, `NebulaEmailCodePurpose`, `nebulaCodeInvalidCredentials`, `InvalidCredentialsError`.
- PHONE/SMS compatibility remains unchanged.
- `publish_to: none` remains intentional for RC Git-tag distribution.
- Tag must be exactly `v0.1.0-rc2`.
- Existing `v0.1.0-rc1` is immutable and must not be moved.
- Tag must point at the exact independently reviewed canonical release candidate.
- If canonical main moves after baseline resolution or after exact review, STOP; rebuild/review a new exact candidate rather than tagging an unreviewed or stale-baseline commit.

## Required verification
- `sdk_release_gate.dart --self-check` PASS.
- release regression tests PASS.
- Task Source / Cross Repo / Platform self-check PASS.
- API surface PASS at `131`.
- governance / secret scan / format / analyze / full tests / smoke PASS.
- exact write-set PASS.
- `lib/**`, `governance/api_surface.snapshot`, `lib/nebula_sdk.dart`, `governance/public_api.txt` byte-identical to the resolved execution baseline.
- release docs accurately describe RC2 as Git-tag distribution and do not claim pub.dev/registry publication.
- migration notes state that consumer Apps must repin immutably and adapt through App-owned adapters; no provider secret or OAuth authorization-code acquisition belongs in the SDK package.

## Exit
Delivery goes to independent RC Review. Agent C does not merge or create the tag. Coordinator publishes only after exact Formal SUCCESS + official exact-head reviewer approval, verifies post-publication governance, then creates immutable `v0.1.0-rc2` and waits for the tag-triggered release gate SUCCESS. Only then may consumer Apps repin RC2 through their own dependency governance.
