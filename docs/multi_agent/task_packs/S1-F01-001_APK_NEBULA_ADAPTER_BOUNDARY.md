# S1-F01-001 APK Nebula Adapter Boundary
- ID：S1-F01-001
- Owner：Flutter Integration Agent A
- Branch/worktree：`s1/f01-adapter` / `wt-s1f01`
- Goal：建立 App 唯一 `platform/nebula` 适配边界；页面/业务不得直接 import SDK。
- Allowed：Flutter NFC Writer `lib/platform/nebula/**`、`lib/app/dependency.dart`、相关 tests/docs。
- Forbidden：parser/NFC runtime/action execution、业务 Feature、Asset/Upload/Payment/AI、SDK public surface。
- Evidence：changed files、import scan、adapter tests、`flutter analyze`。
