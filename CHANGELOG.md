# Changelog

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
