# AUTH-V2-BE-STAGING-DEPLOY-001 — Staging Sequence Variance Acceptance

## Decision status

**PROPOSED ONE-TIME GOVERNANCE ACCEPTANCE — EFFECTIVE ONLY AFTER THIS EXACT PUBLICATION RECEIVES OFFICIAL INDEPENDENT REVIEW APPROVAL AND IS MERGED TO CANONICAL `main`.**

This publication addresses FlyPostAPI closure Review #630 on exact candidate `85ae77a2a3cdf1a12e45fa6d554964fb8ddd6cc8`. It does not rewrite the deployment history and does not claim that `AUTH_V2_STAGING_DEPLOYMENT_V1` §8 was followed in exact order.

## Recorded deviation

The frozen contract requires, before staging mutation:

```text
...
8. run migration verify/status before migration;
9. apply migrations only with reviewed migration tooling;
10. replace only the existing staging-api ...
```

Actual RC3 execution had fresh pre-release staging evidence showing 47 successful migrations ending at 047 plus disposable rehearsal/compatibility proof, but it did **not** rerun staging `cmd/migrate status/verify` immediately before starting RC3. The existing RC3 startup migration path then applied 048/049. Exact RC3 `cmd/migrate status` and `verify` were run after deployment and passed.

Therefore this is a real mandatory-sequence deviation. Post-deploy verification is not treated as retroactive proof that the pre-mutation step occurred.

## Mechanical facts after the deviation

The following already-completed evidence reduces remediation risk but does not erase the deviation:

- immutable release `v0.1.0-rc3` source commit `107671bef95c4969f4333c07c78f7d35bfde7227`;
- exact deployed image `sha256:9c2838c8cf94deb7b1973e717cbc2960e90ccd98f52d14495027d87cec0ad25f`;
- migration ledger through 049 with `failed=0`;
- exact RC3 migration tool reports `Pending:` empty and `verify: all applied checksums match`;
- `/health` HTTP 200 with non-degraded jobs;
- Nearvia mobile bootstrap and ES256 Proof V1 runtime-config PASS;
- missing proof and legacy literal `1` fail closed with code `12001`;
- EMAIL disabled and Google unbound fail closed with code `12004`;
- analytics and error-report ingress PASS;
- post-deploy inventory shows one canonical Compose project `staging`;
- post-deploy drift check reports `ok=true`, `issues=[]`, `warnings=[]`;
- RC2 service-image compatibility against post-049 schema was proven before deployment; schema rollback is not claimed.

No evidence indicates a schema checksum mismatch, partial migration, second runtime, provider secret activation, or runtime drift.

## Architecture / Coordinator disposition

If this exact publication is independently APPROVED and merged, the governing disposition is:

```text
This single RC3 execution-sequence variance: ACCEPTED FOR CLOSURE
Rollback / redeploy solely to recreate ordering evidence: NOT REQUIRED
Schema rollback: NOT AUTHORIZED / NOT REQUIRED
Provider binding expansion: NOT AUTHORIZED
Future §8 sequence requirement: UNCHANGED AND MANDATORY
```

Rationale: rollback or redeploy would not reconstruct the missing pre-mutation observation; it would add new runtime mutation after exact migration/state verification has already proven the applied state consistent. The safer governance correction is to preserve the real history, independently accept or reject this one-time variance, and keep the original fail-closed rule unchanged for every later deployment.

This is **not** a blanket waiver. It applies only to `AUTH-V2-BE-STAGING-DEPLOY-001` / RC3 deployment on 2026-08-27 and only to the missing immediate pre-start staging CLI `status/verify` repetition. It does not waive migration rehearsal, checksum verification, single-runtime rules, exact release provenance, independent review, or provider fail-closed requirements.

## Mandatory future control

`AUTH_V2_STAGING_DEPLOYMENT_V1` remains byte-for-byte unchanged by this publication. For every future governed staging deployment under this contract or a descendant contract, evidence must capture immediately before mutation:

```text
exact migration tool identity
status
verify
pending migration list
current migration ledger state
```

A future omission remains a STOP condition and cannot cite this RC3 acceptance as precedent for skipping the step.

## Closure gate after acceptance

Only after this exact variance publication is independently APPROVED and merged may FlyPostAPI PR #27 be corrected to cite the canonical variance decision. PR #27 must then rerun exact CI and independent exact-head review.

Task Board `AUTH-V2-BE-STAGING-DEPLOY-001` must remain not-DONE until that FlyPostAPI closure candidate is APPROVED, merged, descendant CI is green, and the final Coordinator closure publication is independently reviewed.
