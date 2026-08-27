# AUTH-V2-NEARVIA-OAUTH-001 — Nearvia Apple/Google Provider Acquisition Preflight

- ID：AUTH-V2-NEARVIA-OAUTH-001
- Review task identity: `AUTH-V2-NEARVIA-OAUTH-001` (this candidate is a follow-up registration, not an implementation or re-closure of `AUTH-V2-NEARVIA-UI-001`)
- Owner: Nearvia OAuth Provider Integration Agent
- Reviewer: App Architecture Review Agent
- Execution repo：`../Nearvia`
- Execution branch：`auth/v2-nearvia-oauth-001`
- Execution remote: `origin`
- Execution worktree: `wt-auth-v2-nearvia-oauth-001`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`READ_ONLY`
- Product adapter rule: `ADAPTER_FIRST`
- State write authority: Coordinator only

## Required upstream

- `AUTH-V2-NEARVIA-APP-001 = DONE / CLOSED_REVIEW_PASS`
- `AUTH-V2-NEARVIA-UI-001 = DONE / CLOSED_REVIEW_PASS`
- `AUTH-V2-NEARVIA-BE-APP-001 = DONE / CLOSED_REVIEW_PASS` — `app_key=nearvia`, server-generated `app_id=351164732780056576`, staging origin `https://testapi.nfcwriter.top22.top`; production origin remains `UNRESOLVED`.
- Nearvia canonical runtime: `origin/main@0b57c604c6e633e6259d98d327cbdc602e6bc18f`
- immutable Nebula SDK: `v0.1.0-rc2@ac96fb5f428cc37293bc5a63e23c90fe40ff8af2`

## Product scope

Nearvia overseas V1 keeps this order:

1. EMAIL/password primary.
2. Apple third-party sign-in.
3. Google third-party sign-in.
4. PHONE/SMS remains deferred for Nearvia.

This Story is only for Apple/Google authorization-code acquisition readiness. It does not authorize SMS, Push, Family/Trust, RTC authorization, Backend auth semantics, Nebula SDK mutation, or any client secret/private key in the App.

## Current gate

`OPEN_PREREQUISITE_EVIDENCE_ONLY`.

## Accepted Backend runtime-gap evidence

Nearvia PR #23 exact `b2b667a4f5b6df47601199241287faf905d513a9`, Review #597 `APPROVED / official=true / stale=false`, merge `0b57c604c6e633e6259d98d327cbdc602e6bc18f`, descendant Formal `SUCCESS` establishes:

- dedicated Nearvia Product App exists as `app_key=nearvia`, `app_id=351164732780056576`;
- Backend Auth V2 code capability is canonical, but checked-in Dev/test/prod configs still have `auth.email.enabled=false`, `enabled_app_ids=[]`, `auth.oauth.apps=[]`;
- shared staging API remains `nebula-backend-api:0.1.0-rc2` from source `6d2ddd3a...` and its canonical staging config has no top-level `auth:` section;
- therefore Backend per-App provider binding and staging Auth V2 runtime readiness are both **not ready** and must not be inferred from Product App registration.


Production/provider code mutation is **not authorized yet**. Before Coordinator may change this Story to `OPEN_IMPLEMENTATION`, the execution repository must contain sanitized evidence for all public provider-registration prerequisites below. Secrets must remain outside Git.

## Required provider-registration evidence

Apple:

- final Nearvia iOS bundle identifier / App ID;
- Sign in with Apple capability ownership for the intended Apple team;
- Service ID / client identifier if the chosen authorization flow requires it;
- exact redirect/callback URI expected by Backend provider configuration;
- confirmation that any server-side Apple private key/client secret is held outside the App repository.

Google:

- final Android application ID and iOS bundle identifier;
- Android OAuth client registration for the final package plus signing certificate fingerprints required by the chosen Google flow;
- iOS OAuth client registration / public client identifier;
- exact redirect/callback semantics expected by Backend provider configuration;
- confirmation that server-side provider secret material is held outside the App repository.

Nearvia / Backend public binding:

- **Satisfied staging Product App prerequisite:** `app_key=nearvia`, server-generated `app_id=351164732780056576`, staging API origin `https://testapi.nfcwriter.top22.top`, accepted via FlyPostAPI PR #24 / Review #593 / merge `bcd93b51aa2b2d479057e2e6b260ee9aab067353`;
- production API origin is still `UNRESOLVED`;
- Backend per-App Apple/Google provider config must still be ready to consume authorization codes for the same identifiers;
- no NFC Writer AppKey/client identifier is reused or guessed.

## Evidence-only authorized mutation

Until the Coordinator unlocks implementation, the only allowed Nearvia mutation is:

- `docs/evidence/AUTH-V2-NEARVIA-OAUTH-001/**`

Evidence may record public identifiers, callback URIs, bundle/application IDs, signing certificate fingerprints and provider-registration status. It must not include passwords, private keys, client secrets, refresh tokens, authorization codes or Keychain contents.

## Future implementation scope after a separate Coordinator unlock

The later `OPEN_IMPLEMENTATION` publication may authorize only the minimum App-owned provider acquisition layer required to obtain short-lived authorization codes and pass them to the existing `NearviaOAuthLoginCoordinator` / `NearviaAuthPort`.

Expected future write set may include, only after that unlock:

- Nearvia App-owned OAuth acquisition code under `poc/watch_capability/app/lib/auth/**`;
- `poc/watch_capability/app/pubspec.yaml` / lock for reviewed provider dependencies;
- minimum Android/iOS public provider metadata, entitlements and registration plumbing;
- focused provider-acquisition tests and build verification.

It must still forbid client secrets/private keys in the App, direct Backend token exchange from UI, Nebula SDK mutation, PHONE/SMS and Push.

## Verification before implementation unlock

Coordinator must mechanically verify:

- all required public identifiers refer to Nearvia, not NFC Writer or another product;
- Apple and Google registrations match the exact package/bundle identifiers to be built;
- callback/redirect values match Backend provider configuration contract;
- no secret material is committed;
- current Nearvia main still contains the canonical AuthPort/OAuth coordinator and no duplicate provider path;
- deployment/provider prerequisites are independently reviewed.

## Exit

This registration may close as a reviewed preflight authority while remaining implementation-blocked. Actual provider acquisition code starts only after a separate Coordinator publication changes `execution_gate` to `OPEN_IMPLEMENTATION`, `implementation_authorized=true`, `app_mutation_authorized=true`, and `provider_authorization_acquisition_authorized=true` on fresh evidence.
