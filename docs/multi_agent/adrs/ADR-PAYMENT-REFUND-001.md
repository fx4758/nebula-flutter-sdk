# ADR-PAYMENT-REFUND-001：真实渠道退款能力（PROPOSED）

> 状态：PROPOSED（S1 阶段架构决策，非 MA0-C01 验收前置）
> 上游审计：MA0-C01 §4.2 / §4.3（Payment HIGH-RISK PARTIAL，refund = LOCAL-ONLY）
> 关联：ADR-PAYMENT-RECON-001（对账，建议同批建设）

## 1. 现状（实证）

- `Service.Refund()`（`service.go:187-208`）仅执行 `UpdateOrderStatus(orderID, 2)` + `CreateTransaction("REFUND")`，**不调用任何渠道退款**。
- `Provider` 接口（`provider.go:16-23`）仅含 `Channel()` / `CreateCharge` / `VerifyCallback`，**无 `Refund`**。
- 注释明示「真实渠道退款由后续 adapter 在 Provider 接口下补齐」。

## 2. 问题

当前退款只是本地状态标记 + 流水记录，**资金未实际退回渠道**。生产环境下属高危（HIGH-RISK）半成品。

## 3. 决策选项

- **Option A（推荐）**：在 `Provider` 接口新增 `Refund(ctx, req)`，各渠道 adapter（Stripe/WeChat/Apple）实现真实退款；`Service.Refund` 改为先调 `Provider.Refund` 成功再落库。
- Option B：异步退款任务 + 渠道回查，暂不阻塞主链路。
- Option C：暂不建设，明确标注「退款需人工/运营介入」。

## 4. 决议待定

S1 / Payment Story 评审选定选项，并明确与 ADR-PAYMENT-RECON-001 的对账关系。
