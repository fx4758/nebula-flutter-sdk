# AUTH-V2-BE-001 — Backend Mobile Auth V2 Implementation
- ID：AUTH-V2-BE-001
- Owner：Backend Auth V2 Agent
- Reviewer：Backend Review Agent
- Execution repo：`../flypost_backend`
- Execution branch：`auth/v2-be-001-backend`
- Execution remote：`origin`
- Platform API mode：`IMPLEMENT_FROZEN_CONTRACT`
- SDK public API mode：`NONE`
- Product adapter rule：`ADAPTER_FIRST`
- Required upstream：`AUTH-V2-ARCH-001 = DONE / REVIEW PASS`
- Contract authority：`docs/multi_agent/contracts/MOBILE_AUTH_V2.md`
- ACR authority：`docs/multi_agent/reports/ACR-MOBILE-AUTH-V2-001.md`

## Fresh-base rule
Registration-time FlyPostAPI canonical is `Dev@c9220eaa725a797a40a94c6b1e3970a69b2931f5`.

Execution MUST fresh-fetch `origin/Dev`, use that exact SHA, and create a dedicated worktree. If Dev advanced, reconcile migration numbering and overlapping auth/config/router files mechanically. Never reset canonical Dev and never implement from a stale sibling checkout.

## Goal
Implement only the frozen Mobile Auth V2 Backend authority:
- EMAIL + password registration/login/recovery;
- PHONE + SMS remains wire-compatible with current session semantics;
- APPLE + GOOGLE real server-side OAuth exchange/verification;
- production-capable email verification/reset delivery boundary;
- installation-bound access/refresh/logout trust remains unchanged.

No SDK or consumer App production mutation is authorized.

## Authorized paths
Primary scope:
```text
internal/core/identity/**
internal/model/user.go
internal/migrations/049_mobile_auth_v2.sql   # if 049 remains free
internal/router/router.go                    # registration/composition delta only
internal/router/*auth*test.go
internal/config/config.go                    # typed non-secret auth config only
configs/*.yaml                               # placeholders/schema only; no secrets
```
Additional auth-owned files may be created under `internal/core/identity/**` for password policy, email delivery port/adapter, OAuth adapters/config selection and focused tests. Reuse existing JWT/session/proof/rate-limit infrastructure; do not redesign it.

## Schema / migration
Use migration 049 only if still free after fresh-fetch; otherwise use the next free number and record why. It may only:
1. widen relevant `user_account.provider_uid` and `user_identity.provider_uid` storage for <=254-byte canonical email without truncation;
2. make provider-UID identity comparison byte-stable as frozen;
3. preserve/enforce DB uniqueness of `user_identity(provider, provider_uid)`;
4. add dedicated EMAIL password credential persistence with versioned algorithm/hash metadata and verified timestamp;
5. fail closed on incompatible duplicate/colliding identity rows; never auto-merge/delete/rewrite accounts.

Existing PHONE identities/session rows must not be migrated into EMAIL.

## Frozen EMAIL behavior
Canonical identity key follows exactly: Unicode trim -> NFC -> validate local/domain -> Unicode default case fold local part -> IDNA2008/UTS-46 non-transitional domain -> lowercase ASCII A-label domain -> join. No provider-specific dot removal, plus stripping or alias guessing.

Routes:
```text
POST /api/v1/mobile/auth/login
  provider=EMAIL + email + password
POST /api/v1/mobile/auth/email/code/send
  email + purpose=REGISTER|RESET_PASSWORD
POST /api/v1/mobile/auth/email/register
  email + password + code
POST /api/v1/mobile/auth/email/password/reset
  email + code + new_password
```
Email codes are purpose-bound, single-use, <=10 minutes, and new issuance invalidates the prior active same-target/same-purpose code. Send/reset failures preserve account anti-enumeration.

Password policy is frozen Argon2id V1:
- memory >=19 MiB; iterations >=2; parallelism >=1;
- per-credential CSPRNG salt >=16 bytes; output >=32 bytes;
- self-describing/versioned encoding;
- vetted constant-time verification;
- rehash after successful login when stored policy is below current policy.
Plaintext/reversible password storage/logging/analytics/error-reporting is forbidden.

Successful password reset MUST invalidate all pre-reset access/refresh session authority before returning success. Reuse existing token/session-family revocation; do not weaken refresh reuse detection or installation binding.

