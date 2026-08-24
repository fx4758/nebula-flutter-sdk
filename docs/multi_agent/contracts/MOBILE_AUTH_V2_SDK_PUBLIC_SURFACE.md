# Mobile Auth V2 — Dart SDK Public Surface Freeze

> Status: PUBLIC SURFACE FREEZE CANDIDATE
> Story: `AUTH-V2-SDK-001`
> Date: 2026-08-24
> SDK baseline: `main@1d7c89c7d453760e4c2e5c9670ead705b373ea40`
> Backend authority: FlyPostAPI `Dev@d9ad6c3c0e9186e574081e22d88450d93542fd29`
> Platform contract: `MOBILE_AUTH_V2.md`

## 1. Decision

Mobile Auth V2 extends the existing `NebulaAuth` capability. It does **not** create a second auth subsystem, a product-specific adapter in the SDK, or a caller-authored HTTP surface.

The public SDK supports these credential flows:

```text
PHONE + SMS code                 preserved
EMAIL + password                 added
APPLE authorization code         typed OAuth
GOOGLE authorization code        typed OAuth
EMAIL verification/reset code    dedicated typed operations
EMAIL registration               dedicated typed operation
EMAIL password reset             dedicated typed operation
```

Apps own provider ordering and UI. The SDK owns typed request construction, endpoint paths, InstallationProof transport and session integration. The Backend remains authoritative for identity canonicalization, credential verification, provider trust and session revocation.

## 2. Frozen top-level symbols

### Existing symbols retained

```dart
enum NebulaLoginProvider {
  phone,
  email,
  oauth,
}

final class NebulaLoginRequest { ... }
abstract interface class NebulaAuth { ... }
final class SessionEndpoints { ... }
sealed class NebulaSessionError implements Exception { ... }
```

`email` is an enum member, not a new top-level symbol. Existing `NebulaLoginProvider.phone` remains source- and wire-compatible.

### New public top-level symbols

Exactly four new top-level symbols are frozen:

```dart
enum NebulaOAuthProvider { apple, google }

enum NebulaEmailCodePurpose { register, resetPassword }

const int nebulaCodeInvalidCredentials = 10001;

final class InvalidCredentialsError extends NebulaSessionError {
  const InvalidCredentialsError({super.code, super.requestId})
      : super('invalid credentials');
}
```

No other new top-level Auth V2 symbol is authorized by this freeze.

### Predicted API surface

Current snapshot: `127` top-level symbols.

Frozen delta:

```text
+ NebulaOAuthProvider
+ NebulaEmailCodePurpose
+ nebulaCodeInvalidCredentials
+ InvalidCredentialsError
--------------------------------
127 -> 131
```

Members, constructors and endpoint fields do not create top-level entries in the current `tool/api_surface.dart` model. The later implementation Story must mechanically confirm that the only snapshot additions are these four symbols.

## 3. Login request surface

`NebulaLoginRequest` remains the single login-body owner.

### PHONE — unchanged

```dart
const NebulaLoginRequest.phone({
  required String phone,
  required String code,
});
```

Wire body remains exactly:

```json
{
  "provider": "PHONE",
  "phone": "13800000000",
  "code": "123456"
}
```

No EMAIL prerequisite, account conversion or provider priority is introduced.

### EMAIL — added

```dart
const NebulaLoginRequest.email({
  required String email,
  required String password,
});
```

Wire body exactly:

```json
{
  "provider": "EMAIL",
  "email": "user@example.com",
  "password": "<secret>"
}
```

### OAuth — typed and tightened

The existing public OAuth constructor is retained by name but its arbitrary provider string is removed:

```dart
const NebulaLoginRequest.oauth({
  required NebulaOAuthProvider oauthProvider,
  required String oauthCode,
});
```

Wire conversion is SDK-owned:

```text
NebulaOAuthProvider.apple  -> APPLE
NebulaOAuthProvider.google -> GOOGLE
```

Wire body exactly:

```json
{
  "provider": "OAUTH",
  "oauth_provider": "APPLE|GOOGLE",
  "oauth_code": "<authorization-code>"
}
```

The current untyped `String oauthProvider` is an intentionally disabled-placeholder-era surface. Auth V2 tightens that member to `NebulaOAuthProvider`; arbitrary provider strings are no longer accepted. This is an intentional source tightening for the previously non-production OAuth path. PHONE compatibility is unaffected.

No compatibility constructor accepting arbitrary provider strings may remain publicly reachable.

## 4. Validation rules

SDK validation mirrors Backend input bounds but does not become identity authority. Limits are measured as UTF-8 bytes, not Dart code-unit count.

```text
email             non-empty, valid UTF-8 representation, <=254 UTF-8 bytes
password          8..128 UTF-8 bytes
verification code exactly 6 ASCII decimal digits
OAuth code        non-empty, <=4096 UTF-8 bytes
OAuth provider    NebulaOAuthProvider only
```

