# Nebula Flutter SDK Integration Guide — 0.1.0-rc1

RC1 is distributed as an immutable Forgejo Git tag. It is not a registry release and does not override each product repository's dependency-governance rules.

## 1. Consume an immutable identity

Where direct Git dependencies are allowed:

```yaml
nebula_sdk:
  git:
    url: http://192.168.31.102:3000/root/nebula-flutter-sdk.git
    ref: v0.1.0-rc1
```

Never use `main`, `dev` or another floating branch. Commit the consumer lockfile. Products using vendored/snapshot pins must resolve `v0.1.0-rc1` to its exact commit and repin through their existing reviewed workflow instead of changing dependency architecture.

## 2. Build one host composition root

```dart
final options = NebulaOptions(
  appId: appProfile.appId,
  baseUri: Uri.parse(appProfile.baseUrl),
  environment: NebulaEnvironment.production,
  region: appProfile.region,
);

final transport = HttpTransport(baseUri: options.baseUri);
```

Keep product UI/business modules behind product-owned adapters. Do not scatter SDK construction across feature code.

## 3. Installation and security boundary

The host provides stable installation identity, native/non-exportable P-256 key lifecycle, a `RequestProofSigner` adapter, secure installation-token persistence/renewal, and host lifecycle/fail-soft startup policy.

Do not embed App Secret, private signing keys, admin credentials or provider credentials in Dart configuration.

## 4. Bootstrap/Auth/Config

Use public SDK types only: `NebulaBootstrapClient`, `NebulaSessionAuth` / `NebulaAuth`, and `NebulaConfigClient` / `NebulaConfig`. Product-specific entities and database models stay outside the SDK.

## 5. Mobile Observability

Apps must not construct internal senders/stores or import `src/**`:

```dart
final observability = NebulaMobileObservability.create(
  options: options,
  transport: transport,
  proofSigner: proofSigner,
  installationToken: loadInstallationToken,
  recoverInstallationTrust: recoverInstallationTrust,
  persistentStorage: cacheStorage,
);
```

The App receives only:

```text
observability.analytics
observability.errorReporting
observability.flush()
```

Example caught error:

```dart
await observability.errorReporting.reportCaughtError(
  errorType: 'StateError',
  safeMessage: 'operation failed',
  stackTrace: stackTrace,
);
```

Call `observability.flush()` from suitable host lifecycle/network opportunities. It is fail-soft and must not make telemetry a prerequisite for App startup or user flows.

Error Reporting persistence is SDK-owned over the supplied app/environment-scoped `CacheStorage`. The App must not manufacture `report_id`, trusted app/installation/platform identity or server timestamps.

## 6. Consumer verification

Each product must run its own dependency pin/repin review and integration tests. SDK release acceptance is not a substitute for App architecture/security acceptance.

SDK release gates include:

```bash
dart run tool/task_source_guard.dart --self-check
dart run tool/platform_api_guard.dart --self-check
dart run tool/api_surface.dart
dart run tool/governance.dart
dart run tool/secret_scan.dart
dart analyze
dart test
dart run tool/smoke.dart
```

## 7. Rollback

The RC tag is immutable. If RC1 is rejected, consumers roll back to their previously accepted immutable SDK identity. Fixes publish a later RC tag; never retarget `v0.1.0-rc1`.
