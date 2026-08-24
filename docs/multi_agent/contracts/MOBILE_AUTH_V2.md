# Mobile Auth Contract V2 — Email-First Multi-Provider Authentication

> Status: ARCHITECTURE FREEZE CANDIDATE
> Date: 2026-08-24
> Baseline SDK: `450dbd2864c1fb8a9fd9ef4bffca327552f132fe`
> Baseline Backend: FlyPostAPI `Dev` @ `c9220eaa725a797a40a94c6b1e3970a69b2931f5`

## 1. Decision

Nebula Mobile Auth V2 supports four first-class login methods:

```text
EMAIL_PASSWORD   default primary method
PHONE_CODE       supported optional method; existing compatibility retained
APPLE            OAuth provider
GOOGLE           OAuth provider
```

Apps decide presentation order. The Platform contract does not encode product name, screen order, region UI, or commercial policy.

`PHONE_CODE` is not deprecated. Existing mobile phone-code requests remain valid and keep their current session semantics.

V1-compatible phone login remains:

```json
{
  "provider": "PHONE",
  "phone": "13800000000",
  "code": "123456"
}
```

No V2 implementation may remove PHONE, silently rewrite it to EMAIL, or require an EMAIL account before phone login.

## 2. Email/password — primary method

Login remains on the canonical session-creation endpoint:

```http
POST /api/v1/mobile/auth/login
```

```json
{
  "provider": "EMAIL",
  "email": "user@example.com",
  "password": "<secret>"
}
```

Rules:
- email identity lookup uses the deterministic canonical key defined below;
- password is never logged, returned, persisted in plaintext, included in analytics, or placed in push payloads;
- failed login does not disclose whether the email exists, is frozen, pending deletion, or has another provider;
- successful login issues the existing installation-bound access/refresh session; refresh/logout semantics do not change.

### Email canonical identity key

V2 MUST NOT leave email identity normalization to database collation or provider-specific heuristics. The server canonical key is deterministic:

1. trim leading/trailing Unicode whitespace;
2. normalize the complete address to Unicode NFC;
3. split into one non-empty local part and one non-empty domain; display-name/comment forms are rejected at the API boundary;
4. apply Unicode default case folding to the local part;
5. canonicalize the domain with IDNA2008/UTS-46 non-transitional processing, then lowercase its ASCII A-label form;
6. join as `canonical_local@canonical_domain`;
7. do not apply provider-specific dot removal, plus-tag stripping, Gmail/Yahoo rules, or mailbox alias guessing.

The canonical key must be <=254 UTF-8 bytes. The original request value is not an identity key. All register/login/reset lookups and uniqueness checks use exactly this canonical key.

## 3. Phone/SMS code — supported optional method

Existing endpoints remain supported:

```http
POST /api/v1/mobile/auth/code/send
POST /api/v1/mobile/auth/login
```

Code-send body remains compatible:

```json
{"phone":"13800000000"}
```

Login remains `provider=PHONE` with `phone + code`. Phone login may create a first user account exactly as V1 does. Apps may place this under “Other sign-in methods”; the backend and SDK must not infer UI priority from provider type.

## 4. Apple / Google OAuth

Third-party login uses the same session-creation endpoint:

```json
{
  "provider": "OAUTH",
  "oauth_provider": "APPLE",
  "oauth_code": "<short-lived provider authorization code>"
}
```

or `oauth_provider=GOOGLE`.

Rules:
- accepted OAuth providers in V2 are exactly APPLE and GOOGLE;
- provider authorization code is exchanged/verified server-side by a real provider adapter;
- the authoritative `app_id` from InstallationProof selects that App's provider configuration and accepted client/audience; client-supplied fields can never select another App's client ID, audience, redirect identity, secret, or key material;
- provider verification MUST validate the official exchange result and signed identity material: signature/JWKS (or provider-equivalent trust chain), issuer, configured audience/client ID, expiry/not-before where present, and a non-empty provider subject;
- authorization codes are single-use credentials: no automatic login retry after an exchange attempt, no raw-code persistence/logging, and provider replay/reuse failure is terminal `invalid_credentials`;
- if a selected provider flow requires PKCE verifier or nonce material that is absent from this V2 request, that flow MUST remain disabled until a contract/public-surface amendment adds the required typed proof;
- client-supplied subject/openid/email is never authoritative;
- only the server-verified provider subject may become the provider identity key; provider credentials/tokens are never written into `user_account.provider_uid` directly;
- the old placeholder behavior “code == provider UID” is forbidden and remains unreachable;
- raw provider credentials are not persisted or logged.

