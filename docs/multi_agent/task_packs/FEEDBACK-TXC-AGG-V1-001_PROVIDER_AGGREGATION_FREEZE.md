# FEEDBACK-TXC-AGG-V1-001 TXC Provider Aggregation Freeze
- ID：FEEDBACK-TXC-AGG-V1-001
- Owner：Feedback Provider Architecture Agent
- Execution repo：`.`
- Execution branch：`feedback/txc-agg-v1-001-provider-aggregation-freeze`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`READ_ONLY`
- Governance state：provider/admin aggregation contract freeze only; no production mutation.
- Upstream：`FEEDBACK-ARCH-V1-001 = DONE / REVIEW PASS`; `FEEDBACK-PLATFORM-ACR-V1-001 = DONE / DEFERRED_SECOND_CONSUMER_INSUFFICIENT`.

## Purpose
Freeze the low-cost path that remains legal while the new Mobile Feedback entry/session contract is blocked: keep Tencent TXC/兔小巢 as NFC Writer China provider and normalize its feedback into the Nebula multi-App Admin control plane without exposing TXC to product code or converting FlyPost-specific feedback storage/reply semantics into a fake Platform contract.

This Story does **not** unblock SDK or Mobile Feedback ingress.

## Required output
Create exactly one contract:

- `docs/multi_agent/contracts/FEEDBACK_PROVIDER_AGGREGATION_V1.md`

## Mandatory decisions
The freeze MUST mechanically decide:

1. Provider-neutral Admin read model for feedback records scoped by current `product_app/app_id`.
2. TXC read contract based on the documented provider API (`GET /api/v1/{productId}/posts`, Timestamp + server-side Signature, cursor/max_id/count/date semantics), without making TXC wire format canonical.
3. TXC product/community ID and private key storage boundary. Secrets MUST remain server-side and MUST NOT be placed in SDK/App/runtime-config/plain product config.
4. App-to-provider mapping authority: how one `product_app` selects/configures a feedback provider without adding a public `feedback` capability entitlement ID.
5. Whether V1 should proxy/read TXC on demand, incrementally ingest/cache, or persist normalized records; select one low-cost operational model and justify it.
6. If persistence is selected, whether existing FlyPost `user_feedback` is suitable. It MUST NOT be reused merely because it has `app_id`; FlyPost reply/status/user_notification semantics must be mechanically compared.
7. Stable provider-neutral normalized fields, including internal provider source/external ID, app scope, content, author/contact availability, timestamps, client/version metadata, processing state and provider metadata boundaries.
8. Dedup/idempotency and cursor strategy for incremental ingestion.
9. Data retention and deletion behavior, including provider-origin data and normalized copies/cache.
10. Provider outage/rate-limit behavior: Admin must fail/read stale deterministically without causing high-frequency provider polling or operator-triggered amplification.
11. Reply boundary: TXC read API does not prove a generic reply-write API. V1 must not report a reply as delivered unless a real provider/native write path exists; deep-link/provider management may remain necessary.
12. Historical import strategy for existing NFC Writer TXC feedback, including bounded pagination and resumability.
13. Admin placement: common current-App `用户反馈`, not FlyPost-only feedback menu, when a feedback provider is configured.
14. Separation from existing FlyPost feedback domain: preserve FlyPost product behavior; do not silently migrate or merge it into common Feedback in this Story.
15. Security: provider secret rotation, outbound hostname allowlist/TLS, signature construction server-side, response-size limits, timeout/backoff, log redaction.
16. Cost controls: no always-on aggressive polling, bounded sync batch/window, provider API calls observable, default low-frequency/incremental strategy.
17. Exact future implementation write sets for Backend/provider adapter, Admin BFF/UI and any schema/migration work; no implementation authority in this Story.

## Existing facts to verify fresh
- `root/FlyPostAPI` canonical has `user_feedback` with `app_id`, but its Admin list/reply semantics are FlyPost-specific and current list is not app-scoped.
- `root/FlyPostBackend` unified Admin is the multi-App operator surface.
- NFC Writer active `product_app` is `nfc_writer` in TEST; provider credentials are not currently registered in Nebula.
- TXC provider API/read semantics must be taken from the current provider documentation/evidence, never guessed from stale integrations.

## Forbidden
- Any `lib/**` SDK mutation.
- Any Mobile Platform endpoint/contract change.
- NFC Writer/App mutation.
- TXC credential access or printing in this Story.
- Backend/BFF/Admin production mutation.
- DB migration/schema mutation.
- Adding `feedback` capability entitlement ID.
- Reusing `user_feedback` as common storage without explicit reviewed proof.
- Implementing a reply/write adapter from an unverified provider API.
- Task Board mutation by execution Agent.

## Verification
- docs-only diff;
- `git diff --check` PASS;
- exact fresh canonical cross-repo evidence;
- secret/provider/product-name erasure from App/SDK boundary;
- independent Provider/Architecture Review PASS.

## Exit
After canonical `DONE / REVIEW PASS`, Coordinator may separately register implementation Stories for the reviewed write sets. Any Mobile/SDK entry implementation remains blocked by `FEEDBACK-PLATFORM-ACR-V1-001` until its second-consumer gate is reopened and approved.
