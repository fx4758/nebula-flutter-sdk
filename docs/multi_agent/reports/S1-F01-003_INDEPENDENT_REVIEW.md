# S1-F01-003 Independent Architecture Review

- Story: `S1-F01-003 Bootstrap Contract Reconciliation`
- Delivery commit: `75e8321f5e911c0014205258ec824aa6ace4fd74`
- Parent / baseline: `5408cfbf32fbb59a89a4d9966fed17fe6955a930`
- Backend authority: FlyPostAPI `Dev @ 956981c119b01a0c1b4bf0793a20bed8f31d1180`
- Verdict: **PASS / no blocker**
- Method: fresh detached SDK worktree + read-only Backend ref; delivery report/PR text was not treated as evidence.

## Mechanical evidence

1. Scope: 11 changed files, only `docs/**` + `test/**`; `lib/**=0`, workflow/tool/runtime-governance diff=0, Coordinator-owned task-state diff=0.
2. Git/CI: parent is canonical main `5408cfb`; PR #2 required check PASS (Forgejo Run #211); fast-forward landing produced `main=75e8321`; main push Run #212 PASS.
3. Backend assertions: endpoint/body cap, `64/128/64/1024/16KiB` limits, request-id echo, request-hash signature, HTTP 429/503 `40002`, and handler `12001/30001/50001` mapping all matched authority source.
4. Independent Go standard-library probe: JSON `null`, field omission, and `""` all decode to empty string for a Go `string` field; non-empty string remains non-empty. This validates nullable canonical attestation compatibility without Backend change.
5. SDK evidence: targeted contract/fixture tests PASS; pre-delivery full suite 196/196 PASS; analyze/governance/API-surface/secret-scan and exact execution branch/repo guards PASS.

## Accepted contract conclusions

- Canonical request = 5 required + 6 optional values, 11 SDK-owned keys; absent optionals encode as JSON `null`.
- `attestation` is nullable string evidence, not object.
- Backend caps use Go `len(string)`; F01-004 must validate UTF-8 bytes, not Dart UTF-16 code units.
- Bootstrap `data.request_id` echoes `bootstrap_request_id`; V2 does not claim a separately generated server correlation identifier.
- Current renewal formula is 24h TTL with `renew_after` at 80% TTL; corrected fixture uses +69120 seconds.
- Idempotency ledger scope is resolved App + bootstrap request ID; current request hash excludes locale/region/attestation. SDK retries are stricter: same immutable values + same ID.
- Current observed outputs: `200/0`, `200/12001`, `200/30001`, `429/40002`, `503/40002`, `200/50001`. `12003/12004` are allocated but not current Bootstrap emissions.
- One bounded retry ceiling is preserved; Bootstrap `50001` is server failure and must not fall through to session `AuthenticationRequiredError`.

## Mutation strength

Three temporary reviewer mutations were independently caught, then restored:

- M1: `renew_after` reverted to old +4320s -> FAIL (`expected 69120, actual 4320`).
- M2: response `request_id` changed to unrelated value -> paired-ID test FAIL.
- M3: `public_key` limit changed from 1024 back to stale 4096 -> V2 oracle test FAIL.

Restore run passed and reviewer worktree returned clean.

## Non-blocking observation

`FlyPostAPI/internal/middleware/logger.go` comments claim the middleware generates `X-Request-ID`, but current implementation at the authority commit does not visibly generate/set it. Other code accepts/uses client-provided `X-Request-Id`. V2 does not depend on automatic server generation, so this is an observability/comment debt, not an S1-F01-003 blocker.

## Promotion

S1-F01-003 is accepted as **DONE / PASS**. Coordinator may promote `S1-F01-004` to **READY / CHANGE_APPROVED**. This does not authorize Backend/App changes and does not release S1-F01-002; App `NEBULA-DEP-002` remains downstream of F01-004.
