# AUTH-V2-BE-STAGING-DEPLOY-VARIANCE-001 — RC3 Staging Sequence Variance Disposition

- ID：AUTH-V2-BE-STAGING-DEPLOY-VARIANCE-001
- Owner: Backend Deployment Architecture Agent
- Reviewer: Platform Architecture Review Agent
- Execution repo：`.`
- Execution branch：`architecture/auth-v2-be-staging-deploy-variance-001`
- Execution remote: `hub`
- Execution worktree: `wt-auth-v2-be-staging-deploy-variance-001`
- Required upstream: `AUTH-V2-BE-STAGING-DEPLOY-ARCH-001 = DONE / CLOSED_REVIEW_PASS`
- Platform API mode：`NONE`
- SDK public API mode：`READ_ONLY`
- Product adapter rule: `ADAPTER_FIRST`
- Status: `READY`
- Execution gate: `OPEN_ARCHITECTURE_INCIDENT_DISPOSITION`

## Incident

Backend `v0.1.0-rc3@107671bef95c4969f4333c07c78f7d35bfde7227` staging was already deployed on the canonical shared staging runtime with a variance from the mandatory fail-closed deployment contract `AUTH_V2_STAGING_DEPLOYMENT_V1.md`: the pre-mutation `migrate status/verify` gate was omitted before staging mutation. This Story records the one-time Architecture disposition of that already-occurred sequence variance.

## Authorized output

Exactly one Architecture disposition update:

```text
docs/multi_agent/contracts/AUTH_V2_STAGING_DEPLOYMENT_V1.md
```

Nothing else may be mutated by this Story. `docs/releases/0.1.0-rc3.md` and existing FlyPost closure evidence are out of scope for this Story.

## Mandatory forbidden actions

1. Treating post-deploy verification as retroactive proof of the omitted pre-mutation gate.
2. Destructive rollback or replay of the staging runtime.
3. Direct SQL against the staging database.
4. Artificial redeploy solely to manufacture evidence.
5. Reusable or general waivers of the contract sequence.
6. Any Backend/runtime/schema/provider/App/SDK mutation.

## Exit gate

`OPEN_ARCHITECTURE_INCIDENT_DISPOSITION` — the disposition is accepted only after exact Formal + official independent Architecture Review `APPROVED` + merge/post-merge governance. Only then may FlyPost closure evidence cite this disposition. No Backend/runtime/schema/provider/SDK/App mutation is authorized by this Story.

## Scope boundary

- This is a one-time disposition; future deployments keep the original fail-closed gate.
- `AUTH-V2-BE-STAGING-DEPLOY-001` is unchanged.
- This Story does not copy or restate the PR #153 acceptance publication.
