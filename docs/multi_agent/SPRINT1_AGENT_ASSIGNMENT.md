# Sprint 1 Agent Assignment — Execution Epoch 2

Status: **CONTROLLED BY COORDINATOR**

SSOT: `task_board.json`. Implementation Agent reads but never edits Task Board. Each Story has one execution repo/branch.

- Agent A: `S1-F01-001` 已 DONE；`S1-F01-002` = **NFC Writer Reference Bootstrap Integration**，继续 WAIT，直到 `S1-F01-003 → S1-F01-004 → NFC Writer NEBULA-DEP-002` 全部 DONE 后，Coordinator 才能从最新 App `dev` 重建 worktree 并显式置 READY。
- Agent D: `S1-F01-003` 已 DONE / independent review PASS；`S1-F01-004` 现 **READY / CHANGE_APPROVED**，只允许按 Bootstrap V2 freeze 实现 canonical SDK surface，不得修改 Backend/App。
- Agent B: `S1-F02-001` → flypost_backend / `s1/f02-001-runtime-config-audit`; after DONE, `S1-F02-002` → SDK / `s1/f02-002-sdk-config`.
- Agent C: `S1-F03-001` → SDK / `s1/f03-001-release`; after DONE, `S1-F03-002` → SDK / `s1/f03-002-api-gate`.

Before editing: run task-source + cross-repo + relevant Platform guards. Shared `main/dev` is never an implementation delivery branch. Delivery Note != acceptance evidence.
