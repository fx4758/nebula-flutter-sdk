# AUTH-V2-SDK-002 — Mobile Auth V2 SDK Implementation

- ID：AUTH-V2-SDK-002
- Owner：SDK Auth V2 Implementation Agent
- Agent：A
- Reviewer：SDK Review Agent
- Execution repo：`.`
- Execution branch：`auth/v2-sdk-002-implementation`
- Execution remote：`hub`
- Execution worktree：`wt-auth-v2-sdk-002`
- Platform API mode：`NONE`
- SDK public API mode：`CHANGE_APPROVED`
- Product adapter rule：`ADAPTER_FIRST`
- Required upstream：`AUTH-V2-SDK-001 = DONE / REVIEW PASS / CLOSED_REVIEW_PASS`.
- Platform contract authority：`docs/multi_agent/contracts/MOBILE_AUTH_V2.md`.
- Frozen SDK surface authority：`docs/multi_agent/contracts/MOBILE_AUTH_V2_SDK_PUBLIC_SURFACE.md`.
- Backend authority：FlyPostAPI `Dev@d9ad6c3c0e9186e574081e22d88450d93542fd29`.
- Execution baseline：nebula-flutter-sdk `main@04d1c1481846d3d170f83b71fc4f553dff5d5146`.

## Goal
Implement exactly the independently reviewed Mobile Auth V2 SDK public surface and session semantics. Add typed EMAIL/password, typed Apple/Google authorization-code login, EMAIL code/register/reset operations, and the frozen invalid-credentials error mapping while preserving PHONE/SMS and existing installation/session authority.

This Story does not acquire provider authorization codes, configure provider credentials, alter Backend contracts, or wire a consumer App.

## Exact authorized production/public write-set
Only these production/governance files may change:

1. `lib/src/auth/login_request.dart`
2. `lib/src/capabilities.dart`
3. `lib/src/auth/session_endpoints.dart`
4. `lib/src/auth/session_errors.dart`
5. `lib/src/auth/session_auth.dart`
6. `lib/src/auth/session.dart`
7. `governance/api_surface.snapshot`

Focused tests/evidence may change only under `test/login_request_test.dart`, `test/session_auth_test.dart`, `test/session_errors_test.dart`, `test/session_test.dart`, `test/error_reporting/error_reporting_public_surface_test.dart`, and `docs/multi_agent/reports/AUTH-V2-SDK-002*`.

The added `test/error_reporting/error_reporting_public_surface_test.dart` authority is a narrow compatibility amendment only: update the pre-existing local `_Auth implements NebulaAuth` fake to implement the three frozen Auth V2 methods (`sendEmailCode`, `registerEmail`, `resetEmailPassword`). It authorizes no production/public API mutation, no behavior expansion, and no changes outside that test file.

Any required eighth production/public path is a scope gap: STOP and return a Delivery Note. Do not widen the write-set.

## Frozen public surface
Exactly four new top-level symbols are authorized:

```text
src/auth/login_request.dart enum NebulaOAuthProvider
src/auth/login_request.dart enum NebulaEmailCodePurpose
src/auth/session_errors.dart const nebulaCodeInvalidCredentials
src/auth/session_errors.dart class InvalidCredentialsError
```

`NebulaLoginProvider` gains member `email`. `NebulaLoginRequest` remains the sole login request owner with unchanged PHONE, new EMAIL, and typed OAuth constructors. No arbitrary OAuth provider string compatibility constructor remains publicly reachable.

`NebulaAuth` gains exactly `sendEmailCode`, `registerEmail`, and `resetEmailPassword` with the signatures frozen in `MOBILE_AUTH_V2_SDK_PUBLIC_SURFACE.md`. No new public request DTO is authorized.

## Wire and endpoint invariants
PHONE wire remains `provider=PHONE + phone + code`. EMAIL login is `provider=EMAIL + email + password`. OAuth is `provider=OAUTH + oauth_provider=APPLE|GOOGLE + oauth_code`.

`SessionEndpoints` remains path owner and adds only:

```text
/api/v1/mobile/auth/email/code/send
/api/v1/mobile/auth/email/register
/api/v1/mobile/auth/email/password/reset
```

