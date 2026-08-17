# Nebula Flutter SDK API Reference — 0.1.0-rc1

Mechanical public-surface SSOT: `governance/api_surface.snapshot` (`127` top-level symbols). Consumer entry point:

```dart
import 'package:nebula_sdk/nebula_sdk.dart';
```

## Foundation / Transport

- `NebulaOptions`, `NebulaEnvironment`, `NebulaRequestId`.
- `NebulaException` family, `NebulaErrorCategory`, `NebulaLogger` and redacting/no-op logging.
- `NebulaTransport`, `HttpTransport`, `NebulaRequest`, `NebulaResponse`, `NebulaHttpMethod`, `NebulaCancellationToken`.
- `RequestProofSigner`, `ProofCanonicalInput`, `RecordingProofSigner`, `FakeTransport`.

## Installation bootstrap

- `NebulaBootstrapClient`, `BootstrapEndpoints.bootstrap`.
- `BootstrapRequest`, `BootstrapResult`.
- `InstallationIdentity`, `InstallationKeyPort`, `NebulaPlatform`, `NebulaProofAlgorithm`, `NebulaAttestationState`.

The SDK owns generic wire validation/parsing. The host owns stable installation identity, native/non-exportable key material, secure installation-token persistence and lifecycle scheduling.

## Session/Auth

- `NebulaAuth`, `NebulaSessionAuth`, `NebulaSession`, `NebulaSessionState` and session events.
- `NebulaLoginRequest`, `NebulaLoginProvider`, `SessionTokenPair`, `SecureTokenStore` and typed session errors.

## Runtime Config

- `NebulaConfig`, `NebulaConfigClient`, `NebulaEffectiveConfig`.
- `NebulaFeatureFlag`, `NebulaConfigItem`, `NebulaCachePolicy`, `NebulaVersionPolicy`, `NebulaVersionAction`.
- `CacheStorage`, `InMemoryCacheStorage`, `StorageNamespace`.

## Analytics

- `NebulaAnalytics`, `NebulaAnalyticsClient`.
- `NebulaAnalyticsEvent`, `NebulaEventPrivacy`.
- `NebulaConsent`, `NebulaConsentStore`, `CacheConsentStore`, `InMemoryConsentStore`.
- `NebulaAnalyticsSender` remains the public integration Port; mobile observability composition supplies the SDK-owned mobile binding internally.

## Error Reporting

Public V1 surface is intentionally small:

```dart
abstract interface class NebulaErrorReporting {
  Future<void> reportCaughtError({
    required String errorType,
    required String safeMessage,
    required StackTrace stackTrace,
    DateTime? occurredAt,
    NebulaRequestId? requestId,
  });
}
```

Persistence, report IDs, retry state, transport sender, provider details, trusted installation/app/platform identity and server `ingested_at` remain internal.

## Mobile Observability composition

```dart
final observability = NebulaMobileObservability.create(
  options: options,
  transport: transport,
  proofSigner: proofSigner,
  installationToken: loadInstallationToken,
  recoverInstallationTrust: recoverInstallationTrust,
  persistentStorage: cacheStorage,
);

final NebulaAnalytics analytics = observability.analytics;
final NebulaErrorReporting errors = observability.errorReporting;
await observability.flush();
```

`flush()` is best-effort. The host decides lifecycle opportunities; queueing, durable Error Reporting persistence, retry, trust recovery and ACK handling stay inside the SDK.

## Facade / marker capabilities

`Nebula` is dependency-injected and exposes transport/auth/config/analytics plus optional Error Reporting. `NebulaAsset`, `NebulaNotification`, `NebulaPayment` and `NebulaAi` are marker contracts only in RC1.

## Stability

RC1 is prerelease. Packaging adds no public symbol. Any public-surface change after RC1 requires separate authorization and a new reviewed version.