## PHONE compatibility red line
Existing production wire remains valid:
```json
{"provider":"PHONE","phone":"13800000000","code":"123456"}
```
Existing `/api/v1/mobile/auth/code/send`, PHONE first-account creation, installation-bound token issuance, refresh rotation/reuse revocation and logout semantics MUST remain unchanged. EMAIL must not be required before PHONE. Existing legacy auth compatibility routes remain unless a separately frozen deprecation Story exists.

## Frozen OAuth behavior
Canonical request:
```json
{"provider":"OAUTH","oauth_provider":"APPLE|GOOGLE","oauth_code":"<short-lived authorization code>"}
```
Rules:
- only APPLE and GOOGLE;
- old placeholder `code == provider UID` remains forbidden/unreachable;
- authoritative InstallationProof `app_id` selects that App's OAuth client/audience/config;
- request fields cannot select another App's client ID/audience/redirect identity/secret/key;
- real exchange and signed identity verification covers provider trust chain/JWKS or equivalent, issuer, configured audience/client ID, expiry/not-before where present, and non-empty subject;
- only server-verified subject becomes provider identity key;
- authorization code is single-use; no automatic retry after exchange; replay/reuse is terminal invalid credentials;
- raw code/provider token/credential is never persisted or logged;
- no silent account merge because provider email matches EMAIL/another provider;
- if selected flow requires nonce/PKCE proof absent from the frozen request, keep it disabled and return for contract/public-surface amendment.

## Production email delivery
Current generic notification `GatewaySender` sandbox is NOT production Auth V2 evidence.

Implement an auth-owned real email delivery boundary/adapter with explicit production configuration and fail-closed readiness. A provider-neutral SMTP/API adapter is allowed, but credentials are external secrets and never enter Git/tests/logs.

Production rules:
- real external delivery required before EMAIL register/reset is production-ready for an App;
- sender config/health fails closed;
- delivery failure invalidates the newly issued code;
- error category cannot reveal account existence;
- raw code cannot enter generic notification-delivery persistence, analytics or error reports.

Do not rewrite generic notification product semantics under this Auth Story. If a shared-port change proves unavoidable, STOP for Architecture review.

## Rate / abuse bounds
Implement before expensive KDF/provider work:
- per-IP, per-installation and per-target budgets;
- email-code and SMS-code target budgets remain independent;
- email <=254 UTF-8 bytes before/after canonicalization;
- password 8..128 UTF-8 bytes;
- verification code exactly 6 decimal digits;
- OAuth provider enum allowlist;
- OAuth code non-empty <=4096 UTF-8 bytes.

Public errors remain low-cardinality; raw provider errors remain server-side.

## Forbidden
- SDK `lib/**`, SDK public API or consumer App mutation;
- removal/deprecation/semantic rewrite of PHONE/SMS;
- auto-link by matching email;
- enabling placeholder OAuth;
- provider credentials/private keys/client secrets in repo, fixtures, CI output or logs;
- plaintext/reversible passwords or raw verification codes in durable DB/log/analytics/error reports;
- generic account linking API/UI, passkeys, TOTP/MFA, SSO, magic-link, push registration;
- unrelated notification/payment/AI/runtime-config redesign;
- direct push to protected `Dev`;
- implementation Agent editing Coordinator Task Board state.

## Required verification
At minimum:
- migration schema + rerun/idempotency/preflight tests;
- canonical-email normalization/byte-limit/collision/concurrency tests;
- Argon2id policy/verify/rehash/no-plaintext tests;
- EMAIL register/login/reset + anti-enumeration + code single-use/expiry/purpose tests;
- password reset revokes all prior session authority;
- PHONE compatibility/session non-regression tests;
- Apple/Google adapter tests with fake HTTP/JWKS or equivalent; wrong issuer/audience/signature/expired/replay/cross-App-client cases fail;
- real-email adapter config/delivery-failure fail-closed tests with fake transport, no real secret;
- route contract/proof/rate-limit tests;
- `go test ./...` PASS;
- migration suite PASS;
- ArchGuard/Sentinel PASS;
- secret scan PASS;
- exact Forgejo PR CI PASS;
- independent Backend Review on exact candidate.

## Exit
Deliver Backend implementation only to `READY_FOR_REVIEW`. No self-review, no self-merge, no Task Board DONE. SDK Auth V2 remains unauthorized until this Story independently reviews, merges to FlyPostAPI `Dev`, and post-merge quality passes.
