# Sprint 1 Agent Assignment — Execution Epoch 2

Status: **CONTROLLED BY COORDINATOR**

SSOT: `task_board.json`. Implementation Agent reads but never edits Task Board. Each Story has one execution repo/branch.

- Agent A: `S1-F01-001` 已 DONE；`S1-F01-002` 继续 WAIT。SDK `S1-F01-003/004` 已 DONE/PASS，当前只等 NFC Writer `NEBULA-DEP-002=DONE`；之后 Coordinator 才能从最新 App `dev` 重建 worktree并显式置 READY。
- Agent D: `S1-F01-003` 与 `S1-F01-004` 均已 **DONE / independent review PASS**；Bootstrap V2 canonical SDK surface 已落 canonical `main=59dd960e...`。
- Agent B: `S1-F02-001` → flypost_backend / `s1/f02-001-runtime-config-audit`; after DONE, `S1-F02-002` → SDK / `s1/f02-002-sdk-config`.
- Agent C: `S1-F03-001` → SDK / `s1/f03-001-release`; after DONE, `S1-F03-002` → SDK / `s1/f03-002-api-gate`.

Before editing: run task-source + cross-repo + relevant Platform guards. Shared `main/dev` is never an implementation delivery branch. Delivery Note != acceptance evidence.
