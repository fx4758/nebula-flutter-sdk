# S1-F01-004 SDK Bootstrap Surface Closure
- ID：S1-F01-004
- Owner：SDK Core Agent D
- Depends：S1-F01-003
- Execution repo：`.`
- Execution branch：`s1/f01-004-sdk-bootstrap-surface`
- Platform API mode：`NONE`
- SDK public API mode：`CHANGE_APPROVED`

## Execution gate
**DONE / independent SDK Review PASS.** Canonical landing: `59dd960e38ad51c2bd60b59044dfa1698f3a7909`. Review evidence: `reports/S1-F01-004_INDEPENDENT_REVIEW.md`. This Story is no longer executable.

## Goal
Implement the minimum canonical SDK-owned bootstrap surface after contract re-freeze.

## Responsibility that must live in SDK
- `BootstrapEndpoints.bootstrap == "/api/v1/mobile/bootstrap"` or an equivalent public endpoint surface.
- Canonical `BootstrapRequest` serialization: exactly 11 keys, JSON null for absent optionals; no consumer Map duplication.
- Exact V2 validation: UTF-8 byte limits, P-256/Base64URL key semantics, nullable string attestation, 32 KiB body ceiling awareness.
- Typed bootstrap client returning `BootstrapResult` through existing `NebulaTransport`.
- At-most-one bounded retry, preserving the same immutable request values and `bootstrap_request_id`.
- Bootstrap-specific error mapping: current `50001` is server failure and MUST NOT fall through to `AuthenticationRequiredError`; `12003/12004` remain allocated-but-not-current-emission inputs.
- Preserve response semantics: `request_id` echoes `bootstrap_request_id`; `renew_after` is server-authoritative.
- Public export/API guard plus fixture/integration tests consuming `test/fixtures/bootstrap_contract_v2.json`.

## Forbidden
No Backend production change; no product-specific names/models; no private-key implementation in SDK core; no Asset/Payment/Notification/AI expansion.

## Acceptance
A consumer can bootstrap with typed SDK API without hardcoding path or wire maps; request/response/error/retry behavior matches the re-frozen contract; Product-name erasure PASS; full SDK tests/analyzer/governance/API-surface gates PASS.
