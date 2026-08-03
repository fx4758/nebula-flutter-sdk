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
| F0 contract tests/CI | DONE | F0-04 fixtures + F0-05 CI/API surface/secret scan complete |
| Real backend integration | BLOCKED | Requires F0 contract freeze and explicit authorization |
| App migration | BLOCKED | Requires F1/F2 and App repository access |

## Task board

| ID | State | Owner | Notes |
| --- | --- | --- | --- |
| F0-01 | DONE | Codex | Initial architecture and compilable contract scaffold |
| F0-02 | DONE | Architect@3cb52e5 | Current-vs-target audit, trust/session contract and coding handoff frozen |
| F0-03 | DONE | Codex | Legacy HMAC sunset plan: docs/11 — protocol-level keep/adapt/remove, version/store-build cutoff via 12003, P0-P5 stages |
| F0-04 | DONE | Codex | Contract fixtures: real-encoding JSON fixtures (bootstrap req/resp, proof canonical, error mapping) + 8 fixture-driven tests |
| F0-05 | DONE | Codex | CI complete: dart test + api_surface + secret_scan in workflow; SEC-SCAN value-pattern guard (25 regression cases) |
| G0-01 | DONE | Codex | Guard PASS; SEC-MOBILE-SECRET negative probe exits 1 |
| G0-02 | DONE | Codex@4c89302 | 23 isolated pass/fail/false-positive cases; all Rule IDs covered |
| G0-03 | DONE | Codex | API surface snapshot tool + version gate: 63 symbols frozen, API-SURFACE guard rule, drift regression case |
| G0-04 | DONE | Codex | Fixtures select/insert their own task rows; no architecture or policy change |
| BR-01 | DONE | Codex | flypost `1bae972`: AI Admin route ownership converged to module/ai; router tests green |
| F1-01..F6 | BLOCKED | - | Follow dependencies in implementation plan |
| FB-01 | DONE | Codex | flypost `d3f6502`: fixtures frozen, 12001-12004 allocated, envelope reconciled; targets not-implemented |
| FB-02 | DONE | Codex | flypost `71eff85`: installation owner module, migration 030, /mobile/bootstrap implemented |
| FB-03 | DONE | Codex | flypost `c7f022a`: proof/replay middleware, pkg/proof, migration 031 public key |
| FB-04 | DONE | Codex | flypost `77a10cb`: session rotation/logout, jwt jti fix, migration 032 |
| FB-05 | DONE | Codex | flypost `fd3f799`: router isolation, trusted claims rate/idempotency keys, CORS header allowlist (MB-08/09/11) |
| FS-01 | DONE | Codex | SDK installation contracts: typed bootstrap/identity, key/token-store/proof Ports, canonicalization tests |
| FS-02 | DONE | Codex | SDK session state machine: serialized §7 transitions, single-flight refresh, logout cleanup, typed errors |
| FC-01 | DONE | Codex | Cross-repo reconciliation: 8 scenarios anchored both sides, contract artifacts + 12 consistency assertions |

## Next recommended task

`F1-01` in nebula-flutter-sdk: HTTP transport, envelope, timeout and cancellation (docs/03 F1, network) — the F0 stage is now fully DONE (F0-01..05: architecture, frozen contract, sunset plan, fixtures, CI/secret scan; G0-01..04 governance baseline). F1 kernel can start.
