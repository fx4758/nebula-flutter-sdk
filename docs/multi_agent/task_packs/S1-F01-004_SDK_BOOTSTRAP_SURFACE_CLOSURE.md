# S1-F01-004 SDK Bootstrap Surface Closure
- ID：S1-F01-004
- Owner：SDK Core Agent D
- Depends：S1-F01-003 + S1-F01-004A/B/C owner recovery
- Execution repo：`.`
- Execution branch：`s1/f01-004-sdk-bootstrap-surface-r2`
- Platform API mode：`NONE`
- SDK public API mode：`CHANGE_APPROVED`

## Execution gate
**READY / R2 CLEAN REPLAY ONLY.** Registered Owner contributions `S1-F01-004A/B/C` are DONE and Coordinator assembled them serially into `integration/s1-f01-004-r2-owner-baseline @ f11fb53d6ff6e6ec689797133e78f6b7a9219a05`. SDK Core must start from exactly that commit on `s1/f01-004-sdk-bootstrap-surface-r2` and replay only the frozen `01-sdk-core.patch`. The old mixed-owner branch/commits remain evidence only. Independent SDK Review R2 is still mandatory before DONE.

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

## R2 replay constraint
SDK Core may replay only `01-sdk-core.patch` SHA-256 `b0b23df76fd75c4134de20089b02cdfe4c17197384bc49d5bd239e41b0ba6e80` from exact base `f11fb53d6ff6e6ec689797133e78f6b7a9219a05`. Mixed-owner commits `19fc097/e101c7a/a7ccd6c/4aa233e` are evidence/proposals only and must not be cherry-picked as the final candidate.

## Acceptance
A consumer can bootstrap with typed SDK API without hardcoding path or wire maps; request/response/error/retry behavior matches the re-frozen contract; fractional int64 response values reject with `FormatException`; Product-name erasure PASS; owner history matches the registered write sets; full SDK tests/analyzer/governance/API-surface gates PASS; independent SDK Review R2 PASS.
