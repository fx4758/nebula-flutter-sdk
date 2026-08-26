# PRODUCT_DEPLOYMENT_OPERATOR_V1

Story: `PLATFORM-PRODUCT-DEPLOY-ARCH-001`
Governance base: `nebula-flutter-sdk main@4a38224abdede7eda0ac34073210a2e5293f47dd`
Backend runtime authority inspected: `root/FlyPostAPI Dev@d9ad6c3c0e9186e574081e22d88450d93542fd29`

## 1. Purpose and boundary

Freeze a generic, low-frequency Product App deployment operator for a governed deployment host when no interactive admin session is available.

This contract is architecture only. It authorizes no Backend mutation, no staging/production mutation, and no product registration by itself. `PLATFORM-PRODUCT-DEPLOY-OP-001` remains blocked until this contract is independently reviewed, merged, and separately opened by Coordinator.

The operator is intentionally narrower than a network management API:

- local CLI process only;
- no new HTTP/admin/network endpoint;
- no HTTP client fallback to `/api/v1/admin/products`;
- no admin login, password reset, token minting, or impersonation;
- no direct SQL insert/update/delete;
- no schema migration;
- no App credential, entitlement, OAuth/provider, SDK, or consumer-App mutation.

Nearvia is only the first caller. The implementation MUST contain no Nearvia, NFC Writer, package/bundle, provider, AppKey, name, region, or App ID default.

## 2. Existing Backend invariants that MUST be reused

Canonical `FlyPostAPI Dev@d9ad6c3...` already owns the Product App invariants:

1. `product.AppInput` normalization:
   - `app_key` lower-case + trim;
   - `name` trim;
   - `default_region_code` upper-case + trim;
   - `app_key` regex `^[a-z][a-z0-9_-]{1,63}$`.
2. `product_app.app_key` has a unique index.
3. Product App IDs use `snowflake.NextID()`.
4. Product App creation is committed through `Repository.CreateApp(...)`.
5. `Repository.CreateApp(...)` creates the row and appends `PRODUCT_APP_CREATE / PRODUCT_APP` audit in the same enclosing transaction; audit failure therefore fails the mutation.
6. `audit.Write` enters the current tamper-evident `sys_audit_log` chain.
7. Production Snowflake authority is a database-coordinated worker lease from `snowflake.Start(... NewMySQLWorkerIDProvider(repository.DB) ...)`, not a fixed worker ID.

The operator MUST compose these invariants; Coding may not fork a second Product App repository, ID generator, audit chain, or validation model.

## 3. Process authority and configuration

Process authority comes from **both**:

- explicit access to an approved deployment host; and
- that host's already-governed Backend DB configuration.

The CLI MUST load/validate Backend configuration through the existing config path and initialize the existing repository DB connection. It MUST NOT accept DB DSN/user/password, admin password, JWT, provider secret, or App credential as command-line flags or stdin payload.

`CONFIG_PATH` / existing Backend environment selection may select the already-governed host configuration. This contract does not authorize pointing a developer machine at production, inventing a production origin, or changing deployment configuration.

The CLI MUST NOT run migrations. Missing/incompatible schema is a hard failure.

## 4. Snowflake authority

Any execution that may create a Product App MUST acquire the same MySQL-coordinated Snowflake worker lease pattern used by `cmd/api`:

```text
snowflake.Start(
  context,
  snowflake.NewMySQLWorkerIDProvider(repository.DB),
  bounded TTL,
)
```

Requirements:

- no `snowflake.Init(<fixed worker>)` in deployed operator code;
- lease acquisition failure is fail-closed before mutation;
- lease loss/ID generation failure is fail-closed;
- lease is closed/released on command exit;
- read-only `inspect` / pure dry-run MUST NOT allocate an ID merely for preview.

## 5. Audit actor contract

For this CLI only:

```text
admin_id = 0
meaning  = SYSTEM_DEPLOYMENT_OPERATOR
source   = local:productctl
```

`admin_id=0` is a reserved sentinel for this deployment-operator path, not a real administrator identity. At canonical Backend `d9ad6c3...`, `sys_audit_log.admin_id` has no FK/non-zero constraint and no existing canonical audit writer uses actor `0`; this contract reserves that unused value for `SYSTEM_DEPLOYMENT_OPERATOR`. The CLI MUST NOT accept an arbitrary/non-zero admin ID and MUST NOT claim to act as a human admin.

