# NEBULA-SDK-RELEASE-002 — RC2 Delivery

- Resolved execution baseline: `4f39b9aedac2a6d853133c6d06dfda0a12d35a00`
- Required ancestor — release-gate implementation: `84852208681e73a1fbe62100fde6d1d85b8a1de9` ✅
- Required ancestor — RC2 authority publication: `dbacd7fa60065e2fe2a868532695ef344833bf16` ✅
- Packaging core: `27b9545ac682255387211a5c013434885b2c0d4f`
- Version: `0.1.0-rc2`
- Planned immutable tag: `v0.1.0-rc2`
- Distribution: immutable Forgejo Git tag; `publish_to: none`; no registry publication.

## Exact scope

Only the authorized release packaging paths differ from the resolved execution baseline:

1. `pubspec.yaml`
2. `CHANGELOG.md`
3. `docs/API_REFERENCE_RC2.md`
4. `docs/INTEGRATION_GUIDE_RC2.md`
5. `docs/MIGRATION_GUIDE_RC2.md`
6. `docs/releases/0.1.0-rc2.md`
7. this Delivery note

`lib/**`, `governance/api_surface.snapshot`, `lib/nebula_sdk.dart`, and `governance/public_api.txt` are byte-identical to the resolved baseline. API surface remains exactly 131.

## mac-mini-ci exact-core verification

Executed on detached exact `27b9545ac682255387211a5c013434885b2c0d4f`:

```text
sdk_release_gate --self-check     PASS
release regression tests          14/14 PASS
task_source_guard                  PASS
cross_repo_guard                   PASS
platform_api_guard                PASS
API surface                        131 PASS
governance                         PASS
secret scan                        PASS
format                             PASS / 0 changes
dart analyze                       PASS / 0 issues
dart test                          273/273 PASS
smoke                              PASS
```

Reference hashes:

```text
lib/nebula_sdk.dart
2ab4b77edb82ce32f46c6bac76dca2bc19e2220ce3e6dd39a6a436395c63fab5

governance/api_surface.snapshot
6c875465c6aea8271e434dd650dd1f0439d9a660ee5ff7b3bfcb8f08ea49bc5b

governance/public_api.txt
4aa2e72323e175fed0e0e4b3c87a85d7db0fdeb954b59f35517ba8976408daf4
```

## Release gate

This candidate is not released by this document. It must first receive fresh Formal SUCCESS and official exact-head independent approval. Coordinator must then verify fresh `hub/main` is still exactly the resolved baseline above and fast-forward `main` to the reviewed release exact. Any canonical drift before publication invalidates this candidate and requires rebuild/review.

Only after canonical publication may Coordinator create immutable `v0.1.0-rc2`. The tag-triggered release gate must succeed before consumer Apps may repin RC2.
