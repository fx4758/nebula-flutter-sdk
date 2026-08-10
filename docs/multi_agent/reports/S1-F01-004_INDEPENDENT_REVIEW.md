# S1-F01-004 Independent SDK Review

- Story: `S1-F01-004 SDK Bootstrap Surface Closure`
- Initial delivery: `19fc0971cd49c9cfe7a94b1a65563f3420846e34`
- Review-fix head: `e101c7a4cd8b7da9e9b70050c14fbd4521a93303`
- Canonical squash landing: `59dd960e38ad51c2bd60b59044dfa1698f3a7909`
- Baseline: `da2944d7b192e6c4bcec0c942039897eb3bad683`
- Contract: `CONTRACT-SDK-BOOTSTRAP V2` / FROZEN / PASS
- Final verdict: **PASS / no blocker**

## Review method

Fresh detached reviewer worktrees were used. PR text and Delivery Note were treated as claims, not evidence. Review covered Git shape/scope, production code, public API, governance behavior, targeted tests, Forgejo required checks, and destructive mutations.

## Mechanical evidence

1. Scope from baseline to final review head: 19 files; no Task Board/Coordinator-owned state, Backend, or App implementation diff.
2. Public API: 125 symbols exactly; approved additions are `BootstrapEndpoints`, `NebulaBootstrapClient`, `NebulaBootstrapErrorCategory`, and `classifyBootstrapError`.
3. Production contract:
   - canonical `POST /api/v1/mobile/bootstrap` endpoint;
   - SDK-owned 11-key request serialization with explicit null optionals;
   - UTF-8 byte validation, canonical present-optionals min=1, 32 KiB body ceiling;
   - P-256 SPKI Base64URL public-key fail-fast validation;
   - one bounded same-body/same-ID retry;
   - no retry for frozen definitive 12001/30001/12003/40002/HTTP429/HTTP503 inputs;
   - `50001` remains Bootstrap server failure, not session authentication fallback;
   - response app/installation/request-ID echo is enforced.
4. Real loopback `HttpTransport -> NebulaBootstrapClient` path passes with the canonical wire body.
5. Product-name erasure passes; SDK bootstrap production surface contains no NFC Writer / StarSprout / FlyPost product semantics.
6. Final implementation gates before delivery: format PASS, analyze 0 issues, `dart test` 210/210 PASS, Governance regression 30 cases PASS, API surface 125 PASS, Secret Scan PASS, task/cross-repo/platform/coordinator-state guards PASS.
7. Forgejo required checks:
   - Run #216 PASS for initial delivery `19fc097`;
   - Run #217 PASS for review-fix head `e101c7a`;
   - main push Run #219 PASS for canonical landing `59dd960`.
8. Landing truth: canonical `59dd960` parent = `da2944d`; tree = final review head `e101c7a` tree (`5e7fcb3d93ff721d2a180f88356b5ef319021268`).

## Review R1 — whole-file governance exemption

Initial review found a real blocker: `DATA-TRUST-BODY-APP-ID` used an exact allowed path but skipped the whole file, so a second unrelated `app_id` body mapping inside `installation.dart` was invisible. Reviewer mutation produced Governance PASS, proving the blind spot.

Fix `e101c7a` introduced `allowed_match_count=1` and policy validation. The final fresh reviewer mutation appended a second same-file `app_id`; Governance failed with `2 matching occurrence(s); allowed budget is 1`. Missing match budget and wildcard path are also regression-tested. **R1 CLOSED.**

## Independent mutation strength

Final reviewer mutations were injected and restored:

- R1: second `app_id` in the exact allowed file -> `DATA-TRUST-BODY-APP-ID` FAIL.
- R2: remove Bootstrap response `request_id` echo check -> mismatch test FAIL and wrong response would otherwise be accepted.
- R3: bypass P-256 curve equation -> corrupted-point validation test FAIL.

Earlier implementation mutations also caught endpoint drift, serializer key loss, 50001 retry removal, UTF-8-to-code-unit regression, optional-empty relaxation, and 50001 misclassification. All mutations were restored; reviewer tree returned clean.

## Residuals

- Backend remains the trust authority for public-key parsing/validation; SDK validation is fail-fast only and owns no private key/signing capability.
- Shared numeric mobile error constants still live in `session_errors.dart`; Bootstrap only imports the constants and does not depend on session state/token machinery. Moving constants solely for naming purity would expand public API provenance and is not justified in this Story.
- App secure installation identity, KeyStore/Keychain, installation-token secure storage, proof signer, and lifecycle remain downstream App responsibilities after immutable SDK repin.

## Promotion

S1-F01-004 is accepted as **DONE / PASS**. SDK bootstrap prerequisites are complete. `S1-F01-002` must remain WAIT until NFC Writer `NEBULA-DEP-002` repins the App to canonical SDK commit `59dd960e38ad51c2bd60b59044dfa1698f3a7909` (or a later explicitly approved commit containing the same closure) and independently passes dependency resolve/compile gates.
