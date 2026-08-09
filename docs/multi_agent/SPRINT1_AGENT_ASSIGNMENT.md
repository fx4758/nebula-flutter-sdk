# Sprint 1 Agent Assignment — Execution Epoch 2

Status: **CONTROLLED BY COORDINATOR**

SSOT: `task_board.json`. Implementation Agent reads but never edits Task Board. Each Story has one execution repo/branch.

- Agent A: `S1-F01-001` → NFC Writer / `s1/f01-001-adapter`; `S1-F01-002` = **NFC Writer Reference Bootstrap Integration**，当前 WAIT，只有在 NFC Writer `NEBULA-DEP-001` 与 `NEBULA-APP-001A` 均 DONE、Coordinator 从最新 App `dev` 重建 worktree 并显式置 READY 后，才可进入 `s1/f01-002-bootstrap`。
- Agent B: `S1-F02-001` → flypost_backend / `s1/f02-001-runtime-config-audit`; after DONE, `S1-F02-002` → SDK / `s1/f02-002-sdk-config`.
- Agent C: `S1-F03-001` → SDK / `s1/f03-001-release`; after DONE, `S1-F03-002` → SDK / `s1/f03-002-api-gate`.

Before editing: run task-source + cross-repo + relevant Platform guards. Shared `main/dev` is never an implementation delivery branch. Delivery Note != acceptance evidence.
