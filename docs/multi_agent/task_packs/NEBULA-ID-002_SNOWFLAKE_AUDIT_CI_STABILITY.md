# NEBULA-ID-002 Snowflake/Audit CI Stability Hardening

- ID: `NEBULA-ID-002`
- Owner: Backend Platform / CI Owner
- Depends: none; this is independent of `S1-F02-003`.
- Execution repo: `../flypost_backend`
- Execution branch: `nebula-id-002-snowflake-audit-ci-stability`
- Governance state: `READ_ONLY` for Implementation Agent; Task Board is Coordinator-owned.
- Delivery: execution-repo commit plus Delivery Note only; no Task Board mutation.
- Platform API mode: `NONE`
- SDK public API mode: `NONE`
- Adapter-first: `ADAPTER_FIRST`

## Incident

FlyPostAPI PR #14's Runtime Config-focused validation passed, but its Quality Baseline / backend job failed in the unrelated `internal/pkg/audit.TestWriteDetailCrossInstanceNoFork` with `snowflake: clock rollback exceeds bound`. Runtime Config, Router, checkout, SDK, and App are not part of this Story.

## Goal

Eliminate or deterministically classify the intermittent Snowflake/Audit test-process instability without weakening production Snowflake guarantees:

- no duplicate ID allocation;
- lease-loss remains fail-closed;
- large clock rollback remains bounded failure;
- no unbounded spin, sleep-based masking, or silent fallback.

## Allowed

- `internal/pkg/snowflake/**`
- `internal/pkg/audit/*_test.go`
- focused test support solely used by those tests
- CI retry/isolation only if diagnosis proves it is an infrastructure-only remedy
- Delivery Note

## Forbidden

- `internal/module/runtimeconfig/**`
- `internal/router/**`
- S1-F02-003 candidate mutation
- Runtime Config endpoint/DTO/wire/error/trust changes
- SDK/App/NFC changes
- worker-ID lease semantics weakening
- replacing the failure with arbitrary sleep or unbounded retry

## Required evidence

1. Start from a fresh fetched Backend `Dev` SHA and record it.
2. Determine whether the failure is test-global default-generator interference, a cross-instance worker identity issue, real clock behavior, or CI topology; cite exact file/line evidence.
3. Run `go test ./internal/pkg/audit -run '^TestWriteDetailCrossInstanceNoFork$' -count=50`.
4. Run `go test ./internal/pkg/audit -race -count=20`.
5. Run the relevant Snowflake tests, including lease-loss and bounded-clock-rollback behavior.
6. Run `go test ./...` at least once on the exact candidate.
7. If any stabilization is CI-only, prove production semantics and test determinism remain separately covered.

## Review boundary

This Story does not unblock or modify the frozen S1-F02-003 implementation. Once the independent CI defect is closed, PR #14 must be rerun unchanged.
