# S1-F02-002 SDK Runtime Config Client Closure
- ID：S1-F02-002
- Owner：SDK Config Agent B
- Depends：S1-F02-001
- Branch/worktree：`s1/f02-runtime-config` / `wt-s1f02`
- Goal：复用现有 `NebulaConfigClient`，只做 Sprint 1 接入 closure；禁止重写 F2 已完成能力。
- Allowed：`lib/src/config/**`（仅必要修正）、tests/docs。
- Forbidden：业务规则、public capability 扩张、Asset/Payment/Notification/AI。
- Evidence：reuse map、cache/offline tests、API surface check、dart analyze/test。
