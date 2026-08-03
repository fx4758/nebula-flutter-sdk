# Execution Status

Last verified: 2026-08-03

## Current baseline

| Item | Status | Evidence |
| --- | --- | --- |
| Independent package scaffold | DONE | `pubspec.yaml`, `lib/` |
| AI task router and architecture | DONE | `docs/00..06`, `AGENTS.md` |
| Public API excludes App Secret | DONE | `NebulaOptions` only exposes public `appId` |
| AI governance G0-G2 baseline | DONE | policy, guard, exception registry, PR/CI gates |
| Governance regression after task transition | DONE | G0-04: GOV-TASK fixtures select/insert own task rows; 23 cases pass while F0-02 stays DONE |
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
| G0-04 | DONE | Codex | Fixtures select/insert their own task rows; no architecture or policy change |
| BR-01 | DONE | Codex | flypost `1bae972`: AI Admin route ownership converged to module/ai; router tests green |
| F1-01..F6 | BLOCKED | - | Follow dependencies in implementation plan |
| FB-01 | DONE | Codex | flypost `d3f6502`: fixtures frozen, 12001-12004 allocated, envelope reconciled; targets not-implemented |
| FB-02 | BLOCKED | - | Installation identity owner module; depends FB-01 |
| FB-03 | BLOCKED | - | Installation proof/replay middleware; depends FB-02 |
| FB-04 | BLOCKED | - | App-bound session rotation/logout; depends FB-01/FB-02 |
| FB-05 | BLOCKED | - | Router and abuse isolation; depends FB-03/FB-04 |
| FS-01 | BLOCKED | - | SDK installation contracts; depends FB-01 fixtures |
| FS-02 | BLOCKED | - | SDK session state machine; depends FS-01/FB-04 |
| FC-01 | BLOCKED | - | Cross-repository compatibility; depends FB/FS tasks |

## Next recommended task

`FB-02` in flypost: installation identity owner module (docs/09). BR-01 restored the flypost router test baseline; FB-01 froze the target protocol fixtures, error codes 12001-12004 and the `{code,data}` envelope.
