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

The SDK queue is not itself a transport batch. The sender MUST construct a final transport batch using the complete serialized request body, including the candidate `batch_id`, before that identity becomes durable/assigned.

Mechanically required construction:

1. select an ordered candidate event set from the bounded queue;
2. generate a provisional client `batch_id`;
3. serialize the complete canonical request body with that provisional ID and exact envelope/array overhead;
4. if the serialized body exceeds the proof-protected ceiling, shrink/recompute the candidate event set before identity is bound; the provisional ID is not yet a durable batch identity and MAY be discarded/replaced during this construction step;
5. only after the complete serialized request fits the ceiling, bind/persist that `batch_id` to that exact ordered event set; from that point the batch is immutable.

Requirements:

- one assigned `batch_id` identifies exactly one immutable final HTTP event set;
- `batch_id` MUST be stable for the complete retry lifecycle of that transport batch;
- assigning a new `batch_id` to retry the same assigned logical transport batch is forbidden;
- once a `batch_id` is assigned, the ordered event payload associated with that batch is immutable;
- events added later to the SDK queue form a new transport batch and receive a new `batch_id`;
- V1 does not require an event-level `event_id` when immutable batch receipt semantics are preserved.

The concrete identifier encoding is an implementation detail as long as it is collision-resistant within the trusted `(app_id, installation_id)` scope and stable across retry/persistence after assignment.

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

Durable identity behavior is frozen as follows:

- same trusted scope + same `batch_id` + same immutable payload => return prior accepted/success semantics without reinsertion;
- same trusted scope + same `batch_id` + different payload => deterministic non-retryable conflict/rejection; it MUST NOT be returned as successful duplicate acceptance.

The receiving authority MUST retain enough durable receipt material to distinguish those two cases. The concrete digest/index/table mechanism is an implementation detail. Existing short-lived Redis `Idempotent()` behavior is not sufficient evidence for this durable receipt contract.

The contract freezes observable behavior, not a table/index implementation.

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

- sizing MUST use exact serialized request-byte accounting of the complete canonical body, including the provisional `batch_id`, envelope, and array overhead;
- identity becomes assigned/durable only after that complete serialized request fits the ceiling; if it does not fit, the event set is shrunk/recomputed before assignment;
- each HTTP request carries exactly one assigned immutable `batch_id` event set;
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
