# S1-F01-004 SDK Bootstrap Surface Closure
- ID：S1-F01-004
- Owner：SDK Core Agent D
- Depends：S1-F01-003
- Execution repo：`.`
- Execution branch：`s1/f01-004-sdk-bootstrap-surface`
- Platform API mode：`NONE`
- SDK public API mode：`READ_ONLY`

## Execution gate
This Story is WAIT. After S1-F01-003 DONE, Coordinator must explicitly set WAIT -> READY and `sdk_public_api_mode -> CHANGE_APPROVED` before any production edit.

## Goal
Implement the minimum canonical SDK-owned bootstrap surface after contract re-freeze.

## Responsibility that must live in SDK
- `BootstrapEndpoints.bootstrap` or the re-frozen equivalent endpoint constant.
- Canonical `BootstrapRequest` wire serialization; no consumer Map duplication.
- Typed bootstrap transport/client call returning `BootstrapResult`.
- Frozen bounded retry/idempotency behavior preserving the same bootstrap request id.
- Typed handling of frozen bootstrap error classes.
- Public export/API guard plus fixture/integration tests.

## Forbidden
No Backend production change; no product-specific names/models; no private-key implementation in SDK core; no Asset/Payment/Notification/AI expansion.

## Acceptance
A consumer can bootstrap with typed SDK API without hardcoding path or wire maps; request/response/error/retry behavior matches the re-frozen contract; Product-name erasure PASS; full SDK tests/analyzer/governance/API-surface gates PASS.
