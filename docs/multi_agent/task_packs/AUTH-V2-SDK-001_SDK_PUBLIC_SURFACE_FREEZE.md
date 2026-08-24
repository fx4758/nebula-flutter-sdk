# AUTH-V2-SDK-001 — Mobile Auth V2 SDK Public Surface Freeze

- ID：AUTH-V2-SDK-001
- Owner：SDK Auth V2 Architect Agent
- Reviewer：Architecture Review Agent
- Execution repo：`.`
- Execution branch：`auth/v2-sdk-001-public-surface-freeze`
- Execution remote：`hub`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`READ_ONLY`
- Product adapter rule：`ADAPTER_FIRST`
- Required upstream：`AUTH-V2-BE-001 = DONE / REVIEW PASS`
- Contract authority：`docs/multi_agent/contracts/MOBILE_AUTH_V2.md`
- Backend authority：FlyPostAPI `Dev@d9ad6c3c0e9186e574081e22d88450d93542fd29`

## Goal
Freeze the minimum typed Dart SDK public surface for Mobile Auth V2 before any `lib/**` or API snapshot mutation. The freeze must let consumer Apps use EMAIL/password, preserved PHONE/SMS, and APPLE/GOOGLE authorization-code login without hand-authoring endpoint paths or JSON.

This Story is design/freeze only. It does **not** implement or export the new surface.

## Existing canonical SDK facts
- `NebulaLoginProvider` currently exposes `phone | oauth`.
- `NebulaLoginRequest.phone(phone, code)` is the existing PHONE wire authority and must remain source/wire compatible.
- `NebulaLoginRequest.oauth` currently accepts untyped provider/code strings.
- `NebulaAuth.login(...)` is the current authenticated-session entry point.
- `SessionEndpoints` currently exposes login/refresh/logout only.
- Backend Auth V2 canonical now accepts EMAIL and OAUTH on `/api/v1/mobile/auth/login` plus dedicated EMAIL code/register/reset routes.

## Required output
Create exactly one public-surface freeze artifact:

`docs/multi_agent/contracts/MOBILE_AUTH_V2_SDK_PUBLIC_SURFACE.md`

The artifact must freeze exact symbols, constructors, method signatures, validation rules, endpoint ownership, exports, compatibility behavior, and expected API-surface delta.

## Mandatory decisions
The freeze must mechanically decide all of the following.

1. **Login providers**
   - Preserve `NebulaLoginProvider.phone`.
   - Add EMAIL as a first-class typed login method.
   - Preserve OAuth as a first-class login method.
   - Decide the exact typed Apple/Google enum/symbol so consumer Apps cannot pass arbitrary provider strings.

2. **Login request constructors**
   - PHONE must retain the current wire body exactly: `provider=PHONE + phone + code`.
   - EMAIL must produce exactly `provider=EMAIL + email + password`.
   - OAuth must produce exactly `provider=OAUTH + oauth_provider=APPLE|GOOGLE + oauth_code`.
   - No caller-authoritative `app_id`, `installation_id`, client ID, audience, redirect URI, secret, provider subject, provider email, nonce, or PKCE proof may be added under this frozen Backend request.

3. **EMAIL code/register/reset**
   Freeze the minimum typed SDK operations for:
   - `POST /api/v1/mobile/auth/email/code/send`;
   - `POST /api/v1/mobile/auth/email/register`;
   - `POST /api/v1/mobile/auth/email/password/reset`.

   Decide whether request values are dedicated immutable request classes, enums plus named parameters, or another minimal typed shape. Consumer Apps must not hand-author JSON or endpoint paths.

4. **Verification purpose**
   Freeze a typed representation containing exactly `REGISTER` and `RESET_PASSWORD`; no arbitrary string purpose.

5. **Session semantics**
   Successful EMAIL registration/login and OAuth login must enter the existing `NebulaSession` authenticated state and persist only refresh token through existing secure-storage rules. Password, email verification code, OAuth authorization code and provider token must never be persisted by the SDK.

6. **Password reset semantics**
   Password reset is not a login operation. On success, existing server-side sessions are revoked; the SDK contract must define the caller-visible local-session consequence without inventing a second session authority or silently preserving a now-invalid authenticated session.

7. **Validation**
   Freeze validation that mirrors Backend byte limits rather than the old generic `<=128 chars` rule:
   - email non-empty and <=254 UTF-8 bytes;
   - password 8..128 UTF-8 bytes;
   - verification code exactly 6 decimal digits;
   - OAuth code non-empty and <=4096 UTF-8 bytes;
   - OAuth provider enum exactly APPLE/GOOGLE.
   Email canonicalization remains Backend authority; SDK may validate bounds but must not invent Gmail/provider alias normalization.

8. **Endpoint ownership**
   Decide exact additions to `SessionEndpoints` or another existing auth endpoint owner. No product App may own literal `/api/v1/mobile/auth/...` paths.

9. **Error mapping**
   Reuse existing low-cardinality session/auth errors where possible. Freeze any additional typed category only if Backend Auth V2 cannot be represented without exposing account existence or raw provider errors.

10. **Compatibility**
    Existing PHONE constructor, PHONE wire body, bootstrap/proof, refresh rotation, logout, token-store and session-state behavior must remain compatible. No forced account migration or EMAIL prerequisite.

11. **OAuth proof gap**
    The Backend canonical remains fail-closed for provider flows requiring nonce/PKCE proof absent from Mobile Auth V2. The SDK freeze must not silently add such proof fields or promise those flows; that requires a later Platform/public-surface amendment.

12. **Product-name erasure**
    No Nearvia, NFC Writer, UI ordering, market-region presentation, or product-specific account model in SDK symbols. Apps own presentation order through adapters/UI.

## Surface minimization
Prefer modifying existing Auth types/capability rather than creating a second auth subsystem. Do not expose:
- SMTP/provider configuration;
- provider client ID/audience/JWKS/issuer;
- password hashes/KDF parameters;
- verification-code storage;
- raw provider token/subject;
- Backend identity/account persistence;
- session-family internals.

## Allowed paths
- `docs/multi_agent/contracts/MOBILE_AUTH_V2_SDK_PUBLIC_SURFACE.md`
- this task pack only if a review clarification is required.

## Forbidden
- any `lib/**` mutation;
- `lib/nebula_sdk.dart` mutation;
- `governance/api_surface.snapshot` / `governance/public_api.txt` mutation;
- Backend schema/API/config mutation;
- consumer App/Nearvia/NFC Writer mutation;
- provider credential material;
- Task Board state mutation by the execution Agent.

## Verification
- Task Source Guard `AUTH-V2-SDK-001` PASS;
- Cross Repo Guard PASS;
- `git diff --check` PASS;
- production/public SDK mutation = 0;
- existing API surface remains 127 lines/symbol entries unchanged during this Story;
- freeze is consistent with `MOBILE_AUTH_V2.md` and FlyPostAPI `Dev@d9ad6c3c...`;
- independent Architecture/SDK public-surface review PASS on exact candidate.

## Exit
Close only the SDK public-surface freeze. After canonical `DONE / REVIEW PASS`, Coordinator may register a separate SDK implementation Story with `sdk_public_api_mode=CHANGE_APPROVED`, an exact serial write-set, predicted API-surface delta, and no App mutation.
