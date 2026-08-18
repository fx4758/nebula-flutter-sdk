# Feedback Provider Aggregation v1

> Story: `FEEDBACK-TXC-AGG-V1-001`
> Status: **FREEZE CANDIDATE**
> Scope: TXC/兔小巢 provider configuration + provider-neutral Admin read aggregation
> Mobile Platform API / SDK ingress: **BLOCKED / OUT OF SCOPE**
> Production implementation authority in this Story: **NONE**

## 1. Decision summary

Feedback Provider Aggregation V1 keeps Tencent TXC as the low-cost China feedback source for NFC Writer while making Nebula Admin the unified operator read surface.

```text
TXC/兔小巢
   |
   | server-side signed pull
   v
Nebula Feedback Provider Adapter
   |
   | normalize + bounded local cache
   v
app_feedback_provider_item
   |
   v
FlyPostBackend thin BFF
   |
   v
Nebula Admin -> Current App -> 用户反馈
```

V1 is deliberately **read/aggregate only**:

- no Mobile feedback submit/entry endpoint;
- no SDK production Feedback client;
- no provider-neutral reply API;
- no migration of FlyPost `user_feedback`;
- no direct browser/App calls to TXC API;
- no `feedback` capability entitlement ID.

TXC remains source-of-origin for TXC feedback. Nebula stores a normalized operational cache, not a replacement community/helpdesk SSOT.

## 2. Fresh canonical facts

### 2.1 FlyPostAPI
Canonical Dev at freeze preflight:

```text
a49397a53708122ef63a664bedec4bc384ce3c46
```

Observed:

- `product_resource_binding` already models App/environment/region -> platform resource binding;
- resource type is server-whitelisted and existence-validated against the resource SSOT model;
- `internal/pkg/secretcrypto` already provides AES-GCM envelope encryption with key versions and previous-key rotation support;
- provider secrets for AI/payment/storage already use ciphertext/nonce/key-version patterns;
- FlyPost `user_feedback` has `app_id`, but its current list/reply behavior is a FlyPost product domain and reply writes `user_notification`;
- current FlyPost feedback list is not scoped by app_id.

Therefore existing `user_feedback` is **not** the common TXC aggregation store.

### 2.2 FlyPostBackend Admin
Canonical unified Admin is the multi-App operator surface. BFF remains a thin signed proxy and MUST NOT store TXC credentials or perform provider calls.

### 2.3 TXC provider API
Current provider documentation/evidence exposes feedback read via:

```text
GET https://txc.qq.com/api/v1/{productId}/posts
Timestamp: <10-digit unix timestamp>
Signature: md5(Timestamp + private_key)
```

Pagination is provider-owned through `next_page_url` / `max_id`, with bounded `count` and optional date window parameters.

This provider wire format is adapter-internal and MUST NOT become an App/SDK/Admin public model.

## 3. Provider resource model

V1 introduces one platform resource type in a later implementation:

```text
feedback_provider
```

It participates in existing `product_resource_binding` rather than placing provider details in `product_config`.

### 3.1 `feedback_provider` conceptual fields

```text
id                     BIGINT PK
provider_type          VARCHAR   // V1: txc
name                   VARCHAR   // operator label
external_product_id    VARCHAR   // TXC product/community ID, non-secret
secret_ciphertext      TEXT      // encrypted provider private key
secret_nonce           VARCHAR
secret_key_version     INT
status                 TINYINT
created_by / updated_by
created_at / updated_at / deleted_at
```

The private key is encrypted/decrypted only with the existing `secretcrypto` envelope. No new crypto/key hierarchy is authorized.

Read APIs return only non-secret provider configuration plus `secret_set: true/false`; they never return ciphertext, nonce, key version or plaintext secret.

### 3.2 Binding semantics

An App selects its provider via:

```text
product_resource_binding
resource_type = feedback_provider
app_id + environment + region_code
```

This is configuration/routing authority for Admin aggregation only. It is **not** a mobile capability entitlement and is not delivered in runtime-config.

For `provider_type=txc`, V1 freezes a **single-App ownership guard**: one active TXC provider resource may not be actively bound to multiple `product_app` IDs. A TXC product/community represents one product feedback space; cross-App sharing risks data leakage.

For one App/environment/region, at most one active feedback provider may be effective in V1. Priority/fallback chains are deferred.

### 3.3 Outbound endpoint policy

TXC base URL is adapter code/config policy, not operator-controlled arbitrary input.

V1 adapter allowlist:

```text
scheme = https
host   = txc.qq.com
```

Admin cannot configure a custom provider URL for `txc`.

## 4. Normalized provider cache

V1 uses a dedicated provider-aggregation cache table. It does not reuse FlyPost `user_feedback`.

Conceptual table:

```text
app_feedback_provider_item
--------------------------
id                       BIGINT PK
app_id                   BIGINT NOT NULL
feedback_provider_id     BIGINT NOT NULL
external_feedback_id     VARCHAR NOT NULL
content                  TEXT NOT NULL
author_display_name      VARCHAR NULL
source_created_at        DATETIME NOT NULL
source_updated_at        DATETIME NULL
has_provider_reply       TINYINT NOT NULL DEFAULT 0
client_info              VARCHAR NULL
client_version           VARCHAR NULL
os                       VARCHAR NULL
os_version               VARCHAR NULL
net_type                 VARCHAR NULL
ingested_at              DATETIME NOT NULL
last_seen_at             DATETIME NOT NULL
```

Required uniqueness/indexing:

```text
UNIQUE(feedback_provider_id, external_feedback_id)
INDEX(app_id, source_created_at DESC)
INDEX(app_id, has_provider_reply, source_created_at DESC)
```

### 4.1 Data minimization

V1 does **not** persist the provider raw JSON blob.

It also does not persist by default:

- TXC `openid` or provider user ID;
- avatar URL;
- arbitrary `customInfo` raw payload;
- provider moderation/community flag sets;
- provider credentials/signatures;
- provider absolute URLs.

Safe version/platform context may be normalized only when provider data exposes it and length/type validation passes.

The normalized cache is an Admin read model, not a user identity store.

### 4.2 No local reply/triage semantics in V1

V1 does not add local `reply`, `internal_note`, `RESOLVED`, or equivalent workflow fields to the provider cache.

For TXC records the only generic reply fact frozen in V1 is:

```text
has_provider_reply: bool
```

This prevents Nebula from pretending that a local state transition delivered a provider reply.

Provider-specific management remains available through a controlled operator deep-link/action where independently safe, or operators continue reply/moderation in TXC.

A future provider-neutral triage/reply workflow is a separate contract.

## 5. Synchronization model

V1 selects **bounded explicit incremental synchronization into the local cache**.

It does not select:

- direct provider fetch on every Admin list request;
- high-frequency always-on polling;
- browser-to-TXC calls;
- unbounded background page walking.

### 5.1 Admin read path

```text
GET Admin feedback list
  -> local app_feedback_provider_item only
```

The read path never calls TXC synchronously. Provider latency/outage therefore does not make ordinary Admin browsing unavailable.

### 5.2 Sync action

A later implementation may expose an Admin-only operation equivalent to:

```text
POST /api/v1/admin/apps/:app_id/feedback/sync
```

It resolves the active `feedback_provider` binding server-side and performs one bounded incremental provider pull.

Minimum safeguards:

- server-side single-flight per provider/App scope;
- minimum interval between successful/attempted operator-triggered syncs;
- provider request timeout;
- provider page count/batch count cap per invocation;
- response body byte cap;
- no provider request executed from BFF/browser;
- no secret or signature in logs/errors.

Recommended initial minimum sync interval: **60 seconds** per provider/App scope. The later implementation may choose a longer default but not a shorter one without review.

### 5.3 Incremental cursor/high-water strategy

TXC remains authoritative for provider pagination. V1 stores only the minimal server sync state needed to resume safely, conceptually:

```text
feedback_provider_sync_state
----------------------------
feedback_provider_id
last_success_at
last_attempt_at
high_water_external_id
backfill_next_page
backfill_from
backfill_to
last_error_code
updated_at
```

For normal incremental sync:

1. fetch the provider first page with a bounded count;
2. upsert unseen records by `(feedback_provider_id, external_feedback_id)`;
3. continue provider pagination only while new/unseen records remain and the per-run page/record cap is not exceeded;
4. stop when the existing high-water boundary is reached or the provider has no next page;
5. advance high-water only after the corresponding local transaction succeeds.

Provider IDs are treated as opaque strings at the adapter boundary even if they appear numeric/monotonic. Correctness must not depend solely on numeric ordering.

### 5.4 Historical import/backfill

Historical import uses the same provider adapter and normalized upsert path, with bounded date windows/provider cursors.

Requirements:

