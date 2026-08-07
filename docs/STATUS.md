# Execution Status

Last verified: 2026-08-07

## Current baseline

| Item | Status | Evidence |
| --- | --- | --- |
| Independent package scaffold | DONE | `pubspec.yaml`, `lib/` |
| AI task router and architecture | DONE | `docs/00..06`, `AGENTS.md` |
| Public API excludes App Secret | DONE | `NebulaOptions` only exposes public `appId` |
| AI governance G0-G2 baseline | DONE | policy, guard, exception registry, PR/CI gates |
| F0 contract tests/CI | READY | F0-04/F0-05 |
| Real backend integration | BLOCKED | Requires F0 contract freeze and explicit authorization |
| App migration | BLOCKED | Requires F1/F2 and App repository access |

## Task board

| ID | State | Owner | Notes |
| --- | --- | --- | --- |
| F0-01 | DONE | Codex | Initial architecture and compilable contract scaffold |
| F0-02 | DONE | WorkBuddy@3cb52e5 | Mobile Bootstrap/User Session contract frozen (docs/08); backend-paired, no App Secret; attestation & oauth/login reserved as BLOCKED/RESERVED |
| F0-03 | DONE | WorkBuddy@851cacb | Legacy HMAC App Secret compatibility + sunset plan (docs/09); full sdk/dart capability inventory keep/adapt/remove |
| F0-04 | READY | - | Contract fixtures/error mapping |
| F0-05 | READY | - | CI/API surface/secret scan |
| G0-01 | DONE | Codex | Guard PASS; SEC-MOBILE-SECRET negative probe exits 1 |
| G0-02 | DONE | Codex@4c89302 | 23 isolated pass/fail/false-positive cases; all Rule IDs covered |
| G0-03 | BLOCKED | - | Requires F0-04 API contract fixture |
| F1-01..F6 | BLOCKED | - | Follow dependencies in implementation plan |

## Next recommended task

`F0-04`: establish API contract fixtures and error-code mapping. Build the frozen contract fixtures (request/response shapes, error categories, code→exception mapping) for the F0-02/F0-03 frozen contracts, enabling `G0-03` (API surface snapshot + version gate). Source: `flypost/sdk/CONTRACT.md` §5 error codes + `docs/08`/`docs/09`. No fabricated backend fields.
