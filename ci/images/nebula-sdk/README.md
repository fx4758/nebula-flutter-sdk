# Nebula SDK CI image recovery — 2026-11-27 RC1

This is a **new reviewed baseline candidate**, not the deleted `flypost/nebula-sdk-ci:20260810-v1` binary. Its embedded identity is deliberately different: `nebula-sdk-ci-candidate-20261127-v1`. Do not retag it as the original image or change the marker to bypass the image guard.

## Provenance and exact build inputs

- Build tag: `local/nebula-sdk-ci:20261127-rc1`
- M1 ARM64 image ID: `sha256:675b62b38cf4ccc51c0a0406c84d6b8e5c9c4c2e036712796ad7b036b0c592e1`
- Dart 3.12.0 base manifest: `sha256:1bc3667e7e5d647bf0f00d62673790b06719ba39e108776a7cc3529887e81fb7`
- Python 3.13-slim-trixie base manifest: `sha256:7249d5587b78209a006dc4a3b5340678f84ea729239193aa559962cd8c1fce50`
- Dockerfile SHA256: `d2a1346fe60e880a5f6467df09a9b7d7560408d2fe4280b0768443805845df10`
- Dependency lock: `governance/ci_dependency_snapshot.json` — Dart 3.12.0, 47 exact package versions, unchanged.

To reproduce, stage a **temporary, untracked** `ci/images/nebula-sdk/cache/` context under the Dockerfile with only these 47 verified package directories at `cache/hosted/pub.dev/<package>-<version>` and 47 corresponding pub.dev SHA256 checksum files under `cache/hosted-hashes/pub.dev/<package>-<version>.sha256`. Reject missing, extra, incorrect-version or untrusted inputs. Verify package archives/checksums against their trusted origin before staging; do not trust a folder name as proof of integrity. Do not commit caches or copy other projects' user data. Run:

```sh
docker build --network none -f ci/images/nebula-sdk/Dockerfile \
  -t local/nebula-sdk-ci:20261127-rc1 ci/images/nebula-sdk
docker image inspect local/nebula-sdk-ci:20261127-rc1
docker run --rm --network none local/nebula-sdk-ci:20261127-rc1 dart --version
```

The recorded image ID is only a verified **M1 candidate**. A new build's content digest must be independently compared/approved, not assumed equal based on its tag.

## CI contract and rollout

The `governance/ci_dependency_snapshot.json` must record the **new** `runner_image` and `image_identity`. Keep `tool/ci_dependency_guard.dart` enabled and the complete 47-version package snapshot unchanged. The new image **correctly fails** the previous image identity guard; do not suppress that failure. Validate a copied SDK source with `--network none`, `dart pub get --offline`, dependency guard, format, analyze, governance, platform, secret scan, API surface, full `dart test`, smoke and Coordinator publication regression.

Only after registered Story, Coordinator publication, exact-head Forgejo CI, independent Reviewer and merge should the existing M1 Runner's **SDK label alone** be repointed to `nebula-sdk:docker://local/nebula-sdk-ci:20261127-rc1`, with a configuration backup and approved restart. Keep its other labels, Agent rights, capacity and protections unchanged; do not install a second Runner. M4 cannot claim Docker SDK jobs before Docker/image capacity has been validated. Existing PR #162 requires refreshed base and fresh exact-head CI/Review afterward.

Rollback is to revert only the SDK label using the existing M1 backup; retain all test evidence and caches. Never disable governance, shorten review, or restart unrelated runners.
