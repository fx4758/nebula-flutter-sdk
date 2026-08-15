# Error Reporting Contract v1

- **Contract ID**: CONTRACT-ERROR-REPORTING
- **Version**: 1
- **Status**: FREEZE CANDIDATE / INDEPENDENT REVIEW REQUIRED
- **Story**: OBS-CONTRACT-V1-001
- **Architecture authority**: `reports/ACR-MOBILE-OBSERVABILITY-001.md`
- **Classification**: Platform-capability candidate; second-consumer evidence VERIFIED
- **Implementation authorization**: NONE

## 1. Scope

Error Reporting V1 covers:

- Flutter/Dart uncaught errors;
- explicit caught errors submitted by application code through the future Nebula capability boundary.

Deferred outside V1:

- native process crash / signal capture;
- minidump;
- ANR;
- breadcrumbs;
- screenshots;
- full/raw logs.

A `fatal` classification, if introduced later, refers only to Flutter/Dart error classification and MUST NOT imply guaranteed native-process crash capture.

## 2. Report identity

Each report instance has a client-generated immutable `report_id`.

`report_id` exists to preserve one report's identity across local persistence and delivery retry. The same persisted report MUST retain the same `report_id` until acknowledged or purged by policy.

The concrete identifier encoding is an implementation detail provided it is collision-resistant within the trusted installation scope and stable through the report lifecycle.

## 3. Client diagnostic facts

The canonical V1 client diagnostic payload semantics are limited to:

- `report_id`;
- `occurred_at`;
- `error_type`;
- `safe_message`;
- `stack`;
- `request_id` when available;
- `reported_app_version`;
- `reported_build_number`.

The receiving authority records a distinct server-authoritative `ingested_at` receipt time. `occurred_at` is the client-side error occurrence time; `ingested_at` is server receipt/persistence time. Offline persistence/retry MUST preserve `occurred_at` and MUST NOT overwrite it with receipt time.

`reported_app_version` and `reported_build_number` are diagnostic snapshots from the time of the error. They are not authorization authority.

## 4. Trusted identity

The client MUST NOT be authority for `app_id`, `installation_id`, or platform.

Trusted identity is derived server-side from InstallationProof and the trusted installation record:

```text
InstallationProof
→ trusted app_id
→ trusted installation_id
→ trusted installation record
→ trusted platform
```

No `user_id` is included by default in Error Reporting V1. Adding user identity requires a separately reviewed privacy/contract change.

## 5. Privacy and redaction

Error Reporting V1 MUST NOT collect or upload by default:

- raw application logs;
- breadcrumbs;
- screenshots;
- user content;
- authentication tokens/secrets;
- product-specific sensitive payloads.

`safe_message` and `stack` are diagnostic fields subject to sanitization/redaction and bounded-size policy. Stored values MUST NOT themselves be written into SDK operational logs by ErrorStore/provider plumbing.

Provider-specific fields MUST NOT become canonical Nebula contract authority.

## 6. Payload bounds and deterministic over-limit behavior

Every payload field and the total report payload MUST be bounded. Concrete numeric limits are implementation/runtime configuration unless later frozen by a reviewed contract change.

Exceeding a configured limit MUST have deterministic behavior such as reject, sanitize, truncate, or drop. The selected outcome MUST be observable/statistically accountable; silent unbounded retention or growth is forbidden.

Any proof-protected upload request MUST remain within the existing InstallationProof accepted body ceiling. Increasing that platform ceiling is not authorized by this contract.

## 7. ErrorStore lifecycle boundary

A future Error Reporting SDK capability MAY define a host-injected `ErrorStore` Port. If implemented, its contract MUST satisfy:

- bounded report count;
- bounded total bytes;
- bounded maximum age/TTL;
- app-private persistence;
- stored values MUST NOT be logged;
- reports are purged after acknowledged upload;
- policy-driven expiry/drop is deterministic and accountable.

Error capture lifecycle is:

```text
Error
→ normalize
→ bound check
→ local persistence (best effort)
→ bounded later upload
→ ACK
→ delete
```

The only fatal-path durability promise is **best-effort durable enqueue**. The contract does not promise persistence after the process has already terminated. Only successfully persisted reports can be guaranteed eligible for next-launch flush.

## 8. Delivery identity and retry

A retry of the same persisted report MUST retain the same immutable `report_id`.

The receiving authority MUST provide durable report-level deduplication semantics sufficient for `commit → response lost → same report retry` to acknowledge prior acceptance without creating a second logical report instance.

Durable identity behavior is frozen as follows:

- same trusted scope + same `report_id` + same immutable diagnostic report payload => acknowledge prior acceptance without creating a second report instance;
- same trusted scope + same `report_id` + different diagnostic report payload => deterministic non-retryable conflict/rejection; it MUST NOT be acknowledged as the prior report.

The receiving authority MUST retain enough durable receipt material to distinguish those two cases. The concrete digest/index/table mechanism is an implementation detail.

This contract freezes observable behavior, not a database table or index.

Retry/backoff MUST be bounded. Offline retry is allowed. App startup MUST NOT upload unbounded history.

## 9. Fingerprint and issue grouping authority

`report_id` and issue fingerprint solve different problems:

- `report_id`: same report instance across persistence/retry;
- fingerprint: same underlying bug across many report instances.

The client is NOT final fingerprint authority. Nebula/server authority owns normalization, fingerprinting, and issue grouping so algorithms do not drift across client versions.

Issue aggregation is a longer-lived projection/concept over short-retention raw reports, not the raw-report store itself. The contract does not freeze a concrete table/schema.

Third-party provider fingerprints MAY be used for diagnostics/display but MUST NOT replace Nebula fingerprint/issue authority.

## 10. Upload budget and storm control

Client implementations MUST support bounded:

- reports per upload;
- bytes per upload;
- retry attempts/backoff;
- offline backlog processing.

The client MUST support server-directed upload-reduction policy. Supported policy values MAY evolve without requiring every client to understand future named values individually; unknown policy evolution must fail safely according to the frozen transport/error contract.

The architecture permits responses semantically equivalent to rate-limit, sample/reduce, mute/defer, or aggregate-only behavior. Concrete policy names/codes are not frozen here.

## 11. Provider strategy

Nebula owns contract/privacy/lifecycle/identity/budget. Provider adapters MAY provide collection backend, dashboard, or storage implementation.

Provider selection MUST consider data residency, regional availability, legal requirements, and export restrictions. No concrete vendor is frozen.

Product/App code MUST NOT directly select provider SDKs by region. Provider routing remains behind the Nebula-owned abstraction.

V1 MAY later use third-party adapters; self-building a complete crash platform is not authorized by this freeze Story.

## 12. Compatibility and versioning

Changes to V1 scope, diagnostic fields, trusted identity, default privacy collection, report identity/dedup semantics, fingerprint authority, ErrorStore lifecycle, or provider authority require reviewed contract change/versioning.

Native crash/minidump/ANR support is a new capability increment, not an implicit V1 extension.

## 13. Explicitly forbidden by this freeze Story

- SDK ErrorReporter/ErrorStore production implementation or public exports;
- Backend endpoint/schema/migration implementation;
- provider SDK integration/initialization;
- App production mutation/repin;
- native crash/minidump/ANR implementation;
- implementation Story registration by Agent A.

## 14. Freeze gate

This document is a freeze candidate. It becomes canonical `v1 FROZEN` only after independent review and canonical `OBS-CONTRACT-V1-001 = DONE / REVIEW PASS` closure.
