# Error Reporting Platform API v1

- **Contract ID**: PLATFORM-API-ERROR-REPORTING-V1
- **Status**: FREEZE CANDIDATE / INDEPENDENT REVIEW REQUIRED
- **Story**: OBS-PLATFORM-API-V1-001
- **Domain authority**: `contracts/ERROR_REPORTING_CONTRACT_V1.md`
- **SDK public-surface authority**: `contracts/ERROR_REPORTING_SDK_PUBLIC_SURFACE_V1.md`
- **Architecture authority**: `adrs/ADR-MOBILE-OBSERVABILITY-001.md`
- **Platform API mode**: CONTRACT_CHANGE
- **Implementation authorization**: NONE

## 1. Scope / classification

This freezes the concrete Platform API for Flutter/Dart Error Reporting V1. It does not implement Backend handlers/storage/fingerprinting, SDK sender transport, App capture wiring, native crash collection, provider adapters or dashboards.

Error Reporting is a product-neutral Platform capability. FlyPost Crash/Telemetry/request_id/release governance remains the verified second-consumer evidence in addition to NFC Writer.

## 2. Endpoint / trust plane

```text
POST /api/v1/mobile/error-reports
Content-Type: application/json; charset=utf-8
```

Required middleware order:

```text
coarse abuse protection
→ body hard limit
→ InstallationProof
→ trusted-installation rate limit
→ Error Reporting handler
```

Required headers:

```text
X-Installation-Token
X-Proof-Timestamp
X-Proof-Nonce
X-Device-Proof
X-Request-Id
```

Legacy HMAC fallback is forbidden. A user token is not required. Caller app/install/platform/user fields are not trusted identity. The server MUST echo `X-Request-Id`; the JSON body envelope remains `{code,data}` only.

## 3. Request wire / compatibility bounds

```json
{
  "reports": [
    {
      "report_id": "opaque-client-id",
      "occurred_at": 1786850400,
      "error_type": "StateError",
      "safe_message": "operation failed",
      "stack": "#0 ...",
      "request_id": "a1b2c3",
      "reported_app_version": "2.4.0",
      "reported_build_number": "30"
    }
  ]
}
```

Top-level key set is exactly `reports`; any unknown top-level key is a request-level invalid payload. Each report carries exactly:

```text
report_id
occurred_at
error_type
safe_message
stack
request_id
reported_app_version
reported_build_number
```

`request_id`, `reported_app_version`, and `reported_build_number` are nullable. Sender SHOULD serialize canonical keys with JSON null when unavailable; omitted optional key and explicit null are the same logical value for dedup equality.

V1 compatibility bounds:

- `reports`: 1..10 when complete request also fits;
- `report_id`: non-empty UTF-8, <=128 bytes;
- `occurred_at`: UTC Unix seconds integer;
- `error_type`: non-empty, <=128 UTF-8 bytes;
- `safe_message`: <=1024 UTF-8 bytes after redaction;
- `stack`: <=8 KiB UTF-8 after normalization;
- `request_id`, `reported_app_version`, `reported_build_number`: nullable, each <=128 UTF-8 bytes;
- one logical report <=12 KiB;
- complete request <=16 KiB exact UTF-8 JSON bytes;
- `report_id` values MUST be unique within one request; duplicate IDs in one request are request-level invalid payload with zero report processing;
- a missing/empty/oversized `report_id` is request-level invalid payload because the server cannot safely identify a per-report rejection;
- after a valid `report_id` is established, unknown/invalid report fields are per-report `invalid_payload`, not implicit V1 expansion.

These bounds match the current SDK V1 compatibility budget. A future server may accept more, but clients cannot rely on larger values without reviewed contract change.

## 4. Trusted identity / clocks

InstallationProof + trusted installation record derive `app_id`, `installation_id` and platform. Request fields cannot override them.

Every accepted report preserves:

```text
occurred_at = immutable client-side error occurrence time
ingested_at = server-authoritative durable acceptance time
```

Offline retry preserves `occurred_at`. Duplicate ACK returns the original `ingested_at`, not retry time. Reported app version/build are diagnostic facts only.

## 5. Privacy boundary

V1 MUST NOT add canonical fields for raw logs, breadcrumbs, screenshots, attachments, user content, auth tokens/cookies, full request/response bodies, native minidumps, ANR payloads or product-specific sensitive material.

`safe_message` and `stack` arrive after SDK/App normalization/redaction; Backend may additionally sanitize or reject but must not silently expand collection. NFC Writer App wiring specifically remains forbidden from placing NFC UID/dumps/keys, MRZ/passport data, card numbers or tag/user content into diagnostics.

## 6. Body ceiling / partial processing

The authoritative Platform request ceiling is the InstallationProof ceiling: **16 KiB exact UTF-8 JSON bytes**. The outer 32 KiB mobile body guard is not sufficient authority.

A batch is delivery convenience, not shared identity. Each `report_id` is accepted/deduplicated independently.

Request-level malformed JSON, missing/empty `reports`, >10 reports, or over-ceiling body causes zero report processing. After request syntax is valid, valid reports MAY be accepted while invalid/conflicting reports are returned as non-retryable per-report rejections. This partial result matches the existing SDK `ErrorReportSendResult` seam.

