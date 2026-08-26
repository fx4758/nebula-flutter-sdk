# PLATFORM-PRODUCT-DEPLOY-ARCH-001 — Product Deployment Operator Freeze
- ID：PLATFORM-PRODUCT-DEPLOY-ARCH-001
- Owner: Platform Deployment Architecture Agent
- Reviewer: Platform Architecture Review Agent
- Execution repo：`.`
- Execution branch：`architecture/platform-product-deploy-arch-001`
- Execution remote: `hub`
- Platform API mode：`NONE`
- SDK public API mode：`READ_ONLY`
- Product adapter rule: `ADAPTER_FIRST`

## Goal
Freeze a generic, audited, non-network deployment operator for low-frequency Product App registration when no interactive admin session is available on a governed deployment host.

The trigger is Nearvia staging registration, but the design MUST contain no Nearvia-specific runtime branch, package ID, AppKey default, or provider semantics.

## Required architecture contract
Write only:
`docs/multi_agent/contracts/PRODUCT_DEPLOYMENT_OPERATOR_V1.md`

The contract must freeze at minimum:
- local CLI only; no new HTTP/admin/network endpoint;
- process authority derives from explicit deployment-host access plus existing Backend DB configuration; the CLI never accepts/prints DB or admin credentials itself;
- reserved audit actor `admin_id=0` means `SYSTEM_DEPLOYMENT_OPERATOR` only for this CLI; it MUST NOT impersonate a real admin user;
- audit source/IP marker is deterministic (for example `local:productctl`), and Product App mutation must still append the existing tamper-evident audit chain in the same transaction;
- reuse Product App normalization, uniqueness, Snowflake numeric ID generation and repository/service transaction semantics; no direct SQL insert;
- `register` is idempotent by `app_key`: exact active match returns existing ID/success; field mismatch, duplicate ambiguity, inactive/conflicting record, audit failure or DB failure is fail-closed;
- explicit `--app-key`, `--name`, `--default-region`, status; there is no consumer-specific default;
- dry-run/read-only inspection supported;
- stdout contains only public product identity/result fields; no config/DB/JWT/provider secrets;
- no App credential issue/rotate, entitlement mutation, provider config, OAuth config, user/admin password operation, schema migration or production endpoint selection;
- command must be testable without a live production DB; exact source CI + focused tests + full `go test ./...` required;
- rollback is archive/disable through normal separately-authorized control plane, never delete/rewrite history.

## Security disposition required
The contract must explicitly justify why local DB-authorized CLI is narrower than adding a network deployment API, and state that shell/DB deployment authority is already privileged. If independent review rejects `admin_id=0` audit semantics, Architecture must revise the actor model before implementation; Coding may not invent one.
