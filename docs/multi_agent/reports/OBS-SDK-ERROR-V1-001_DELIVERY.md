# OBS-SDK-ERROR-V1-001 — Error Reporting Internal Core Delivery Note

- Story: `OBS-SDK-ERROR-V1-001`
- Execution base: `2b96690a51501594715e42b7f5c3a9910586fa2d`
- Core implementation commit: `1d00032eb8bb0cbdbc60130c6e8471bde69a17f2`
- Branch: `obs/sdk-error-v1-001-internal-core`
- Frozen contract authority: `docs/multi_agent/contracts/ERROR_REPORTING_CONTRACT_V1.md`
- Public SDK API mode: `READ_ONLY`
- Delivery state: **READY FOR INDEPENDENT SDK REVIEW**

## Scope delivered

Production changes are restricted to `lib/src/error_reporting/**` and implement the internal V1 domain/lifecycle core only:

- immutable `NebulaErrorReport` with the eight frozen client diagnostic facts;
- secure random UUIDv4-style `report_id` generator with injectable test seam;
- privacy-safe normalization/redaction and UTF-8 byte bounding;
- runtime-tunable report/store/upload/retry budgets;
- host-injected bounded `ErrorReportStore` Port;
- domain-specific `ErrorReportSender` Port, without transport/backend/provider binding;
- best-effort capture that never turns observability failure into an App failure;
- ACK -> delete lifecycle;
- deterministic non-retryable rejection purge/accounting;
- transient retry preserving the same persisted `report_id`;
- bounded retry exhaustion;
- bounded count/bytes/age backlog policy;
- server-directed upload defer/cooldown seam without freezing provider policy names;
- non-sensitive counters for truncation/drop/eviction/retry/ACK/rejection accounting.

The internal report intentionally contains no caller-authoritative `app_id`, `installation_id`, platform or `user_id`. Server-owned `ingested_at` is not serialized by the client; `occurred_at` is preserved through persistence/retry.

## Changed implementation paths

```text
lib/src/error_reporting/budget.dart
lib/src/error_reporting/client.dart
lib/src/error_reporting/normalizer.dart
lib/src/error_reporting/report.dart
lib/src/error_reporting/report_id.dart
lib/src/error_reporting/sender.dart
lib/src/error_reporting/store.dart
```

Focused verification/fakes:

```text
test/error_reporting/error_report_model_test.dart
test/error_reporting/error_reporting_client_test.dart
test/error_reporting/fakes/error_reporting_fakes.dart
test/error_reporting/report_id_test.dart
```

## Frozen-invariant evidence

1. Same persisted report retains one immutable `report_id` across transient retry.
2. `occurred_at` remains the original error occurrence time; no upload/receipt timestamp overwrites it.
3. Trusted app/installation/platform identity is absent from caller-authored report facts.
4. Error Reporting core/store plumbing imports no SDK logging surface and emits no diagnostic values to logs/`print`.
5. Store failure is fail-soft/best-effort and is accounted without claiming guaranteed post-termination capture.
6. Test store mechanically enforces count, bytes and TTL/age bounds; production Port contract requires host implementations to enforce supplied bounds.
7. Per-field/total payload overflow is deterministic (redact/truncate/drop) and counted.
8. ACK deletes; transient failure keeps the same identity and schedules bounded retry; exhaustion is purged/accounted.
9. No native crash/minidump/ANR/breadcrumb/screenshot/raw-log collection exists.
10. No `MobileTelemetryTransport`, transport implementation, endpoint or provider dependency exists.

## Verification evidence

Focused:

```text
dart analyze lib/src/error_reporting test/error_reporting
PASS / 0 issues

dart test test/error_reporting
17/17 PASS
```

Full SDK/governance:

```text
Task Source Guard OBS-SDK-ERROR-V1-001   PASS
Cross Repo Guard                         PASS
Coordinator State Guard                  PASS
Platform API Guard                       PASS
Nebula Governance                        PASS
Governance regression                    30/30 PASS
API surface                              PASS / 125 symbols unchanged
Secret scan                              PASS
dart format check                        PASS
dart analyze                             PASS / 0 issues
dart test                                228/228 PASS
smoke                                    PASS
git diff --check                         PASS
```

Byte-identical to execution base:

```text
lib/nebula_sdk.dart
governance/api_surface.snapshot
governance/public_api.txt
lib/src/nebula.dart
lib/src/capabilities.dart
```

Forbidden/shared production diff:

```text
lib/src/foundation/**   0
lib/src/transport/**    0
lib/src/analytics/**    0
Backend                 0
App / NFC Writer        0
Provider integration    0
Task Board              0
```

## Candidate binding note

The exact core implementation SHA is recorded above. The final review candidate is the PR head containing this evidence-only Delivery Note on top of that core commit; Forgejo PR metadata and the independent formal review MUST bind the exact final candidate SHA. The Implementation Agent does not mark the Story DONE and does not claim canonical closure.

## Exit boundary

This delivery goes only to independent SDK Review. A PASS does not authorize public SDK export, Backend ingest, provider integration, App release, Analytics implementation, native crash support, or any other OBS Story. Coordinator-only canonical publication remains mandatory.
