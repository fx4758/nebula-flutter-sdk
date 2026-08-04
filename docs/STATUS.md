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
| F0 contract tests/CI | DONE | F0-R9 Security Closure complete (review 3, 2026-08-04): 11-item closure verified incl. self-contained HTTP success-path (testsupport SQLite+miniredis, no DSN); barrier concurrency + iss/aud negatives added |
| Real backend integration | BLOCKED | Requires F0 contract freeze and explicit authorization |
| App migration | BLOCKED | Requires F1/F2 and App repository access |

## Task board

| ID | State | Owner | Notes |
| --- | --- | --- | --- |
| F0-01 | DONE | Codex | Initial architecture and compilable contract scaffold |
| F0-02 | DONE | Architect@3cb52e5 | Current-vs-target audit, trust/session contract and coding handoff frozen |
| F0-03 | DONE | Codex | Legacy HMAC sunset plan: docs/11 — protocol-level keep/adapt/remove, version/store-build cutoff via 12003, P0-P5 stages |
| F0-04 | DONE | Codex | Fixtures/cross-repo matrix synced to ADR-F008 (mobile/auth/*); chunked rejection via MaxBytesReader |
| F0-05 | DONE | Codex | CI complete: dart test + api_surface + secret_scan in workflow; SEC-SCAN value-pattern guard (25 regression cases) |
| G0-01 | DONE | Codex | Guard PASS; SEC-MOBILE-SECRET negative probe exits 1 |
| G0-02 | DONE | Codex@4c89302 | 23 isolated pass/fail/false-positive cases; all Rule IDs covered |
| G0-03 | DONE | Codex | API surface snapshot tool + version gate: 63 symbols frozen, API-SURFACE guard rule, drift regression case |
| G0-04 | DONE | Codex | Fixtures select/insert their own task rows; no architecture or policy change |
| BR-01 | DONE | Codex | flypost `1bae972`: AI Admin route ownership converged to module/ai; router tests green |
| F1-01..F6 | BLOCKED | - | Follow dependencies in implementation plan |
| FB-01 | DONE | Codex | flypost `d3f6502`: fixtures frozen, 12001-12004 allocated, envelope reconciled; targets not-implemented |
| FB-02 | DONE | Codex | flypost `71eff85`: installation owner module, migration 030, /mobile/bootstrap implemented |
| FB-03 | DONE | Codex | Middleware order fixed (coarse rate + BodyLimit before Proof); io.Copy bounded; TestHTTPProofFlowPenetratesToHandler |
| FB-04 | DONE | Codex | Token class isolation + iss/aud/type; access resurrection closed; device/bind out via ADR-F009 |
| FB-05 | DONE | Codex | Route inventory asserts order; oauth/login unregistered + feature-switch guard (12004) |
| FS-01 | DONE | Codex | SDK installation contracts: typed bootstrap/identity, key/token-store/proof Ports, canonicalization tests |
| FS-02 | DONE | Codex | SDK session state machine: serialized §7 transitions, single-flight refresh, logout cleanup, typed errors |
| FC-01 | DONE | Codex | TestE2EMobileTrustClosure renamed TestServiceTrustFlow; HTTP proof flow + chunked tests added; fixtures synced |
| R3-CLOSURE | DONE | Codex | Third-review (2026-08-04) 11-item security closure — no R10 introduced: coarse IP limiter (ClientIP only, anti-spoof), refresh cannot resurrect session (TouchIfExists EXPIRE, not SET), user/admin/refresh parser+midware separation, Token() fail-closed (503 on DB err/nil), barrier concurrent refresh (exactly-one-wins), access invalidation via Token middleware, HTTP 50001 must-fail, chunked body-limit proof, iss/aud true-negatives, self-contained HTTP closure (testsupport), SDK proof.dart path ADR-F008, committed+pus |
| R4-CLOSURE | DONE | Codex | Fourth-review (2026-08-03) 3-item closure — all gates green: **P0** Admin subject-validator split (`validateUserSubject`→user_global status/token_version; `validateAdminSubject`→sys_admin_user status only, never user_global) + HTTP bidirectional isolation test (6 cases, proven true-positive vs old impl); **CI-blocker** SDK Governance `api_surface` comment-stripper rewritten as char-level scanner + path-wildcard regression test (snAPSHOT untouched, 63 symbols PASS); **P1** reverse-proxy trusted CIDRs (`server.trusted_proxy_cidrs`, default empty=fail-closed, startup validation, misconfig→SetTrustedProxies(nil)) + 3-scenario HTTP bucket test (trusted/non-trusted/spoofed-XFF). Verified: go test ./... , dart test (58), dart analyze, governance/api_surface/secret_scan all PASS; ArchGuard 0 blocking/7 warning (testsupport exempted), Sentinel 0. F0 sign-off ready for F1. |

## Next recommended task

`F1-01` in nebula-flutter-sdk: HTTP transport, envelope, timeout and cancellation (docs/03 F1, network). **F0 sign-off is complete**: F0-R9 fourth-review closure (2026-08-03) verified 3/3 items (P0 Admin subject split + HTTP isolation, CI-blocker Governance dashboard PASS, P1 trusted-proxy CIDR config) — all gates green (go test ./..., dart test 58, dart analyze, governance/api_surface/secret_scan PASS; ArchGuard 0 blocking/7 warning, Sentinel 0). F0 can formally sign into F1.
