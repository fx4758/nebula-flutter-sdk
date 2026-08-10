# ACR-SDK-BOOTSTRAP-001 — Bootstrap Wire Contract / SDK Surface Gap

## Metadata
- ACR ID：ACR-SDK-BOOTSTRAP-001
- Raised by：Architecture Coordinator after NFC Writer Reference Bootstrap preflight
- Related Story：S1-F01-002 / S1-F01-003 / S1-F01-004
- Triggering Product：NFC Writer
- Date：2026-08-10
- Severity：BLOCKING
- Requested Platform API mode：READ_ONLY（no Backend production change requested）

## Observed Fact

Independent repo verification:

1. Authoritative Backend `Dev=956981c119b01a0c1b4bf0793a20bed8f31d1180` exposes `POST /api/v1/mobile/bootstrap` and `BootstrapRequest` in `internal/core/installation/service.go`.
2. Frozen SDK contract requires `BootstrapEndpoints.bootstrap = "/api/v1/mobile/bootstrap"`; no SDK ref currently defines `BootstrapEndpoints`.
3. Pinned SDK `543894c0...` has `BootstrapRequest.validate()` and `BootstrapResult.fromJson()`, but production `BootstrapRequest` has no canonical `toJson()` and SDK has no public bootstrap client. `HttpTransport` JSON-encodes `request.body`, so a consumer would otherwise duplicate the wire map/path.
4. Existing request serialization is only test-local in `test/cross_repo_contract_test.dart`.
5. Four-way drift exists: frozen doc, SDK model, fixture/tests and Backend disagree on request requiredness/nullability/limits. Backend uses string attestation and accepts empty evidence; fixture uses `null`; SDK uses `String?`. Backend caps app/installation/request IDs at 64, locale/region at 64 and public key at 1024, while pinned SDK currently allows broader limits.

## Gate analysis

- This is a shared SDK capability, not NFC Writer business behavior. StarSprout and FlyPost need the same installation-bootstrap semantics.
- Product-name erasure passes: removing “NFC Writer” does not change the required API.
- App Adapter cannot safely solve it by hardcoding endpoint or duplicating wire fields; that would make the first consumer a second SDK implementation.
- No Backend production change is required if the contract is reconciled to authoritative Backend + fixtures first.

## Options

### Option A — Keep Platform unchanged; reconcile then close SDK surface
- Reconcile the frozen contract/tests to authoritative Backend + fixture behavior.
- Re-freeze exact request field/type/nullability/limits.
- Implement endpoint constant + canonical request serialization + typed bootstrap client in SDK.
- Then repin App to the new immutable SDK commit.

### Option B — Change Backend to match stale prose
- Tighten Backend requiredness/types/limits first.
- Larger compatibility/security/review surface with no current product need.

## Recommended Decision

**Option A.** Do not change Backend production behavior merely to make stale prose true.

## Scope / security

- Platform API：READ_ONLY; no production change intended.
- SDK public API：requires explicit CHANGE_APPROVED only after S1-F01-003 re-freeze.
- Database/migration：none.
- Installation private key remains host secure-store owned and never enters the wire body.
- No App Secret, Provider secret, Asset/Payment/AI expansion.

## Temporary Workaround

**None.** NFC Writer must not hardcode `/api/v1/mobile/bootstrap` or duplicate the test-local wire mapping in production.

## S1-F01-003 reconciliation delivery

Contract Agent delivery reconciled the request drift and found two additional response-fixture drifts: `renew_after` did not match the Backend 80% TTL point, and response `request_id` did not echo the paired `bootstrap_request_id`. Backend string caps are also UTF-8 byte limits; current Dart `String.length` validation is not equivalent. `environment` and `key_algorithm` are not bootstrap request wire fields.

Detailed matrix/evidence: `reports/S1-F01-003_BOOTSTRAP_CONTRACT_RECONCILIATION.md`. Re-freeze candidate: `contracts/SDK_BOOTSTRAP_CONTRACT_FREEZE.md` V2. Machine-readable oracle: `test/fixtures/bootstrap_contract_v2.json`.

## Decision
- CONTRACT AGENT VERDICT：RECONCILED / OPTION A
- INDEPENDENT REVIEW：PASS — `reports/S1-F01-003_INDEPENDENT_REVIEW.md`
- Decision：APPROVED / Option A
- Approved Platform API mode：READ_ONLY / Backend production change not requested
- Approved SDK public API mode：CHANGE_APPROVED for `S1-F01-004` only
- Contract version：CONTRACT-SDK-BOOTSTRAP V2 / FROZEN
- Follow-up：S1-F01-004 → App NEBULA-DEP-002 → S1-F01-002