- resumable across runs;
- no delete/reinsert of already imported records;
- persisted continuation state;
- bounded pages/records per invocation;
- explicit operator progress/last-success visibility;
- cancellation/failure leaves the previous committed cursor intact;
- historical import cannot starve normal incremental sync indefinitely.

A single request must not attempt to pull all historical NFC Writer feedback regardless of age/volume.

### 5.5 Scheduling

Automatic scheduled sync is **deferred from V1 implementation minimum**.

The first implementation can deliver manual/explicit bounded sync plus historical backfill. A later scheduler/webhook Story may add near-real-time ingestion after provider webhook semantics, retry ownership, operational budget and deployment model are independently reviewed.

This keeps initial cash/runtime cost and operational complexity low while preserving the path to automation.

## 6. Admin contract boundary

The later implementation uses Admin-only APIs. These are not Mobile Platform APIs and do not unblock the deferred Feedback entry/session ACR.

### 6.1 Provider resource management

Minimum intent:

```text
GET    /api/v1/admin/feedback/providers
POST   /api/v1/admin/feedback/providers
PUT    /api/v1/admin/feedback/providers/:id
DELETE /api/v1/admin/feedback/providers/:id
POST   /api/v1/admin/feedback/providers/:id/test
```

Provider create/update accepts non-secret configuration and an optional plaintext secret input. Plaintext exists only in request memory, is immediately envelope-encrypted, and is never returned.

Read shape exposes at most:

```text
id
provider_type
name
external_product_id
secret_set
status
created_at
updated_at
```

`test` performs a bounded server-side provider check and discards feedback content. It returns connectivity/configuration outcome, never sample post content or provider secret material.

Provider resource management is an App/platform control-plane operation and may reuse the existing `product.manage` authority. V1 does not require exposing a new public Permissions page.

### 6.2 App feedback read/sync

Minimum intent:

```text
GET  /api/v1/admin/apps/:app_id/feedback
GET  /api/v1/admin/apps/:app_id/feedback/provider-status
POST /api/v1/admin/apps/:app_id/feedback/sync
```

All requests resolve current App scope server-side and must verify that the selected provider binding belongs to the requested App/environment/region.

A later implementation may use one dedicated server RBAC code for common App feedback operations if existing permission semantics prove insufficient. It MUST NOT silently reinterpret FlyPost `feedback.manage` as a cross-App permission without an explicit RBAC review.

### 6.3 Normalized Admin item

Provider-neutral Admin response should expose only stable fields such as:

```text
id
app_id
source = external_provider
provider_type           // operator diagnostic only
content
author_display_name?
source_created_at
source_updated_at?
has_provider_reply
client_info?
client_version?
os?
os_version?
net_type?
ingested_at
```

Provider external IDs may be returned only when required for operator diagnostics/deep-linking and must not become an App/SDK contract.

### 6.4 BFF boundary

FlyPostBackend BFF remains thin:

```text
Browser
 -> BFF Cookie -> Backend Admin auth/signature proxy
 -> FlyPostAPI/Nebula Backend
 -> TXC adapter + cache
```

BFF MUST NOT:

- hold TXC product/private-key config;
- generate TXC signatures;
- call TXC directly;
- cache provider feedback;
- decide App/provider mapping;
- parse provider payloads.

## 7. Admin UX placement

Feedback aggregation is a common current-App operational module.

Target:

```text
Current App
  - 接入状态
  - 运行中心
  - 用户反馈     // only after effective feedback provider configuration/binding
```

`用户反馈` is not a FlyPost-only module and is not entitlement-driven.

Provider configuration should surface through App management/integration configuration, using the provider resource + binding model. The App `接入状态` view should state whether a feedback provider is configured and last sync status.

The feedback list displays local normalized cache plus:

- last successful sync time;
- current sync/backfill state;
- explicit `同步` action subject to the server rate/batch limits;
- clear provider-source indicator for operators;
- no fake `回复` button in V1.

If a provider-specific management link is later exposed, its URL pattern must be independently verified and server/generated; Admin must not concatenate an untrusted provider URL from stored/raw payloads.

## 8. TXC adapter security

### 8.1 Signature

The TXC adapter implements the provider-required signature protocol server-side. Use of MD5 here is protocol compatibility, not a Nebula cryptographic primitive and MUST NOT be reused for Nebula authentication/signing.

`Timestamp` is generated server-side at request time. The private key is decrypted only for the outbound call scope and should be cleared/released with the request object as soon as practical.

### 8.2 Network controls

Required:

