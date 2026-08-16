# OBS-SDK-TRANSPORT-V1-001 — Mobile Observability Transport Delivery Note

- Story: `OBS-SDK-TRANSPORT-V1-001`
- Execution base: `ac2b5bda9dbbd67864d986f955a00b0eeedd65de`
- Core implementation: `aca4860a4679518d1926aecc7ab5660d450e190c`
- Branch: `obs/sdk-transport-v1-001-mobile-observability`
- Backend authority: FlyPostAPI `Dev=a19bd52372370d4f2f551c06d18194df4f547681`
- Error seam authority: `OBS-SDK-ERROR-SEAM-V1-001 = DONE / REVIEW PASS`, freeze `0a6dba92cd361186565b043c54c8c0e7c0730b2a`, Architecture Review #105, canonical closure `e7f1df8de4795ad17f278874559917faac05f8b4`
- M3 reauthorization: `ca040297a790c2a680b7fd0dfdbaab024e75de07`, Review #107, canonical `ac2b5bda9dbbd67864d986f955a00b0eeedd65de`, post-merge UI #149 SUCCESS
- First implementation review: #108 `REQUEST_CHANGES / official=true / exact 5bd0939cc3ba91d8943cfec3e21098244def842a` — correctly identified Analytics `12001` trust-recovery callback authorization mismatch
- Analytics trust scope correction: `af62e96194779eb6652d3cc83bdb194b724da75e`, Review #109 APPROVED, merge `f48018e8e214c627892785844228c9b52fa361a2`, post-merge governance UI #153 SUCCESS
- Current reviewed base after correction: `f48018e8e214c627892785844228c9b52fa361a2`
- Delivery state: **READY FOR NEW FORMAL CI / INDEPENDENT SDK REVIEW**

## Provenance

The earlier exploratory implementation `eda89ef6a59c2a90a0a7223004e4d31edd2e6ce7` is **not** this delivery candidate and was not cherry-picked. Its scope gap was canonicalized separately and fully reverted before the reviewed seam freeze/re-authorization chain. This implementation was rebuilt from fresh canonical base `ac2b5bda9dbbd67864d986f955a00b0eeedd65de` after Task Source Guard made M3 executable again.

Review #108 did not reject the transport mechanics; it rejected a governance mismatch between the frozen Analytics Platform `12001` recovery requirement and the then-current Task Pack wording. Coordinator resolved that mismatch through reviewed governance-only PR #50. The production/test tree remained byte-identical while `f48018e8...` was merged into this branch; no code was changed to bypass the review.

## Exact production write-set

```text
lib/src/analytics/analytics_client.dart
lib/src/analytics/mobile_analytics_sender.dart
lib/src/error_reporting/client.dart
lib/src/error_reporting/sender.dart
lib/src/error_reporting/mobile_error_report_sender.dart
```

Focused proof:

```text
test/analytics/mobile_analytics_sender_test.dart
test/error_reporting/mobile_error_report_sender_test.dart
test/error_reporting/error_reporting_send_seam_test.dart
```

No sixth production file was required. Agent A did not modify Task Board or the M3 Task Pack.

## Analytics transport

The concrete internal mobile sender uses the existing `NebulaTransport`, `RequestProofSigner`, `buildAuthHeaders`, and installation-token callback for `POST /api/v1/mobile/analytics/batches`.

Implemented invariants:
- event `timestamp` maps to wire `occurred_at` while `name / identifiable / properties` are preserved;
- candidate events are ordered; provisional `batch_id` + complete body are exact-byte measured and shrink until <=16 KiB before identity assignment;
- assigned body/`batch_id` remain immutable across transient retry and later retry after defer;
- maximum 50 events per request;
- `code=0` succeeds only after exact ACK validation for `batch_id / accepted_events / duplicate / ingested_at`;
- HTTP 429 / `40002` defer without immediate retry;
- `12004` / `50001` / timeout / transport ambiguity retry the same assigned object;
- `30001` is non-retryable;
- `12001` defers and requires installation-trust recovery before the next network send;
- legacy host-injected `NebulaAnalyticsSender` remains supported with unchanged public interface.