## 5. Email registration and verification

Email registration is separate from login.

### Send verification/reset code

```http
POST /api/v1/mobile/auth/email/code/send
```

```json
{
  "email": "user@example.com",
  "purpose": "REGISTER"
}
```

V2 purposes: `REGISTER` and `RESET_PASSWORD`. Verification codes are purpose-bound, single-use, expire within 10 minutes, and a newly issued code invalidates the prior active code for the same target+purpose. The endpoint returns a generic accepted response and does not expose account existence.

### Complete registration

```http
POST /api/v1/mobile/auth/email/register
```

```json
{
  "email": "user@example.com",
  "password": "<secret>",
  "code": "123456"
}
```

On success: verify code+purpose, create/bind EMAIL identity, create the password credential using the frozen Argon2id policy below, mark email verified, and issue the normal installation-bound user session. The response uses the same token/user shape as login.

### Production email-code delivery

`REGISTER` and `RESET_PASSWORD` are not production-ready unless the code reaches the target through a real email delivery adapter. The current Backend `GatewaySender` sandbox behavior (`sandbox_EMAIL_*` accepted without external I/O) MUST NOT satisfy Auth V2 production acceptance. Deterministic/fake delivery is allowed only in dev/test under explicit non-production configuration.

Production rules:
- provider/SMTP/API credentials are server-side secrets and are never returned to SDK/Apps;
- the auth endpoint becomes enabled for an App only when its production email sender is configured and health-checked;
- a delivery failure invalidates the newly issued verification code and returns a safe low-cardinality availability error;
- outage/error behavior must not become an account-existence oracle;
- raw verification codes are never logged, persisted in notification delivery payloads, analytics, or error reports.

## 6. Password reset

```http
POST /api/v1/mobile/auth/email/password/reset
```

```json
{
  "email": "user@example.com",
  "code": "123456",
  "new_password": "<secret>"
}
```

Successful password reset MUST invalidate all pre-reset user sessions before returning success. Backend implementation may use authoritative token-version invalidation plus persistent session-family revocation, but the observable contract is unambiguous: every access/refresh credential issued before the successful reset becomes invalid. Code-send and reset failures preserve anti-enumeration behavior. Authenticated password change is a separate follow-up operation.

## 7. Persistence

Existing generic identity tables remain authoritative: `user_global`, `user_account`, `user_identity`, `user_token`. `user_account.Provider` already models PHONE/APPLE/GOOGLE/EMAIL and remains provider-neutral.

Baseline persistence has a hard compatibility gap that V2 Backend migration MUST close before EMAIL is enabled: both `user_account.provider_uid` and `user_identity.provider_uid` are currently `VARCHAR(128)`, while the frozen EMAIL canonical key permits up to 254 UTF-8 bytes. V2 MUST widen the relevant provider-UID storage to at least 254 UTF-8 bytes with byte-stable/binary comparison for identity keys; truncation is forbidden.

Authoritative EMAIL uniqueness is the database uniqueness guard on `user_identity(provider=EMAIL, provider_uid=canonical_email)`. Registration creates the corresponding EMAIL `user_account` and `user_identity` in one transaction; concurrent duplicate creation must lose on the database uniqueness guard, never on an application-only find-then-create race. Migration preflight MUST detect incompatible duplicate/colliding legacy rows and abort rather than delete, merge, or rewrite accounts automatically.

Email password material MUST NOT be stored in `user_account.provider_uid`, `user_identity.provider_uid`, or `user_global`. V2 introduces a dedicated password-credential record keyed to the EMAIL account identity, with at least:

