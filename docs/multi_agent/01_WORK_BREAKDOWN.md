# Epic → Feature → Story → Task 工作分解

## 0. 统一颗粒度

- 1 SP：单一文档、测试或局部适配。
- 2 SP：单模块完整能力，依赖已冻结。
- 3 SP：跨层实现，但不跨两个领域。
- Story 最大 3 SP、最多 6 个 Task、唯一 Owner、可独立验收。
- 每个 Sprint 13-17 SP；Story 不超过 7 个。

---

# EPIC-GOV 多 Agent 治理与契约

## Feature GOV-F1：真实基线

### MA0-A01｜平台 API 与跨仓契约事实审计｜2 SP

Tasks：
1. 从 router/handler/fixture 枚举真实 mobile API。
2. 标注 Implemented / Partial / Placeholder / Missing。
3. 对照 SDK endpoint 常量和 fixture。
4. 输出冲突、缺口和待冻结项。
5. 禁止修改实现。

验收：每个结论都有文件路径和测试证据；不得用百分比替代事实。

### MA0-B01｜SDK F0-F2 能力审计｜2 SP

Tasks：
1. 枚举公共 API surface。
2. 映射 Auth/Config/Analytics/Storage/Transport 能力。
3. 标注可直接复用和待重构项。
4. 确认当前单 package 决策。
5. 输出 F3 准入条件。

验收：公共导出、测试数、治理门禁均有证据。

### MA0-C01｜Backend Asset/Notification/Payment 审计｜2 SP

Tasks：
1. 审计 file/asset 真实状态机和路由。
2. 审计 notification 客户端入口和 App scope。
3. 审计 payment 客户端入口、Provider 和幂等。
4. 标记可适配、需收口、禁止复用部分。
5. 输出后续 Contract 输入。

验收：不得将后台管理 API 当移动端 API；不得把骨架称为生产闭环。

## Feature GOV-F2：并行协作

### MA0-D01｜Flutter NFC Writer 接入点审计｜2 SP

Tasks：
1. 确认 Flutter App 根目录、构建入口、状态管理和网络层。
2. 找到 bootstrap/login/config/upload 最小接入点。
3. 标记旧 Android 子工程和当前脏文件边界。
4. 定义 Nebula composition root 候选位置。
5. 输出接入风险与最小 Demo 路径。

验收：不修改 App；明确一个最小可安装 flavor/build variant。

### MA0-Q01｜分支、工作树和门禁审计｜2 SP

Tasks：
1. 记录三个仓库当前 branch/dirty files。
2. 定义 Agent worktree/branch 命名。
3. 定义冲突目录和串行合并顺序。
4. 定义每类 Story 的测试命令。
5. 输出 Merge Gate。

验收：任何两个并行 Story 不共享可写文件；共享时明确串行化。

### MA0-S01｜安全基线审计｜2 SP

Tasks：
1. 记录已有安全能力和未完成 WIP。
2. 将最低安全门槛映射到 Asset/Auth/Payment。
3. 标记必须同步实现和可后置项。
4. 不新增安全代码。
5. 输出 S7 输入清单。

验收：安全不阻塞 S1-S3，但每个主链 Story 有最低安全验收。

---

# EPIC-ASSET Asset Platform + SDK

## Feature AS-F1：Asset Contract

### S1-A01｜移动端 Asset 状态机冻结｜3 SP

Tasks：
1. 定义 asset、upload session、object reference 的职责。
2. 定义状态：reserved/uploading/uploaded/verifying/available/failed/expired/deleted。
3. 定义合法迁移与幂等行为。
4. 定义 owner/app/installation/user scope。
5. 定义可见性、过期和删除语义。
6. 形成 ADR。

验收：每个状态有进入条件、退出条件和重复调用行为。

### S1-A02｜Asset Mobile API Contract｜3 SP

候选端点由审计后冻结，不允许直接沿用示例：

```text
POST   /api/v1/mobile/assets/uploads
POST   /api/v1/mobile/assets/uploads/{id}/complete
GET    /api/v1/mobile/assets/{id}
DELETE /api/v1/mobile/assets/{id}
```

Tasks：
1. 冻结请求响应字段。
2. 冻结错误码。
3. 冻结 proof/session/header 要求。
4. 冻结 checksum/MIME/size。
5. 冻结 direct upload 和 server fallback 语义。
6. 输出 OpenAPI 或 CONTRACT 文档。

验收：SDK 和 Backend Agent 对字段无自由解释空间。

### S1-A03｜Asset Contract Fixtures｜2 SP

至少包括 create/complete/query/delete 成功，以及 invalid MIME、too large、quota exceeded、expired ticket、owner mismatch、emergency disabled。

验收：fixture 可被 Go 和 Dart 测试共同消费。

