# Execution Status

Last verified: 2026-08-03

## Current baseline

| Item | Status | Evidence |
| --- | --- | --- |
| Independent package scaffold | DONE | `pubspec.yaml`, `lib/` |
| AI task router and architecture | DONE | `docs/00..06`, `AGENTS.md` |
| Public API excludes App Secret | DONE | `NebulaOptions` only exposes public `appId` |
| F0 contract tests/CI | READY | F0-04/F0-05 |
| Real backend integration | BLOCKED | Requires F0 contract freeze and explicit authorization |
| App migration | BLOCKED | Requires F1/F2 and App repository access |

## Task board

| ID | State | Owner | Notes |
| --- | --- | --- | --- |
| F0-01 | DONE | Codex | Initial architecture and compilable contract scaffold |
| F0-02 | READY | - | Freeze bootstrap/session sequence with flypost |
| F0-03 | READY | - | Legacy HMAC compatibility and sunset plan |
| F0-04 | READY | - | Contract fixtures/error mapping |
| F0-05 | READY | - | CI/API surface/secret scan |
| F1-01..F6 | BLOCKED | - | Follow dependencies in implementation plan |

## Next recommended task

`F0-02`: compare flypost routes, middleware and `sdk/CONTRACT.md`; produce a Mobile Bootstrap/User Session contract without changing backend code. Any missing backend endpoint must be recorded as a dependency, not invented in this SDK.
