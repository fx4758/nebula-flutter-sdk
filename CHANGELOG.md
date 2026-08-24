# Changelog

## 0.1.0-rc2 - 2026-08-25

Second immutable release candidate of the Nebula Flutter SDK. RC2 packages the already-reviewed Mobile Auth V2 SDK surface on top of RC1.

### Added since RC1

- Typed EMAIL/password login through `NebulaLoginRequest.email(...)`.
- Typed Apple/Google authorization-code login through `NebulaOAuthProvider`.
- Purpose-bound EMAIL verification codes through `NebulaEmailCodePurpose`.
- EMAIL registration and password reset operations on `NebulaAuth`.
- Stable invalid-credentials mapping `nebulaCodeInvalidCredentials = 10001` / `InvalidCredentialsError`.

### Compatibility / release invariants

- PHONE/SMS login behavior remains preserved.
- Public API surface is exactly 131 top-level symbols (RC1: 127; Auth V2 added four symbols before packaging).
- RC2 packaging changes no `lib/**` source and no API snapshot.
- `publish_to: none` remains intentional; RC2 is distributed by immutable Forgejo tag `v0.1.0-rc2`, not a package registry.
- Consumer apps obtain Apple/Google authorization codes through their App/provider adapters and pass only the authorization code to the SDK; provider secrets never belong in the App or SDK package.
- Consumer apps must repin through their own reviewed immutable dependency workflow.

## 0.1.0-rc1 - 2026-08-18

First immutable release candidate of the Nebula Flutter SDK.

### Included

- Installation bootstrap and InstallationProof foundations.
- Session/auth lifecycle with secure-storage and signing ports.
- Runtime Config with ETag/304, TTL, stale-if-error, security-critical no-stale and single-flight refresh.
- Consent-aware Analytics with bounded queueing and mobile transport binding.
- Error Reporting public capture API, bounded durable `CacheStorage` persistence, retry/trust-recovery and partial ACK handling.
- `NebulaMobileObservability.create(...)` composition for Analytics + Error Reporting and fail-soft `flush()` lifecycle delivery.
- Request correlation, typed transport errors, redacted logging, cancellation and test helpers.
- Immutable RC Git-tag release gate, API-surface snapshot gate and Platform-boundary CI guard.

### Release invariants

- Public API surface remains exactly 127 top-level symbols.
- Packaging changes no `lib/**` source and no API snapshot.
- `publish_to: none` remains intentional; RC1 is distributed by immutable Forgejo tag `v0.1.0-rc1`, not a package registry.
- Consumer apps must use their own reviewed dependency pin/repin process and must not import `package:nebula_sdk/src/**`.
