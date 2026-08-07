# S1-F01-002 Bootstrap Lifecycle Integration
- ID：S1-F01-002
- Owner：Flutter Integration Agent A
- Depends：S1-F01-001
- Branch/worktree：`s1/f01-adapter` / `wt-s1f01`
- Goal：把 Nebula bootstrap 接入唯一 Composition Root；失败不得阻塞 App 启动。
- Allowed：App bootstrap/composition-root、`lib/platform/nebula/**`、tests/docs。
- Forbidden：业务页面直接 SDK、parser/NFC runtime、Asset/Payment/Notification/AI。
- Evidence：startup flow、failure fallback test、single composition-root proof、`flutter analyze/test`。