Every actual Product App creation MUST still use the existing Product Repository transaction and audit path, with:

```text
action      PRODUCT_APP_CREATE
target_type PRODUCT_APP
target_id   generated Product App ID
admin_id    0
ip/source   local:productctl
```

Audit append failure rolls back Product App creation. Dry-run/exact-match inspection produces no audit mutation.

## 6. V1 command surface

V1 exposes only:

```text
productctl inspect  --app-key <key>

productctl register \
  --app-key <key> \
  --name <name> \
  --default-region <region> \
  --status active \
  [--description <text>] \
  [--owner <text>] \
  [--dry-run]
```

Hard rules:

- `register` requires explicit `--app-key`, `--name`, `--default-region`, and `--status`;
- the only V1 register status is `active` (`1`); disabled/inactive creation is rejected;
- `description` and `owner` are optional generic Product App fields and default to empty strings;
- there are no product-specific defaults;
- V1 has no update, delete, restore, disable, archive, credential, entitlement, provider, or OAuth subcommand.

Rollback/disable of an already-created Product App is a separately-authorized normal control-plane operation. `productctl` MUST NOT erase/rewrite registration history.

## 7. Input validation

After existing Product App normalization, the operator MUST additionally fail before DB mutation when:

- `default_region_code` does not match `^[A-Z][A-Z0-9_-]{0,15}$`;
- name exceeds the `product_app.name` limit (128 chars) or is empty;
- description exceeds 512 chars;
- owner exceeds 128 chars;
- status is not active for `register`.

Existing `app_key` normalization/regex remains authoritative and MUST be reused, not copied with divergent semantics.

## 8. Unscoped lookup and conflict model

Idempotency is keyed by normalized `app_key` and MUST inspect **all physical rows, including soft-deleted rows**.

Reason: `product_app.app_key` is uniquely indexed while the GORM model has `DeletedAt`; a scoped query can hide a soft-deleted row that still owns the unique key. Treating that state as absent would produce an unsafe create attempt.

Lookup result rules:

### 8.1 Zero physical rows

- `inspect`: return `NOT_FOUND` read-only.
- `register --dry-run`: return `WOULD_CREATE` with no ID allocation/audit/write.
- `register`: create through the existing Product Repository transaction.

### 8.2 Exactly one row

Fail closed when any of the following is true:

- soft-deleted row;
- status is not active;
- persisted identity fields do not exactly match the normalized requested spec.

Exact-match comparison fields are:

```text
app_key
name
description
owner
default_region_code
status
```

`id`, timestamps, and deletion metadata are not requested identity fields.

If the row is active and all fields match:

- return the existing server-generated ID as success;
- do not update the row;
- do not write another audit event.

### 8.3 More than one physical row

Return `AMBIGUOUS_CONFLICT` and perform zero mutation even if one row appears to match. Database uniqueness should make this impossible in healthy schema; detecting it is a corruption/fail-closed guard.

## 9. Concurrent identical registration

Two identical operators may race after both observe absence. The database unique key remains the final arbiter.

If create fails due to an `app_key` uniqueness race, the operator MAY perform one unscoped re-read:

- exactly one active exact-match row -> return existing ID/success;
- anything else -> fail closed.

No retry may update/overwrite the winner.

## 10. Internal implementation seam

`cmd/productctl/**` is a composition root only. Product semantics stay in `internal/module/product/deployment_operator.go`.

The reviewed implementation should expose an internal-module seam equivalent to:

```go
type DeploymentOperator struct { /* Product repository dependency */ }

func NewDeploymentOperator(db *gorm.DB) *DeploymentOperator
func (o *DeploymentOperator) Inspect(in AppInput) (DeploymentResult, error)
func (o *DeploymentOperator) Register(in AppInput) (DeploymentResult, error)
```

Exact symbol spelling may vary only if the independently reviewed implementation preserves this ownership split:

