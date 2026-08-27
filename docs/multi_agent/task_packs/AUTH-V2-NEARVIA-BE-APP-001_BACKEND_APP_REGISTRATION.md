# AUTH-V2-NEARVIA-BE-APP-001 — Nearvia Backend App Registration

- ID：AUTH-V2-NEARVIA-BE-APP-001
- Owner: Backend Nearvia Deployment Agent
- Reviewer: Backend Review Agent
- Execution repo：`../flypost_backend`
- Execution branch：`auth/v2-nearvia-be-app-001`
- Execution remote: `origin`
- Execution worktree: `wt-auth-v2-nearvia-be-app-001`
- Required upstream: `AUTH-V2-BE-001 = DONE`, `AUTH-V2-NEARVIA-IDENTITY-002 = DONE`, `PLATFORM-PRODUCT-DEPLOY-OP-001 = DONE / CLOSED_REVIEW_PASS` (satisfied; operator merge `5dfee7163ed1dbcb691dc65e8752eb18f2b464fb`)
- Platform API mode：`NONE`
- SDK public API mode：`READ_ONLY`
- Product adapter rule: `ADAPTER_FIRST`

## Authority
Backend canonical for staging registration: `root/FlyPostAPI Dev@5dfee7163ed1dbcb691dc65e8752eb18f2b464fb`.
Nearvia product identity authority: `com.lcloudy.nearvia`, Apple Team `V4U9V436CM`.
Nebula governance authority at registration: `main@8cb207b760741e75deaa0aac2416914066f65ab0`.

Backend already owns the Product App domain/repository/transaction/audit primitives behind `product_app` and generates numeric App IDs with Snowflake. This Story MUST NOT invoke the network/admin-session `POST /v1/admin/products` path. It may execute only after `PLATFORM-PRODUCT-DEPLOY-OP-001` is independently reviewed and canonical, using that reviewed local deployment operator to reuse the same generic Product App invariants. It MUST NOT hard-code Nearvia into Backend runtime code or add a product-specific schema/migration.

## Frozen public Backend product identity
```text
app_key              nearvia
name                 Nearvia
default_region_code  GLOBAL
status               1 / active
numeric app_id       351164732780056576 / SERVER_GENERATED; never guessed or copied from NFC Writer
```

`app_key=nearvia` is public, not a secret. App credentials and provider secrets are outside this Story.

## Environment facts
Current shared staging API origin:
```text
https://testapi.nfcwriter.top22.top
```
This is staging infrastructure only. It is NOT Nearvia product identity or production-origin authority.
Production API origin remains `UNRESOLVED`; do not invent one.

## Execution gate and accepted closure
This Story is **DONE / CLOSED_REVIEW_PASS**. No further Product App mutation is authorized by this closed Story. The generic operator remains canonical from FlyPostAPI PR #23 exact `5ea2538ab0ff10bde7d556269ea3d20a29426f05`, Review #586 `APPROVED / official=true / stale=false`, merge `5dfee7163ed1dbcb691dc65e8752eb18f2b464fb`, with descendant quality SUCCESS.

Nearvia staging registration evidence is accepted from FlyPostAPI PR #24 exact `08df889eb714b271656dbe957c4c7f8df50d08a6`, Review #593 `APPROVED / official=true / stale=false`, merge `bcd93b51aa2b2d479057e2e6b260ee9aab067353`, with descendant Quality Baseline SUCCESS. The reviewed execution converged on server-generated `app_id=351164732780056576`, `app_key=nearvia`, `name=Nearvia`, `default_region_code=GLOBAL`, active status, and idempotent reread/rerun.

Accepted execution proved:
1. pre-registration `inspect -> NOT_FOUND`;
2. `register --dry-run -> WOULD_CREATE`;
3. one real registration `CREATED -> app_id=351164732780056576`;
4. readback `EXISTS -> same app_id`;
5. identical register rerun `EXISTS -> same app_id`;
6. staging API origin remains `https://testapi.nfcwriter.top22.top` and production origin remains unresolved.

There is no HTTP/admin-session fallback. If the reviewed local operator cannot perform the registration safely/auditably, STOP and report the generic platform gap. Do not reset an admin password, call `POST /v1/admin/products`, or direct-insert SQL around the operator.

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
- `POST /v1/admin/products` or any network/admin-session registration fallback;
- admin password reset/impersonation to manufacture deployment authority;
- direct SQL insert instead of the reviewed local deployment operator;
- execution Agent Task Board edits.

## Required evidence
- exact FlyPostAPI deployment source/runtime used by staging;
- reviewed local deployment-operator dry-run/registration/read result;
- `PLATFORM-PRODUCT-DEPLOY-OP-001` canonical closure evidence and the Coordinator reopen authority used for this staging execution;
- numeric Nearvia App ID + `app_key=nearvia`;
- name `Nearvia`, region `GLOBAL`, active status;
- staging API origin;
- production API origin explicitly `UNRESOLVED` unless independently supplied;
- no secret exposure/commit;
- no duplicate active Nearvia Product App;
- exact independent Backend review.

## Exit
This closes only the dedicated Nearvia Backend App registration prerequisite. OAuth still requires production/Play signing fingerprints, Apple/Google provider registrations, Backend per-App provider binding, production API origin and external secret-custody evidence before a separate Coordinator unlock.