The SDK may reject obviously malformed email input needed to construct a bounded request, but canonical EMAIL identity remains Backend-owned. The SDK MUST NOT implement provider-specific dot removal, plus-tag stripping, alias guessing, Gmail/Yahoo rules, or a second authoritative canonicalization algorithm.

Local validation fails before network I/O and does not log the rejected secret value.

## 5. Typed EMAIL verification purpose

```dart
enum NebulaEmailCodePurpose {
  register,
  resetPassword,
}
```

Wire mapping:

```text
register      -> REGISTER
resetPassword -> RESET_PASSWORD
```

No arbitrary string purpose is public.

## 6. `NebulaAuth` capability additions

Auth V2 extends the existing capability with exactly these operations. No dedicated second public Auth capability is introduced.

```dart
abstract interface class NebulaAuth {
  // Existing members remain.

  Future<void> sendEmailCode({
    required String email,
    required NebulaEmailCodePurpose purpose,
    NebulaCancellationToken? cancellationToken,
  });

  Future<void> registerEmail({
    required String email,
    required String password,
    required String code,
    NebulaCancellationToken? cancellationToken,
  });

  Future<void> resetEmailPassword({
    required String email,
    required String code,
    required String newPassword,
    NebulaCancellationToken? cancellationToken,
  });
}
```

No new request classes are public in V2. Named parameters keep the surface small while preserving compile-time typing for purpose and provider.

### `sendEmailCode`

- Requires an active InstallationProof context.
- Sends the typed purpose and email only.
- Does not change the user-session state.
- Does not persist email or verification code.

### `registerEmail`

- Uses the existing installation-bound authenticated-session path.
- On success consumes the Backend token pair through the same `NebulaSession` rules as `login`: access token memory-only, refresh token secure-storage-only, state becomes `authenticated`.
- On failure does not persist password/code and must not fabricate a user session.

### `resetEmailPassword`

Password reset is not login. Backend success means all pre-reset sessions are revoked. Therefore SDK success has one mandatory local consequence:

```text
clear in-memory access token
+ clear persisted refresh token for the current namespace
+ leave the installation identity intact
+ final local user-session state = installationActive
```

If there is no current authenticated user session, success leaves the SDK at `installationActive`. The SDK MUST NOT silently keep an `authenticated` state backed by credentials that the Backend has just revoked.

Implementation may add an internal/member-level `NebulaSession` transition/helper to perform this deterministic local cleanup; that helper is not a new top-level public symbol. It must not issue a second password-reset request or reconstruct session authority.

## 7. Endpoint ownership

`SessionEndpoints` remains the endpoint-path owner and adds these fields with exact defaults:

```dart
const SessionEndpoints({
  this.login = '/api/v1/mobile/auth/login',
  this.refresh = '/api/v1/mobile/auth/refresh',
  this.logout = '/api/v1/mobile/auth/logout',
  this.emailCodeSend = '/api/v1/mobile/auth/email/code/send',
  this.emailRegister = '/api/v1/mobile/auth/email/register',
  this.emailPasswordReset = '/api/v1/mobile/auth/email/password/reset',
});

final String emailCodeSend;
final String emailRegister;
final String emailPasswordReset;
```

Consumer Apps may not own or hand-author these paths. All four credential flows use the existing SDK InstallationProof request path.

## 8. Error surface

Backend Auth V2 canonical maps invalid login credentials and invalid/expired verification credentials to stable code `10001`. The current SDK does not recognize that code and would conservatively classify it as `AuthenticationRequiredError`, which is incorrect for a failed credential attempt.

V2 freezes:

```dart
const int nebulaCodeInvalidCredentials = 10001;

final class InvalidCredentialsError extends NebulaSessionError {
  const InvalidCredentialsError({super.code, super.requestId})
      : super('invalid credentials');
}
```

`classifySessionError` MUST map `10001` to `InvalidCredentialsError`. This class deliberately does not distinguish "email exists", "password wrong", "code wrong", "code expired", provider subject, provider raw error, or account state.

Existing mappings remain:

```text
30001 -> InvalidRequestError
40002 / HTTP 429 -> RateLimitedError
12004 -> TemporarilyUnavailableError
12002 -> SessionRevokedError
12001 -> InvalidInstallationError
10003 -> AuthenticationRequiredError
```

No provider-specific public error type is added. Raw Apple/Google/SMTP errors never enter SDK public errors.

## 9. Secret and persistence rules

The following are ephemeral request inputs only and MUST NOT enter `SecureTokenStore`, cache storage, analytics, Error Reporting, request IDs, logs, exception messages, or session events:

```text
password
new_password
EMAIL verification/reset code
OAuth authorization code
provider token / ID token
```

EMAIL itself is not an SDK identity key and is not persisted by Auth V2.

Existing token rules remain unchanged:

```text
installation token -> existing installation storage rule
access token       -> memory only
refresh token      -> SecureTokenStore only
```

## 10. OAuth provider-proof boundary

