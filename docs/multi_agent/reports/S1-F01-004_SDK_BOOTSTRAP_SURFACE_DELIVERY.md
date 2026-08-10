# S1-F01-004 SDK Bootstrap Surface Closure — Delivery Note

- Story: `S1-F01-004`
- Baseline: canonical SDK `main @ da2944d7b192e6c4bcec0c942039897eb3bad683`
- Contract authority: `CONTRACT-SDK-BOOTSTRAP V2` / FROZEN / PASS
- Authorization: `ACR-SDK-BOOTSTRAP-001` / `sdk_public_api_mode=CHANGE_APPROVED`
- Execution branch: `s1/f01-004-sdk-bootstrap-surface`
- Delivery status: **IMPLEMENTED / PENDING INDEPENDENT SDK REVIEW**

## Production closure

The SDK now owns the complete canonical bootstrap wire surface:

1. `BootstrapEndpoints.bootstrap == "/api/v1/mobile/bootstrap"`.
2. `BootstrapRequest.toJson()` emits exactly 11 keys; absent optionals are explicit JSON `null`.
3. `BootstrapRequest.validate()` enforces V2 UTF-8 byte limits, canonical non-empty-present optionals, 32 KiB canonical JSON body ceiling, and P-256 SPKI public-key format.
4. `NebulaBootstrapClient` uses the existing `NebulaTransport`; no second HTTP stack exists.
5. Automatic retry is capped at one extra attempt, reuses the exact same immutable canonical body/request ID, and only accepts frozen retry inputs.
6. Response `app_id`, `installation_id`, and `request_id` are mechanically checked against the request before success is returned.
7. `classifyBootstrapError()` keeps Bootstrap semantics separate from session fallback: current `50001` is `serverFailure`, never authentication-required.

Public-key validation is fail-fast only. The SDK never owns or exports a private key and never signs here; Backend validation remains authoritative.

## Public API delta

Approved new top-level public symbols: 4.

- `BootstrapEndpoints`
- `NebulaBootstrapClient`
- `NebulaBootstrapErrorCategory`
- `classifyBootstrapError`

`BootstrapRequest.toJson()` is a member on the existing public model. API snapshot moved from 121 to 125 symbols with no extra leak.

## Governance closure for public `app_id`

The frozen bootstrap request must serialize public `app_id` (product/app key), while the existing `DATA-TRUST-BODY-APP-ID` rule correctly forbids mobile-authored trusted App scope elsewhere.

The guard now supports exact `allowed_paths` only. The sole exception is:

`lib/src/auth/installation.dart`

Reason: Bootstrap V2 sends the public app key; Backend independently resolves trusted numeric AppID. Wildcard allowed paths are mechanically rejected, and the existing “body-authored app scope” regression in other files remains blocking.

## Verification evidence

Latest pre-delivery gates:

- `dart format --output=none --set-exit-if-changed .` PASS
- `dart analyze` PASS / 0 issues
- `dart test` **210/210 PASS**
- real loopback `HttpTransport -> NebulaBootstrapClient` integration PASS
- Product-name erasure PASS
- `Nebula Governance` PASS
- Governance regression **30 cases PASS**
- API surface PASS: 125 symbols
- Secret scan PASS
- Task Source Guard `S1-F01-004` PASS
- Cross Repo Guard exact repo/branch PASS
- Platform API Guard (`NONE`) PASS
- Coordinator State Guard in Implementation mode PASS / zero Coordinator-owned state diff
- `git diff --check` PASS

## Mutation strength

Temporary production mutations were injected and restored; all were caught:

- M1 endpoint drift -> endpoint test FAIL.
- M2 drop `region` from serializer -> exact 11-key test FAIL.
- M3 remove `50001` retry -> client retry test FAIL.
- M4 regress UTF-8 required cap to Dart `String.length` -> byte-cap test FAIL.
- M5 allow empty canonical optional-present values -> canonical V2 optional test FAIL.
- M6 classify `50001` as invalid installation -> Bootstrap error-classification test FAIL.

M1-M4 restore hash matched exactly; M5-M6 restore hash matched exactly. Post-restore targeted tests PASS.

Independent review R1 found a real whole-file exemption blind spot: a second `app_id` mapping added inside the exact allowed file was initially invisible. The guard was tightened to `allowed_match_count=1`; regression now proves both missing match budget and a second same-file match are blocking. Reviewer mutation R1 is therefore closed mechanically rather than by convention.

## Residual / downstream

- Backend remains the authoritative P-256 parser/validator; SDK validation is fail-fast defense, not a trust boundary.
- `12003/12004` remain allocated platform categories but are not current Bootstrap production emissions; client behavior is frozen for compatibility if returned later.
- This Story does not implement App KeyStore/Keychain, installation-token secure storage, proof signing, or App lifecycle. Those remain NFC Writer `NEBULA-APP-001B` responsibilities after immutable SDK repin.
- No Backend or App repository was modified.

This implementation Agent does **not** mark S1-F01-004 DONE and does not release `S1-F01-002`. Independent SDK Review and separate Coordinator publication remain mandatory.
