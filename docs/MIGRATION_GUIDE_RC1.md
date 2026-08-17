# Nebula Flutter SDK Migration Guide — 0.1.0-rc1

This guide covers migration from development consumption (`0.1.0-dev.1`, path pins or pre-RC immutable commits) to the first reviewed RC identity.

## Packaging changes only

- Package version becomes `0.1.0-rc1`.
- Release identity becomes immutable tag `v0.1.0-rc1` after Coordinator publication.
- `publish_to: none` stays unchanged.
- Packaging does not modify `lib/**` or `governance/api_surface.snapshot`; public surface remains 127 symbols.

## Path consumer -> immutable tag

Before:

```yaml
nebula_sdk:
  path: ../nebula-flutter-sdk
```

After, only where direct Git dependencies are permitted:

```yaml
nebula_sdk:
  git:
    url: http://192.168.31.102:3000/root/nebula-flutter-sdk.git
    ref: v0.1.0-rc1
```

Commit the resolved lockfile and review the exact commit.

## Existing immutable/vendored consumer

Do not change dependency architecture merely to consume RC1. Resolve the tag to its exact SDK commit, update the existing pin/snapshot atomically, then run the consumer's dependency and integration gates. NFC Writer follows this model.

## Observability consumers

Apps moving from older pre-composition SDK commits should use `NebulaMobileObservability.create(...)` and the returned public `analytics`, `errorReporting` and `flush()` members. Do not import internal mobile senders, `ErrorReportingClient`, `ErrorReportStore` or `CacheErrorReportStore`.

## Existing adapters

RC1 packaging itself is not an API migration. Preserve reviewed product adapters, host-owned installation/security lifecycle and product-local offline behavior. Do not merge historical product integration work merely because the SDK now has an RC tag.

## Rollback

If validation fails before publication, no authoritative tag is created. After publication, never move the tag; fix forward to a later RC. Consumer rollback uses its previous accepted immutable SDK identity.
