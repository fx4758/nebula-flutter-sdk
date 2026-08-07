# MA0-C01 Acceptance Review

- Story: MA0-C01
- Review date: 2026-08-07
- Reviewer role: Architecture / Governance
- Result: **CHANGES_REQUIRED**
- Story state: keep `REVIEW`; do not mark `DONE`

## Authority decision

Backend source of truth is exclusively:

`/Users/sean/Documents/project/forAI/flypost_backend`

The former Codex worktree is deprecated. It may not be used as a current implementation candidate, contract source, migration source, defect source, or ADR decision input.

## Acceptance findings

### A. Scope / deliverable

- PASS: report exists at the required path.
- PASS: doc-only; no Backend code or dirty `sdk/dart/**` was modified by this Story.
- PASS: Asset / Notification / Payment are all covered with source evidence.
- PASS: Notification correctly distinguishes real client INAPP lifecycle from sandbox external channels.

### B. Blocking factual corrections

1. **Deprecated BE-Codex is treated as a candidate authority — BLOCKER.**
   Remove BE-Codex from base commits, current classification, Asset option comparison, migration input, capability defect input, and follow-up decision inputs. At most retain one historical note stating it is non-authoritative and must not drive implementation.

2. **Mobile trust-subject table is factually wrong — BLOCKER.**
   The report says the mobile group uses `InstallationProof + AppToken`. Current `flypost_backend/internal/router/router.go` shows:
   - `/api/v1/mobile/bootstrap`: coarse IP + body limit; no InstallationProof, no AppToken.
   - mobile code/send, login, refresh: InstallationProof; no AppToken.
   - mobile logout: InstallationProof + user Token; no AppToken.
   - runtime-config: InstallationProof; no AppToken.
   There is currently no AppToken in the mobile chain.

3. **Current Asset persistence/migration facts are wrong — BLOCKER.**
   `internal/model/file.go` keeps the Go type `FileObject`, but `TableName()` is `asset_object`; `StorageConfig.TableName()` is `asset_storage_config`. Migration `017_rename_batch7.sql` already renamed `file_object -> asset_object` and `storage_config -> asset_storage_config`. Therefore statements such as “data table is file_object” and “no asset/file related migration” are incorrect.

4. **`file -> asset Replace` is not an admissible current conclusion — BLOCKER.**
   With BE-Codex deprecated there is no approved replacement implementation. The valid current conclusion is: the existing `module/file` cannot be used *as-is* as the final mobile Asset contract and needs an architecture decision/evolution plan. Do not claim it has already been replaced.

5. **Current file owner trust gap is missing from the Asset decision input — BLOCKER.**
   `internal/module/file/file.go` reads `owner_id`/`owner_type` from client input for both upload/presign; authenticated `uid` is read then discarded in upload. Final mobile Asset contract must not trust arbitrary ownership claims from the request. This is a material reason the current module cannot be exposed as-is.

6. **Payment maturity is overstated — BLOCKER.**
   Do not call the Payment core chain `production-capable`. Current source and `docs/PRODUCTION_READINESS_AUDIT_2026-08-03.md` classify it as high-risk partial:
   - `Service.Refund()` marks the order refunded and writes a REFUND transaction without calling a Provider refund API; the source comment says real provider refund is future work.
   - Provider interface has no Refund/Query reconciliation port.
   - production readiness requires atomic callback transition, live refund state machine, and reconciliation before money safety is closed.
   - live charge adapters exist for selected providers, but that does not make the full Payment domain production-ready.
   Replace “production-capable” with a capability-by-capability classification (charge/callback/subscription/refund/reconcile).

### C. Non-blocking refinements

- Use “payment collection/charge” rather than “出金” when discussing customer payment; refund is the outbound money path.
- Tests were not required by this doc-only Task Pack, so “not run” is acceptable, but test existence must not be treated as test pass evidence.

## Required resubmission shape

Revise `MA0_C01_BACKEND_CAPABILITY_AUDIT.md` using only `flypost_backend` as authority and keep the same Task Pack scope. The revised report must contain:

1. One authoritative Asset section for current `module/file` + `pkg/storage` + `asset_object` tables.
2. Correct current trust chain and ownership-trust gaps.
3. Notification classification: INAPP client lifecycle vs external sandbox channels.
4. Payment matrix at least covering: create charge, callback, subscription, refund, reconciliation, provider live/sandbox state.
5. Adapt / Refactor Later / Replace / Deferred classifications based only on the authority tree.
6. Asset Contract decision inputs rewritten without BE-Codex as an option.

## Acceptance decision

`MA0-C01 = CHANGES_REQUIRED`

Keep Story in `REVIEW`. After the report is revised, request re-review; no code changes are required for this correction round.
