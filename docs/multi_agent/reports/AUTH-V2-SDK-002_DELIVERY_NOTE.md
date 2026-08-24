# AUTH-V2-SDK-002 Delivery Note

## Delivery state

Implementation is complete inside the authorized production/public write-set. The canonical focused test scope and implementation governance gates pass. Full-repository analysis/test closure is blocked by one pre-existing test fake outside this Story's authorized focused test scope; no out-of-scope mutation was made.

## Baseline and implementation head

- Baseline: `4326b08a6b5498d7ba3b0eb6112452c86c9f7430`
- Implementation head before this evidence-only Delivery Note: `954d47580bb7917e5c06aaea637cec9ab1f9a1e8`
- Branch: `auth/v2-sdk-002-implementation`

## Authorized production/public delta

Exactly the seven authorized production/public paths changed:

- `lib/src/auth/login_request.dart`
- `lib/src/capabilities.dart`
- `lib/src/auth/session_endpoints.dart`
- `lib/src/auth/session_errors.dart`
- `lib/src/auth/session_auth.dart`
- `lib/src/auth/session.dart`
- `governance/api_surface.snapshot`

Focused tests changed only in the registered focused test scope:

- `test/login_request_test.dart`
- `test/session_auth_test.dart`
- `test/session_errors_test.dart`
- `test/session_test.dart`

Backend mutation: `0`.
App mutation: `0`.
Provider authorization-code acquisition/configuration mutation: `0`.
WeChat/QQ mutation: `0` (intentionally deferred to a separate provider-contract/migration Story).

## Public API proof

API surface changed from `127` to `131` with exactly these additions and zero removals:

- `src/auth/login_request.dart enum NebulaEmailCodePurpose`
- `src/auth/login_request.dart enum NebulaOAuthProvider`
- `src/auth/session_errors.dart class InvalidCredentialsError`
- `src/auth/session_errors.dart const nebulaCodeInvalidCredentials`

`lib/nebula_sdk.dart` is byte-identical to baseline:
`2ab4b77edb82ce32f46c6bac76dca2bc19e2220ce3e6dd39a6a436395c63fab5`

`governance/public_api.txt` is byte-identical to baseline:
`4aa2e72323e175fed0e0e4b3c87a85d7db0fdeb954b59f35517ba8976408daf4`

## Implemented Auth V2 behavior

- PHONE constructor and wire remain unchanged.
- EMAIL login uses typed `EMAIL + email + password` wire.
- OAuth constructor accepts only `NebulaOAuthProvider.apple/google` and maps to `APPLE/GOOGLE`.
- EMAIL code send maps typed `register/resetPassword` to `REGISTER/RESET_PASSWORD` and does not change session state.
- EMAIL registration consumes the returned token pair through the existing authenticated-session path.
- EMAIL password reset sends exactly `email + code + new_password`, then clears local user scope without remote logout, preserves installation identity, and ends at `installationActive`.
- EMAIL/password/OAuth-code bounds are UTF-8-byte based; EMAIL verification code is exactly six ASCII decimal digits.
- Secret validation failures do not include the rejected secret value.
- Backend code `10001` maps to `InvalidCredentialsError`; existing error mappings remain intact.

## Passing evidence on mac-mini-ci

At implementation head `954d47580bb7917e5c06aaea637cec9ab1f9a1e8`:

- Task Source Guard: PASS
- Cross Repo Guard: PASS
- Platform API Guard: PASS
- API surface: PASS (`131` symbols)
- `git diff --check`: PASS
- Focused Auth V2 + session tests: PASS (`40/40`)
- Nebula Governance: PASS
- Secret scan: PASS
- `lib/src/auth/session_auth.dart`: `396` lines (budget <= 400)

## Exact scope gap preventing full-repository green

`dart analyze` reports exactly one issue:

`test/error_reporting/error_reporting_public_surface_test.dart:7:13`

The local test fake `_Auth implements NebulaAuth` predates Auth V2 and now lacks the three newly frozen interface members:

- `NebulaAuth.sendEmailCode`
- `NebulaAuth.registerEmail`
- `NebulaAuth.resetEmailPassword`

Running that test alone fails to load for the same reason. This path is **not** in `AUTH-V2-SDK-002.focused_test_scope`; the task pack says focused tests/evidence may change only in the registered list. The implementation agent therefore did not mutate it or widen scope implicitly.

Required corrective is mechanical test-fixture compatibility only (no production/public API change): update that `_Auth` fake to implement the three frozen methods. Coordinator/Architecture must explicitly authorize that test path (or register a corrective Story) before Agent A may modify it.

Until that scope amendment/corrective is canonical, full `dart analyze` and full `dart test` are not green, so this candidate must not be represented as Formal/review/merge-ready.
