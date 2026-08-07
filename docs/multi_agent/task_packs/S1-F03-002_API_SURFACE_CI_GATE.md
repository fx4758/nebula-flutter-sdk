# S1-F03-002 API Surface CI Gate
- ID：S1-F03-002
- Owner：SDK Governance Agent C
- Depends：S1-F03-001
- Branch/worktree：`s1/f03-release` / `wt-s1f03`
- Goal：public API drift 在 CI 中阻断，并绑定审批流程。
- Allowed：`tool/**`、`governance/**`、`.github/workflows/**`、相关 docs/tests。
- Forbidden：业务实现。
- Evidence：negative probe 必须 FAIL、正常 snapshot PASS、governance tests。