```text
user_account_id
password_hash
password_algorithm
password_version
verified_at
created_at
updated_at
```

Exact migration/table naming is Backend-owned; credential data is private and never appears in API responses.

### Password hash policy V1

Password credential version 1 uses **Argon2id** with minimum memory 19 MiB, minimum 2 iterations, minimum parallelism 1, a CSPRNG salt of at least 16 bytes per credential, and output of at least 32 bytes. The stored hash encoding MUST be self-describing/versioned (for example PHC format) so parameters and salt are recoverable without plaintext. Implementations may raise work factors after capacity measurement but may not go below these floors.

Verification uses a vetted constant-time implementation. Plaintext or reversible password storage is forbidden. `password_algorithm/password_version` are authoritative migration metadata. On successful login, credentials below the current policy are rehashed with fresh salt before/with session issuance. A future KDF/parameter change increments the policy version and never reinterprets old hashes. Optional server-side pepper is a separate key-management decision and does not replace per-credential random salt.

## 8. Account linking

V2 does not silently merge accounts because two providers return the same email. Google email == EMAIL identity or Apple relay email == existing email MUST NOT trigger automatic account merge. Explicit authenticated account linking is a later contract.

## 9. Session and installation trust — unchanged

The following remain exactly as V1/RC1:
- installation bootstrap and proof precede user authentication;
- login sessions bind to App + installation;
- access token is memory-only on client;
- refresh token is secure-storage-only;
- refresh rotation is single-flight and atomic;
- refresh reuse revokes the session family;
- logout is access-token + installation-proof protected and idempotent;
- caller provider fields never author app_id/installation_id.

Auth V2 changes credential acquisition, not session trust.

## 10. Validation / abuse controls

Minimum bounds:
- email input: non-empty, <=254 UTF-8 bytes before canonicalization; canonical key must also be <=254 UTF-8 bytes and follow §2 exactly;
- password: 8..128 UTF-8 bytes at API boundary;
- verification code: exactly 6 decimal digits;
- OAuth provider: enum allowlist;
- OAuth code: non-empty, <=4096 UTF-8 bytes;
- per-IP, per-installation and per-target limits before expensive provider/KDF work;
- email-code and SMS-code have independent target budgets;
- credentials and personal identifiers are prohibited from logs/analytics/error reports.

## 11. Error semantics

Apps receive low-cardinality safe categories, including:

```text
invalid_credentials
verification_invalid_or_expired
rate_limited
temporarily_unavailable
provider_unavailable
session_revoked
invalid_installation
```

Provider raw errors remain server-side.

## 12. SDK V2 direction

The SDK continues PHONE while adding EMAIL and real OAuth:

```dart
NebulaLoginRequest.email(email: ..., password: ...)
NebulaLoginRequest.phone(phone: ..., code: ...)
NebulaLoginRequest.oauth(provider: NebulaOAuthProvider.apple, code: ...)
NebulaLoginRequest.oauth(provider: NebulaOAuthProvider.google, code: ...)
```

Registration/reset require dedicated typed request methods. Apps must not hand-author JSON or endpoint paths. Exact public symbols require a dedicated SDK Public Surface Story; this freeze does not authorize `lib/**` mutation.

## 13. App presentation rule

Platform does not decide visual priority. One consumer may present:

```text
Email                 primary
Continue with Apple   third-party
Continue with Google  third-party
Other sign-in methods
  -> Phone / SMS code
```

Another consumer may put PHONE first. Both consume the same contract.

## 14. Migration / rollback

- Existing PHONE clients continue working without forced upgrade.
- Existing refresh tokens/sessions do not migrate merely because Auth V2 ships.
- OAuth placeholder remains disabled until real adapters deploy.
- EMAIL can be feature-gated per App during rollout without removing PHONE.
- Rollback may disable EMAIL/OAuth while keeping PHONE/refresh/logout available.
- No migration rewrites PHONE identities into EMAIL identities.

## 15. Out of scope

Account linking UI/API, passkeys/WebAuthn, TOTP/MFA, enterprise SSO, magic-link login, product-specific family/profile models, push-token registration, and provider purchasing/credential provisioning.