All Auth V2 calls use existing InstallationProof transport. Consumer Apps must not hand-author endpoint paths or JSON.

## Validation and secret invariants
Validation is pre-network and UTF-8-byte based where frozen:

```text
email             non-empty, <=254 UTF-8 bytes
password          8..128 UTF-8 bytes
verification code exactly 6 ASCII decimal digits
OAuth code        non-empty, <=4096 UTF-8 bytes
OAuth provider    typed Apple/Google only
```

Do not add provider-specific email canonicalization. Password, new password, verification/reset code and OAuth authorization code must never enter token stores, cache storage, analytics, Error Reporting, logs, request IDs, exception messages or session events.

## Session semantics
- PHONE login remains unchanged.
- EMAIL login / Apple login / Google login use the existing authenticating -> authenticated path.
- EMAIL registration success consumes the Backend token pair through the same authenticated-session path; access token remains memory-only and refresh token remains SecureTokenStore-only.
- EMAIL code send causes no user-session transition.
- EMAIL password reset success clears in-memory access token + current namespace refresh token, preserves installation identity, and ends at `installationActive`.
- Password reset must not issue a second reset request or fabricate a replacement session.

A member/internal `NebulaSession` cleanup transition/helper may be added in `session.dart` only as required by the frozen reset semantics. It must add no top-level public symbol.

## Error invariant
Add stable code `10001` and map it to `InvalidCredentialsError`. Existing mappings remain unchanged. Do not expose account-existence distinctions or raw Apple/Google/SMTP/provider failures.

## API surface invariant
Canonical pre-implementation snapshot is `127`. Expected implementation snapshot is `131` with exactly four additions and zero removals:

```text
NebulaOAuthProvider
NebulaEmailCodePurpose
nebulaCodeInvalidCredentials
InvalidCredentialsError
```

`lib/nebula_sdk.dart` and `governance/public_api.txt` must remain byte-identical to execution base because all affected libraries are already exported.

## Forbidden / unchanged
Outside the exact write-set, production paths remain unauthorized, including `lib/nebula_sdk.dart`, `governance/public_api.txt`, `lib/src/nebula.dart`, transport/foundation/storage/config/analytics/error_reporting, and every other `lib/src/auth/**` file.

Also forbidden: Backend/schema/config mutation; Nearvia/NFC Writer/App mutation or SDK repin; provider SDK integration or authorization-code acquisition; provider client ID/audience/JWKS/issuer/secret/nonce/PKCE surface; new dependency; second Auth subsystem; caller-authored App/installation/proof/provider identity; Task Board mutation by Agent A.

## Verification
- `dart run tool/task_source_guard.dart --story AUTH-V2-SDK-002` PASS.
- `dart run tool/cross_repo_guard.dart --story AUTH-V2-SDK-002 --repo . --check-branch` PASS.
- `dart run tool/platform_api_guard.dart --story AUTH-V2-SDK-002` PASS.
- `git diff --check` and exact production write-set PASS.
- PHONE constructor/wire non-regression PASS.
- EMAIL login/register/code/reset focused tests PASS.
- Apple/Google enum -> wire mapping PASS; arbitrary provider string unavailable.
- UTF-8 bounds + six-digit code validation PASS before transport.
- reset success clears user scope to `installationActive` while preserving installation identity.
- `10001 -> InvalidCredentialsError`; existing mappings unchanged.
- API surface exactly `131`, with the four frozen additions and zero removals.
- `lib/nebula_sdk.dart` + `governance/public_api.txt` byte-identical to base.
- focused tests + full analyzer/tests/governance/secret scan PASS; the compatibility-amended error-reporting public-surface test must compile/load/pass.
- Delivery Note records exact base/candidate, path diff, 127->131 proof, unchanged hashes and Backend/App/provider mutation = 0.

## Exit
Delivery goes to independent SDK Review. Agent A does not merge or mark DONE. Coordinator merges only after exact candidate Formal SUCCESS + official reviewer-agent APPROVED/stale=false, then performs post-merge governance and canonical closure. Consumer App integration remains separately unauthorized until this Story closes.
