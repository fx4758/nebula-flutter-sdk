# FEEDBACK-TXC-AGG-BE-V1-001 Backend TXC Aggregation Implementation
- ID：FEEDBACK-TXC-AGG-BE-V1-001
- Owner：Backend Feedback Provider Agent
- Execution repo：`../flypost_backend` (`root/FlyPostAPI`)
- Execution branch：`feedback/txc-agg-be-v1-001`
- Execution remote：`origin`
- Platform Mobile API mode：`READ_ONLY / NO CHANGE`
- Admin API mode：`IMPLEMENT_FROZEN_CONTRACT`
- SDK public API mode：`NONE`
- Required upstream：`FEEDBACK-TXC-AGG-V1-001 = DONE / REVIEW PASS`
- Contract authority：`docs/multi_agent/contracts/FEEDBACK_PROVIDER_AGGREGATION_V1.md`

## Fresh-base rule
Registration-time canonical FlyPostAPI Dev is `a49397a53708122ef63a664bedec4bc384ce3c46` and open PR #8 is docs-only I18N work.

Execution MUST first fresh-fetch `origin/Dev` and use the exact fresh SHA. Do not build on the dirty main working tree. Create a dedicated worktree from fresh `origin/Dev`. If Dev has advanced, mechanically reconcile migration numbering/write-path overlap before mutation; never reset canonical Dev.

## Authorized implementation
Implement the frozen TXC provider aggregation Backend/Admin API only.

### Schema
Expected next migration if still free at execution time:

```text
internal/migrations/048_feedback_provider_aggregation_v1.sql
```

The migration may create only the reviewed V1 structures:

```text
feedback_provider
app_feedback_provider_item
feedback_provider_sync_state
```

If migration number 048 is occupied on fresh Dev, choose the next free number and record the reason; do not renumber canonical migrations.

### Models
Allowed new model file(s) under `internal/model/**` for exactly the three structures above.

### Admin aggregation/provider implementation
Allowed paths:

```text
internal/module/admin/**
```

Only for:

- feedback provider CRUD/test;
- server-side TXC read adapter;
- normalized App feedback list/provider-status;
- explicit bounded incremental sync/backfill state;
- provider secret envelope use through existing `secretcrypto`;
- focused tests.

No Mobile/user Feedback route may be added.

### Product resource binding
Allowed serial-owned paths:

```text
internal/module/product/service.go
internal/module/product/repository.go
internal/module/product/service_test.go
internal/module/product/repository_test.go   if already present/needed
```

Only to:

- whitelist `feedback_provider`;
- map resource existence to the new SSOT model;
- enforce the reviewed TXC single-App active-binding rule;
- preserve existing binding/delete/audit behavior.

### Router/contract
Allowed:

```text
internal/router/admin_contract_test.go
internal/router/router.go                    only if the existing Admin registration seam mechanically requires it
```

Prefer extending existing `adminH.RegisterConsole` / Admin module registration. Do not create a new Mobile route group.

### Secret crypto

```text
internal/pkg/secretcrypto/** = REUSE ONLY
```

No crypto semantic changes are authorized.

## Frozen behavior
- TXC provider host is fixed/allowlisted `https://txc.qq.com`.
- Signature is generated server-side from provider-required Timestamp + decrypted private key; never log it.
- Provider secret is encrypted at rest and never returned by read APIs.
- One active TXC provider resource cannot be bound to two different Apps.
- Admin feedback list reads local normalized cache only; it never performs synchronous TXC I/O.
- Explicit sync is single-flight/rate/batch/timeout/response-size bounded.
- `next_page_url` is treated as untrusted; only expected relative TXC API path/query is accepted.
- Upsert idempotency key is `(feedback_provider_id, external_feedback_id)`.
- High-water/backfill cursor advances only after local persistence succeeds.
- Provider failure preserves stale cache and bounded sync error state.
- Do not persist raw provider JSON, openid/provider user ID, avatar URL, arbitrary customInfo, secret/signature.
- Do not reuse/migrate/change FlyPost `user_feedback` or `user_notification` semantics.
- No generic reply endpoint/action.
- No automatic polling/webhook daemon.
- No `feedback` capability entitlement ID.

## Admin API intent
Implementation may add the frozen Admin-only routes equivalent to:

```text
GET    /api/v1/admin/feedback/providers
POST   /api/v1/admin/feedback/providers
PUT    /api/v1/admin/feedback/providers/:id
DELETE /api/v1/admin/feedback/providers/:id
POST   /api/v1/admin/feedback/providers/:id/test

GET    /api/v1/admin/apps/:app_id/feedback
GET    /api/v1/admin/apps/:app_id/feedback/provider-status
POST   /api/v1/admin/apps/:app_id/feedback/sync
```

Use existing Admin auth/RBAC. Provider resource management may use `product.manage`. Do not silently redefine FlyPost `feedback.manage` as a common cross-App permission. If a new RBAC code proves mechanically required, STOP and return for Architecture review rather than expanding scope.

## Hard limits to implement/test
At minimum:

```text
TXC page count parameter <= 100
incremental pages per explicit sync <= 5
connect timeout <= 5s
overall provider request timeout <= 10s
provider response body <= 2 MiB/page
minimum sync interval >= 60s/provider-App scope
```

Backfill is resumable across bounded invocations and may not pull all history in one request.

## Forbidden
- SDK/App/BFF/Admin Vue mutation.
- Mobile Platform route/contract/schema change.
- NFC Writer mutation.
- Native provider implementation.
- generic reply/attachment/community features.
- automatic scheduled polling/webhook service.
- new Docker/service/daemon.
- `architecture.yaml` mutation by implementation Agent.
- secretcrypto algorithm/key hierarchy mutation.
- provider credentials in repo/tests/logs.
- task board state writes by implementation Agent.

## Required verification
- focused provider CRUD/secret tests;
- resource binding whitelist/existence/single-App guard tests;
- TXC signature/host/redirect/next-page/timeout/body/page bounds tests with fake HTTP server/transport, no real provider secret;
- normalized mapping/data-minimization tests;
- sync idempotency/cursor transaction/concurrency/cooldown/stale-cache tests;
- historical backfill resumability tests;
- FlyPost feedback non-regression tests;
- Admin route contract tests;
- migration schema/rerun tests;
- `go test ./...` PASS;
- ArchGuard/Sentinel PASS;
- secret scan PASS;
- exact PR CI PASS;
- independent Backend/Architecture Review on exact candidate.

## Exit
Deliver only to `READY_FOR_REVIEW`. No self-merge and no DONE. Admin Vue/BFF implementation remains a separate Story after Backend canonical merge.
