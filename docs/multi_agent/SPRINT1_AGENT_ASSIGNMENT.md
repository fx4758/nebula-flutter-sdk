# Sprint 1 Agent Assignment — Execution Epoch 2

Status: **CONTROLLED BY COORDINATOR**

SSOT: `task_board.json`. Implementation Agent reads but never edits Task Board. Each Story has one execution repo/branch.

- Agent A: `S1-F01-001` 已 DONE；`S1-F01-002` 继续 WAIT。stale `59dd960/7929487` 不构成 SDK prerequisite；必须等 `S1-F01-004 R2 DONE/PASS → NFC Writer NEBULA-DEP-002 DONE` 后，Coordinator 才能从最新 App `dev` 重建 worktree 并显式置 READY。
- Agent D / SDK Core: `S1-F01-003` 已 DONE；`S1-F01-004` = **WAIT / REQUEST CHANGES R1**。不得继续施工，直到 004A/B/C 全部 owner-authored delivery 并由 Coordinator 组装 baseline；届时只 replay `01-sdk-core.patch`。
- SDK Architect: `S1-F01-004A` READY，仅 `lib/nebula_sdk.dart`。
- Architecture/PM: `S1-F01-004B` READY，仅 `governance/policy.json`。
- Quality: `S1-F01-004C` READY，仅 `governance/api_surface.snapshot`、`governance/public_api.txt`、`tool/governance*.dart`。
- Agent B: `S1-F02-001` → flypost_backend / `s1/f02-001-runtime-config-audit`; after DONE, `S1-F02-002` → SDK / `s1/f02-002-sdk-config`.
- Agent C: `S1-F03-001` → SDK / `s1/f03-001-release`; after DONE, `S1-F03-002` → SDK / `s1/f03-002-api-gate`.

Before editing: run task-source + cross-repo + relevant Platform guards. Shared `main/dev` is never an implementation delivery branch. Delivery Note != acceptance evidence.
