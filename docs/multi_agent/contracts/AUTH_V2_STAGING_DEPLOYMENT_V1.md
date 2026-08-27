# AUTH V2 Shared Staging Deployment V1

Status: **FROZEN CANDIDATE — architecture review required**

Story: `AUTH-V2-BE-STAGING-DEPLOY-ARCH-001`

## 1. Purpose and authorities

This contract governs the next Backend release candidate and its deployment to the single shared TEST/staging runtime. It exists because Auth V2 code is canonical but staging still runs Backend `v0.1.0-rc2`.

Frozen current authorities:

```text
Nebula governance base   main@23a9066bb6f2cd332335dba90e076b3047041045
Backend release base     Dev@bcd93b51aa2b2d479057e2e6b260ee9aab067353
Current staging release  v0.1.0-rc2@6d2ddd3a6c626b7918b29da6e92e13684bc3ef7a
Current staging image    nebula-backend-api:0.1.0-rc2
Current image artifact   sha256:9ff892f5080427665dd123fd479ab11dbd6e04a3f6d043a5fe6aabc6f63cee5e
Compose project          staging
API service              staging-api
Network                  staging_backend
Public TEST origin       https://testapi.nfcwriter.top22.top
```

`v0.1.0-rc1` and `v0.1.0-rc2` are immutable and MUST NOT be retargeted.

## 2. RC3 release identity

The next shared-staging candidate is frozen as:

```text
release identity   v0.1.0-rc3
release branch     release/backend-v0.1.0-rc3
release base       bcd93b51aa2b2d479057e2e6b260ee9aab067353
```

At architecture freeze time `v0.1.0-rc3` does not exist. RC3 MUST contain exactly the production/schema/config tree of the frozen release base plus a docs-only release-evidence commit. Later `Dev` commits do not enter RC3; they require a later release identity.

The release-evidence commit may add only:

```text
docs/releases/0.1.0-rc3.md
docs/evidence/AUTH-V2-BE-STAGING-DEPLOY-001/**
```

Its production/schema/config delta from `bcd93b51...` MUST be zero. The exact release commit requires PR CI and official independent review before tag publication. Tag `v0.1.0-rc3` MUST point to that exact reviewed release commit and is immutable thereafter.

## 3. Why direct Dev deployment is forbidden

The rc2 -> frozen RC3 base delta is approximately 45 files / +5.3k lines and includes feedback-provider aggregation, migrations 048/049, Mobile Auth V2, Product deployment operator work and configuration changes. Mutable `Dev` is therefore not a deployment identity.

## 4. Migration authority and rehearsal

Fresh staging ledger at freeze time:

```text
schema_migration rows    47
last applied             047_mobile_observability_v1.sql
failed rows              0
048 applied              no
049 applied              no
```

For RC3, `migrate verify` against a clone/rehearsal of the current staging schema MUST pass and `migrate status/plan` MUST show exactly these pending migrations, in order:

```text
048_feedback_provider_aggregation_v1.sql
049_mobile_auth_v2.sql
```

Any additional pending migration, missing historical row, failed row, checksum mismatch or different ordering is a STOP condition.

Migration 049 contains a fail-closed legacy-data preflight and conditional widening/collation changes. Rehearsal MUST use a disposable MySQL instance restored from a sanitized schema/data-compatible staging snapshot or an equivalent mechanically proven fixture. A preflight failure MUST stop the release; no direct SQL repair is authorized by this Story.

## 5. Build and artifact provenance

Staging is runtime-only. Building or compiling on the staging host is forbidden.

RC3 image build MUST run on an authorized build/CI node from the exact immutable RC3 tag/commit. Evidence MUST record:

```text
tag / exact commit
builder identity
GOOS/GOARCH and toolchain versions
Dockerfile exact digest
image repository:tag
image ID / content digest
exported artifact SHA-256 if an image archive is transferred
```

The staging host MUST verify the transferred artifact/image digest before load/use. No mutable `latest` tag is allowed.

## 6. Compatibility gates before deployment

The exact RC3 candidate MUST pass normal FlyPostAPI PR gates and full `go test ./...`, plus migration rehearsal. In addition, a pre-deploy compatibility matrix MUST prove the existing shared consumers remain valid:

- `POST /api/v1/mobile/bootstrap`;
- InstallationProof positive and fail-closed negative cases;
- `GET /api/v1/mobile/runtime-config` with canonical proof V1;
- analytics batch ingress;
- mobile error-report ingress;
- legacy mobile auth/refresh/logout behavior that rc2 already serves;
- existing Admin/BFF route contract and health surface;
- Product App/read paths used by current deployments.