- command parses flags/config and renders sanitized result;
- Product module owns normalization, unscoped conflict detection, idempotency and repository transaction dispatch;
- existing Repository owns Product App persistence/audit transaction;
- existing Snowflake package owns ID generation authority.

No router/handler/admin-auth change is required or authorized.

## 11. Result and exit semantics

Machine-readable stdout contains only public Product identity/result fields, for example:

```text
outcome            CREATED | EXISTS | WOULD_CREATE | NOT_FOUND
app_id             server-generated ID when an existing/created row is known
app_key
name
default_region_code
status
```

Description/owner are compared internally for idempotency but MUST NOT be emitted by default; V1 stdout stays limited to the public identity/result fields above.

Recommended process exit classes:

```text
0 success / read-only result
2 invalid command or input
3 conflict / inactive / deleted / ambiguous state
4 DB / audit / Snowflake / authority failure
```

Exact numeric codes may be implemented as constants, but tests MUST freeze deterministic mapping.

Neither stdout nor stderr may print DB credentials/DSN, admin credentials/JWT, App credentials, provider/OAuth secrets, config dumps, private keys, or raw secret-bearing environment variables. Operational errors must be classified/sanitized.

## 12. Dry-run semantics

`register --dry-run` performs the same normalization, validation, and unscoped conflict checks as real registration, but:

- no Product App write;
- no audit write;
- no Snowflake ID allocation;
- no mutation of any table;
- exact existing active match returns `EXISTS`;
- absent returns `WOULD_CREATE`;
- any conflict returns the same conflict class real registration would return.

## 13. Explicitly forbidden behavior

Implementation MUST NOT:

- add or call a deployment/admin HTTP endpoint;
- call `/api/v1/admin/products` as fallback;
- reset/create an admin account to gain authority;
- accept admin ID/user/password/JWT to impersonate a user;
- use raw `INSERT/UPDATE/DELETE` SQL for Product App mutation;
- modify schema/migrations;
- hard-code Nearvia/NFC Writer/App IDs/AppKeys/names/regions;
- issue/rotate App credentials;
- mutate entitlement, provider, OAuth, user/auth, SDK, or consumer App state;
- use a fixed production Snowflake worker ID;
- silently resurrect/update/disable a conflicting Product App;
- hide a soft-deleted row during idempotency checks;
- expose secrets in command output.

## 14. Verification contract

`PLATFORM-PRODUCT-DEPLOY-OP-001` must include focused automated coverage for at least:

1. exact active match -> existing ID, zero write;
2. absent -> Snowflake-created ID + Product App row + audit row;
3. audit failure -> Product App transaction rollback;
4. invalid app_key -> reject;
5. invalid/oversize region -> reject;
6. name/description/owner length validation;
7. inactive row -> conflict;
8. soft-deleted row -> conflict;
9. field mismatch -> conflict;
10. duplicate/ambiguous physical rows -> conflict where test schema permits simulation;
11. dry-run absent -> `WOULD_CREATE`, zero DB/audit/ID mutation;
12. dry-run exact -> `EXISTS`, zero mutation;
13. uniqueness race reconciliation -> exact winner may resolve to existing success; mismatch fails;
14. CLI required-flag/status validation;
15. no secret-bearing output;
16. Snowflake lease acquisition/authority failure -> zero Product App mutation.

Tests MUST NOT require a live production DB. Test seams may inject SQLite/test DB and deterministic ID/lease behavior, but deployed code must use the real MySQL-coordinated Snowflake lease.

Exit gate:

```text
exact source candidate
+ governance/Formal SUCCESS
+ focused operator tests
+ full go test ./...
+ independent Backend Review APPROVED
```

Only after merge and post-merge quality may Coordinator separately authorize any staging use of `productctl`.

## 15. Security disposition

A deployment host that can read the Backend DB configuration and reach the DB is already privileged. Adding a remotely reachable management API would expand the attack surface by adding route exposure, authentication/session handling, credential lifecycle, rate limiting, and remote abuse paths.

This local operator does not reduce host-security requirements; it narrows the new capability to an already-privileged execution boundary and preserves existing Product App validation, uniqueness, Snowflake allocation, transaction, and tamper-evident audit semantics.

Therefore V1 deliberately chooses a local audited operator over a new network deployment API.
