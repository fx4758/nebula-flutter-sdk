# ADR-PAYMENT-RECON-001：支付对账能力（PROPOSED）

> 状态：PROPOSED（S1 阶段架构决策，非 MA0-C01 验收前置）
> 上游审计：MA0-C01 §4.2 / §4.3（Payment HIGH-RISK PARTIAL，reconciliation = MISSING）
> 关联：ADR-PAYMENT-REFUND-001（真实退款，建议同批建设）

## 1. 现状（实证）

- `Provider` 接口（`provider.go:16-23`）**无 `Reconcile`**，全仓无对账实现。
- 现有 `HandleCallback` 仅处理异步支付回调，无周期性渠道账单比对 / 差异告警。

## 2. 问题

缺乏对账意味着：渠道侧资金状态与本地订单可能长期不一致且无法发现；退款（ADR-PAYMENT-REFUND-001）上线后差异风险翻倍。

## 3. 决策选项

- **Option A（推荐）**：在 `Provider` 接口新增 `Reconcile(ctx, period)`，各渠道 adapter 拉取账单并与本地订单/流水比对，产出差异报告 + 自动/人工调理。
- Option B：仅建设离线对账脚本，不入接口。
- Option C：依赖渠道异步回调 + 人工巡检，暂不建设自动对账。

## 4. 决议待定

S1 / Payment Story 评审选定选项，并与退款能力同批排期。
