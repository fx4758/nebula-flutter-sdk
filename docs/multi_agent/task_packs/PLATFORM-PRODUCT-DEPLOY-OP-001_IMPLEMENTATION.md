# PLATFORM-PRODUCT-DEPLOY-OP-001 — Product Deployment Operator Implementation
- ID：PLATFORM-PRODUCT-DEPLOY-OP-001
- Owner: Backend Platform Coding Agent
- Reviewer: Backend Review Agent
- Execution repo：`../flypost_backend`
- Execution branch：`platform/product-deploy-op-001`
- Execution remote: `origin`
- Platform API mode：`NONE`
- SDK public API mode：`READ_ONLY`
- Product adapter rule: `ADAPTER_FIRST`

## Gate
`OPEN_IMPLEMENTATION` after `PLATFORM-PRODUCT-DEPLOY-ARCH-001 = DONE / CLOSED_REVIEW_PASS`. Contract authority: `docs/multi_agent/contracts/PRODUCT_DEPLOYMENT_OPERATOR_V1.md`. Backend authority: `root/FlyPostAPI Dev@d9ad6c3c0e9186e574081e22d88450d93542fd29`.

## Authorized implementation surface
Expected narrow write set:
```text
cmd/productctl/**
internal/module/product/deployment_operator.go
internal/module/product/deployment_operator_test.go
docs/evidence/PLATFORM-PRODUCT-DEPLOY-OP-001/**
```
No schema/migration/router/admin-auth/API/SDK/App/provider files.

## Required behavior
Implement exactly the reviewed `PRODUCT_DEPLOYMENT_OPERATOR_V1` contract. Generic only; no Nearvia/NFC Writer constants or product defaults.

Required tests include exact-match idempotency, mismatch fail-closed, duplicate/conflict fail-closed, audit-chain append/failure rollback, Snowflake-generated ID, invalid app_key/region rejection, no secret output, dry-run no mutation, and CLI argument validation. Full `go test ./...` is mandatory.

## Exit
Coding delivers one exact candidate to review only. No self-review, no direct protected-branch push, no staging mutation and no Task Board mutation. Coordinator may authorize staging use only after exact Formal/CI + independent Backend APPROVED + merge/post-merge quality.
