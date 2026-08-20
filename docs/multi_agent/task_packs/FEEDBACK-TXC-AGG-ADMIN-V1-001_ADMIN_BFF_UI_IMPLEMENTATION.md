# FEEDBACK-TXC-AGG-ADMIN-V1-001 Admin BFF/UI Aggregation Implementation
- ID：FEEDBACK-TXC-AGG-ADMIN-V1-001
- Owner：Admin Feedback Aggregation Agent
- Execution repo：`../flypost_admin_platform` (`root/FlyPostBackend`)
- Execution branch：`feedback/txc-agg-admin-v1-001`
- Execution remote：`origin`
- Platform Mobile API mode：`READ_ONLY / NO CHANGE`
- Backend Admin API mode：`READ_ONLY CONSUMER OF FROZEN CONTRACT`
- SDK public API mode：`NONE`
- Required upstream：`FEEDBACK-TXC-AGG-BE-V1-001 = DONE / REVIEW PASS / CLOSED_REVIEW_PASS`
- Contract authority：`docs/multi_agent/contracts/FEEDBACK_PROVIDER_AGGREGATION_V1.md`

## Fresh-base rule
Registration-time canonical `root/FlyPostBackend` `Dev` is `dcffff58a1a76a393ebff0fa475c4141b25e65a8`.
Execution MUST fresh-fetch `Dev`, create a dedicated clean worktree/clone and confirm exact SHA before mutation. Do not reuse stale/dirty `flypost_server` or unrelated Admin worktrees.

## Goal
Expose the already-canonical TXC aggregation Backend contract through the existing thin BFF and Ant Design Vue multi-App console.

For the selected App:
- show `用户反馈` only when an effective `feedback_provider` binding exists for the current environment/region;
- show normalized cached feedback only for the selected `app_id`;
- show provider readiness/sync state in `接入状态`;
- allow bounded explicit sync with loading/cooldown/error state;
- provide platform operator management for `feedback_provider` resources, with secret input write-only;
- keep FlyPost `/feedback` + reply lifecycle separate and unchanged.

## Authorized write set
BFF only:
```text
internal/module/admin/routes.go
internal/module/admin/handler_*.go
internal/module/admin/*test.go
```
Admin SPA only:
```text
admin/src/api/index.ts
admin/src/views/AppFeedbackView.vue
admin/src/views/AppIntegrationView.vue
admin/src/views/ProductsView.vue
admin/src/router/index.ts
admin/src/modules/registry.ts
admin/src/store/app.ts
admin/src/layout/AdminLayout.vue
```
No other production path is authorized without Coordinator/Architecture review.

## Frozen BFF routes
Proxy same-path only:
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
BFF remains provider-blind: no TXC host/signature/private-key logic, no provider calls, no DB/RBAC/JWT interpretation.

## UI requirements
- `用户反馈` is a common App menu, not FlyPost product menu.
- It appears only when provider-status for current App/environment/region says `configured=true`.
- Direct `/app-feedback` when unconfigured fails closed to `/app-integration`.
- Switching Apps/regions clears previous provider readiness/rows before loading new scope.
- Do not create a `feedback` capability entitlement ID.
- `接入状态` shows configured/provider_type/sync_state/last_success_at/bounded error class.
- Unconfigured state explains create provider + bind `resource_type=feedback_provider`.
- Secret is write-only; never read back/render/cache/log; read shape uses only `secret_set`.
- V1 provider type is `txc`; no arbitrary base URL.
- Feedback page reads normalized cache only; no reply/resolve/community/attachment CTA.
- Explicit sync calls Backend sync endpoint only; provider outage preserves displayed cached rows.

## Forbidden
- FlyPostAPI mutation.
- Nebula SDK/App/NFC Writer mutation.
- Mobile Feedback endpoint/session.
- TXC browser/BFF direct call or credential exposure.
- Native provider, generic reply/triage/attachments/community, polling/webhook daemon.
- FlyPost `FeedbackView.vue` semantics or `/feedback/:id/reply` mutation.
- new capability ID.
- task board mutation by implementation Agent.

## Required verification
- all 8 BFF routes and forwarding tests;
- no provider hostname/secret/signature logic in BFF/browser;
- unconfigured hide + route fail-closed;
- configured App current-app-only cache;
- App/region switch isolation;
- sync loading/cooldown/error handling;
- secret write-only/cleared after submit;
- FlyPost Feedback non-regression;
- `go test ./...`, `vue-tsc --noEmit`, Vite production build, Element residue 0, secret guards, exact PR CI;
- independent Admin/Architecture Review on exact candidate.

## Exit
Deliver only to `READY_FOR_REVIEW`. No self-merge and no DONE. Mobile/SDK/NFC Writer provider-neutral integration remains blocked by `FEEDBACK-PLATFORM-ACR-V1-001 = DEFERRED_SECOND_CONSUMER_INSUFFICIENT` until explicitly reopened.
