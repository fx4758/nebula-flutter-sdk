# Nebula Multi-Agent Execution Entry

> Status: **ACTIVE / SSOT**
> Executable source: `task_board.json`
> Policy: `governance/AGENT_EXECUTION_SOURCE_POLICY.md`

## Start protocol
1. Read `task_board.json`.
2. Use only the exact assigned Story ID in `story_tracking`.
3. Run `dart run tool/task_source_guard.dart --story <ID>`.
4. Read the guard-selected one-to-one Task Pack.
5. Work only on declared branch/worktree/paths; submit DELIVERED, never self-approve DONE.

## Active stage
MA0 is DONE. Current active sprint is **S1-A Foundation Integration**. Active Stories and state are machine-readable in `task_board.json`. Do not infer active work from SDK historical `STATUS.md`.

## Cross-repo facts
- SDK authority: this repository, single package `nebula_sdk`.
- Backend authority: `../flypost_backend`; `flypost_server` is management/BFF.
- First App: `../flutter NFC Writer` Flutter root; nested legacy Android is read-only unless explicitly assigned.
- Product-specific parser/NFC/action logic stays in App.

## Hard stops
No Asset SDK, Upload API, Payment live refund, Advanced Risk Engine, or new public capability unless explicitly registered/unblocked in `task_board.json`.

## Platform boundary
Platform API is read-only by default. Consumer integration never authorizes Backend contract changes. Use `platform_api_mode` from `task_board.json`; any gap in a READ_ONLY Story becomes an ACR + separate authorized Story. Contract changes require second-consumer evidence. See `governance/PLATFORM_API_CHANGE_POLICY.md`.

## Acceptance
Agent summary is not evidence. Reviewer independently checks diff/source/config/tests. Only Reviewer/Coordinator moves REVIEW to DONE.
