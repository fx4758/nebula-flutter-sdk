# OBS-SDK-COMPOSITION-LIFECYCLE-V1-002 — Mobile Observability Lifecycle Implementation

- ID：OBS-SDK-COMPOSITION-LIFECYCLE-V1-002
- Execution repo：`.`
- Execution branch：`obs/sdk-composition-lifecycle-v1-002-implementation`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`CHANGE_APPROVED`

Status: **READY / CHANGE_APPROVED**

## Goal
Implement the reviewed `MOBILE_OBSERVABILITY_SDK_LIFECYCLE_V1.md` contract exactly.

## Authorized production write-set
```text
lib/src/nebula.dart
lib/src/observability/mobile_observability_composition.dart
```

Focused tests may be added/updated only under:
```text
test/observability/**
test/error_reporting/** only when needed for composition delegation proof
```

## Required behavior
- add exactly one existing-class member: `Future<void> NebulaMobileObservability.flush()`;
- top-level API symbol count remains 127;
- `NebulaErrorReporting` public surface remains unchanged;
- one composition flush attempts Analytics and internal Error Reporting independently;
- one domain failure must not suppress the other;
- composition flush is fail-soft and returns no queue/result/retry/provider details;
- construction remains zero-network;
- no timer/background worker/platform lifecycle listener;
- preserve all existing domain retry/defer/trust/ACK/budget semantics.

## Forbidden
```text
Backend/App/provider mutation
new top-level symbol/export
NebulaErrorReporting.flush
queue/store/sender/client/result public exposure
transport/auth/proof changes
Analytics queue/retry changes
ErrorReportingClient retry policy changes
governance/public_api.txt drift
unrelated refactor
```

## Acceptance
- Task Source / Cross Repo / governance PASS;
- focused observability + Error Reporting tests PASS;
- API surface remains 127 with zero new top-level symbol;
- analyzer + full SDK tests PASS;
- independent SDK review on exact candidate;
- merge + post-merge governance PASS.
