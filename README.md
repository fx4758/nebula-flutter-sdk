# Nebula Flutter SDK

Nebula 多 App 共用的客户端基础能力工程。业务 App 保留 UI、业务流程和业务实体；本工程只承载稳定、跨产品、可独立测试的客户端基础设施。

## AI 接手入口

开始任何实现前，依次阅读：

1. [`AGENTS.md`](AGENTS.md)
2. [`docs/00_AI_HANDOFF.md`](docs/00_AI_HANDOFF.md)
3. [`docs/01_ARCHITECTURE.md`](docs/01_ARCHITECTURE.md)
4. [`docs/02_SECURITY_MODEL.md`](docs/02_SECURITY_MODEL.md)
5. [`docs/03_IMPLEMENTATION_PLAN.md`](docs/03_IMPLEMENTATION_PLAN.md)
6. 当前 Sprint 对应的验收项：[`docs/04_ACCEPTANCE_CRITERIA.md`](docs/04_ACCEPTANCE_CRITERIA.md)

不要一次加载全部仓库规则。`00_AI_HANDOFF.md` 是路由页，只要求按任务加载相关文档，避免规则数量导致上下文和 Token 持续膨胀。

## 当前状态

- 工程阶段：F0，架构与安全基线。
- 当前代码：最小、可分析的纯 Dart 公共契约。
- 尚未授权：接入真实 API、复制旧 SDK 实现、发布到 pub、修改 flypost/server。
- 后端事实源：`../flypost/docs/ARCHITECTURE.md` 与 `../flypost/sdk/CONTRACT.md`。

## 本地检查

```bash
dart pub get
dart run tool/governance.dart
dart format --output=none --set-exit-if-changed .
dart analyze
dart run tool/smoke.dart
```

Flutter 原生插件进入 F3 后再增加 `flutter` 依赖；F0-F2 的网络、身份、配置和分析契约保持纯 Dart，以便测试和服务端 Dart 工具复用。

AI 治理采用按需加载和机器门禁。详细机制见 [`docs/07_AI_GOVERNANCE.md`](docs/07_AI_GOVERNANCE.md)，临时例外不得通过注释静默跳过，必须登记在 `governance/exceptions.json`。
