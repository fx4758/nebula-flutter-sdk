# AUTH-V2-BE-STAGING-DEPLOY-ARCH-001 — Shared Staging Auth V2 Deployment Freeze

- ID：AUTH-V2-BE-STAGING-DEPLOY-ARCH-001
- Owner: Backend Deployment Architecture Agent
- Reviewer: Platform Architecture Review Agent
- Execution repo：`.`
- Execution branch：`architecture/auth-v2-be-staging-deploy-arch-001`
- Execution remote: `hub`
- Execution worktree: `wt-auth-v2-be-staging-deploy-arch-001`
- Required upstream: `AUTH-V2-BE-001 = DONE / CLOSED_REVIEW_PASS`
- Platform API mode：`NONE`
- SDK public API mode：`READ_ONLY`
- Product adapter rule: `ADAPTER_FIRST`

## Problem statement

Shared TEST/staging still runs immutable Backend `v0.1.0-rc2` source `6d2ddd3a6c626b7918b29da6e92e13684bc3ef7a`; canonical Backend Dev has advanced to `bcd93b51aa2b2d479057e2e6b260ee9aab067353`. The delta is not Auth-only: it contains migrations, feedback-provider aggregation, Mobile Auth V2, product deployment operator work and config changes. Direct deployment of mutable Dev is forbidden.

## Architecture output

Freeze exactly:

```text
docs/multi_agent/contracts/AUTH_V2_STAGING_DEPLOYMENT_V1.md
```

The contract must define fail-closed:

1. immutable release-candidate identity; never retarget `v0.1.0-rc2`;
2. exact source/candidate authority and release-evidence review chain;
3. build outside staging; staging is runtime-only;
4. image/artifact digest provenance;
5. migration rehearsal from current rc2 schema state before staging mutation;
6. handling of migrations `048_feedback_provider_aggregation_v1.sql` and `049_mobile_auth_v2.sql`, including Auth V2 preflight failure;
7. backward-compatibility smoke for mobile bootstrap, InstallationProof, runtime-config, analytics/error-reporting and existing admin/BFF contract;
8. Auth V2 capability smoke with provider/email bindings still disabled unless separately authorized;
9. one canonical Compose project `staging`; no duplicate service/database/environment;
10. remote governance: inventory -> registry -> preflight -> deploy lease -> mutation -> health/smoke -> drift-check -> release;
11. rollback semantics that do not pretend forward-only schema rollback exists; image rollback only when migrated schema backward-compatibility is mechanically proven;
12. fail-closed stop conditions for migration incompatibility, route/proof/runtime-config regression, health failure, resource drift or stale source;
13. no Apple/Google provider IDs/secrets, Nearvia OAuth App code, production origin, SDK/App mutation.

## Authorized write set

```text
docs/multi_agent/contracts/AUTH_V2_STAGING_DEPLOYMENT_V1.md
```

No Backend/runtime/App/SDK mutation is authorized by this Architecture Story.

## Accepted closure

Architecture is **DONE / CLOSED_REVIEW_PASS**. Contract `AUTH_V2_STAGING_DEPLOYMENT_V1.md` is accepted by PR #149 exact `9ccb6c64984ae64abbf850f474920c17661959d5`, Review #611 `APPROVED / official=true / stale=false`, merge `075998ee561bc08bf5e11c3492c0ef7dfb809754`, descendant governance `SUCCESS`. No architecture mutation remains authorized by this closed Story.
