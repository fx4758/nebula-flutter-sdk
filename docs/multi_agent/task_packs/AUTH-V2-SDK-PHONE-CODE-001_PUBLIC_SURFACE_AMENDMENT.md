# AUTH-V2-SDK-PHONE-CODE-001 — PHONE SMS Code Acquisition Public-Surface Amendment

- ID：AUTH-V2-SDK-PHONE-CODE-001
- Owner：SDK Auth V2 Architect Agent
- Reviewer：Architecture Review Agent
- Execution repo：`.`
- Execution branch：`auth/v2-sdk-phone-code-001-public-surface-amendment`
- Execution remote：`hub`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`READ_ONLY`
- Product adapter rule：`ADAPTER_FIRST`
- Required upstream：`AUTH-V2-SDK-002 = DONE / REVIEW PASS`
- Contract authority：`docs/multi_agent/contracts/MOBILE_AUTH_V2.md`
- Backend authority：FlyPostAPI `Dev@d9ad6c3c0e9186e574081e22d88450d93542fd29`
- Trigger：NFC Writer `AUTH-V2-NFC-APP-002` independent Review #467 on exact `e2fc93136df7fca101f867199d44ae1a8fe2c0e2`

## Goal

Correct one omission in the already-canonical Auth V2 SDK freeze: PHONE login is preserved as `phone + code`, and the Backend canonical has `POST /api/v1/mobile/auth/code/send`, but RC2 exposes no typed SDK operation that lets a consumer obtain that SMS login code. The original freeze explicitly required consumer Apps to use PHONE/SMS without hand-authoring endpoint paths or JSON, so this is a contract-completion corrective, not a new product feature.

This Story is architecture/freeze only. It must not modify `lib/**`, exports, API snapshots, Backend code, or consumer Apps.

## Required decisions

Freeze the minimum member-level amendment to the existing Auth capability:

```dart
abstract interface class NebulaAuth {
  Future<void> sendPhoneCode({
    required String phone,
    NebulaCancellationToken? cancellationToken,
  });
}
```

and the existing endpoint owner:

```dart
const SessionEndpoints({
  ...,
  this.phoneCodeSend = '/api/v1/mobile/auth/code/send',
});

final String phoneCodeSend;
```

No new top-level symbol is required. The top-level public API surface must remain `131`.

## Frozen behavior

- request body is exactly `{ "phone": <phone> }`;
- request uses the existing InstallationProof transport and target `/api/v1/mobile/auth/code/send`;
- no automatic retry because the endpoint is rate-limited and sends an external credential;
- success does not mutate user-session state;
- phone/code must never enter logs, analytics, Error Reporting, cache, request IDs, or token storage;
- rate-limit / invalid-installation / invalid-request / temporary-unavailable errors reuse existing low-cardinality Auth/session errors;
- `NebulaLoginRequest.phone(phone:, code:)` wire/session behavior remains unchanged;
- no SMS vendor/provider configuration is exposed by the SDK;
- consumer Apps may not hand-author this endpoint as a workaround.

## Required output

Amend only:

`docs/multi_agent/contracts/MOBILE_AUTH_V2_SDK_PUBLIC_SURFACE.md`

The amended contract must explicitly reconcile the original goal (“PHONE/SMS usable without hand-authored endpoint/JSON”) with the missing code-acquisition member and freeze the exact implementation write-set for a later separately registered implementation corrective.

## Allowed paths

- `docs/multi_agent/contracts/MOBILE_AUTH_V2_SDK_PUBLIC_SURFACE.md`
- this task pack only if review clarification is required.

## Forbidden

- any `lib/**` mutation;
- `lib/nebula_sdk.dart` mutation;
- `governance/api_surface.snapshot` / `governance/public_api.txt` mutation;
- Backend mutation;
- NFC Writer / Nearvia mutation;
- SMS vendor credentials/configuration;
- Task Board mutation by the execution Agent.

## Acceptance

- exact contract amendment freezes `sendPhoneCode` + `SessionEndpoints.phoneCodeSend`;
- API top-level surface remains 131;
- PHONE login wire body and session semantics unchanged;
- consumer hand-authored endpoint workaround explicitly forbidden;
- production/public mutation = 0;
- Task Source Guard, governance, diff check and independent exact-head architecture review pass.

## Exit

Only after this architecture corrective is canonical may Coordinator register an SDK implementation corrective. That implementation must be independently reviewed and released immutably before NFC Writer may repin and return PR #211 to review.