```text
HTTPS only
fixed/allowlisted txc.qq.com host
redirect policy fail-closed for unexpected host changes
bounded connect/overall timeout
bounded response body
bounded page count and count parameter
no proxying of arbitrary next_page_url host/scheme
```

`next_page_url` returned by TXC is accepted only as a relative path/query matching the expected TXC API path family. Absolute/scheme-relative/unexpected-host values are rejected.

Recommended implementation bounds to freeze in the later detailed contract/tests:

```text
provider count per page <= 100
incremental pages per explicit sync <= 5
connect timeout <= 5s
overall provider request timeout <= 10s
provider response body <= 2 MiB per page
```

Historical backfill may require more total pages, but only across multiple resumable invocations.

### 8.3 Logging/redaction

Logs/metrics may include:

```text
provider_id
app_id
operation
HTTP/provider status category
latency
records read/inserted/updated
cursor/backfill progress category
```

Logs MUST NOT include:

- private key/signature;
- full provider response body;
- feedback content;
- openid/provider user IDs;
- arbitrary customInfo;
- encrypted secret fields.

## 9. Failure and stale-data semantics

Provider sync failure does not delete/blank the existing cache.

Admin list remains available from last successful cache and exposes sync health separately.

Provider-status minimum semantics:

```text
configured
provider_type
last_attempt_at
last_success_at
sync_state       // idle/running/failed/backfill
last_error_class // bounded non-secret category
```

Do not return provider raw error bodies.

A sync invocation fails closed if provider binding/config/secret is invalid. It must not silently fall back to another App's provider or another region.

## 10. Retention and deletion

V1 provider cache is not indefinite raw archival.

Default normalized cache retention target: **365 days**, configurable by deployment/product policy within a reviewed bounded range.

Rules:

- provider data older than active retention may be purged from local cache without deleting the provider-origin record;
- historical backfill outside the effective retention window is skipped unless an explicit reviewed import policy says otherwise;
- disabling/unbinding a provider stops new sync but does not immediately erase cached rows;
- final provider resource deletion requires no active bindings;
- provider secret ciphertext/nonce are cleared/crypto-erased on final provider deletion according to the existing secret-envelope deletion policy;
- cache purge must be App/provider scoped and auditable;
- no raw provider identity fields are retained merely for future speculation.

Provider-side deletion cannot be inferred reliably from omission unless the provider contract explicitly guarantees it; V1 must not automatically hard-delete local rows based only on one missing page/result.

## 11. Separation from FlyPost `user_feedback`

The common provider cache and FlyPost product feedback domain remain separate in V1.

FlyPost `user_feedback` has product-specific semantics:

```text
user_id
FlyPost reply -> user_notification
feedback.manage
FlyPost Admin list/reply lifecycle
```

The TXC aggregation cache has different semantics:

```text
external provider source
no trusted Nebula/FlyPost user identity
read mirror/cache
provider reply fact only
no local reply delivery
provider-specific sync lifecycle
```

Having an `app_id` column in both domains is not sufficient reason to merge them.

V1 forbids migrating FlyPost rows into `app_feedback_provider_item`, serving FlyPost `user_feedback` through common provider endpoints, making TXC records trigger FlyPost `user_notification`, or changing FlyPost `/api/v1/admin/feedback` behavior as part of TXC aggregation.

A future common Native Feedback domain may revisit convergence with an explicit migration/semantics review.

## 12. Cost controls

V1 remains intentionally cheaper than building a full in-house feedback system:

- TXC continues to host the end-user feedback/community experience where it is sufficient;
- Nebula stores only normalized text/context cache, not provider attachments/raw payloads;
- no new dedicated service/container is required by the minimum design;
- no always-on polling daemon is required;
- manual/bounded sync means provider API traffic scales primarily with operator activity/backfill, not App DAU;
- existing MySQL, Admin Backend/BFF, `secretcrypto`, product binding and audit infrastructure are reused.

Operational metrics required from a later implementation:

```text
feedback_provider_sync_requests_total
feedback_provider_sync_failures_total
feedback_provider_records_read_total
feedback_provider_records_upserted_total
feedback_provider_sync_latency
feedback_provider_last_success_age
```

Metrics must be label-bounded; feedback IDs/content/user identifiers are forbidden metric labels.

## 13. Future implementation write sets

This freeze authorizes no writes. After canonical close, Coordinator may register separate implementation Stories.

### 13.1 Backend/provider implementation — `root/FlyPostAPI`

Expected direction:

