# OBS-SDK-ERROR-API-V1-002 — Error Reporting Public Surface Implementation Delivery Note

- Story: `OBS-SDK-ERROR-API-V1-002`
- Execution base: `dd8308320d7a34e2834a9c190817cd1779b6c416`
- Implementation candidate: `643f9a84f82970cf45328a0969c75c66f07cad1d`
- Branch: `obs/sdk-error-api-v1-002-public-surface-implementation`
- Frozen surface authority: `docs/multi_agent/contracts/ERROR_REPORTING_SDK_PUBLIC_SURFACE_V1.md`
- SDK public API mode: `CHANGE_APPROVED`
- Delivery state: **READY FOR INDEPENDENT SDK REVIEW**

## Implemented frozen surface

Exactly one new public top-level symbol is published through the already-exported `capabilities.dart` library:

```dart
abstract interface class NebulaErrorReporting {
  Future<void> reportCaughtError({
    required String errorType,
    required String safeMessage,
    required StackTrace stackTrace,
    DateTime? occurredAt,
    NebulaRequestId? requestId,
  });
}
```

`Nebula` adds only the frozen optional nullable member:

```dart
NebulaErrorReporting? errorReporting
```

`ErrorReportingClient` remains internal/unexported and implements the public capability by mapping only the five frozen App-facing diagnostics into the existing internal capture pipeline. It explicitly imports `foundation/request_id.dart` as required by Dart library rules. Public reporting is fail-soft and does not expose persistence/upload/result state.

## Exact authorized production/API diff

```text
lib/src/capabilities.dart
lib/src/nebula.dart
lib/src/error_reporting/client.dart
governance/api_surface.snapshot
```

Focused proof only:

```text
test/error_reporting/error_reporting_public_surface_test.dart
```

No fifth production/public-surface file was required.

## API surface proof

Before snapshot update, the authoritative tool reported exactly:

```text
+ added: src/capabilities.dart class NebulaErrorReporting
```

After the authorized snapshot update:

```text
125 -> 126 top-level symbols
only new symbol:
src/capabilities.dart class NebulaErrorReporting
```

`Nebula.errorReporting` is member-level and introduces no additional top-level symbol.

## Required unchanged paths

Both paths remain byte-identical to execution base by Git blob hash:

```text
lib/nebula_sdk.dart
base/current blob = 52191077bdcfeb08f104979b8ca26e9aec184db5

governance/public_api.txt
base/current blob = 8169be75428f0863d11634bab189d013d45292fe
```

The existing barrel already exports `capabilities.dart` and `nebula.dart`; no new barrel export or public-api allowlist path was added.

## Frozen-boundary evidence

- no public input DTO;
- no public result DTO;
- no public report/store/sender/budget/retry/provider/transport type;
- no caller-authoritative `app_id`, `installation_id`, platform, or `user_id` parameter;
- no native crash/minidump/ANR semantics;
- no public `flush()` or provider selection;
- nullable facade preserves existing constructor source compatibility;
- `requestId` maps through existing public `NebulaRequestId` to internal string correlation only;
- persistence/reporting subsystem failure does not escape as App control-flow failure.

## Verification evidence

Focused public-surface verification:

```text
dart analyze changed public-surface files + focused test
PASS / 0 issues

dart test test/error_reporting/error_reporting_public_surface_test.dart
4/4 PASS
```

Full repository verification:

```text
Task Source Guard OBS-SDK-ERROR-API-V1-002   PASS
Cross Repo Guard                              PASS
Coordinator State Guard                       PASS
Platform API Guard                            PASS
Nebula Governance                             PASS
Governance regression                         30/30 PASS
API surface                                   PASS / 126 symbols
Secret scan                                   PASS
dart analyze                                  PASS / 0 issues
dart test                                     232/232 PASS
smoke                                         PASS
git diff --check                              PASS
```

## Forbidden-scope confirmation

```text
lib/nebula_sdk.dart            0 drift
governance/public_api.txt      0 drift
lib/src/foundation/**          0 drift
lib/src/transport/**           0 drift
lib/src/analytics/**           0 drift
Backend                        0
App / NFC Writer               0
Provider integration           0
Analytics implementation       0
Task Board                     0
```

## Candidate binding

The implementation candidate is the exact SHA recorded above. This Delivery Note is an evidence-only commit layered on that implementation. The final review candidate is the PR head containing both commits and MUST be bound by exact SHA in Forgejo formal review. Agent A does not merge, mark the Story DONE, or authorize Backend/App/provider/Analytics follow-up work.
