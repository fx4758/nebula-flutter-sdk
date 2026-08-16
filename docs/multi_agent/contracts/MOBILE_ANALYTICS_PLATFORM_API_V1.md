# Mobile Analytics Platform API v1

- **Contract ID**: PLATFORM-API-MOBILE-ANALYTICS-V1
- **Status**: FREEZE CANDIDATE / INDEPENDENT REVIEW REQUIRED
- **Story**: OBS-PLATFORM-API-V1-001
- **Domain authority**: `contracts/MOBILE_ANALYTICS_CONTRACT_V1.md`
- **Architecture authority**: `adrs/ADR-MOBILE-OBSERVABILITY-001.md`
- **Platform API mode**: CONTRACT_CHANGE
- **Implementation authorization**: NONE

## 1. Scope / Platform evidence

This freezes the concrete mobile Platform API for the already-frozen Mobile Analytics semantics. It does not implement Backend routes/storage, SDK sender, App wiring, provider or BI.

Analytics remains Nebula-owned product-data authority. Platform reuse is now mechanically evidenced beyond NFC Writer:

- Nearvia `17a6529592d21bf3ced52f121fa1ebed97f8a87a`: ADR-002 requires existing Nebula analytics for consent/privacy-compliant product/technical events; V1 architecture requires aggregated reliability telemetry.

This resolves the earlier ACR Analytics second-consumer gap. FlyPost Crash/Telemetry evidence is not relabeled as Analytics evidence.

## 2. Endpoint / trust plane

```text
POST /api/v1/mobile/analytics/batches
Content-Type: application/json; charset=utf-8
```

Required middleware order:

```text
coarse abuse protection
→ body hard limit
→ InstallationProof
→ trusted-installation rate limit
→ Analytics handler
```

Required existing mobile headers:

```text
X-Installation-Token
X-Proof-Timestamp
X-Proof-Nonce
X-Device-Proof
X-Request-Id
```

Legacy HMAC `Signature()` fallback is forbidden. A user token is not required. Caller `app_id`, `installation_id`, platform, region and `user_id` are not trusted Analytics identity.

The server MUST echo the effective correlation value in response header `X-Request-Id`. JSON response envelope remains exactly `{code,data}` with no `msg/message`.

## 3. Request wire

```json
{
  "batch_id": "opaque-client-id",
  "events": [
    {
      "name": "screen_view",
      "occurred_at": 1786850400,
      "identifiable": false,
      "properties": {"screen": "home"}
    }
  ]
}
```

Top-level keys are exactly `batch_id` and `events`. Event keys are exactly `name`, `occurred_at`, `identifiable`, `properties`.

V1 rules:

- `batch_id`: non-empty UTF-8, <=128 bytes;
- `events`: ordered array, 1..50 when final bytes also fit;
- `name`: non-empty, <=128 Unicode scalar values;
- `occurred_at`: UTC Unix seconds integer from SDK event timestamp;
- `identifiable`: boolean privacy classification, not trusted user identity;
- `properties`: JSON object, <=64 top-level keys;
- each source event MUST already satisfy the existing SDK `NebulaAnalyticsEvent` input bound; no additional mapped-event byte cap is frozen beyond the exact 16 KiB final request ceiling;
- server MUST support up to 50 events when the final body fits; clients MUST split earlier when exact bytes require it;
- unknown top-level/event fields are invalid payload, not implicit V1 expansion.

## 4. Trusted identity / privacy

InstallationProof + trusted installation record derive `app_id`, `installation_id` and platform. Body/query/header cannot override them.

V1 has no `user_id`. `identifiable=true` only means the App/SDK classified the event as consent-requiring; it does not authorize server-side identity inference.

`properties` MUST NOT be used for auth secrets/tokens, raw logs, screenshots, raw user content, NFC dumps/UIDs, MRZ/passport data, payment-card data or equivalent high-risk payload merely because JSON permits it. Product adapters own consent/minimization; the Platform contract stays product-neutral.

## 5. Exact-byte split / body ceiling

The outer mobile body guard is 32 KiB, but InstallationProof reads at most 16 KiB. Therefore this API ceiling is **16 KiB exact UTF-8 JSON request bytes**.

Required sender construction:

```text
select ordered candidate events
→ generate provisional batch_id
→ serialize complete request including ID
→ measure exact UTF-8 bytes
→ shrink/rebuild while >16 KiB
→ bind batch_id only after final request fits
→ retry immutable batch with the same ID
```

Correctness MUST NOT depend on compression. An over-ceiling request MUST NOT partially commit events.

## 6. Durable atomic acceptance

A batch is atomic: all ordered events are accepted under one durable receipt or none are accepted.

Durable identity scope:

```text
(trusted app_id, trusted installation_id, batch_id)
```

Required observable behavior:

- new ID + valid payload → commit exactly once;
- same ID + same logical payload → prior success, no reinsertion;
- same ID + different logical payload → `code=30001`, non-retryable conflict, zero insertion from the conflicting request;
- commit + lost response + same-ID retry is safe.

