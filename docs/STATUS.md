# Execution Status

Last verified: 2026-08-03

## Current baseline

| Item | Status | Evidence |
| --- | --- | --- |
| Independent package scaffold | DONE | `pubspec.yaml`, `lib/` |
| AI task router and architecture | DONE | `docs/00..06`, `AGENTS.md` |
| Public API excludes App Secret | DONE | `NebulaOptions` only exposes public `appId` |
| AI governance G0-G2 baseline | DONE | policy, guard, exception registry, PR/CI gates |
| Governance regression after task transition | BLOCKED | G0-04: test fixture hard-codes `F0-02 READY` |
| F0 contract tests/CI | READY | F0-04/F0-05 |
| Real backend integration | BLOCKED | Requires F0 contract freeze and explicit authorization |
| App migration | BLOCKED | Requires F1/F2 and App repository access |

## Task board

| ID | State | Owner | Notes |
| --- | --- | --- | --- |
| F0-01 | DONE | Codex | Initial architecture and compilable contract scaffold |
| F0-02 | DONE | Architect@3cb52e5 | Current-vs-target audit, trust/session contract and coding handoff frozen |
| F0-03 | READY | - | Legacy HMAC compatibility and sunset plan |
| F0-04 | READY | - | Contract fixtures/error mapping |
| F0-05 | READY | - | CI/API surface/secret scan |
| G0-01 | DONE | Codex | Guard PASS; SEC-MOBILE-SECRET negative probe exits 1 |
| G0-02 | DONE | Codex@4c89302 | 23 isolated pass/fail/false-positive cases; all Rule IDs covered |
| G0-03 | BLOCKED | - | Requires F0-04 API contract fixture |
| G0-04 | READY | Coding AI | Make invalid-state fixture select/insert its own task; no architecture changes |
| F1-01..F6 | BLOCKED | - | Follow dependencies in implementation plan |
| FB-01 | READY | - | flypost target fixtures and error allocation; docs/09 ownership |
| FB-02 | BLOCKED | - | Installation identity owner module; depends FB-01 |
| FB-03 | BLOCKED | - | Installation proof/replay middleware; depends FB-02 |
| FB-04 | BLOCKED | - | App-bound session rotation/logout; depends FB-01/FB-02 |
| FB-05 | BLOCKED | - | Router and abuse isolation; depends FB-03/FB-04 |
| FS-01 | BLOCKED | - | SDK installation contracts; depends FB-01 fixtures |
| FS-02 | BLOCKED | - | SDK session state machine; depends FS-01/FB-04 |
| FC-01 | BLOCKED | - | Cross-repository compatibility; depends FB/FS tasks |

## Next recommended task

`G0-04`: a coding AI fixes `tool/governance_test.dart` so tests create/select their own fixture task instead of requiring `F0-02` to remain `READY`. Acceptance: all 23+ cases pass while F0-02 remains DONE; no architecture or policy semantics change. After G0-04, start `FB-01` in flypost.
