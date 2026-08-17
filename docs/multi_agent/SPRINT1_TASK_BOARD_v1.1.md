# Sprint 1 Task Board — Human Mirror

> **NON-SSOT.** Machine authority: `task_board.json`. State writes are Coordinator-only.

| Story | State | Execution Repo | Execution Branch | Platform API | SDK Public API |
|---|---|---|---|---|---|
| S1-F01-001 Adapter Boundary | **DONE / PASS** | Flutter NFC Writer | `s1/f01-001-adapter` | NONE | READ_ONLY |
| S1-F01-002 Bootstrap Lifecycle | **READY / UNBLOCKED** | Flutter NFC Writer | `s1/f01-002-bootstrap` | NONE | READ_ONLY |
| S1-F02-001 Backend Runtime Config Audit | READY | flypost_backend | `s1/f02-001-runtime-config-audit` | READ_ONLY | NONE |
| S1-F02-002 SDK Config Closure | READY after F02-001 DONE | nebula-flutter-sdk | `s1/f02-002-sdk-config` | NONE | READ_ONLY |
| S1-F03-001 SDK Release Workflow | **DONE / REVIEW PASS** | nebula-flutter-sdk | `s1/f03-001-release` | NONE | READ_ONLY |
| S1-F03-002 API Surface CI Gate | **READY** | nebula-flutter-sdk | `s1/f03-002-api-gate` | NONE | READ_ONLY |

One Story = one execution repo. Agent returns Delivery Note only; Coordinator records state. Agent summary is not acceptance evidence.
