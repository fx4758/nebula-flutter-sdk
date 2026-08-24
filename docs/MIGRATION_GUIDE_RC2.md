# Nebula Flutter SDK Migration Guide — 0.1.0-rc2

This guide covers consumer migration from `v0.1.0-rc1` (or an older immutable SDK commit) to RC2.

## Packaging identity

- Package version becomes `0.1.0-rc2`.
- Release identity becomes immutable tag `v0.1.0-rc2` after Coordinator publication.
- `publish_to: none` remains unchanged.
- Packaging modifies no `lib/**` or API snapshot.

## Public-surface delta since RC1

RC1 has 127 top-level symbols. RC2 canonical source has 131. Exactly four new top-level symbols were added by the separately reviewed Auth V2 implementation before packaging:

```text
NebulaOAuthProvider
NebulaEmailCodePurpose
nebulaCodeInvalidCredentials
InvalidCredentialsError
```

Existing public symbols are not removed by Auth V2.

## Existing PHONE/SMS consumers

No provider migration is required. Preserve the existing `NebulaLoginRequest.phone(...)` path and App adapter architecture.

## Add EMAIL/password

Use `NebulaLoginRequest.email(...)`, `sendEmailCode(...)`, `registerEmail(...)` and `resetEmailPassword(...)`. Do not create App-local copies of Nebula endpoint paths or request JSON.

## Add Apple/Google

Provider SDK/OS integration stays in the consumer App. Obtain an authorization code there, then call `NebulaLoginRequest.oauth(...)` with typed `NebulaOAuthProvider.apple` or `.google`.

Do not place OAuth client secrets or provider private credentials in the Flutter App or SDK. Any provider configuration/provisioning remains a separately governed consumer/provider task.

## Immutable/vendored consumers

Do not change dependency architecture merely to consume RC2. Resolve `v0.1.0-rc2` to the exact SDK commit, update the existing pin/snapshot atomically, update the lockfile/manifest as applicable, and run the consumer's dependency/integration gates.

## Rollback

If RC2 validation fails in a consumer, repin to its previous accepted immutable SDK identity. Never move an existing release tag.