The test must compare response status/code semantics against rc2 baselines for unchanged surfaces. A route removal, auth downgrade/fallback, changed proof canonicalization or incompatible response contract is a STOP condition.

## 7. Auth V2 capability gate

RC3 may expose the already-reviewed Auth V2 code paths, but provider/email deployment configuration remains separately gated.

At initial RC3 staging deployment:

```text
Nearvia app_id                  351164732780056576
Backend per-App OAuth binding   disabled / not ready
email enabled                   false unless separately authorized
Apple/Google credentials        absent from this Story
```

Capability smoke MUST prove the new Auth V2 routes are mounted and fail closed when required provider/email configuration is absent. It MUST NOT fabricate provider client IDs, secrets, authorization codes or SMTP credentials.

This deployment can set `staging_auth_v2_runtime_ready=true` only for code/runtime capability. It MUST leave `backend_provider_binding_ready=false` until a later independently reviewed provider-binding Story succeeds.

## 8. Canonical staging mutation sequence

Before mutation on the TEST node:

1. read `/home/ubuntu/AGENTS.md`;
2. run `agent-selftest`;
3. run `agent-inventory` and read `resource-registry.json`;
4. run `agent-preflight --intent deploy` for the execution Story;
5. require exactly one Compose project named `staging` and the registered `staging-api`, `staging-mysql`, `staging-valkey`, `staging-admin-bff`, `staging-nginx` resources;
6. acquire the exclusive `deploy` lease;
7. verify rc2 current image/source and RC3 artifact digest;
8. run migration `verify/status` before migration;
9. apply migrations only with the reviewed migration binary/tooling;
10. replace only the existing `staging-api` image/service definition as frozen by execution evidence; do not create a second API service;
11. wait for health, then run compatibility + Auth V2 capability smokes;
12. run post-deploy inventory and `agent-drift-check`;
13. reconcile the existing resource registry evidence;
14. release the deploy lease.

Any failure after lease acquisition must stop further mutations and preserve diagnostics without leaking secrets.

## 9. Rollback semantics

Migrations 048/049 are forward migrations; this Story does not authorize destructive schema rollback.

Before deployment, the execution candidate MUST mechanically prove whether the rc2 API binary/image remains compatible with the post-048/049 schema. Only if that compatibility smoke passes may the rc2 image be retained as an emergency service rollback target.

If backward compatibility is not proven, deployment is **no-go** until a separately reviewed rollback/fix-forward plan exists. Never claim "rollback available" solely because the old image exists.

A failed migration 049 preflight occurs before accepted deployment and is a no-go, not a condition to bypass with direct SQL.

## 10. Release and merge authority

The RC3 release-evidence PR must freeze exact commit identity and receive:

- FlyPostAPI Migrations SUCCESS;
- Quality Baseline backend/go-sdk/dart-sdk SUCCESS;
- focused migration rehearsal/compatibility evidence;
- official exact-head independent review with `stale=false`.

Only then may the immutable `v0.1.0-rc3` tag be created on that reviewed exact commit and the image be built. Tag creation, image build, staging deployment and Task Board closure are Coordinator/release-chain actions, not reviewer actions.

## 11. Explicit exclusions

This contract does not authorize:

- Apple/Google console registration or public-client invention;
- provider private key/client secret material;
- Backend per-App Apple/Google binding;
- SMTP production credentials;
- Nearvia App OAuth acquisition code;
- PHONE/SMS changes;
- production API/domain decisions;
- Nebula SDK mutation;
- Nearvia/NFC Writer App mutation;
- unrelated new Backend feature work;
- direct SQL migration repair;
- a second staging environment.

## 12. Execution unlock contract

After this architecture contract is independently accepted and merged, Coordinator may open `AUTH-V2-BE-STAGING-DEPLOY-001` only with an exact publication that:

- closes this Architecture Story;
- keeps Backend production-code mutation false;
- authorizes only RC3 release/evidence paths required by this contract;
- sets `staging_deployment_authorized=true` only for the execution Story;
- pins release base `bcd93b51aa2b2d479057e2e6b260ee9aab067353` and release identity `v0.1.0-rc3`;
- leaves all provider configuration/credential/App/SDK flags false.

Any code corrective discovered during release rehearsal requires a separate corrective authorization and a new reviewed exact candidate before RC3 publication.