### S1-Q01｜Contract Review Gate｜2 SP

Tasks：
1. Backend Reviewer 对状态机可实现性评审。
2. SDK Reviewer 对取消、恢复和错误映射评审。
3. Security Reviewer 只检查密钥泄露、越权、成本 P0。
4. 关闭所有 blocking comment。

验收：三方 review 结论落盘；未关闭 blocking 不进入 S2。

### S1-A04｜Asset Ownership/Compatibility ADR｜2 SP

验收：明确 `internal/module/file` 是适配、迁移还是保留；明确历史 `/files/*` 兼容策略；不靠搬目录完成架构。

### S1-Q02｜S2 并行写集划分｜3 SP

验收：Backend、SDK、Contract test 三个 Agent 的 allowed paths 不重叠；共享 router/public export 有 Integration Owner。

## Feature AS-F2：Backend Asset

### S2-A01｜Backend Upload Session/Reservation｜3 SP

Tasks：
1. 按冻结契约建立或适配模型。
2. 创建短期 upload session。
3. 实现幂等创建。
4. 校验 App capability、owner、大小和 MIME。
5. 返回 Provider-neutral upload instruction。
6. 写单元与 HTTP 测试。

量化验收：重复幂等键只产生 1 个有效 reservation；超限请求在 Provider 调用前拒绝。

### S2-A02｜Backend Complete/Verify｜3 SP

Tasks：
1. Head Object 或等价验证。
2. 比对 size/MIME/checksum。
3. 原子状态迁移。
4. complete 幂等。
5. 失败/过期清理入口。
6. 测试非法迁移。

量化验收：重复 complete 返回同一 asset；未上传对象不能进入 available。

### S2-A03｜Backend Query/Delete｜2 SP

验收：owner scope 完整；删除幂等；删除后不返回永久可用 URL。

### S2-A04｜Asset Contract HTTP Tests｜2 SP

验收：至少 10 个 S1-A03 fixture 全部通过；路由中间件顺序有断言。

## Feature AS-F3：SDK Asset

### S2-S01｜SDK Asset Model + Capability｜3 SP

Tasks：
1. 定义公共 asset/upload task 模型。
2. 定义状态和进度事件。
3. 定义 cancellation。
4. 定义 typed errors。
5. 增加 Facade capability。
6. API surface/gov 更新。

验收：不暴露 Provider/Bucket/OSS SDK 类型。

### S2-S02｜SDK Direct Upload Executor｜3 SP

Tasks：
1. create upload session。
2. 根据 instruction 直传。
3. 上传请求不带 Nebula Authorization。
4. 完成后调用 complete。
5. 支持进度、超时、取消。
6. FakeTransport/HTTP fake 测试。

量化验收：取消后不调用 complete；并发重复 start 不产生两个有效任务。

### S2-S03｜SDK Resume/Recovery｜2 SP

验收：保存最小恢复状态；过期 ticket 可重建；已上传未 complete 可恢复确认；用户切换不串任务。

### S2-Q01｜Asset 跨仓 E2E｜2 SP

验收：create → upload → complete → query；失败矩阵至少覆盖 6 类；contract fixture 无漂移。

---

# EPIC-APK NFC Writer APK 接入

## Feature APK-F1：Composition Root

### S3-D01｜NebulaAppAdapter｜2 SP

Tasks：建立唯一 SDK 组装点；注入 environment/appId/storage/logger；连接 lifecycle；不改业务页面；增加 fake 初始化测试。

验收：App 内只有一个 Nebula 构造位置。

### S3-D02｜Bootstrap + Config 接入｜3 SP

验收：首次启动、二次启动、离线缓存、强制升级、runtime-config disabled 五种场景可复现。

### S3-D03｜Auth Session 接入｜3 SP

验收：restore/login/refresh/logout；App 不保存 Nebula token；401 storm 仍只刷新一次。

### S3-D04｜Asset Demo 业务接入｜3 SP

首个真实场景限定为一个附件入口，不扩展动态便签全业务。

验收：选择文件 → 上传 → 保存 asset id → 重启后查询；失败可重试，不保存永久 Bucket URL。

### S3-Q01｜Staging APK 构建与真机验证｜2 SP

验收：至少一个 Android flavor 可构建安装；输出 APK 路径、commit、设备、步骤和结果。

### S3-D05｜接入问题回流｜1 SP

验收：问题严格归类 SDK/API/App/Contract/Security，不在 App 内临时绕过。

---

# EPIC-COMMON Notification + Entitlement

## Feature CM-F1：Notification Device Lifecycle

### S4-A01｜Notification Mobile Contract｜2 SP
冻结注册、更新、解绑、用户切换语义；不同时接所有厂商渠道。

