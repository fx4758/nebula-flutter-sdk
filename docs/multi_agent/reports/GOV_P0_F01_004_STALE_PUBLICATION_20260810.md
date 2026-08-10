# GOV-P0 — S1-F01-004 Stale Review Publication Incident

- Incident ID: `GOV-P0-F01-004-STALE-PUBLICATION-20260810`
- Date: 2026-08-10
- Affected repo: `nebula-flutter-sdk`
- Last accepted production baseline before incident: `da2944d7b192e6c4bcec0c942039897eb3bad683`
- Authoritative independent R1: `e07e825f6a94bc2c651b166118b37cf235df8de4` / **REQUEST CHANGES**
- Stale production landing: `59dd960e38ad51c2bd60b59044dfa1698f3a7909`
- Stale acceptance publication: `7929487b6a94e20c511725c706a7fa825c07c522`
- Implementation rework tip at reconciliation: `4aa233ee90bec5356d8acce8146e274571bef51e`

## Incident

`59dd960` entered canonical `main` with the exact tree of `e101c7a`, then `7929487` published `S1-F01-004 = DONE / PASS`.

That publication is stale because authoritative review `e07e825` recorded **REQUEST CHANGES R1**, and `59dd960` equals the `e101c7a` tree so it does not contain later `a7ccd6c` strict-int64 response parsing. It also accepted mixed-owner history in which SDK Core authored Quality/Architecture-owned governance/public-surface paths (`GOV-OWN-01`).

## Recovery authority and proof

Frozen `CROSS_REPO_EXECUTION_POLICY.md` §5 requires a stale shared-branch delivery to preserve evidence, quarantine the shared branch back to its pre-delivery code tree without rewriting history, record the incident, and review isolated branches only.

Coordinator applied non-committing reverts of `7929487` then `59dd960`. The complete resulting tree exactly matches `da2944d`:

```text
revert_tree  = f5187baf999cdd10eb396ac3e17876b3185d09f7
da2944d_tree = f5187baf999cdd10eb396ac3e17876b3185d09f7
QUARANTINE_TREE_RESTORE: PASS
```

## R2 owner-split evidence

Handoff: `/Users/sean/Documents/project/forAI/handoff-s1-f01-004-r2/`

Verified SHA-256:

- `01-sdk-core.patch` = `b0b23df76fd75c4134de20089b02cdfe4c17197384bc49d5bd239e41b0ba6e80`
- `02-sdk-architect-public-surface.patch` = `1a0732dafb231f3a65d4dcaf359833d0e62a9ec342ea2df30651104ecc0ac2c2`
- `03-architecture-pm-policy.patch` = `86edf41ddfbd1efdfe473c938d5b04d0f275ee4e5f42d942807b02591ec5cff6`
- `04-quality-governance-surface.patch` = `a40c139d8bcfa07f1f04c6bf4ab7c1262d24f7de243fd732d63a783b739270ed`

Path overlap = 0. Applying all four to clean `da2944d` reconstructs the exact extracted R2 tree:

```text
rebuilt  = ede383517b0fe9dd2f12defa85a40b7b10ad0e1b
expected = ede383517b0fe9dd2f12defa85a40b7b10ad0e1b
OWNER_SPLIT_RECONSTRUCTION: PASS
```

This proves decomposition fidelity only, not owner authorization.

## Recovery execution model

Registered serial owner contributions:

- `S1-F01-004A` — SDK Architect owns `02` (`lib/nebula_sdk.dart` only).
- `S1-F01-004B` — Architecture/PM owns `03` (`governance/policy.json` only).
- `S1-F01-004C` — Quality owns `04` (`governance/api_surface.snapshot`, `governance/public_api.txt`, `tool/governance*.dart` only).

These are owner-authored contributions, not standalone merge-to-main candidates: `02` exports Core files and `04` freezes the final public surface, so only the assembled recovery tip is required to satisfy full SDK gates. Each Owner must commit only its registered paths on its own branch. Coordinator serially assembles those owner commits; after A/B/C are delivered, SDK Core may replay only `01-sdk-core.patch` from the owner-authorized integration baseline.

Until final R2 independent review PASS and Coordinator publication:

```text
S1-F01-004 = WAIT / REQUEST CHANGES R1
NEBULA-DEP-002 = WAIT
S1-F01-002 / NFC Writer 001B = WAIT
```
