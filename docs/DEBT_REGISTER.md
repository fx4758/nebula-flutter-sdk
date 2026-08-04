# Architecture and Governance Debt

只登记已确认、暂未收口的事实。状态：`OPEN / MITIGATED / CLOSED`。

| ID | Severity | Status | Owner | Target | Debt | Exit evidence |
| --- | --- | --- | --- | --- | --- | --- |
| DEBT-F001 | HIGH | OPEN | Platform Identity | F0-03 | 旧 Dart SDK 将 App Secret 放入移动客户端 | 新 bootstrap 契约、旧通道截止日期、迁移测试 |
| DEBT-F002 | MEDIUM | OPEN | SDK | F1 | 当前新工程只有能力契约，没有生产 Transport/Auth 实现 | F1 验收全部通过 |
| DEBT-F003 | MEDIUM | OPEN | Platform Config | F2 | effective config/feature 客户端契约尚未形成 | flypost route+contract+integration test |
| DEBT-F004 | CRITICAL | CLOSED | Platform Identity | FB-05/F0-R9 | `/auth/logout` 已挂用户 Token middleware（`mobileAuthAuthed` 组 `Token()` + installation proof 链，docs/08 §6.4）；`fd3f799`(FB-05 router 隔离) + `b4a32cb`(F0-R9 收口)。测试：`route_inventory_test.go::TestMobileAuthTargetChainMounted`（无凭据请求先被 Token 拦截 10003）、`mobile_closure_http_test.go::TestMobileAuthHTTPLogoutClosure` |
| DEBT-F005 | CRITICAL | CLOSED | Platform Identity | FB-04/PR-007 | refresh 原子轮换 + 重放族吊销已落地：`77a10cb`(FB-04 App-bound session rotation and logout) + `4148580`(PR-007 Token 体系对齐 ADR-006)。测试：`session_rotation_test.go::TestRefreshRotatesInPlace`/`TestRefreshReuseRevokesFamily`、`r9_security_test.go::TestConcurrentRefreshBarrierExactlyOneWins`/`TestConcurrentRefreshOneWinsOneRevokes`、`proof_bound_test.go::TestRefreshCASConflictRevokesFamily`、SDK `test/cross_repo_contract_test.dart` FC-01 2-3 |
| DEBT-F006 | HIGH | CLOSED | Platform Identity | FB-04/F0-04 | user token 绑定可信 App/installation scope 已实现：`77a10cb`(App-bound session) + `c7f022a`(FB-03 installation proof & replay middleware)。测试：`session_rotation_test.go::TestRefreshAppInstallationMismatchRejected`、`proof_bound_test.go::TestRefreshBoundProofScopeMatched`/`MismatchRejected`/`TestLogoutBoundScopeMismatchRejected`、SDK `test/cross_repo_contract_test.dart` |
| DEBT-F007 | HIGH | CLOSED | SDK Contract | FB-01/F0-04 | 旧 SDK 登录模型与 envelope 已与 runtime 对齐：fixtures 冻结 + typed SDK contract 解析真实 wire。SDK `a21672c`(F0-R2 解析真实 bootstrap wire) + `6c88de5`(F0-R9 收口 path 同步 ADR-F008)；flypost `d3f6502`(FB-01 fixtures 冻结/envelope 对齐)。测试：`test/contract_fixtures_test.dart`、`test/cross_repo_contract_test.dart`（FC-01 全场景） |

新增债务必须有 owner、目标 Sprint 和可验证 Exit。禁止把普通待办或愿望放入本表。