Logical equality covers the ordered event list and field values. JSON whitespace/object-key ordering do not change equality; event array ordering does. Digest/index/table implementation is not frozen. Short-lived Redis nonce/idempotency alone is insufficient durable receipt evidence.

## 7. Success response / clocks

First acceptance:

```json
{"code":0,"data":{"batch_id":"opaque-client-id","accepted_events":1,"duplicate":false,"ingested_at":1786850403}}
```

Duplicate ACK:

```json
{"code":0,"data":{"batch_id":"opaque-client-id","accepted_events":1,"duplicate":true,"ingested_at":1786850403}}
```

`ingested_at` is the original server-authoritative durable acceptance Unix time. Duplicate ACK returns the original value. `accepted_events` equals the immutable accepted count.

Every stored event preserves two clocks: `occurred_at` (client occurrence) and `ingested_at` (server acceptance). Offline upload MUST NOT overwrite occurrence time. Product/behavior analysis uses occurrence time unless a query explicitly asks for operational ingestion time.

## 8. Error / retry contract

| Condition | HTTP | code | Client classification |
|---|---:|---:|---|
| accepted / duplicate | 200 | 0 | success |
| malformed/unknown field/invalid event/empty batch/ID conflict | 200 | 30001 | non-retryable |
| invalid InstallationProof/token/key/replay | 200 | 12001 | recover installation trust; no blind retry |
| trusted-installation rate limit | 429 | 40002 | defer; no immediate automatic retry loop |
| durable receipt/storage dependency unavailable | 200 | 12004 | bounded retry, same batch ID |
| unexpected server failure | 200 | 50001 | bounded retry, same batch ID |
| transport timeout/5xx/connection failure without accepted envelope | transport | — | ambiguous/transient; bounded retry, same batch ID |

HTTP 429 + `code=40002` is the V1 rate-limit signal. The current public `NebulaTransport` does not expose response headers/body for non-2xx responses, so V1 correctness MUST NOT depend on reading `Retry-After`. The concrete sender MUST apply its own bounded cooldown/backoff after 429. Exposing a server-selected retry duration through the generic transport is a separate reviewed transport/API change.

Observability failure is fail-soft and MUST NOT break core App behavior.

### Concrete SDK sender mapping requirement

The existing generic `HttpTransport` is not the Analytics retry policy. The concrete mobile Analytics sender MUST translate frozen Platform outcomes into the existing Analytics sender/client semantics without changing public `NebulaTransport` API:

- HTTP 429 -> Analytics rate-limit classification so `NebulaAnalyticsClient` does not immediate-auto-retry the batch; the sender uses bounded local cooldown and does not require response-header access;
- `code=12004` or `code=50001` after a valid mobile exchange -> transient Analytics send failure so the existing bounded Analytics backoff retries the **same assigned `batch_id`**;
- `code=30001` -> non-retryable Analytics failure;
- timeout/connection/ambiguous transport failure -> transient Analytics send failure with the same assigned `batch_id`;
- `code=0` only -> successful batch ACK.

The sender MUST NOT generate a replacement `batch_id` merely to adapt error categories.

## 9. Legacy relationship / compatibility

Legacy `POST /api/v1/analytics/events` is **not reused** by the mobile sender. It remains for existing clients with its legacy HMAC/token/App-Key trust and legacy fields (`user_id`, `props`, `region_code`, server-created time).

The new endpoint is additive. Backend MAY map accepted mobile events into the same Nebula Analytics SSOT/aggregation authority only if mobile `occurred_at`, trusted installation scope, privacy classification and durable `batch_id` semantics remain intact.

Rollback before mobile rollout is disabling/not routing the new endpoint. After rollout, Backend rollback must keep this endpoint compatible or return frozen transient semantics (`12004`) while clients follow bounded queue policy. Changing path/method, trust source, request fields, durable identity, 16 KiB ceiling, atomicity, clocks or error semantics requires reviewed versioning.

## 10. Platform API policy answers

1. Capability: generic mobile Analytics batch ingest.
2. Platform: product-neutral event/trust/batch semantics.
3. Consumers: NFC Writer + canonical Nearvia `origin/main` evidence.
4. Product-name erasure: contract remains meaningful unchanged.
5. Adapter insufficient: durable receipt/trust/server time live on Backend.
6. SDK-only insufficient: SDK cannot manufacture server acceptance/errors.
7. Gap: legacy Analytics lacks mobile proof, occurrence time, immutable batch receipt.
8. Change: additive endpoint/wire/trust/idempotency/body/error contract.
9. Compatibility/rollback: additive coexistence and §9 rollback.
10. Security/privacy/cost: trusted installation, consent classification, 16 KiB ceiling, bounded retries and prohibited high-risk payload classes.

## 11. Freeze gate

FREEZE CANDIDATE only. It becomes FROZEN after Formal CI, exact independent Architecture Review, merge and Coordinator closure. This Story authorizes no Backend/SDK/App/provider implementation.
