# SDK Public API Surface Change Process

> Status：PROPOSED（S1/S2 流程约定草案，合规 DoD #8）
> Author：SDK Architect Agent（采纳 MA0-B01 验收非阻塞建议 2）
> Date：2026-08-07T09:46:48+08:00
> Related：MA0-B01 §5 共享串行文件、§7 F3 准入 checklist、governance/api_surface.snapshot

## 1. 目的

多 Agent 并行开发 Feature SDK（Asset / Notification / Payment / Ai）时，防止各 Agent 各自修改公共 API 导出导致符号冲突、snapshot 漂移、门禁失败。

## 2. 规则

### 2.1 Feature Agent 权限

- ✅ **允许**：在 `lib/src/**` 内部新增实现（private/internal 模块、测试、fakes）。
- 🚫 **禁止**：修改任何 **public export**：
  - `lib/nebula_sdk.dart`（barrel export）
  - `lib/src/nebula.dart`（`Nebula` facade）
  - `lib/src/capabilities.dart`（`NebulaAuth` + 4 标记接口）
  - `lib/src/foundation/**`、`lib/src/transport/**`、`lib/src/storage/**`（SDK Architect 独占）

### 2.2 变更公共 API 的流程

当需要新增/修改 public export 时：

1. Feature Agent **提交变更提案**（PR/讨论），说明新增符号与理由；
2. **SDK Architect 审批**（串行所有权，避免与并行 Agent 冲突）；
3. 审批通过后，由 **surface Owner**（SDK Architect 或其指定 Owner）执行：
   ```bash
   dart run tool/api_surface.dart --update
   ```
4. 重跑门禁：`governance` 与 `secret_scan` 仍 PASS；
5. snapshot 符号数从 121 → N，差异须评审确认无意外导出。

### 2.3 当前约束（WIP Quarantine）

- `tool/api_surface.dart` 当前为 dirty（WIP Quarantine），**不得由 Feature Agent 自行 `--update`**；须先由该工具 Owner 提交/协调（见 MA0-B01 §6 阻塞项 3）。
- F3 阶段开始前，surface Owner 须先解除该 quarantine 并确认 snapshot 可重跑。

## 3. 违反后果

- 未审批修改 public export → 多 Agent 合并冲突、CI 红线（api_surface diff / governance fail）；
- 私自 `--update` → snapshot 与实际导出不一致，门禁失真。

## 4. 关联

- 03_OWNERSHIP_MATRIX（SDK Architect Serial Ownership）
- MA0-B01 §5 共享串行文件清单
- MA0-B01 §7 F3 准入 checklist「SDK Public API Surface 变更流程生效」
