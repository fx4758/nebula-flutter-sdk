# S1-F01-004 Independent SDK Review — R1

- Story: `S1-F01-004 SDK Bootstrap Surface Closure`
- Original delivery reviewed: `19fc0971cd49c9cfe7a94b1a65563f3420846e34`
- Rework tip reviewed: `e101c7a4cd8b7da9e9b70050c14fbd4521a93303`
- Parent / canonical baseline: `da2944d7b192e6c4bcec0c942039897eb3bad683`
- Contract authority: `CONTRACT-SDK-BOOTSTRAP V2` / FROZEN / PASS
- Reviewer role: independent SDK Reviewer; delivery note text was navigation only, not evidence.
- Review time: `2026-08-10T11:58:07+08:00`
- Verdict: **REQUEST CHANGES / NOT DONE**

## 1. Scope and positive evidence

The core Bootstrap implementation direction is correct and substantially matches V2:

- canonical endpoint is `/api/v1/mobile/bootstrap`;
- `BootstrapRequest.toJson()` owns the 11-key wire map with explicit null optionals;
- UTF-8 byte caps, optional non-empty semantics, P-256 SPKI fail-fast validation, and 32 KiB canonical JSON cap are implemented;
- `NebulaBootstrapClient` reuses `NebulaTransport`, preserves one immutable body across retry, and caps automatic retry to one extra attempt;
- `50001` is bootstrap `serverFailure`, not session authentication fallback;
- response identity checks cover `app_id`, `installation_id`, and `request_id == bootstrap_request_id`;
- Product-name erasure passes for the Bootstrap production surface.

Independent locked-image verification on the latest candidate used `flypost/nebula-sdk-ci:20260810-v1` / Dart `3.12.0` / identity `nebula-sdk-ci-20260810-v1` and passed:

- CI dependency guard: PASS / 47 packages;
- Governance: PASS;
- Governance regression: **30 cases PASS** at `e101c7a`;
- API surface: PASS / 125 symbols;
- Secret scan: PASS;
- format: PASS;
- analyze: PASS / 0 issues;
- `dart test`: **210/210 PASS**;
- Task Source Guard / Cross Repo Guard: PASS;
- Coordinator State Guard: PASS / zero Coordinator-owned task-state diff;
- Platform API Guard: PASS / no Backend write scope;
- `git diff --check`: PASS.

Passing gates do not override the two blocking findings below because both are outside the current test/ownership enforcement coverage.

## 2. BLOCKER — GOV-OWN-01: SDK Core Agent modified Quality/serial-owner governance paths

### Evidence

Task Board / Task Pack assigns this Story to `SDK Core Agent D` with `sdk_public_api_mode=CHANGE_APPROVED`. That authorizes the approved SDK public semantic delta; it does not transfer ownership of unrelated governance tooling.

`docs/multi_agent/03_OWNERSHIP_MATRIX.md` freezes:

- governance policy: Architecture/PM serial ownership; Implementation Agent read-only;
- `governance/**`, `tool/**`: **Quality Agent**, no parallel write;
- `lib/nebula_sdk.dart`: SDK Architect serial ownership.

The candidate delta from `da2944d` nevertheless contains owner-sensitive changes including:

- `governance/policy.json`;
- `governance/api_surface.snapshot`;
- `governance/public_api.txt`;
- `tool/governance.dart`;
- `tool/governance_test.dart`;
- `lib/nebula_sdk.dart`.

Most critically, the SDK implementation Agent changed the blocking scanner/policy that was rejecting its own new `app_id` wire map. A green result from the modified guard cannot establish authority to modify that guard.

### Required change

Do not self-authorize the SDK implementation by editing Quality-owned enforcement in the same implementation ownership context.

Acceptable closure is one of:

1. **Preferred:** split the governance/public-surface integration into an explicitly owned Quality / SDK Architect / Coordinator-approved serial change, land that prerequisite/integration independently, then rebase/rebuild the SDK Core candidate on the authorized baseline; or
2. Coordinator explicitly records a narrow owner delegation for the exact serial paths before re-review, with the Quality/SDK Architect owner independently reviewing the scanner/public-surface mutation.

At minimum `governance/policy.json` and `tool/governance*.dart` must not remain an SDK Core self-exemption without separate owner authorization. The API snapshot/barrel serial ownership must also be explicitly reconciled rather than inferred from `CHANGE_APPROVED`.

## 3. BLOCKER — CONTRACT-INT64-01: V2 int64 response times accept fractions and silently truncate

### Evidence

V2 freezes:

- `expires_at`: int64 unix seconds;
- `renew_after`: int64 unix seconds;
- `server_time`: int64 unix seconds.

Current `BootstrapResult._unixSeconds` accepts any Dart `num` and calls `toInt()`. Independent negative probe supplied:

- `expires_at = 1.75`;
- `renew_after = 1.25`;
- `server_time = 1.5`.

The parser returned success and produced `1000/1000/1000` milliseconds. A malformed non-int64 wire value is therefore silently normalized instead of rejected as `invalidResponse`.

This matters specifically to F01-004 because the Task Pack requires request/response/error behavior to match the re-frozen V2 contract, and the new bootstrap error classifier already defines malformed response handling. The malformed value currently never reaches that failure path.

### Required change

- Require integer wire values for all three fields (`int`, or an equivalently strict integral-wire check with no truncation).
- Add a negative contract test proving fractional JSON numbers are rejected.
- Keep server-authoritative `renew_after`; do not derive/round a client value.

## 4. R1 finding closed by implementation rework — GOV-EXEMPT-01

The original `19fc0971` implementation introduced `allowed_paths` such that `DATA-TRUST-BODY-APP-ID` skipped all matches in `lib/src/auth/installation.dart`.

Independent mutation added a second unrelated body mapping in that same file:

```text
{'app_id': 'untrusted-scope'}
```

At `19fc0971`, `Nebula Governance` incorrectly returned PASS.

The implementation branch then advanced to `e101c7a`, adding `allowed_match_count = 1` plus two regression cases. Repeating the same mutation at `e101c7a` fails with `DATA-TRUST-BODY-APP-ID` because two occurrences exceed the allowed budget.

**Status: technically CLOSED at `e101c7a`.** This does not close GOV-OWN-01: the scanner change is still authored in the wrong ownership context.

## 5. Non-blocking observation

The delivery statement that SDK production legacy FlyPost comments were fully removed is broader than repository fact. Current `lib/**` still contains pre-existing FlyPost/flypost comments in `http_transport.dart` and `config_endpoints.dart`. They are inherited from `da2944d` and were not introduced by F01-004, so this review does **not** count them as an F01-004 regression. Product-name erasure for the new Bootstrap surface itself passes.

## 6. Re-review gate

A replacement candidate may be re-reviewed when all of the following are true:

1. owner-sensitive governance/public-surface writes are split or explicitly delegated/reviewed by their registered owners;
2. fractional Bootstrap response times are mechanically rejected with a regression test;
3. the bounded `app_id` exception remains no broader than one authorized Bootstrap occurrence;
4. locked CI image gates remain green;
5. Task Board / Sprint Board / assignment remain Coordinator-owned;
6. no Backend or NFC Writer implementation is added.

Until then:

```text
S1-F01-004 = REQUEST CHANGES / NOT DONE
NEBULA-DEP-002 = WAIT
S1-F01-002 / NFC Writer 001B = WAIT
```

No immutable SDK repin and no NFC Writer Bootstrap integration is authorized by this review.
