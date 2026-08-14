# Mobile Analytics Contract v1

- **Contract ID**: CONTRACT-MOBILE-ANALYTICS
- **Version**: 1
- **Status**: FREEZE CANDIDATE / INDEPENDENT REVIEW REQUIRED
- **Story**: OBS-CONTRACT-V1-001
- **Architecture authority**: `reports/ACR-MOBILE-OBSERVABILITY-001.md`
- **Classification**: Nebula-owned capability; Platform API classification PENDING
- **Implementation authorization**: NONE

## 1. Scope

This contract freezes the domain semantics required for mobile Analytics ingest. It does not implement or select a Backend endpoint, database schema, SDK sender implementation, or provider.

The existing SDK domain boundary remains the starting point: `NebulaAnalyticsEvent` + `NebulaAnalyticsSender`. This Story does not authorize public event-model or public sender API mutation.

## 2. Trust and identity

Mobile Analytics ingest MUST use the approved mobile trust chain based on InstallationProof/trusted installation state. It MUST NOT require an App Secret in a mobile binary and MUST NOT reuse legacy HMAC `Signature()` as mobile trust.

Server-authoritative identity is derived from the trusted installation context. Caller-supplied identity MUST NOT override trusted `app_id`, `installation_id`, platform, or user identity when user identity is applicable.

The contract does not add `user_id` to the canonical event payload. Privacy/identity semantics remain governed by the existing Analytics event model and future implementation review.

## 3. Request/batch identity

The SDK queue is not itself a transport batch. Before assigning identity, the sender MUST exact-byte split queued events into one or more final transport batches that each fit the proof-protected request budget. Each resulting transport batch has its own client-generated `batch_id`.

Requirements:

- exact-byte split occurs **before** `batch_id` assignment;
- one `batch_id` identifies exactly one final transport request event set;
- `batch_id` MUST be stable for the complete retry lifecycle of that transport batch;
- assigning a new `batch_id` to retry the same logical transport batch is forbidden;
- once a `batch_id` is assigned, the ordered event payload associated with that batch is immutable;
- reusing one `batch_id` with materially different event payload is invalid;
- events added later to the SDK queue form a new transport batch and receive a new `batch_id`;
- V1 does not require an event-level `event_id` when immutable batch receipt semantics are preserved.

The concrete identifier encoding is an implementation detail as long as it is collision-resistant within the trusted `(app_id, installation_id)` scope and stable across retry/persistence.

## 4. Durable acceptance semantics

The server-side contract MUST provide durable receipt semantics for `(trusted app_id, trusted installation_id, batch_id)` or an equivalent durable identity with the same observable behavior.

Required behavior:

```text
first request
→ batch committed
→ success response lost
→ same immutable batch_id retried
→ server returns accepted/success result
→ events are NOT inserted a second time
```

A retry of an already accepted immutable batch MUST NOT be reported as a failure merely because the batch is a duplicate. Existing short-lived Redis `Idempotent()` behavior is not sufficient evidence for this durable receipt contract.

The contract freezes behavior, not a table/index implementation.

## 5. Time semantics

Analytics preserves two distinct clocks:

- `occurred_at`: client-side event occurrence time carried from the SDK event timestamp;
- `ingested_at`: server-side receipt/persistence time.

Behavioral aggregation/trend semantics MUST NOT silently replace `occurred_at` with `ingested_at`. Operational ingestion analysis MAY use `ingested_at`.

Offline queueing and delayed flush therefore preserve event occurrence time across upload delay.

## 6. Canonical logical request/event semantics

The V1 mobile ingest logical request is:

```text
batch_id
events[]
```

Each event carries exactly the Analytics domain semantics:

```text
name
occurred_at
identifiable
properties
```

`occurred_at` is the mobile-ingest representation of the existing SDK event timestamp. A future concrete sender/DTO may perform serialization mapping, but MUST preserve these logical names/semantics at the contract boundary and MUST NOT silently discard occurrence time or privacy semantics.

Trusted `app_id`, `installation_id`, platform, and applicable authenticated user context are derived from the server trust chain and are not caller-authoritative Analytics event fields.

Legacy Backend `name / user_id / props / region_code / created_at` is not declared equivalent by this contract.

## 7. Body and splitting rules

Every proof-protected canonical HTTP request MUST fit within the currently accepted InstallationProof body ceiling. Architecture review mechanically established the current proof read ceiling as `maxProofReadBytes = 16 * 1024`.

Requirements:

- splitting MUST use exact serialized request-byte accounting, including envelope/array overhead;
- queued events MUST be partitioned into final transport batches before identity assignment; each HTTP request carries exactly one immutable `batch_id` event set;
- correctness MUST NOT depend on gzip/compression ratio;
- gzip/compression is OPTIONAL/DEFERRED optimization;
- increasing the InstallationProof body ceiling is a separate Platform contract change, not an Analytics-local decision.

Concrete per-request event count and byte budgets remain runtime/implementation configuration within this ceiling.

## 8. Retry/error semantics

Automatic retry MUST preserve the same immutable logical batch identity for ambiguous/transient delivery failures.

The frozen contract requires deterministic classification of at least:

- accepted/success;
- invalid payload/non-retryable failure;
- authentication/proof failure;
- rate-limited/upload-reduction response;
- transient/unavailable failure eligible for bounded backoff.

Exact numeric error codes are not invented by this Story and require downstream Backend/SDK contract implementation review.

Analytics retry MUST remain bounded. Observability failure MUST NOT break core App behavior.

## 9. Cost and abuse control

Client upload is bounded by request bytes/count, bounded retry/backoff, and bounded queued data. Server acceptance/retention is also bounded.

The client MUST support server-directed upload-reduction policy whose supported policy values MAY evolve. No contract rule requires uploading all queued history at App startup.

Concrete runtime quotas are not architecture invariants here.

## 10. Analytics authority and provider rule

Nebula remains Analytics SSOT/product-data authority. Third-party BI/export/experimentation integrations MAY consume downstream data later but MUST NOT replace the Nebula Analytics authority through product-code routing.

## 11. Compatibility and versioning

Any future change to event semantics, trusted identity, durable batch behavior, occurrence-time semantics, proof/body ceiling assumptions, or retry acknowledgement requires a reviewed contract version/change path.

Platform API promotion is separately gated by mechanically verified Analytics second-consumer evidence.

## 12. Explicitly forbidden by this freeze Story

- Backend endpoint/router/DTO/schema/migration implementation;
- SDK concrete sender/public API/export mutation;
- App transport implementation/repin;
- provider integration;
- treating legacy `/analytics/events` as mobile-ready;
- registering implementation Stories from Agent A.

## 13. Freeze gate

This document is a freeze candidate. It becomes canonical `v1 FROZEN` only after independent review and canonical `OBS-CONTRACT-V1-001 = DONE / REVIEW PASS` closure.
