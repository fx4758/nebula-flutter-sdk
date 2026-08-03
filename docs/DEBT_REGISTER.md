# Architecture and Governance Debt

只登记已确认、暂未收口的事实。状态：`OPEN / MITIGATED / CLOSED`。

| ID | Severity | Status | Owner | Target | Debt | Exit evidence |
| --- | --- | --- | --- | --- | --- | --- |
| DEBT-F001 | HIGH | OPEN | Platform Identity | F0-03 | 旧 Dart SDK 将 App Secret 放入移动客户端 | 新 bootstrap 契约、旧通道截止日期、迁移测试 |
| DEBT-F002 | MEDIUM | OPEN | SDK | F1 | 当前新工程只有能力契约，没有生产 Transport/Auth 实现 | F1 验收全部通过 |
| DEBT-F003 | MEDIUM | OPEN | Platform Config | F2 | effective config/feature 客户端契约尚未形成 | flypost route+contract+integration test |
| DEBT-F004 | CRITICAL | OPEN | Platform Identity | FB-05 | `/auth/logout` 当前未挂用户 Token middleware | route inventory + authenticated idempotent logout test |
| DEBT-F005 | CRITICAL | OPEN | Platform Identity | FB-04 | refresh 创建新 session 且未原子轮换旧 refresh generation | concurrency + refresh reuse family-revocation tests |
| DEBT-F006 | HIGH | OPEN | Platform Identity | FB-04 | user token 未绑定可信 App/installation scope | App/installation mismatch contract tests |
| DEBT-F007 | HIGH | OPEN | SDK Contract | FB-01/F0-04 | 旧 SDK 登录模型和响应 envelope 与 runtime 不一致 | frozen fixtures + typed SDK contract |

新增债务必须有 owner、目标 Sprint 和可验证 Exit。禁止把普通待办或愿望放入本表。
