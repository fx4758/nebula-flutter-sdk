# FC-01 — Cross-Repository Reconciliation

Contract artifacts only: this document and `test/cross_repo_contract_test.dart`
contain **no duplicate production implementation**. They pin the F0-02 target
protocol facts on both sides so that a drift on either repository fails loudly.

- SDK side: `nebula-flutter-sdk` (this repo), commits `3e9ed32` (FS-01), `e313691` (FS-02).
- Server side: `flypost`, branches `codex/fb-05-router-isolation` (FB-01..05).

## Scenario matrix (docs/09 §4)

| # | Scenario | SDK anchor | flypost anchor | Status |
| --- | --- | --- | --- | --- |
| 1 | fresh install → bootstrap → phone login → authenticated request | `cross_repo_contract_test.dart` (fields round-trip, no App Secret), FS-01 `BootstrapRequest/Result` | `TestMobileBootstrapFixtures`, `TestMobileTargetRoutesImplemented`, `TestMobileProofHeaders` | ✅ both sides |
| 2 | access expiry → one refresh → all callers resume | FS-02 `NebulaSession.refresh` single-flight (concurrent callers share one Future) | `TestRefreshRotatesInPlace` (in-place rotation, no new row) | ✅ both sides |
| 3 | refresh replay → session family revoked | FS-02 `SessionRevokedError` → `REVOKED` + `SecurityAlert`, local tokens cleared | `TestRefreshReuseRevokesFamily` (durable revocation 12002) | ✅ both sides |
| 4 | logout → old access and refresh rejected | FS-02 `signOut` clears access/refresh even on network failure; route contract | `TestLogoutUnderTokenMiddleware`, `TestLogoutIdempotent` | ✅ both sides |
| 5 | App A token at App B rejected | FS-01/02 `tokenNamespace(environment, appId)` isolation; mismatch → refresh rejection | `TestRefreshAppInstallationMismatchRejected`, `TestRefreshMismatchedTokenRejected` | ✅ both sides |
| 6 | installation key loss → new bootstrap, old key rejected | FS-01 `InstallationKeyPort.generateKeyPair` = fresh identity per call; private key never leaves key store | FB-02 installation owner (reinstall = new identity, old key never recovered, docs/08 §4.3) | ✅ both sides |
| 7 | legacy build remains on legacy chain until cutoff | SDK target canonicalization is the 7-segment proof form; no legacy HMAC string in SDK auth contracts | `TestLegacyAuthRoutesStillRegistered`, `TestRouteInventoryMiddlewareClasses` | ✅ both sides (cutoff is F0-03, not yet) |
| 8 | high-cost saturation does not block bootstrap/login | SDK honors one bounded bootstrap retry with same `bootstrap_request_id` (docs/08 §3) | `TestAbuseIsolationAIfloodDoesNotConsumeBootstrapBucket` | ✅ both sides |

## Frozen wire facts (shared)

| Fact | SDK | flypost |
| --- | --- | --- |
| bootstrap request fields | `kBootstrapRequestFields` (11 fields, docs/08 §4.1) | `TestMobileBootstrapFixtures` |
| bootstrap response fields | `kBootstrapResultFields` (10 fields, docs/08 §4.2) | `TestMobileBootstrapFixtures` |
| proof canonical input | `ProofCanonicalInput.canonicalize()` = `V1\nMETHOD\nPATH\nTIMESTAMP\nNONCE\nBODY_SHA256\nTOKEN_SHA256` | `internal/pkg/proof` (FB-03) |
| proof headers | `X-Installation-Token`, `X-Proof-Timestamp`, `X-Proof-Nonce`, `X-Device-Proof`, `X-Request-Id` | `TestMobileProofHeaders`, `TestCORSPreflightAllowlistIncludesMobileHeaders` |
| error codes | `nebulaCodeInstallationInvalid=12001` … `nebulaCodeTemporarilyUnavailable=12004` | `internal/pkg/errcode/errcode.go` (FB-01 allocation) |
| response envelope | `{code, data}` only, no `msg` | `TestEnvelopeCodeDataOnly` |
| authentication schemes | target proof only; no App Secret / legacy HMAC fallback in SDK core | `TestRouteInventoryMiddlewareClasses` (bootstrap ≠ 40001 chain) |

## Reconciliation check (local, SDK side)

```bash
dart test test/cross_repo_contract_test.dart   # 12 assertions, all green
```

Server-side anchors run in flypost with `go test ./internal/router/...` (all green).
