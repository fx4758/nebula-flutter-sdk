# AUTH-V2-NEARVIA-BE-APP-001 — Nearvia Backend App Registration

- ID：AUTH-V2-NEARVIA-BE-APP-001
- Owner: Backend Nearvia Deployment Agent
- Reviewer: Backend Review Agent
- Execution repo：`../flypost_backend`
- Execution branch：`auth/v2-nearvia-be-app-001`
- Execution remote: `origin`
- Execution worktree: `wt-auth-v2-nearvia-be-app-001`
- Required upstream: `AUTH-V2-BE-001 = DONE`, `AUTH-V2-NEARVIA-IDENTITY-002 = DONE`
- Platform API mode：`USE_EXISTING_CONTROL_PLANE`
- SDK public API mode：`READ_ONLY`
- Product adapter rule: `ADAPTER_FIRST`

## Authority
Backend canonical at registration: `root/FlyPostAPI Dev@d9ad6c3c0e9186e574081e22d88450d93542fd29`.
Nearvia product identity authority: `com.lcloudy.nearvia`, Apple Team `V4U9V436CM`.
Nebula governance authority at registration: `main@8cb207b760741e75deaa0aac2416914066f65ab0`.

Backend already owns an audited Product App control plane (`POST /v1/admin/products` / `product_app`) and generates numeric App IDs with Snowflake. This Story MUST use that generic mechanism; it MUST NOT hard-code Nearvia into Backend runtime code or add a product-specific schema/migration.

## Frozen public Backend product identity
```text
app_key              nearvia
name                 Nearvia
default_region_code  GLOBAL
status               1 / active
numeric app_id       SERVER_GENERATED; never guessed or copied from NFC Writer
```

`app_key=nearvia` is public, not a secret. App credentials and provider secrets are outside this Story.

## Environment facts
Current shared staging API origin:
```text
https://testapi.nfcwriter.top22.top
```
This is staging infrastructure only. It is NOT Nearvia product identity or production-origin authority.
Production API origin remains `UNRESOLVED`; do not invent one.

## Authorized execution
After this Story is canonical, the Deployment Agent may:
1. confirm no active `app_key=nearvia` exists on staging;
2. create exactly one active Product App through the existing audited control plane;
3. record server-generated numeric App ID and public AppKey in sanitized evidence;
4. verify `app_key=nearvia -> same app_id` using the existing resolver/read path without issuing App credentials;
5. record staging API origin and keep production origin unresolved;
6. on re-run, verify the existing registration rather than create a duplicate.

If the control plane cannot do this safely/auditably, STOP and report a generic platform gap. Do not direct-insert around the control plane.

## Authorized repository write set
```text
docs/evidence/AUTH-V2-NEARVIA-BE-APP-001/**
```
Backend production code/schema/Auth V2/provider config and SDK/App source are READ_ONLY. A genuine generic-control-plane defect requires separate corrective authorization before Coding mutation.

## Forbidden
- NFC Writer App ID/AppKey/client reuse;
- product-specific Backend runtime branch;
- schema/migration changes;
- Apple/Google clients/secrets or `auth.oauth.apps` mutation;
- App credential issuance/rotation;
- production endpoint invention;
- PHONE/SMS, Push, consumer App or SDK mutation;
- direct SQL insert instead of audited control plane;
- execution Agent Task Board edits.

## Required evidence
- exact FlyPostAPI deployment source/runtime used by staging;
- audited Product App creation/read result;
- numeric Nearvia App ID + `app_key=nearvia`;
- name `Nearvia`, region `GLOBAL`, active status;
- staging API origin;
- production API origin explicitly `UNRESOLVED` unless independently supplied;
- no secret exposure/commit;
- no duplicate active Nearvia Product App;
- exact independent Backend review.

## Exit
This closes only the dedicated Nearvia Backend App registration prerequisite. OAuth still requires production/Play signing fingerprints, Apple/Google provider registrations, Backend per-App provider binding, production API origin and external secret-custody evidence before a separate Coordinator unlock.
