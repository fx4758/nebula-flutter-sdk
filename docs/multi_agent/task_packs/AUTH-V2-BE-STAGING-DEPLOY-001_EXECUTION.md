# AUTH-V2-BE-STAGING-DEPLOY-001 — Shared Staging Auth V2 Runtime Deployment

- ID：AUTH-V2-BE-STAGING-DEPLOY-001
- Owner: Backend Release / Deployment Agent
- Reviewer: Backend Review Agent
- Execution repo：`../flypost_backend`
- Execution branch：`auth/v2-be-staging-deploy-001`
- Execution remote: `origin`
- Execution worktree: `wt-auth-v2-be-staging-deploy-001`
- Required upstream: `AUTH-V2-BE-001 = DONE`, `AUTH-V2-BE-STAGING-DEPLOY-ARCH-001 = DONE / CLOSED_REVIEW_PASS`
- Platform API mode：`NONE`
- SDK public API mode：`READ_ONLY`
- Product adapter rule: `ADAPTER_FIRST`

## Current gate

`OPEN_RELEASE_AND_STAGING_EXECUTION`.

Architecture prerequisite is satisfied by PR #149 exact `9ccb6c64984ae64abbf850f474920c17661959d5`, Review #611 `APPROVED / official=true / stale=false`, merge `075998ee561bc08bf5e11c3492c0ef7dfb809754`, descendant governance `SUCCESS`.

Execution is pinned to immutable release identity `v0.1.0-rc3` with release base `bcd93b51aa2b2d479057e2e6b260ee9aab067353`. Backend production/schema/provider/App/SDK mutation remains unauthorized; any corrective requires a separate Story/publication.

## Execution intent after a separate Coordinator unlock

Only after the architecture contract is canonical and Coordinator publishes a separate execution unlock may this Story:

1. freeze an exact immutable Backend release candidate from canonical reviewed history; mutable `Dev` is not a deploy identity;
2. create release/deployment evidence under the Story-authorized evidence path;
3. run exact PR CI / full Go quality / migration rehearsal against disposable MySQL;
4. build the exact image on an authorized build/CI node, never the staging runtime host;
5. preserve immutable prior rc2 and never retarget tags;
6. deploy only to existing `staging-api` within Compose project `staging`, under remote deploy governance/lease;
7. run contract-defined pre/post compatibility and Auth V2 capability smokes;
8. record exact image digest, source, migration state, public staging origin and rollback evidence;
9. keep Apple/Google per-App binding disabled unless another reviewed Story supplies provider identifiers and authority.

## Authorized repository write set

```text
docs/releases/0.1.0-rc3.md
docs/evidence/AUTH-V2-BE-STAGING-DEPLOY-001/**
```

The release-evidence candidate must be docs-only relative to release base `bcd93b51...`. Any production-code/schema/config corrective requires separate authorization.

## Forbidden

- direct mutable-Dev deployment;
- retargeting `v0.1.0-rc1` or `v0.1.0-rc2`;
- building on staging;
- second Compose project, DB, API runtime, tunnel/daemon or shadow staging;
- skipping migrations or direct SQL around migration tooling;
- claiming schema rollback without proof;
- Apple/Google provider/client/secret mutation;
- Nearvia OAuth implementation unlock;
- production API origin invention;
- SDK/App mutation.

## Exit

Success closes only shared staging Auth V2 runtime deployment readiness. It does not prove Backend per-App Apple/Google binding or external provider registration readiness.