```text
internal/model/**
  feedback_provider
  app_feedback_provider_item
  provider sync-state

internal/migrations/**
  new provider/cache/sync-state schema

internal/module/admin/**
  provider config CRUD/test
  app feedback list/status/sync
  TXC adapter orchestration/read mapping

internal/module/product/service.go
internal/module/product/repository.go
internal/module/product/*test.go
  feedback_provider whitelist/existence validation

internal/pkg/secretcrypto/**
  REUSE ONLY

internal/router/admin_contract_test.go
existing Admin registration seam
  Admin routes only; no Mobile route
```

The implementation should stay inside existing `admin` aggregation + `product` control-plane architecture instead of creating a new unclassified core domain solely for this read-only provider integration. If a new package/domain is mechanically required, architecture ownership must be separately authorized.

### 13.2 Admin/BFF implementation — `root/FlyPostBackend`

Expected direction:

```text
internal/module/admin/**
  thin proxy routes/handlers only

admin/src/api/index.ts
admin/src/views/AppFeedbackView.vue           NEW
admin/src/views/AppIntegrationView.vue        provider readiness/status
admin/src/router/index.ts
admin/src/modules/registry.ts
admin/src/views/ProductsView.vue or equivalent App integration configuration
```

BFF remains provider-blind/thin beyond routing the Admin request to Backend.

### 13.3 Explicitly not in those implementation Stories

```text
Nebula SDK lib/**
Mobile Platform feedback endpoint
NFC Writer App Help route
Native provider submit
provider-neutral reply
attachments
scheduled/webhook ingestion daemon
FlyPost user_feedback migration
```

## 14. Implementation verification obligations

A later Backend implementation must cover at least:

1. provider secret encrypted at rest; plaintext never returned on read;
2. secret rotation/update leaves no plaintext DB column;
3. TXC signature generated only server-side;
4. outbound host/scheme fixed/allowlisted and redirect SSRF tests;
5. `next_page_url` absolute/scheme-relative/foreign-host rejection;
6. provider response byte/page/count bounds;
7. App A cannot read/sync App B provider/cache;
8. TXC provider resource cannot be actively shared across two Apps;
9. product resource binding existence/delete guards include `feedback_provider`;
10. incremental sync idempotency on duplicate external IDs;
11. transaction failure does not advance high-water cursor;
12. concurrent sync single-flight/rate-bound behavior;
13. provider outage retains prior cache and exposes bounded failure state;
14. raw openid/avatar/customInfo/provider body not persisted/logged;
15. historical backfill resumability;
16. local Admin list never performs synchronous TXC network I/O;
17. no FlyPost `user_feedback`/`user_notification` drift;
18. no Mobile route added;
19. migration rerun/schema conventions PASS;
20. ArchGuard/Sentinel/secret scan/full Go tests PASS.

A later Admin implementation must verify:

1. `用户反馈` hidden when no effective provider binding;
2. App Integration explains provider-unconfigured state;
3. configured App shows normalized cached feedback only for current app_id;
4. explicit sync respects loading/cooldown/error state;
5. secret input is write-only and cleared after submit;
6. no provider credential/provider API call in browser/BFF;
7. no fake reply CTA in V1;
8. switching Apps cannot leak previous App feedback/provider state;
9. Vue typecheck/build/secret guards PASS.

## 15. Deferred

Not part of Aggregation V1:

```text
TXC webhook ingestion
scheduled automatic polling
provider fallback chains
Native feedback storage/submit
provider-neutral user reply
attachments/media
public voting/community/roadmap
AI classification/summarization
cross-provider dedup
cross-App feedback analytics
export/data warehouse pipeline
```

These may be added only from real product/operational evidence.

## 16. Freeze disposition

```text
FEEDBACK_PROVIDER_AGGREGATION_V1
========================================
Provider source:
TXC / 兔小巢 (V1)

End-user TXC experience:
KEPT

Nebula Admin operator view:
NORMALIZED LOCAL CACHE

Provider config:
feedback_provider resource
+ product_resource_binding

Secret storage:
existing secretcrypto AES-GCM envelope

Sync:
explicit bounded incremental + resumable backfill

Always-on polling:
NO

FlyPost user_feedback reuse:
NO

Generic reply:
NO

Mobile Platform API:
UNCHANGED / BLOCKED

SDK/App ingress:
UNCHANGED / BLOCKED

feedback capability entitlement ID:
NO
```

This is a **FREEZE CANDIDATE** only. It becomes canonical after exact independent Provider/Architecture Review, merge and Coordinator closure. No production, schema or provider credential mutation is authorized by this document alone.
