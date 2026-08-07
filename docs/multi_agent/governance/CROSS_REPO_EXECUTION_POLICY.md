# Cross-Repository Story Execution Policy — GOV-CROSS-REPO-001

Status: **FROZEN / BLOCKING**
Effective: 2026-08-07

## 1. Core rule

A Story may depend on multiple repositories, but an implementation Agent executes in **exactly one `execution_repo` per Story**.

Cross-repo dependency does **not** mean cross-repo write permission.

- `governance_repo`: `nebula-flutter-sdk`, contains Task Board/Task Pack and is read-only to implementation Agents unless the Story's `execution_repo` is this SDK repository and the changed path is not Coordinator-owned.
- `execution_repo`: the only repository where the Agent may create implementation commits for that Story.
- `execution_branch`: one Story = one reviewable feature branch. Direct push to shared `main/dev` is forbidden for implementation delivery.

If a second repository needs implementation changes, Coordinator splits a second Story with its own Owner/reviewer/branch.

## 2. State authority

Implementation Agents **never edit**:

- `docs/multi_agent/task_board.json`
- `docs/multi_agent/02_SPRINT_BOARD.md`
- Agent assignment/dispatch global state
- architecture authorization fields

Coordinator/Architecture Owner owns all persisted Story state transitions:

`READY -> IN_PROGRESS -> DELIVERED -> REVIEW -> DONE/BLOCKED`

Agent communicates a **Delivery Note only**: Story ID, execution repo, branch, commit, changed paths, tests, residual risk. Coordinator independently verifies evidence and then updates Task Board.

This supersedes the old rule that allowed an Agent to write its own `READY -> IN_PROGRESS -> DELIVERED` state.

## 3. Repository/branch gate

Before editing, Agent must validate:

1. exact Story ID from Task Board;
2. `execution_repo` matches the repository it is about to modify;
3. current branch equals `execution_branch`;
4. governance repo has no Agent-authored state mutation;
5. declared Platform/SDK public API modes still pass their guards.

A mismatch is **GOV-P0**. Stop; do not 'helpfully' update another repo.

## 4. Sprint 1 mapping

- `S1-F01-001`: execution repo = Flutter NFC Writer; branch = `s1/f01-001-adapter`.
- `S1-F01-002`: execution repo = Flutter NFC Writer; branch = `s1/f01-002-bootstrap`.
- `S1-F02-001`: execution repo = `flypost_backend`; branch = `s1/f02-001-runtime-config-audit`.
- `S1-F02-002`: execution repo = `nebula-flutter-sdk`; branch = `s1/f02-002-sdk-config`.
- `S1-F03-001`: execution repo = `nebula-flutter-sdk`; branch = `s1/f03-001-release`.
- `S1-F03-002`: execution repo = `nebula-flutter-sdk`; branch = `s1/f03-002-api-gate`.

No combined F01/F02/F03 branch is authoritative for new work.

## 5. Shared branch protection

Implementation delivery must not be pushed directly to shared `main`, `dev`, release, or default LAN branches. If accidental direct push occurs:

1. preserve the delivery commit on a feature/review branch;
2. quarantine the shared branch back to its pre-delivery code tree without losing history;
3. record the incident;
4. review from the feature branch only.

## 6. Reviewer rule

Any Story where the Agent changed a repository other than `execution_repo`, or changed Coordinator-owned state, is automatically **CHANGES REQUIRED on governance**, even if the implementation itself is technically correct. The implementation commit may still be reviewed separately after isolation.
