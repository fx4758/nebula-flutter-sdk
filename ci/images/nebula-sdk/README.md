# SDK CI RC2 — pinned offline image

This is a new replacement image, not the retired 20260810-v1 binary. The exact official Dev integration SHA is f6563f6858b1b9d0b1db8071c0e645ea510aea24 with tree e3c08b02c4de9108ac056773543fba95a359045c. Its tree matches original PR #164 V3 sealed SHA 89582667128aaaefb558ac14f964a7b9422db5fe (independently compared using git rev-parse SHA^{tree}). The RC2 correction is restricted to the same four-file V3 write set.

The SDK snapshot retains all 47 exact packages with two explicit maps: package_hosted_sha256 contains each pub.dev archive SHA256 observed in the trusted SDK pubspec.lock; package_cache_tree_sha256 contains the SHA256 of each extracted package content tree. The latter hashes the sorted relative UTF-8 path, a null byte, the file SHA256 lower hex, and an LF byte for every regular file. Symlinks, missing/extra packages, missing/extra SHA files and content drift are rejected by a RUN validator during Docker build. M1 audited 4,215 cached files (69,518,332 bytes), 47/47 package and archive hash matches, no symlinks. The separate evidence manifest SDK_CI_47_HASH_MANIFEST.json SHA256 is 6fc111dff443bfdea195f1d120a0a28161d1f9b591231407120d2fb0bc8c406c.

To build from the SDK repository root: stage exactly the 47 verified package dirs and 47 pub.dev hosted SHA256 metadata files in an UNTRACKED temporary ci/images/nebula-sdk/cache/ matching the Dockerfile layout; then run:

    docker build --network none -f ci/images/nebula-sdk/Dockerfile -t local/nebula-sdk-ci:20261127-rc2 .

The Dockerfile pins official Dart 3.12 ARM64 and Python 3.13 slim ARM64 source digests; its RUN hash guard reads the committed SDK snapshot and fails on any changed package bytes. Do not commit third-party cache data or treat hash metadata as a substitute for trusted source validation. Verify the new OCI image ID, run full SDK checks offline and independently review it before using the existing M1 Runner. The image identity is nebula-sdk-ci-candidate-20261127-v2 and must never be changed to impersonate the retired image.

Release: same V3 task and PR #164, server-side coordinator-publication label, real exact-head Governance CI SUCCESS, independent Reviewer APPROVED and V3 Architect merge. Only repoint the ONE SDK label on the existing M1 runner after RC2 is built and verified; retain the other seven labels and rollback backup. M4 is not activated.

## Builder compatibility and tamper-proof evidence

M1's Docker legacy builder does not execute source supplied solely by Dockerfile RUN Python heredoc syntax; this was detected in the first RC2 draft. The audited current Dockerfile instead uses a shell printf command that passes the complete readable Python source to python3 -c. The fixed offline build log explicitly contains CI_PACKAGE_HASH_GUARD_PASS packages=47 files=4215. Both negative tests were executed and failed correctly: changing a hosted archive SHA produces mismatched hosted SHA: args-2.7.0; changing one extracted package file produces package content changed: args-2.7.0. The verified ARM64 image ID is sha256:9356017ef184da817ae41befe4a7c6b7bf4f007488d667b9b06d493b158c3855. See the versioned evidence report for log hashes and full 278/278 local regression results. Old PR #164 Reviewer REQUEST_CHANGES has not been self-approved.
