# S1-F01-003 Bootstrap Contract Reconciliation
- ID：S1-F01-003
- Owner：SDK Contract Agent D
- Execution repo：`.`
- Execution branch：`s1/f01-003-bootstrap-contract-reconcile`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`NONE`
- Related ACR：`reports/ACR-SDK-BOOTSTRAP-001.md`

## Goal
Reconcile bootstrap wire truth before any production SDK bootstrap work. This Story is contract/tests/docs only.

## Required authority
- FlyPostAPI remote `Dev` at Story start; currently verified `956981c119b01a0c1b4bf0793a20bed8f31d1180`.
- `contracts/SDK_BOOTSTRAP_CONTRACT_FREEZE.md`.
- `test/fixtures/bootstrap_request.json` / `bootstrap_response.json`.
- `lib/src/auth/installation.dart` plus cross-repo/fixture tests.

## Must resolve
1. Required vs optional diagnostic/routing fields.
2. `attestation` exact wire type/nullability.
3. Exact per-field limits.
4. Canonical request serialization ownership.
5. Endpoint constant obligation.
6. Bootstrap retry/idempotency and error mapping inputs.

## Forbidden
No SDK `lib/**` production change; no Backend production diff; no App implementation; no silent wire change.

## Acceptance
- One internally consistent re-frozen contract matching authoritative Backend and fixtures, or a separately authorized Platform contract change.
- Tests express the final contract without test-local assumptions contradicting production types.
- Independent reviewer PASS and ACR decision updated.
- Only after DONE may Coordinator promote S1-F01-004.
