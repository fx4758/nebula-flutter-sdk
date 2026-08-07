# Definition of Done 与量化验收

## 1. 所有 Story 通用 DoD

必须同时满足：

1. Story ID 唯一，Owner 唯一。
2. 只修改允许目录。
3. 交付物存在并可定位。
4. 每条验收条件有证据。
5. 测试命令和结果完整。
6. 已知限制明确，不用“后续优化”掩盖缺口。
7. 更新 Sprint Board/task_board。
8. 无未经批准的公共 API、路径、错误码、数据表变化。
9. 未覆盖他人未提交修改。
10. 有 handoff block。

## 2. Contract Story DoD

- 状态机有合法/非法迁移表。
- 每个 endpoint 有 auth/proof/scope/idempotency。
- Request/Response 字段有类型、必填、上限、空值语义。
- 错误码至少覆盖 validation/auth/forbidden/not-found/conflict/rate-limit/emergency/provider。
- 有成功和失败 fixture。
- Backend 与 SDK Reviewer 均给出明确 review 结论。

## 3. Backend Story DoD

- Handler 不直接访问 DB/Provider。
- Service 状态机可测试。
- Repository/Provider 错误不会泄露敏感信息。
- 成功、参数错误、鉴权/作用域错误、幂等、失败回滚测试齐全。
- 新 migration 只新增，不修改历史 migration。
- `go test ./...` 或 Task Pack 指定范围通过。
- ArchGuard/Sentinel 保持基线，不新增 blocking violation。

## 4. SDK Story DoD

- Public API 不暴露内部 wire DTO/Provider 类型。
- 使用现有 `NebulaTransport`、Storage Port、Logger、Cancellation。
- 非幂等请求无无限或隐式重试。
- 支持 timeout/cancel/error classification。
- FakeTransport tests 覆盖正常、业务错误、网络错误、取消。
- `dart analyze`、`dart test`、governance、api_surface、secret_scan 通过。
- 公共导出变更有 API surface 更新和版本影响说明。

## 5. APK Integration Story DoD

- App 只有一个 SDK composition root。
- 页面/ViewModel 不直接请求 Platform API。
- Token/Installation/Config/Asset 状态不重复保存在不受控位置。
- 至少一个 Staging build variant 可构建。
- 真机步骤、设备、APK 路径、commit 和结果记录完整。
- 失败路径有 UI 或日志可观察结果。

## 6. Security 最低门槛

S1-S6 每个业务 Story 同步验证：

- 输入数量和体积上限。
- App/installation/user owner scope。
- 敏感字段不进入日志、analytics 或异常。
- 非幂等操作有 Idempotency Key 或明确拒绝重复。
- 外部成本调用前有 capability/limit/emergency 接入点。
- Provider secret 不进入移动端。

系统性风险评分、复杂限流和安全后台可在 S7 实现，但以上不得后置。

## 7. Handoff Block 模板

```text
Story ID:
Owner:
Base commit:
Branch/worktree:
Changed paths:
Deliverables:
Contract/API changes:
Database changes:
Tests executed:
Test result:
Acceptance evidence:
Known limitations:
Security minimum checks:
Follow-up dependencies:
Architecture Change Request:
```
## 8. Platform API Boundary DoD（Blocking）

每个 Story 必须声明 `platform_api_mode` 与 `sdk_public_api_mode`。

- `READ_ONLY`：Reviewer 必须验证 protected production diff = 0；测试通过不能覆盖此门禁。
- `IMPLEMENT_FROZEN_CONTRACT`：必须有 APPROVED ACR + frozen contract + 独立 Reviewer；行为不得超出 contract。
- `CONTRACT_CHANGE`：再加 ADR、contract version、第二消费者证据、兼容/回滚、安全成本评审。
- Product requirement 能由 App Adapter 解决时，Platform 变更自动不满足 DoD。
- Agent 不能把自己的 Story 从 READ_ONLY 改成写模式后继续实现。
