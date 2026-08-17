# OBS-SDK-COMPOSITION-LIFECYCLE-V1-001 — Mobile Observability Composition Lifecycle Freeze

Task ID: `OBS-SDK-COMPOSITION-LIFECYCLE-V1-001`

Status: **READY / FREEZE ONLY**

## Problem

NFC Writer `NEBULA-APP-001D` exact final-pin preflight found a delivery lifecycle gap after `OBS-SDK-COMPOSITION-V1-002` closure:

```text
NebulaErrorReporting.reportCaughtError(...)
→ durable local capture only

ErrorReportingClient.flush()
→ internal only

NebulaMobileObservability
→ no lifecycle/flush trigger

composition
→ no timer/scheduler/background worker
```

The App therefore cannot legally trigger delivery of persisted Error Reporting backlog without importing SDK internals or rebuilding transport/store pieces.

## Goal

Freeze the smallest composition-level lifecycle seam that can trigger both already-frozen domains without exposing queue/retry/provider controls or ErrorReporting internals.

Preferred candidate shape for independent review:

```dart
NebulaMobileObservability.flush()
```

The exact member name is not frozen by this task pack. The contract review must decide it.

## Required semantics

The freeze must preserve all of these invariants:

- existing public top-level symbol count remains 127;
- no new public ErrorReporting queue/result/retry/store/sender/client types;
- one composition-level lifecycle trigger may invoke Analytics flush + internal ErrorReporting flush;
- domain failures are isolated/fail-soft: one domain must not suppress the other;
- caller receives no queue/result/retry details;
- construction remains zero-network;
- no timer/background worker is required by V1;
- App calls the lifecycle trigger only after first frame / foreground resume;
- SDK still owns batching, retry, defer, trust recovery, ACK handling and budgets;
- `NebulaErrorReporting` remains `reportCaughtError(...)` only;
- Backend/platform wire contracts remain unchanged.

## Authorized scope

Freeze delivery is docs/governance only:

```text
docs/multi_agent/contracts/MOBILE_OBSERVABILITY_SDK_LIFECYCLE_V1.md
docs/multi_agent/reports/OBS-SDK-COMPOSITION-LIFECYCLE-V1-001*.md
```

Forbidden in this Story:

```text
lib/**
governance/api_surface.snapshot
Backend/App/provider mutation
new top-level public symbol
public ErrorReporting queue/retry controls
background worker/timer implementation
```

## Exit

Independent Architecture Review must approve the exact lifecycle contract before Coordinator may register a CHANGE_APPROVED SDK implementation Story. NFC Writer `NEBULA-APP-001D` remains BLOCKED until implementation closes and the App performs one new final immutable SDK repin/re-audit.