## 7. Durable report identity

Durable identity scope:

```text
(trusted app_id, trusted installation_id, report_id)
```

Required per-report behavior:

- new ID + valid report → persist one logical report;
- same ID + same logical diagnostic payload → acknowledge prior acceptance without a second report;
- same ID + different logical payload → reject with `id_conflict`; never masquerade as duplicate success.

Logical equality uses canonical report field values. JSON whitespace/key ordering and omitted-vs-null optional fields do not create a different payload. Digest/index/storage implementation remains internal. Short-lived nonce/idempotency state alone is insufficient.

## 8. Success / partial-result response

```json
{
  "code": 0,
  "data": {
    "accepted": [
      {"report_id": "r-1", "ingested_at": 1786850403, "duplicate": false}
    ],
    "rejected": [
      {"report_id": "r-2", "reason": "id_conflict"}
    ],
    "defer_remaining": false,
    "retry_after_seconds": null
  }
}
```

Frozen non-retryable rejection reasons:

```text
invalid_payload
id_conflict
```

A duplicate accepted report appears in `accepted` with `duplicate=true` and original `ingested_at`. Accepted/rejected IDs are disjoint and subsets of request IDs.

`defer_remaining=true` asks the client to pause later backlog processing after applying this request's results. `retry_after_seconds` is null or non-negative integer seconds and defines the minimum cooldown for later uploads; it does not undo reports already accepted.

## 9. Error / retry contract

| Condition | HTTP | code | Client behavior |
|---|---:|---:|---|
| valid request processed, including partial rejections | 200 | 0 | delete accepted + non-retryable rejected IDs; retry only IDs absent from both |
| request-level malformed/invalid envelope | 200 | 30001 | non-retryable construction defect |
| invalid InstallationProof/token/key/replay | 200 | 12001 | recover installation trust; no blind retry |
| trusted-installation rate limit before report processing | 429 | 40002 | no report accepted; defer full set, honor `Retry-After` |
| durable receipt/store/provider dependency unavailable before valid result | 200 | 12004 | retain and bounded retry |
| unexpected server failure before valid ACK | 200 | 50001 | retain and bounded retry |
| ambiguous transport timeout/5xx/connection loss | transport | — | retry same persisted report IDs; durable dedup makes commit+lost-response safe |

HTTP 429 MUST include non-negative integer-seconds `Retry-After`. Concrete SDK sender maps transport responses into `ErrorReportSendResult` without public SDK expansion.

Inside `code=0`, a request report omitted from both `accepted` and `rejected` remains retryable; omission is the only successful-envelope per-report retryable outcome.

### Concrete SDK sender mapping requirement

The concrete Error Reporting transport sender MUST map Platform outcomes into the existing `ErrorReportSendResult`/retry seam without changing the public Error Reporting surface:

- `code=0` -> populate accepted/rejected IDs exactly from the response;
- HTTP 429 + `code=40002` -> no accepted/rejected IDs for the unprocessed request and `deferRemaining=true` with the frozen `Retry-After` cooldown;
- `code=12004`, `code=50001`, timeout, connection failure or ambiguous transport failure -> leave affected reports retryable (no false accepted/rejected IDs);
- request-level `code=30001` -> deterministic non-retryable sender failure for the malformed request; it MUST NOT delete unrelated persisted reports as if individually rejected.

A sender MUST never manufacture accepted IDs when the response did not durably acknowledge them.

## 10. Fingerprint / provider boundary

This wire is report-instance ingest only. It exposes no issue fingerprint/grouping key, provider event ID/dashboard URL/provider routing. Nebula/server remains final fingerprint/grouping authority; provider identifiers may exist internally but cannot become required request fields.

## 11. Compatibility / rollback

The endpoint is additive; there is no legacy mobile Error Reporting endpoint to replace. Before SDK transport rollout it may be disabled/not routed. After rollout, temporary Backend rollback must keep this route compatible or return frozen transient semantics so bounded local ErrorStore can retry later.

Changing path/method, trust source, diagnostic fields, durable `report_id` semantics, partial acknowledgement, time authority, privacy default or 16 KiB ceiling requires reviewed versioning. Native crash/minidump/ANR remains a new capability version, not implicit V1 extension.

## 12. Platform API policy answers

1. Capability: generic Flutter/Dart Error Reporting ingest.
2. Platform: diagnostic schema is product-neutral.
3. Consumers: NFC Writer + FlyPost release Crash/Telemetry lane.
4. Product-name erasure: contract remains valid unchanged.
5. Adapter insufficient: trust/time/durable ACK live on Backend.
6. SDK-only insufficient: local store/sender cannot create server acceptance/grouping authority.
7. Gap: no canonical Error Reporting Backend endpoint existed.
8. Change: additive endpoint/wire/trust/idempotency/error/privacy contract.
9. Compatibility/rollback: additive route + fail-soft retention rules in §11.
10. Security/privacy/cost: InstallationProof, 16 KiB request, 10-report/12-KiB-report compatibility bounds, redacted diagnostics, bounded retry and server defer.

## 13. Freeze gate

FREEZE CANDIDATE only. It becomes FROZEN after Formal CI, exact independent Architecture Review, merge and Coordinator closure. No Backend/SDK/App/provider implementation is authorized by this Story.
