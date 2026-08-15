# OBS-SDK-ERROR-API-V1-002 Error Reporting SDK Public Surface Implementation
- ID：OBS-SDK-ERROR-API-V1-002
- Owner：SDK Architect Agent A
- Execution repo：`.`
- Execution branch：`obs/sdk-error-api-v1-002-public-surface-implementation`
- Platform API mode：`NONE`
- SDK public API mode：`CHANGE_APPROVED`
- Governance state：implements only the already frozen Error Reporting SDK Public Surface v1; Task Board remains Coordinator-only.
- Required upstream：`OBS-SDK-ERROR-API-V1-001 = DONE / REVIEW PASS`.
- Frozen surface authority：`docs/multi_agent/contracts/ERROR_REPORTING_SDK_PUBLIC_SURFACE_V1.md`.

## Goal
Implement exactly the independently reviewed public surface freeze without expanding the Error Reporting contract, exposing internal orchestration types, or touching Backend/App/provider/Analytics surfaces.

## Exact authorized production write-set
Only these production/governance files may change:

1. `lib/src/capabilities.dart`
2. `lib/src/nebula.dart`
3. `lib/src/error_reporting/client.dart`
4. `governance/api_surface.snapshot`

Tests and a Delivery Note may be added/updated as needed to prove the frozen surface, but no other production/public-surface path is authorized.

## Required implementation
The implementation MUST match the frozen surface exactly:

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

`Nebula` facade wiring MUST add only the optional nullable capability member required by the freeze:

```dart
NebulaErrorReporting? errorReporting
```

Existing constructor call sites MUST remain source compatible.

`ErrorReportingClient` MAY implement/adapt `NebulaErrorReporting`, but MUST remain unexported/internal. It may add the explicit `request_id` import required by Dart library rules.

## API surface invariant
Current canonical surface: `125` top-level symbols.

Expected implementation surface: `126` top-level symbols.

The ONLY new top-level public symbol is:

```text
src/capabilities.dart class NebulaErrorReporting
```

`Nebula.errorReporting` is a member-level change and must not introduce any additional top-level symbol.

## Must remain byte-identical
- `lib/nebula_sdk.dart`
- `governance/public_api.txt`

The existing barrel already exports `capabilities.dart` and `nebula.dart`; adding another barrel export is forbidden.

## Internal-only invariant
No existing `lib/src/error_reporting/**` top-level implementation type becomes public except the new interface declared in `capabilities.dart`. In particular the following remain internal-only: report/store/sender/budget/retry/normalizer/provider/transport types and concrete `ErrorReportingClient`.

## Forbidden
- Any Backend mutation.
- Any App/NFC Writer mutation or SDK repin.
- Provider integration.
- Analytics mutation.
- `lib/nebula_sdk.dart` mutation.
- `governance/public_api.txt` mutation.
- `lib/src/foundation/**` or `lib/src/transport/**` mutation.
- Expanding the frozen method signature, adding result/input DTOs, or exposing trusted app/installation/platform identity to callers.
- Adding native crash/minidump/ANR semantics.
- Adding public store/sender/budget/provider types.
- Any Task Board/Sprint Board mutation by the Implementation Agent.

If implementation requires any path or symbol beyond the exact frozen write-set/surface, STOP and return a Delivery Note identifying the gap; do not expand scope.

## Verification
- Task Source Guard `OBS-SDK-ERROR-API-V1-002` PASS.
- Cross Repo Guard PASS.
- `git diff --check` PASS.
- Exact production write-set check PASS.
- `lib/nebula_sdk.dart` and `governance/public_api.txt` byte-identical to execution base.
- API surface tool PASS at exactly `126` symbols with only `NebulaErrorReporting` added.
- Focused Error Reporting/public-surface tests PASS.
- Full analyzer PASS/no regression.
- Full SDK tests/governance/secret scan PASS.
- Delivery Note records exact base/candidate, path diff, 125→126 proof, unchanged-path hashes, and confirms Backend/App/provider/Analytics mutation = 0.

## Exit
Delivery goes to independent SDK Review. A PASS does not authorize Backend ingest, App integration, provider integration, or Analytics implementation. Coordinator performs merge and canonical closure separately.
