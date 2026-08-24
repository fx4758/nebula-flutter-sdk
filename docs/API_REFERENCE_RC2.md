# Nebula Flutter SDK API Reference — 0.1.0-rc2

Mechanical public-surface SSOT: `governance/api_surface.snapshot` (`131` top-level symbols). Consumer entry point:

```dart
import 'package:nebula_sdk/nebula_sdk.dart';
```

RC2 contains the complete RC1 foundation plus the canonical Mobile Auth V2 surface. Packaging itself adds no symbol.

## Foundation / Transport

- `NebulaOptions`, `NebulaEnvironment`, `NebulaRequestId`.
- `NebulaException` family, `NebulaErrorCategory`, `NebulaLogger` and redacting/no-op logging.
- `NebulaTransport`, `HttpTransport`, `NebulaRequest`, `NebulaResponse`, `NebulaHttpMethod`, `NebulaCancellationToken`.
- `RequestProofSigner`, `ProofCanonicalInput`, `RecordingProofSigner`, `FakeTransport`.

## Installation bootstrap

- `NebulaBootstrapClient`, `BootstrapEndpoints.bootstrap`.
- `BootstrapRequest`, `BootstrapResult`.
- `InstallationIdentity`, `InstallationKeyPort`, `NebulaPlatform`, `NebulaProofAlgorithm`, `NebulaAttestationState`.

The host owns stable installation identity, native/non-exportable key material, secure installation-token persistence and lifecycle scheduling. SDK calls continue to use the existing InstallationProof authority.

## Session / Auth V2

Public session capability adds EMAIL registration/reset operations while preserving existing session methods. The App can call:

```dart
await auth.login(NebulaLoginRequest.phone(phone: phone, code: code));
await auth.login(NebulaLoginRequest.email(email: email, password: password));
await auth.login(NebulaLoginRequest.oauth(
  oauthProvider: NebulaOAuthProvider.apple, // or .google
  oauthCode: authorizationCode,
));

await auth.sendEmailCode(
  email: email,
  purpose: NebulaEmailCodePurpose.register,
);
await auth.registerEmail(email: email, password: password, code: code);
await auth.resetEmailPassword(
  email: email,
  code: code,
  newPassword: newPassword,
);
```

Stable invalid-credentials mapping:

```dart
nebulaCodeInvalidCredentials == 10001
InvalidCredentialsError
```

OAuth provider SDKs, provider client secrets and authorization-code acquisition are outside Nebula Flutter SDK. The host obtains an Apple/Google authorization code through its App-owned provider adapter and passes it to `NebulaLoginRequest.oauth`.

## Runtime Config

- `NebulaConfig`, `NebulaConfigClient`, `NebulaEffectiveConfig`.
- `NebulaFeatureFlag`, `NebulaConfigItem`, `NebulaCachePolicy`, `NebulaVersionPolicy`, `NebulaVersionAction`.
- `CacheStorage`, `InMemoryCacheStorage`, `StorageNamespace`.

## Analytics / Error Reporting / Mobile Observability

RC1 observability APIs remain unchanged, including `NebulaAnalytics`, `NebulaErrorReporting` and `NebulaMobileObservability.create(...)`. `flush()` remains best-effort and App lifecycle scheduling remains host-owned.

## Facade / marker capabilities

`Nebula` remains dependency-injected. `NebulaAsset`, `NebulaNotification`, `NebulaPayment` and `NebulaAi` remain marker contracts where no separately frozen concrete surface exists.

## Stability

RC2 is prerelease. Compared with RC1, the canonical SDK surface grew from 127 to 131 symbols through the separately reviewed Auth V2 implementation. RC2 packaging adds no further public/API behavior change.
