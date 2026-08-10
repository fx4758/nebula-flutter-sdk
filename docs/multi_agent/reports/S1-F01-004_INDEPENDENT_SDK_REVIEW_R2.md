# S1-F01-004 Independent SDK Review R2

- Story: `S1-F01-004 SDK Bootstrap Surface Closure`
- Reviewed candidate: `07e26d5376c1715c5daba909572af37483c71fbe`
- Candidate branch: `hub/s1/f01-004-sdk-bootstrap-surface-r2`
- Immutable execution base: `refs/tags/s1-f01-004-r2-execution-base -> 6a11f575557854f0b772c175d484a5a4e31c4859`
- Owner-authorized runtime baseline: `f11fb53d6ff6e6ec689797133e78f6b7a9219a05`
- R1 authority: `e07e825f6a94bc2c651b166118b37cf235df8de4`
- Contract: `CONTRACT-SDK-BOOTSTRAP V2`
- Verdict: **PASS / no blocking finding**

## Review method

The delivery note was treated as a claim, not evidence. Review used a fresh detached worktree pinned to `07e26d5`, independently fetched remote refs, inspected the frozen V2 contract and production code, verified Git ancestry and owner provenance, byte-compared the replay patch, ran the locked SDK CI image, and performed destructive mutations that had to fail before restoring the tree.

The Reviewer did not modify Task Board, Sprint Board, assignment state, Backend, or NFC Writer.

## Git shape and replay integrity

`07e26d5` is a direct one-commit Core replay above immutable execution base `6a11f575`. Its diff contains exactly the frozen 13 SDK Core files.

Independent binary-diff verification:

```text
expected 01-sdk-core.patch:
b0b23df76fd75c4134de20089b02cdfe4c17197384bc49d5bd239e41b0ba6e80

07e26d5 diff vs execution base:
b0b23df76fd75c4134de20089b02cdfe4c17197384bc49d5bd239e41b0ba6e80

CORE_PATCH_BYTE_MATCH: PASS
```

`07e26d5` does not modify `governance/**`, `tool/**`, or `lib/nebula_sdk.dart`.

## GOV-OWN-01 — CLOSED

Owner-sensitive file provenance in final candidate ancestry:

```text
lib/nebula_sdk.dart              -> 10517be / SDK Architect
governance/policy.json           -> 72189ef / Architecture-PM
governance/api_surface.snapshot  -> f11fb53 / Quality
governance/public_api.txt        -> f11fb53 / Quality
tool/governance.dart             -> f11fb53 / Quality
tool/governance_test.dart        -> f11fb53 / Quality
```

Mixed-owner commits `19fc097`, `e101c7a`, `a7ccd6c`, and `4aa233e` are all **not ancestors** of `07e26d5`.

Destructive probe: a second `app_id` map was injected into `installation.dart`. Governance failed with `DATA-TRUST-BODY-APP-ID`, reporting 2 matches against allowed budget 1. Mutation was restored. The owner/self-exemption blocker is therefore closed both historically and mechanically.

## CONTRACT-INT64-01 — CLOSED

`BootstrapResult._unixSeconds()` now requires `int`; it no longer accepts `num` followed by `toInt()` normalization.

Reviewer deliberately regressed it back to `num.toInt()` and ran the fractional regression. The test failed because malformed `1.75 / 1.25 / 1.5` values were accepted instead of throwing `FormatException`. Mutation was restored. The exact R1 truncation regression is now mechanically guarded.

## Bootstrap V2 contract review

Final candidate remains aligned with the frozen V2 contract:

- SDK-owned `POST /api/v1/mobile/bootstrap` endpoint;
- exactly 11 canonical request keys with explicit null optionals;
- 5 required / 6 nullable optionals;
- UTF-8 byte limits and 32 KiB canonical body ceiling;
- Base64URL P-256 SPKI fail-fast validation;
- nullable string attestation; no `environment` or `key_algorithm` request wire;
- existing `NebulaTransport` only;
- one bounded automatic retry with the same canonical body object/request ID;
- retry inputs: transport ambiguity, `50001`, allocated `12004`;
- no-immediate-retry: `12001`, `30001`, `12003`, `40002`, HTTP 429, HTTP 503;
- `50001` -> Bootstrap `serverFailure`, never authentication-required;
- response app/installation/request-ID echo enforced;
- server-authoritative `renew_after` consumed as returned.

Destructive response-identity probe: Reviewer removed only the `request_id` echo comparison. The targeted identity-mismatch test failed because the wrong response was then accepted. Mutation was restored.

## Independent locked CI

Environment:

```text
flypost/nebula-sdk-ci:20260810-v1
Dart 3.12.0
nebula-sdk-ci-20260810-v1
```

Results:

```text
CI dependency guard       PASS / 47 packages
Nebula Governance         PASS
Governance regression     PASS / 30 cases
API Surface               PASS / 125 symbols
Secret Scan               PASS
dart format               PASS
dart analyze              PASS / 0 issues
dart test                 PASS / 211 tests
smoke                     PASS
Task Source Guard         PASS
Cross Repo Guard          PASS
Coordinator State Guard   PASS
Platform API Guard        PASS
git diff --check          PASS
```

Final `lib/** + governance/** + tool/** + test/**` content is identical to the already reconstructed R2 evidence tree.

## Remote stability and verdict

At review completion:

```text
reviewed candidate = 07e26d5376c1715c5daba909572af37483c71fbe
remote branch      = 07e26d5376c1715c5daba909572af37483c71fbe
REMOTE_STABLE      = PASS
```

**PASS.** Both R1 blockers are closed in the clean R2 history and implementation. No new blocking SDK architecture, contract, ownership, governance, or regression-defense issue was found.

Reviewer does **not** mark `S1-F01-004` DONE. Correct promotion boundary remains:

```text
Independent SDK Review R2 PASS
        ↓
Coordinator verifies and publishes S1-F01-004 DONE
        ↓
NEBULA-DEP-002 may be released
        ↓
only after App repin DONE may S1-F01-002 / NFC Writer 001B be promoted
```

Until Coordinator publication lands, NFC Writer repin and `S1-F01-002` remain blocked by canonical Task Board state.
