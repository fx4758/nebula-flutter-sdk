# Agent Execution Source Policy — GOV-P0-EXEC-SSOT

Status: **FROZEN**  
Effective: 2026-08-07

## One executable source of truth
The **only executable task source** is `docs/multi_agent/task_board.json`.
`docs/STATUS.md`, `docs/03_IMPLEMENTATION_PLAN.md`, historical F0/F1/F2/F3 IDs, old handoff notes, commit messages, and chat summaries are context/history only and MUST NOT be used to auto-select work.

## Mandatory startup protocol
Before changing any file, every implementation agent MUST:
1. Read `docs/multi_agent/task_board.json`.
2. Receive an exact active Story ID from `story_tracking`.
3. Run `dart run tool/task_source_guard.dart --story <STORY_ID>`.
4. Read only the `task_pack` printed by the guard plus required inputs.
5. Confirm owner, branch/worktree, allowed/forbidden paths, reviewer.
If the Story ID is absent/not active or the guard fails: **STOP. Do not substitute another task.**

## Legacy/internal roadmap IDs
`F0-*`, `F1-*`, `F2-*`, `F3-*`, `FB-*`, `FS-*`, `FC-*` are SDK/backend internal history unless explicitly registered in `task_board.json`.

## State authority
`task_board.json` is Coordinator-owned state. Implementation Agents **never edit it** and do not persist claim/delivery state in the governance repo. Agent returns a Delivery Note; Coordinator independently verifies it and owns all persisted transitions `READY -> IN_PROGRESS -> DELIVERED -> REVIEW -> DONE/BLOCKED`. Agent messages are not acceptance evidence. See `governance/CROSS_REPO_EXECUTION_POLICY.md`.

## Branch authority
`main` is the canonical LAN clone entry and MUST contain the active task router/guard. Feature code stays on assigned feature branches/worktrees until evidence-based review.

Any mismatch among `main`, task board, task pack, branch/worktree, or Story ID is **GOV-P0** and blocks implementation.

## Coordinator publication path

Coordinator-owned execution state is published to canonical `main` only through a PR carrying the Forgejo label `coordinator-publication`. The governance workflow derives Coordinator mode from the server-side PR event label; branch names, commit messages, PR titles and file content are not authorization signals.

- Without that label, `coordinator_state_guard` runs in Implementation mode and any Coordinator-owned diff fails.
- With that label on a PR targeting `main`, the workflow may invoke explicit Coordinator mode; all other governance/test/API/secret gates still run.
- The workflow and Coordinator guard tools are themselves Coordinator-owned paths.
- `main` MUST be protected server-side against direct push and MUST require the governance status check before merge.
- Implementation Agents must not request/apply the publication label as a substitute for a Delivery Note; publication authorization belongs to the Coordinator/Architecture Owner.
