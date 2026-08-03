# Governance Runtime

此目录存放机器可读治理事实，不存放长篇建议。

- `policy.json`：当前 blocking 规则和复杂度预算；
- `public_api.txt`：允许从公共 barrel 导出的文件；
- `exceptions.json`：临时例外，必须包含 owner、reason、issue、expires_on；
- `../tool/governance.dart`：唯一执行入口。

新增规则前先证明至少发现过一次真实缺陷，或对应明确的安全/兼容红线。规则必须能自动检查；纯建议进入 Review Checklist，不进入 blocking policy。

## Exception schema

```json
{
  "id": "EX-001",
  "rule_id": "RULE-ID",
  "path": "lib/src/example.dart",
  "owner": "team-or-person",
  "reason": "why the safe alternative cannot be used yet",
  "issue": "tracking-id-or-url",
  "expires_on": "2026-09-01"
}
```

过期例外使治理检查失败。禁止无截止日期和全目录通配豁免。