`NebulaOAuthProvider` selects only the provider name placed in the Backend request. It does not select client ID, audience, redirect URI, JWKS, issuer, secret or App identity. Authoritative InstallationProof `app_id` selects those server-side.

The frozen Backend request has no typed nonce or PKCE verifier field. Therefore:

- SDK Auth V2 MUST NOT silently add nonce/PKCE fields;
- SDK MUST NOT promise support for a provider configuration that requires those absent proofs;
- Backend canonical `requires_nonce` / `requires_pkce` fail-closed behavior remains authoritative;
- adding those proof fields requires a later Platform contract/public-surface amendment.

Provider authorization-code acquisition itself is host/product-platform integration outside this SDK HTTP surface; Apps pass only the resulting bounded authorization code into the typed login request.

## 11. Session state behavior

Existing `NebulaSession` state machine remains authoritative.

```text
PHONE login        -> existing authenticating -> authenticated path
EMAIL login        -> same path
APPLE/GOOGLE login -> same path
EMAIL register     -> same successful token/session path
send EMAIL code    -> no user-session transition
password reset OK  -> current user scope cleared -> installationActive
```

A failed credential attempt must not trigger refresh-loop semantics merely because code `10001` was previously unknown. It surfaces as `InvalidCredentialsError`.

Refresh rotation, refresh-reuse family revocation, logout and InstallationProof semantics are unchanged.

## 12. Compatibility

### Guaranteed non-regression

- `NebulaLoginRequest.phone(phone:, code:)` remains unchanged.
- PHONE wire JSON remains byte/field compatible.
- PHONE does not require EMAIL.
- Existing installation bootstrap/proof, token storage, refresh rotation/reuse revocation and logout semantics remain unchanged.
- No PHONE identity migration is represented in SDK API.

### OAuth source tightening

The old `oauthProvider: String` surface modeled a disabled placeholder and had no production real-provider compatibility guarantee. V2 intentionally changes that member type to `NebulaOAuthProvider`. Existing code using literal strings must migrate to `.apple` or `.google`. No arbitrary-string compatibility shim is frozen because that would preserve the exact invalid state Auth V2 is meant to remove.

## 13. Product erasure

No SDK symbol, method, enum or endpoint contains:

```text
Nearvia
NFC Writer
email-first UI priority
phone-under-other-methods UI priority
market presentation policy
family/elder/profile product concepts
```

A product adapter may choose Email first, Apple/Google buttons next and Phone under other sign-in methods; another product may put Phone first. Both consume this same surface.

## 14. Frozen implementation write-set for the later Story

This freeze does **not** authorize implementation. If independently accepted and canonically closed, the later `CHANGE_APPROVED` implementation Story should be limited to the smallest serial set mechanically required by this surface:

```text
lib/src/auth/login_request.dart
lib/src/auth/session_endpoints.dart
lib/src/auth/session_errors.dart
lib/src/auth/session.dart                 # only local reset cleanup/state helper if required
lib/src/auth/session_auth.dart
lib/src/capabilities.dart
governance/api_surface.snapshot
focused auth/session tests
```

Expected unchanged:

```text
lib/nebula_sdk.dart                       # touched files are already exported
governance/public_api.txt
bootstrap/proof/key-store/token-store wire authority
Backend/App repos
```

The implementation Story must confirm `127 -> 131` with exactly the four top-level additions frozen in §2.

## 15. Owner pre-review mechanical evidence

Before freezing the candidate head, the Architecture/SDK freeze owner mechanically verified:

```text
Task Source Guard --self-check                 PASS
Task Source Guard AUTH-V2-SDK-001              PASS
Cross Repo Guard --check-branch                PASS
API surface current snapshot                   PASS / 127
git diff --check                               PASS
lib/** mutation                                0
api_surface.snapshot/public_api.txt mutation   0
Backend authority cross-check                  Dev=d9ad6c3c0e9186e574081e22d88450d93542fd29
```

A temporary, non-repository API-surface simulation inserted only the four frozen top-level declarations into copies of the already exported Auth source files and ran the repository `tool/api_surface.dart` collector. Result:

```text
simulated surface = 131
added:
  src/auth/login_request.dart enum NebulaEmailCodePurpose
  src/auth/login_request.dart enum NebulaOAuthProvider
  src/auth/session_errors.dart class InvalidCredentialsError
  src/auth/session_errors.dart const nebulaCodeInvalidCredentials
removed: none
```

The simulation mutated no repository file and did not update the canonical snapshot. It proves only the predicted symbol-level delta; implementation remains unauthorized in this Story.

## 16. Acceptance for this freeze Story

`AUTH-V2-SDK-001` is complete only when all are true:

- this document is the only new/changed contract output from the execution Agent;
- `lib/**` delta = 0;
- API snapshot remains 127 unchanged in this Story;
- Task Source Guard PASS;
- Cross Repo Guard PASS;
- `git diff --check` PASS;
- independent Architecture/SDK public-surface review APPROVED on the exact candidate;
- canonical merge + post-merge governance PASS.

Only then may Coordinator register the separate SDK implementation Story.
