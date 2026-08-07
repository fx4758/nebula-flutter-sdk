# S1-F01-001 APK Nebula Adapter Boundary
- ID：S1-F01-001
- Owner：Flutter Integration Agent A
- Execution repo：`../flutter NFC Writer`
- Execution branch：`s1/f01-001-adapter`
- Governance state：`READ_ONLY` for Implementation Agent; Task Board/Sprint Board由 Coordinator 独占写
- Delivery：只提交 execution repo 的 commit + Delivery Note；不得跨仓 claim/deliver 落盘
- Platform API mode：`NONE`
- SDK public API mode：`READ_ONLY`
- Goal：建立 App 唯一 `platform/nebula` 适配边界；页面/业务不得直接 import SDK。
- Allowed：Flutter NFC Writer `lib/platform/nebula/**`、`lib/app/dependency.dart`、相关 tests/docs。
- Forbidden：parser/NFC runtime/action execution、业务 Feature、Asset/Upload/Payment/AI、SDK public surface、Backend Platform API。
- Adapter-first：如果 App 需求与现有 SDK/Platform 模型不一致，先在 Adapter 映射；不得为了减少映射代码要求 SDK/Platform 增产品字段。
- Gap rule：确实无法适配时只提交证据 + ACR；本 Story 不得改 Platform API 或 SDK public API。
- Evidence：changed files、import scan、adapter tests、`flutter analyze`、无跨仓 Platform diff。

## Review Rework R1（Blocking）

Independent Reviewer found that `NebulaAdapter.debugClient` publicly returns SDK type `Nebula`; `@visibleForTesting` is not access control. This bypasses the intended Adapter boundary through type inference even without a direct SDK import.

Required:
- remove/private-test-hook the SDK-typed public member;
- add ARCH-010 regression that prevents public Adapter signatures from exposing SDK types;
- keep `lib/platform/nebula/**` as the only SDK import location;
- no new capability / Backend / SDK public API change.

## Review Rework R2（Blocking）

R1 removed `debugClient`, but independent negative probes proved ARCH-010 still has false negatives. Current code also retains public SDK-typed seams.

Required:
- no public top-level/member signature in the App-facing Nebula boundary may expose `nebula_sdk` types; specifically close `nebulaSessionStatusOf(NebulaSessionState)`;
- close or mechanically isolate `PendingProofSigner implements RequestProofSigner` / `ProofCanonicalInput` so business code cannot consume that SDK seam;
- replace the single-line/class-only R-NEB-5 scan with a surface-oriented guard covering top-level declarations, multiline signatures, and all business-reachable Nebula boundary files;
- negative probes must include getter return, top-level function, multiline parameter, and internal pending-port import; each forbidden case must fail the guard;
- no SDK/Backend/Task Board change by the implementation Agent.


## Final Review Result

- Verdict: **PASS / DONE**
- Reviewed by: Architecture Coordinator
- Reviewed at: `2026-08-07T23:14:37+08:00`
- App delivery: `lan/s1/f01-001-adapter` @ `5e9ee79374397aaaeec88666f9fb99952ee89750`
- Evidence: target tests 19 PASS; full `test/arch` 77 PASS; analyzer baseline `WARNING 48<49 / INFO 318=318`; 25 rules OK.
- Boundary closure: Analyzer AST exact public-surface allowlist + Dart `part` / `_private` pending seam.
- Destructive verification: six forbidden mutations all made ARCH-010 fail; restored baseline passed.
- Shared `lan/dev` remained `00c0dc0`; no direct shared-branch delivery.
- `S1-F01-002` is now dependency-unblocked but remains READY/unclaimed.
