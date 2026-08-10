# Sprint 1 Agent Assignment — Execution Epoch 2

Status: **CONTROLLED BY COORDINATOR**

SSOT: `task_board.json`. Implementation Agent reads but never edits Task Board. Each Story has one execution repo/branch.

- Agent A: `S1-F01-001` 已 DONE；`S1-F01-002` 继续 **WAIT**。App canonical `dev=5d2f4cf` 已发布 ACR `0fd061d` 的 Architecture 裁定；必须等待 `NEBULA-APP-SECURE-001` + `NEBULA-APP-PROFILE-001` 均 DONE，然后由 Coordinator 从最新 App `dev` 重建 `wt-s1f01-002-app` 并显式置 READY。
- Agent D / SDK Core: `S1-F01-003`、`S1-F01-004` 均 DONE。F01-004 reviewed candidate=`07e26d5`，Independent SDK Review R2=`e33ebeb` PASS。SDK Core 停止施工；任何后续 Bootstrap contract/public-surface 变更必须走新 ACR/Story。
- SDK Architect: `S1-F01-004A` DONE，owner delivery=`c1fced21`。
- Architecture/PM: `S1-F01-004B` DONE，owner delivery=`b7d380bb`。
- Quality: `S1-F01-004C` DONE，owner delivery=`2f417e51`。
- Coordinator owner baseline: `integration/s1-f01-004-r2-owner-baseline @ f11fb53`; 不单独 merge main。
- Agent B: `S1-F02-001` → flypost_backend / `s1/f02-001-runtime-config-audit`; after DONE, `S1-F02-002` → SDK / `s1/f02-002-sdk-config`.
- Agent C: `S1-F03-001` → SDK / `s1/f03-001-release`; after DONE, `S1-F03-002` → SDK / `s1/f03-002-api-gate`.

Before editing: run task-source + cross-repo + relevant Platform guards. Shared `main/dev` is never an implementation delivery branch. Delivery Note != acceptance evidence.