Proof tests verify resolved path `/base/api/v1/mobile/analytics/batches`; transient retry preserves the same canonical body SHA and installation-token SHA.

## Error Reporting transport and internal seam

The concrete internal sender binds `POST /api/v1/mobile/error-reports`.

Implemented invariants:
- wire payload is `{reports:[...]}` from immutable `NebulaErrorReport.toDiagnosticMap()` facts;
- no caller-authoritative App / installation / platform / user identity appears in the body;
- at most 10 reports and exact complete body <=16 KiB;
- accepted/rejected IDs are validated against the exact report IDs included in the transport attempt; allowed rejection reasons are `invalid_payload` and `id_conflict`;
- internal `affectedReportIds` binds each sender outcome to the exact subset governed by that transport attempt, so defensive sender splitting never burns retry budget or drops an unsent sibling;
- `code=0 + defer_remaining=true` applies accepted/rejected first, preserves omitted affected IDs without attempt increment, then applies bounded cooldown;
- HTTP 429 / `40002` preserves the affected set without retry-attempt burn;
- `12004` / `50001` / transport ambiguity consume normal bounded retry only for affected IDs;
- request-level `30001` performs a local deterministic non-retryable drop only for affected IDs, with dedicated accounting and no fabricated server ACK/rejection/retry-exhaustion event;
- `12001` preserves reports, consumes no normal delivery retry attempt, applies cooldown, and requires installation-trust recovery before the next network send;
- malformed/foreign/overlapping response IDs fail safe as transient/ambiguous rather than success.

Proof tests verify the resolved canonical path `/base/api/v1/mobile/error-reports` and the exact transmitted body remains <=16 KiB.

## Public/shared byte identity

The following required paths remain byte-identical to execution base:

```text
lib/nebula_sdk.dart
lib/src/capabilities.dart
lib/src/nebula.dart
lib/src/analytics/analytics_sender.dart
lib/src/analytics/event.dart
lib/src/analytics/nebula_analytics.dart
lib/src/transport.dart
lib/src/transport/**
lib/src/foundation/**
governance/api_surface.snapshot
governance/public_api.txt
```

API surface remains exactly **126 symbols**.

## Verification

Focused transport/seam verification is green, including exact-byte split, same assigned Analytics ID/body across retry, 429 defer, 12001 recovery-before-network, 30001 classification, partial accepted/rejected, subset-aware Error retry/drop, and proof canonical path/body evidence.

Full local repository verification on the implementation tree:

```text
Task Source Guard OBS-SDK-TRANSPORT-V1-001  PASS
Cross Repo Guard                             PASS
Cross Repo regression                        PASS
Coordinator State Guard                      PASS
Coordinator State regression                 PASS
Coordinator publication mode regression      PASS
Platform API Guard                           PASS
Platform API regression                      PASS
Nebula Governance                            PASS
Governance regression                        30/30 PASS
API surface                                  PASS / 126 symbols
Secret scan                                  PASS
Dart format                                  99 files / 0 changed
dart analyze                                 PASS / 0 issues
dart test                                    249/249 PASS
smoke                                        PASS
git diff --check                             PASS
```

CI dependency-resolution regression tests also PASS locally. The standalone runtime pin check intentionally reports local environment drift because this workstation currently runs Dart 3.11.4 while Formal CI requires Dart 3.12.0. No exception or bypass is claimed; Forgejo Formal CI on the exact final review candidate is the authoritative Dart 3.12.0 gate.

## Forbidden-scope confirmation

```text
public SDK exports/snapshots   0 drift
shared transport/**           0 drift
foundation/**                 0 drift
Backend                       0 mutation
App / NFC Writer              0 mutation
Provider integration          0 mutation
Task Board / Task Pack        0 Agent A mutation
S1-F01-002                    untouched / unrelated
```

## Review binding

This Delivery Note is an evidence-only commit layered on core implementation `aca4860a4679518d1926aecc7ab5660d450e190c`. The final review candidate is the PR head containing both commits and must be bound by exact SHA in Formal CI and independent SDK Review. Agent A does not merge, mark M3 DONE, or start `NEBULA-APP-001D` integration from this delivery.