### S4-B01｜Backend Device Lifecycle｜3 SP
验收：installation 唯一性；token 更新幂等；logout 用户解绑但 installation 语义清晰。

### S4-S01｜SDK Notification Adapter Port｜2 SP
验收：SDK 只管理 platform token lifecycle，不把华为/小米等厂商逻辑写进公共核心。

## Feature CM-F2：Entitlement

### S4-A02｜Entitlement Query Contract｜2 SP
必须表达免费、订阅、永久购买与云资源有效期的区别。

### S4-B02｜Backend Entitlement Snapshot｜3 SP
验收：按 app+user 输出 capability/limit/expiry/source；免费用户有明确默认值。

### S4-S02｜SDK Entitlement Cache｜2 SP
验收：缓存、过期刷新、stale 标识；App 不通过本地价格判断权益。

### S4-Q01｜Common Platform E2E｜2 SP
验收：登录后注册 push token、查询权益、logout 后 scope 正确。

---

# EPIC-PAY Payment Foundation

## Feature PAY-F1：Contract & Sandbox

### S5-A01｜Payment Mobile Contract｜3 SP
冻结订单状态、交易状态、idempotency、client payload、provider-neutral response、callback side effect。

### S5-B01｜Backend Order/Query 收口｜3 SP
验收：app+user scope；金额和产品来自可信服务端；重复下单幂等。

### S5-B02｜Sandbox Callback + Entitlement Grant｜3 SP
验收：重复 callback 只发放一次权益；非法金额/产品/provider id 被拒绝。

### S5-S01｜SDK Payment Capability｜2 SP
验收：create/query/restore result；SDK 不决定金额、Provider、预算。

### S5-Q01｜Payment Sandbox E2E｜2 SP
验收：create → sandbox paid → callback → query paid → entitlement active。

### S5-SEC01｜支付最低安全评审｜2 SP
验收：签名、重放、金额、App scope、唯一事件均有测试或明确 blocked 项。

---

# EPIC-API Platform API Consolidation

## Feature API-F1：Contract SSOT

### S6-A01｜Mobile API Registry｜3 SP
验收：每个 mobile endpoint 有状态、Owner、SDK consumer、auth/proof、fixture、错误码。

### S6-A02｜Unified Error Mapping｜2 SP
验收：Go/Dart 对相同 code 分类一致；未知 code 有稳定 fallback。

### S6-Q01｜Cross-repo Contract Gate｜3 SP
验收：fixture drift、endpoint drift、public API drift 自动失败。

### S6-A03｜Capability Matrix｜2 SP
状态只允许 Production/Beta/Contract-only/Deferred，且有证据链接。

### S6-D01｜第二 App 接入准备审计｜1 SP
只做 Focus/StarSprout 或 FlyPost 的接入差异评估，不开始迁移。

### S6-Q02｜M2 验收报告｜2 SP
验收：API 基本成型清单、未完成项、风险、下一里程碑明确。

---

# EPIC-SEC Security & Reliability

## Feature SEC-F1：真实链路保护

### S7-S01｜Auth/SMS Protection｜3 SP
验收：IP、phone、installation、App budget、emergency；正常用户与攻击桶隔离。

### S7-S02｜Asset Cost Protection｜3 SP
验收：文件大小、日配额、reservation expiry、presign rate、emergency；读取不被上传开关误伤。

### S7-S03｜Payment Replay/Callback Protection｜3 SP
验收：签名、时间窗、唯一事件、金额、状态迁移、审计。

### S7-S04｜Ingest/Feedback 防灌水设计与实现｜2 SP
只针对真实存在入口；没有入口则输出 contract 和 deferred，不编造 Handler。

### S7-S05｜Emergency Capability Matrix｜2 SP
验收：login/sms/upload/analytics/payment-create 可独立关闭；payment-callback 使用安全模式而非粗暴关闭。

### S7-Q01｜Abuse Regression Suite｜3 SP
验收：至少覆盖登录爆破、短信刷量、upload ticket 洪泛、超大文件、callback 重放、emergency。

---

# EPIC-REL Release Candidate

## Feature REL-F1：SDK/API/APK RC

### S8-Q01｜SDK Public API 审计｜2 SP
验收：无内部 DTO 泄露；API surface 与版本策略一致。

### S8-A01｜OpenAPI/Contract 完整性审计｜2 SP
验收：实现与契约双向无漂移。

### S8-D01｜APK 全链回归｜3 SP
链路：安装 → bootstrap → config → login → refresh → upload → entitlement → logout → offline restart。

### S8-S01｜故障与降级演练｜3 SP
场景：API 不可用、config 不可用、OSS 失败、refresh 失败、maintenance、upload disabled。

### S8-Q02｜Release Artifacts 与交接｜3 SP
输出：SDK version/changelog、API registry、APK、测试报告、已知限制、回滚方案。
