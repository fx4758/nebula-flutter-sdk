# Execution Status

Last verified: 2026-08-04

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
| F1-01 | DONE | Codex | SDK kernel network layer: `HttpTransport` (dart:io, zero runtime deps) — envelope decode `{code,data,request_id}`, connect+receive timeout, cancellation via `Future.any` + `client.close(force)` (propagates to socket, not future-drop), business-code→`NebulaApiException` mapping; `NebulaCancellationToken` + `NebulaTimeoutException`/`NebulaCancelledException`/`NebulaHttpException`; 10 new tests; api_surface 70 symbols, governance PASS, secret_scan PASS, dart analyze clean, 68 tests pass |
| F1-02 | DONE | Codex | User-session capability: `NebulaSessionAuth` implements `NebulaAuth` and wires the FS-02 `NebulaSession` state machine to `HttpTransport` — real login/refresh/logout HTTP calls (`/api/v1/mobile/auth/*`), proof headers (`X-Installation-Token`/`X-Device-Proof`, SHA-256 canonical per docs/08 §5), single-flight refresh inherited from the state machine (401 storm → 1 network call), typed error mapping via `classifySessionError`, `restoreSession` from `SecureTokenStore`, self-contained pure-Dart SHA-256 (`lib/src/foundation/sha256.dart`, zero deps); 14 new tests (login success/error/validation, restore+concurrent single-flight refresh, sign-out local-clear on remote failure, timeout/cancel mapping, proof-header attachment); api_surface 75 symbols, governance/secret_scan PASS, dart analyze clean, 82 tests pass |
| F1-03 | DONE | Codex | Storage ports + namespace: `StorageNamespace` (canonical `environment/app_id/user_id/key` per docs/02 §2, segment sanitization rejects `/`+NUL), `SecureStorage` Port + `InMemorySecureStorage` fake, `CacheStorage` Port + `InMemoryCacheStorage` fake (optional TTL hint, byte values); all exported from `nebula_sdk.dart` and registered in `governance/public_api.txt`; 14 new tests; api_surface 80 symbols, governance/secret_scan PASS, dart analyze clean, 96 tests pass. Frozen FS-01 `SecureTokenStore` (colon namespace) left untouched for backward compatibility |
| F1-04 | DONE | Codex | Foundation: `NebulaRequestId` (128-bit secure-random correlation id) + transport attaches `X-Request-Id` and prefers server-echoed `request_id`; `NebulaErrorCategory` + `classifyNebulaError` (exhaustive mapping over `NebulaException` types/codes/status); redacted logging Port `NebulaLogger`/`NebulaLogEvent`/`NebulaLogLevel` + `NoOpLogger` (privacy-by-default) + `RedactingLogger` + `redact`/`redactValues` (docs/02 §4: only request id/endpoint/result/duration); transport emits a redacted log event per call when a logger is injected; 14 new tests; api_surface 89 symbols, governance/secret_scan PASS, dart analyze clean, 110 tests pass. ADR-F010: `max_public_exports` 20→40 (frozen F1-F4 roadmap) |
| F1-05 | DONE | Codex | Kernel testing: public scriptable `FakeTransport implements NebulaTransport` (`lib/src/testing/fake_transport.dart` — FIFO enqueue response/error/handler, records `requests`, `pendingCount`; exported for host-app reuse) + `test/kernel_integration_test.dart` (13 tests) driving `NebulaSessionAuth` with no backend: login success/typed-error/rate-limit/5xx/timeout/cancel/unexpected, restore + 10× concurrent `getAccessToken` → exactly 1 refresh request (F1 exit), refresh revoked → local clear, refresh timeout → token preserved, sign-out local-clear on remote-logout failure. **F1 exit met**: all error paths verifiable via fake transport; concurrent refresh is one network call. api_surface 91 symbols, governance/secret_scan PASS, dart analyze clean, 123 tests pass |
| F2-01..F6 | BLOCKED | - | Follow dependencies in implementation plan |
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

`F2-01` in nebula-flutter-sdk: effective config/feature/version API contract (docs/03 F2, config, depends on flypost contract; blocked until the flypost config endpoints are frozen). **F1 is complete**: F1-01..F1-05 all DONE — kernel network layer, user session capability, storage ports + namespace, redacted logging/error classification/request ID, and the fake-transport kernel integration test. F1 exit criteria met: all error paths verifiable via `FakeTransport` without a real backend; concurrent refresh triggers exactly one network call. Gates green (dart test 123, dart analyze, governance/secret_scan PASS; api_surface 91 symbols).
