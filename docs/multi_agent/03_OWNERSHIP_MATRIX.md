# Agent Ownership Matrix

## 1. 角色

| Role | 主职责 | 不能做 |
|---|---|---|
| Contract Agent | API、状态机、fixture、错误码、ADR | 不写业务实现 |
| SDK Architect Agent | SDK 边界、Facade、public API、foundation | 不修改 Backend |
| SDK Feature Agent | Asset/Notification/Entitlement/Payment capability | 不自建 Transport/Storage |
| Backend Platform Agent | mobile API service/repository/provider | 不修改 SDK 公共语义 |
| APK Integration Agent | Flutter App composition root 和接入 | 不在 App 内复制 SDK 能力 |
| Quality Agent | contract/governance/integration gates | 不替代业务 Owner 修功能 |
| Security Architect Agent | threat model、最低门槛、后期加固 | MA0 不写安全代码 |

## 2. 仓库与目录所有权

### nebula-flutter-sdk

| Path | Primary Owner | Parallel Write |
|---|---|---|
| `docs/multi_agent/**` | Architecture/PM Agent | 否，状态文件需串行更新 |
| `docs/06_API_CONTRACT.md`, `docs/12_*` | Contract Agent | 否 |
| `lib/src/foundation/**` | SDK Architect | 否 |
| `lib/src/transport/**` | SDK Architect | 否 |
| `lib/src/storage/**` | SDK Architect | 否 |
| `lib/src/auth/**` | Auth/SDK Agent | 与 Asset Agent 可并行，但不得改共享 proof API |
| `lib/src/config/**` | Config/SDK Agent | 现有 WIP 未归属前冻结 |
| `lib/src/analytics/**` | Analytics/SDK Agent | 现有 WIP 未归属前冻结 |
| `lib/src/asset/**` | Asset SDK Agent | 独占目录 |
| `lib/src/notification/**` | Notification SDK Agent | 独占目录 |
| `lib/src/entitlement/**` | Entitlement SDK Agent | 独占目录 |
| `lib/src/payment/**` | Payment SDK Agent | 独占目录 |
| `lib/nebula_sdk.dart` | SDK Architect | 串行合并 |
| `lib/src/nebula.dart` | SDK Architect | 串行合并 |
| `governance/**`, `tool/**` | Quality Agent | 否 |

### flypost_backend

| Path | Primary Owner | Notes |
|---|---|---|
| `internal/core/identity/**` | Identity Backend Agent | 当前 mobile auth 权威 |
| `internal/core/installation/**` | Installation Backend Agent | 不由 Asset 修改 |
| `internal/module/runtimeconfig/**` | Config Backend Agent | 当前已有稳定实现 |
| `internal/module/file/**` | Asset Audit/Transition Owner | 先审计，最终归属待 ADR |
| `internal/core/asset/**` | Asset Platform Owner | 目录不存在时先 ADR，不允许只搬文件 |
| `internal/core/notification/**` | Notification Backend Agent | 与 Asset 可并行 |
| `internal/core/payment/**` | Payment Backend Agent | 与 Asset 可并行 |
| `internal/core/appidentity/**` | Platform Identity Owner | 公共能力，变更需架构审查 |
| `internal/router/**` | Integration Owner | 串行合并 |
| `internal/migrations/**` | Migration Owner | 已合并 migration 不可改 |
| `sdk/dart/**` | Quarantine | 已有未提交修改；不以它替代独立 SDK |

### flutter NFC Writer

| Path | Primary Owner | Notes |
|---|---|---|
| Flutter 根项目 `lib/**` | APK Integration Agent | MA0 后再细分 |
| `pubspec.yaml` | APK Integration Owner | SDK path/version 变更串行 |
| `android/**` | APK Build Owner | 仅构建必要改动 |
| 嵌套 `NFCWriter/**` | Legacy Android Owner | 本轮默认只读/禁止修改 |

## 3. 当前 WIP Quarantine

### nebula-flutter-sdk

以下文件在规划落盘前已有未提交修改，Owner 未明确前其他 Agent 禁止修改：

- `lib/src/analytics/consent.dart`
- `lib/src/analytics/event.dart`
- `lib/src/auth/session_auth.dart`
- `lib/src/config/config_client.dart`
- `lib/src/config/effective_config.dart`
- `lib/src/foundation/logging.dart`
- `lib/src/foundation/sha256.dart`
- `lib/src/storage/cache_storage.dart`
- `lib/src/testing/fake_transport.dart`
- `lib/src/transport/http_transport.dart`
- 对应测试和 tooling 修改

### flypost_backend

以下文件在规划落盘前已有未提交修改，默认冻结：

- `sdk/dart/lib/src/app.dart`
- `sdk/dart/lib/src/auth.dart`
- `sdk/dart/lib/src/client.dart`
- `sdk/dart/lib/src/notification.dart`
- `sdk/dart/lib/src/payment.dart`

### NFC Writer

旧 Android 子工程存在大量源码、构建产物和二进制未提交变更。任何 Agent 不得执行清理、reset、批量格式化或覆盖操作。

## 4. Branch/Worktree 规则

推荐命名：`agent/<story-id>-<short-name>`。

- Agent 必须从明确基线 commit 建 worktree。
- 不允许直接在当前 dirty working tree 开始业务实现。
- 每个 Story 只改 Task Pack 允许的路径。
- 跨 Owner 文件（如 `nebula.dart`、public export、router）由 Integration Owner 最后串行合并。
