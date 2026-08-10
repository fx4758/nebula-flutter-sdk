# Sprint 1 Agent Assignment — Execution Epoch 2

Status: **CONTROLLED BY COORDINATOR**

SSOT: `task_board.json`. Implementation Agent reads but never edits Task Board. Each Story has one execution repo/branch.

- Agent A: `S1-F01-001` 已 DONE；`S1-F01-002` 继续 WAIT。stale `59dd960/7929487` 不构成 SDK prerequisite；必须等 `S1-F01-004 R2 DONE/PASS → NFC Writer NEBULA-DEP-002 DONE` 后，Coordinator 才能从最新 App `dev` 重建 worktree 并显式置 READY。
- Agent D / SDK Core: `S1-F01-003` 已 DONE；`S1-F01-004` 现 **READY / R2 CLEAN REPLAY ONLY**。执行 branch=`s1/f01-004-sdk-bootstrap-surface-r2`，base=`f11fb53`；只允许 replay 冻结的 `01-sdk-core.patch`，禁止 cherry-pick `19fc097/e101c7a/a7ccd6c/4aa233e`。交付后必须独立 SDK Review R2，未 PASS 前不得 DONE。
- SDK Architect: `S1-F01-004A` DONE，owner delivery=`c1fced21`。
- Architecture/PM: `S1-F01-004B` DONE，owner delivery=`b7d380bb`。
- Quality: `S1-F01-004C` DONE，owner delivery=`2f417e51`。
- Coordinator owner baseline: `integration/s1-f01-004-r2-owner-baseline @ f11fb53`; 不单独 merge main。
- Agent B: `S1-F02-001` → flypost_backend / `s1/f02-001-runtime-config-audit`; after DONE, `S1-F02-002` → SDK / `s1/f02-002-sdk-config`.
- Agent C: `S1-F03-001` → SDK / `s1/f03-001-release`; after DONE, `S1-F03-002` → SDK / `s1/f03-002-api-gate`.

Before editing: run task-source + cross-repo + relevant Platform guards. Shared `main/dev` is never an implementation delivery branch. Delivery Note != acceptance evidence.
