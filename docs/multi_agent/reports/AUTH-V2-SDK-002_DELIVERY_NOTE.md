# AUTH-V2-SDK-002 Delivery Note

## Delivery state

SDK Auth V2 production implementation and the explicitly authorized test-fake compatibility corrective are complete. The implementation branch has absorbed the canonical scope amendment, and full-repository analyzer/test closure is green.

## Baseline and exact heads

- Original implementation baseline: `4326b08a6b5498d7ba3b0eb6112452c86c9f7430`
- Original production delivery exact: `7589c2ab1beea85ac24b472a7f6f5138722204fd`
- Test-fake scope amendment PR: `#93`
- Scope amendment exact: `f6832616d4c18730fe3153b022b7321154fcaf38`
- Scope amendment Review: `#393 APPROVED / reviewer-agent / official=true / stale=false`
- Scope amendment merge: `df94d81d13042f6ea8fc6901fbcd10e019d3bcd2`
- Scope amendment post-merge governance: `#285 SUCCESS`
- Implementation + compatibility corrective head before this evidence-only note: `749cf53017137caf7dcdfec4894620633dd34ea5`
- Branch: `auth/v2-sdk-002-implementation`

## Authorized production/public delta

Exactly the seven authorized production/public paths changed from the original implementation baseline:

- `lib/src/auth/login_request.dart`
- `lib/src/capabilities.dart`
- `lib/src/auth/session_endpoints.dart`
- `lib/src/auth/session_errors.dart`
- `lib/src/auth/session_auth.dart`
- `lib/src/auth/session.dart`
- `governance/api_surface.snapshot`

Focused tests/evidence changed only in the registered scope:

- `test/login_request_test.dart`
- `test/session_auth_test.dart`
- `test/session_errors_test.dart`
- `test/session_test.dart`
- `test/error_reporting/error_reporting_public_surface_test.dart`
- `docs/multi_agent/reports/AUTH-V2-SDK-002_DELIVERY_NOTE.md`

The compatibility corrective changed only the pre-existing `_Auth implements NebulaAuth` fake in `test/error_reporting/error_reporting_public_surface_test.dart`, adding empty test stubs for `sendEmailCode`, `registerEmail`, and `resetEmailPassword`.

Backend mutation: `0`.
App mutation: `0`.
Provider authorization-code acquisition/configuration mutation: `0`.
WeChat/QQ mutation: `0` (intentionally deferred to a separate provider-contract/migration Story).
Compatibility corrective production/public delta: `0`.

## Public API proof

API surface changed from `127` to `131` with exactly these additions and zero removals:

- `src/auth/login_request.dart enum NebulaEmailCodePurpose`
- `src/auth/login_request.dart enum NebulaOAuthProvider`
- `src/auth/session_errors.dart class InvalidCredentialsError`
- `src/auth/session_errors.dart const nebulaCodeInvalidCredentials`

`lib/nebula_sdk.dart` remains byte-identical to the original baseline:
`2ab4b77edb82ce32f46c6bac76dca2bc19e2220ce3e6dd39a6a436395c63fab5`

`governance/public_api.txt` remains byte-identical to the original baseline:
`4aa2e72323e175fed0e0e4b3c87a85d7db0fdeb954b59f35517ba8976408daf4`

## Implemented Auth V2 behavior

- PHONE constructor and wire remain unchanged.
- EMAIL login uses typed `EMAIL + email + password` wire.
- OAuth constructor accepts only `NebulaOAuthProvider.apple/google` and maps to `APPLE/GOOGLE`.
- EMAIL code send maps typed `register/resetPassword` to `REGISTER/RESET_PASSWORD` and does not change session state.
- EMAIL registration consumes the returned token pair through the existing authenticated-session path.
- EMAIL password reset sends exactly `email + code + new_password`, clears local user scope without remote logout, preserves installation identity, and ends at `installationActive`.
- EMAIL/password/OAuth-code bounds are UTF-8-byte based; EMAIL verification code is exactly six ASCII decimal digits.
- Secret validation failures do not include the rejected secret value.
- Backend code `10001` maps to `InvalidCredentialsError`; existing error mappings remain intact.

## Full verification on mac-mini-ci

Exact verified source head: `749cf53017137caf7dcdfec4894620633dd34ea5`.

Because the CI data volume was nearly full, no project evidence or cache was deleted. A fresh verification clone remained under the allowed CI root while Dart test-generated temporary/cache files were redirected to the already-mounted writable NAS volume. This changed no source, dependency, or remote state.

Results:

- Task Source Guard: PASS
- Cross Repo Guard: PASS
- Platform API Guard: PASS
- API surface: PASS (`131` symbols)
- Focused Auth V2 + compatibility tests: PASS (`44/44`)
- Full `dart analyze`: PASS (`No issues found`)
- Full test directory: PASS (`273/273`)
- Nebula Governance: PASS
- Secret scan: PASS (`no hard-coded credential values`)
- `git diff --check`: PASS on implementation/corrective changes
- `lib/src/auth/session_auth.dart`: `396` lines (budget <= 400)
- `lib/nebula_sdk.dart` and `governance/public_api.txt`: unchanged hashes above

## Scope-gap closure

The prior blocker at `test/error_reporting/error_reporting_public_surface_test.dart:7:13` is CLOSED.

The Coding Agent originally stopped correctly because the file was outside the canonical focused test scope. Coordinator/Architecture then published the narrow scope amendment in PR #93, independent review approved it at exact `f6832616...`, Coordinator merged it, and post-merge governance #285 passed. Only after that canonical authorization did the implementation branch add the three test-only compatibility stubs.

No production/public SDK behavior was changed by the corrective.

## Exit

This Story is ready to form the implementation PR candidate. Merge remains unauthorized until the final delivery exact receives its own Formal SUCCESS and independent official exact-head SDK Review APPROVED/stale=false. Consumer App integration remains separately unauthorized until canonical closure.
