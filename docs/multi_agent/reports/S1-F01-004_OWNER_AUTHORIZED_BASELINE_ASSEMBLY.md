# S1-F01-004 Owner-Authorized R2 Baseline Assembly

- Coordinator date: 2026-08-10
- Canonical main at assembly: `9303b649c3a1a16ccca17f0106061d3fe9584dbc`
- Recovery incident: `GOV-P0-F01-004-STALE-PUBLICATION-20260810`
- R1 authority: `e07e825f6a94bc2c651b166118b37cf235df8de4` / REQUEST CHANGES
- Integration branch: `integration/s1-f01-004-r2-owner-baseline`
- Owner-authorized baseline: `f11fb53d6ff6e6ec689797133e78f6b7a9219a05`
- SDK Core clean R2 branch: `s1/f01-004-sdk-bootstrap-surface-r2`
- Routed execution base: `5df87706b85bba7a935cd8c2aefc48975ba4b8c9` (parent `f11fb53`; routing/docs only)

## Owner contribution acceptance

All three registered owner deliveries were independently fetched from `hub`, verified to have parent `9303b649c3a1a16ccca17f0106061d3fe9584dbc`, verified to touch only their registered write sets, and byte-compared against the frozen handoff proposals.

| Story | Owner delivery | Frozen proposal SHA-256 | Byte match | Integrated commit |
|---|---|---|---|---|
| S1-F01-004A | `c1fced21f081f8bdadf4b8fbb81b3bb4d3c8421c` | `1a0732dafb231f3a65d4dcaf359833d0e62a9ec342ea2df30651104ecc0ac2c2` | PASS | `10517be` |
| S1-F01-004B | `b7d380bb6c8e476e871222994fe8b0f57f61312c` | `86edf41ddfbd1efdfe473c938d5b04d0f275ee4e5f42d942807b02591ec5cff6` | PASS | `72189ef` |
| S1-F01-004C | `2f417e51067f74a41f26ee86ea13f96dba3c0769` | `a40c139d8bcfa07f1f04c6bf4ab7c1262d24f7de243fd732d63a783b739270ed` | PASS | `f11fb53` |

The integration branch was assembled by serial cherry-pick from canonical `9303b64`. It is deliberately **not** merged to `main`; the public export and API-surface contributions depend on the SDK Core replay and therefore are an integration baseline, not a standalone release candidate.

## SDK Core replay gate

Only the following proposal may be replayed by SDK Core from `f11fb53`:

```text
01-sdk-core.patch
SHA-256 b0b23df76fd75c4134de20089b02cdfe4c17197384bc49d5bd239e41b0ba6e80
```

Mixed-owner historical commits `19fc097`, `e101c7a`, `a7ccd6c`, and `4aa233e` remain evidence only and must not be cherry-picked into the R2 candidate.

The old execution branch `s1/f01-004-sdk-bootstrap-surface` is superseded. Clean execution is pinned to:

```text
branch:        s1/f01-004-sdk-bootstrap-surface-r2
owner baseline: f11fb53d6ff6e6ec689797133e78f6b7a9219a05
execution base: 5df87706b85bba7a935cd8c2aefc48975ba4b8c9
```

## Independent reconstructed R2 verification

Coordinator created a detached worktree from `f11fb53`, applied the exact frozen `01-sdk-core.patch`, and compared `lib/**`, `governance/**`, `tool/**`, and `test/**` against extracted R2 tip `4aa233e`. Runtime/governance/test diff was empty.

Locked CI image:

```text
flypost/nebula-sdk-ci:20260810-v1
Dart 3.12.0
image identity: nebula-sdk-ci-20260810-v1
```

Results:

```text
CI dependency guard   PASS / 47 packages
Nebula Governance     PASS
Governance regression PASS / 30 cases
API Surface           PASS / 125 symbols
Secret Scan           PASS
dart format           PASS
dart analyze          PASS / 0 issues
dart test             PASS / 211 tests
smoke                 PASS
```

This validates the exact target composition but does not pre-approve the future SDK Core commit. After SDK Core creates the clean R2 candidate, an independent SDK Review R2 is still mandatory.

## Coordinator state transition

- `S1-F01-004A/B/C` -> DONE as owner contributions.
- `GOV-OWN-01` -> mechanically closed at the owner-baseline boundary.
- `S1-F01-004` -> READY for exact `01-sdk-core.patch` replay only.
- `S1-F01-002` / NFC Writer remains WAIT.
- `NEBULA-DEP-002` remains WAIT until S1-F01-004 R2 is independently accepted and published DONE.
