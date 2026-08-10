# S1-F01-002 NFC Writer Reference Bootstrap Integration
- ID：S1-F01-002
- Owner：Flutter Integration Agent A
- Depends：S1-F01-001 + current NFC Writer baseline gate
- Execution repo：`../flutter NFC Writer`
- Execution branch：`s1/f01-002-bootstrap`
- Governance state：`READ_ONLY` for Implementation Agent; Task Board/Sprint Board由 Coordinator 独占写
- Delivery：只提交 execution repo 的 commit + Delivery Note；不得跨仓 claim/deliver 落盘
- Platform API mode：`NONE`
- SDK public API mode：`READ_ONLY`
- Product role：NFC Writer 是 Nebula Flutter SDK 的第一个 **Reference Consumer**，不是 SDK 的产品语义来源。

## Execution gate

当前 Story 定义已冻结，但**不得领取**，直到 Coordinator 机械确认：

1. `S1-F01-003 = DONE`（bootstrap contract reconciliation）；
2. `S1-F01-004 = DONE`（canonical SDK bootstrap surface closure）；
3. `flutter NFC Writer:NEBULA-DEP-001 = DONE`；
4. `flutter NFC Writer:NEBULA-APP-001A = DONE`；
5. `flutter NFC Writer:NEBULA-DEP-002 = DONE`（已满足）；
6. `flutter NFC Writer:NEBULA-APP-SECURE-001 = DONE`（secure installation identity）；
7. `flutter NFC Writer:NEBULA-APP-PROFILE-001 = DONE`（public product registration/runtime profile）；
8. 从届时最新 App `dev` **重新创建** `s1/f01-002-bootstrap` / `wt-s1f01-002-app`；当前 ACR worktree 不得继续 production implementation；
9. Task Board 由 Coordinator 将本 Story `WAIT -> READY`。

当前 blocker authority：App ACR `0fd061d51bd89313eb86cd774bb1ef5413d5a0d0`，Architecture publication 已进入 App canonical `dev=5d2f4cf0710abf248feea68335bcf281c4300aea`。

`NEBULA-APP-SECURE-001` 与 `NEBULA-APP-PROFILE-001` 是 App-owned prerequisite，不授权本 Story 扩大 `Platform API mode=NONE` 或修改 SDK/Backend。

历史 `S1-F01-001` 的 DONE 只证明 Adapter Boundary 合同成立，不授权在旧 App baseline 上继续 bootstrap。

## Goal

把 Nebula bootstrap 接入 NFC Writer 唯一 Composition Root，并把这次接入固化为 StarSprout / FlyPost 后续可复用的参考范式：

`App -> App-owned Nebula Adapter -> nebula_flutter_sdk`

Bootstrap 失败必须 fail-soft，不得阻塞 App 首屏、NFC 核心能力或本地数据主链。

## Allowed

- App bootstrap/composition-root；
- `lib/platform/nebula/**`；
- `lib/app/dependency.dart` 的最小装配；
- bootstrap lifecycle tests / architecture guards / docs；
- 只读消费已冻结 SDK public API。

## Forbidden

- 业务页面/feature 直接 import Nebula SDK；
- parser / NFC runtime / Action execution；
- Asset / Payment / Notification / AI；
- Backend Platform API；
- 修改 SDK public surface；
- 把 NFC scan/NDEF/TagSnapshot/Dynamic Note/Photo Card/NFC permission 等产品语义塞进 SDK；
- 为适配 NFC Writer 新增 `nfcWriter*`、NFC-specific 或其他产品命名的 SDK bootstrap 参数。

## Reference-consumer contract

生命周期差异必须留在 App Adapter / Composition Root。SDK 只能看到通用概念，例如 AppIdentity、Environment、BootstrapOptions、Runtime Config、Analytics、Crash/Session 等冻结能力；SDK 不得知道当前消费者是 NFC Writer、StarSprout 或 FlyPost。

发现 frozen contract / SDK public surface 真缺口时：**停止，提交 ACR，拆独立 SDK Story**；本 Story 禁止跨仓顺手修 SDK。

## Acceptance

必须同时满足：

1. SDK 仅由 Composition Root / `lib/platform/nebula/**` Adapter 引用；
2. `feature/**` 禁止直接 import `nebula_flutter_sdk`；
3. UI 禁止直接 import `nebula_flutter_sdk`；
4. bootstrap public/input contract 不包含 NFC Writer / NFC-specific 参数或业务模型；
5. App-specific lifecycle/fail-soft 决策留在 App，SDK 只提供通用 lifecycle 能力；
6. 同一 SDK initialize/bootstrap 语义可被 StarSprout / FlyPost 复用，无需重新设计 lifecycle；
7. **Product-name erasure test**：把“NFC Writer”替换成任意 App 名后，SDK 接口与 bootstrap 语义仍成立；
8. bootstrap failure 不阻塞 `runApp`/首屏/NFC 核心链；
9. 只有一个 Composition Root 承担 SDK 装配；
10. targeted tests + architecture guards + analyzer baseline + `flutter test` 按 Task/Repo 当前 Gate 通过。

## Evidence

Delivery Note 至少包含：startup flow、failure fallback test、single composition-root proof、SDK import boundary scan、product-name erasure review、analyzer/test/guard 结果，以及确认“0 SDK repo diff / 0 Backend diff”。
