# Nebula Platform API + Flutter SDK Master Plan V1

## 1. 架构目标

本计划不是重新建设一个空 SDK，而是在现有 F0-F2 基础上完成三个收口：

1. SDK 从“基础能力可测”推进到“真实 APK 可接入”。
2. Backend 从“多处已有能力”推进到“Platform API 契约基本成型”。
3. Security 从“局部先行”调整为“最低门槛同步 + 真实链路后系统加固”。

## 2. 架构冻结

### 2.1 SDK

当前继续采用单 package：

```text
nebula-flutter-sdk/
├── lib/nebula_sdk.dart          # 唯一稳定公共出口
├── lib/src/foundation
├── lib/src/transport
├── lib/src/storage
├── lib/src/auth
├── lib/src/config
├── lib/src/analytics
├── lib/src/asset                # 下一阶段
├── lib/src/notification         # 下一阶段
├── lib/src/entitlement          # 下一阶段
└── lib/src/payment              # 后续阶段
```

约束：

- `Nebula` 是依赖注入 Facade，不改成 Service Locator。
- OpenAPI/fixture DTO 不直接暴露为公共 API。
- Feature capability 依赖 `NebulaTransport`、Storage Port、Auth/Proof Port，不自建网络栈。
- 非幂等请求默认不自动重试。
- Asset 上传必须由平台签发短期 Ticket/Presign，SDK 不持有 Bucket 密钥。
- 至少两个 App 完成接入并证明独立发布价值前，不拆成多个 Dart package。

### 2.2 Platform Backend

当前平台权威实现仍在 `flypost_backend`，按模块化单体推进：

```text
router → handler → service → repository/provider
```

约束：

- 移动端 Platform API 使用 `/api/v1/mobile/*` 作为可信身份链路的主命名空间；最终路径由 Contract Story 冻结。
- App/installation/user scope 来自可信 token/proof，不信任请求体声明。
- 业务模块不得直接调用外部 OSS/支付/通知 Provider。
- 已有 `internal/module/file`、`core/payment`、`core/notification` 先审计，再决定适配、收口或新增 Facade；禁止只改目录名冒充平台化。
- `flypost_server` 继续是管理后台/BFF，不成为移动端平台能力的权威实现。

### 2.3 APK 接入

首接仓库：`flutter NFC Writer`。

接入原则：

- App 只通过一个 `NebulaAppAdapter` 或等价 composition root 组装 SDK。
- 页面和 ViewModel 不直接构建 Transport、TokenStore、Proof、Config Client。
- 首次接入只覆盖 bootstrap/config/auth/asset，不同时迁移所有老业务。
- 真实集成使用 Staging，不连接生产环境。

### 2.4 Security

安全分两层。

#### 同步最低门槛

每个业务 Story 必须同时满足：

- 输入上限
- Auth/Authz
- App/installation/user scope
- 幂等要求
- 敏感信息不入日志
- 资源成本上限或明确的后续加固挂点

#### 后置系统加固

在真实接口稳定后集中完成：

- 组合限流与风险策略
- 预算/配额
- 防灌水、防爬虫
- emergency switch
- 审计、告警、故障演练

后置不等于取消；它不阻塞契约和主流程，但在 Release Candidate 前必须完成。

## 3. Epic 结构

| Epic | 名称 | 结果 |
|---|---|---|
| EPIC-GOV | 多 Agent 治理与契约 | 多仓并行不冲突，契约先于实现 |
| EPIC-ASSET | Asset Platform + SDK | 上传、确认、查询、删除、恢复闭环 |
| EPIC-APK | NFC Writer APK 接入 | 可安装 APK 使用真实 SDK 主链 |
| EPIC-COMMON | Notification + Entitlement | 推送设备生命周期与会员权益查询 |
| EPIC-PAY | Payment Foundation | 订单、查单、sandbox callback 与权益发放 |
| EPIC-API | Platform API Consolidation | OpenAPI/fixture/错误码/能力矩阵形成 SSOT |
| EPIC-SEC | Security & Reliability | 围绕真实接口完成安全加固 |
| EPIC-REL | Release Candidate | SDK、API、APK 可回归、可交接、可发布 |

## 4. Sprint 路线

| Sprint | Story Point | 目标 | 里程碑 |
|---|---:|---|---|
| MA0 | 12 | 事实审计、冲突隔离、契约输入冻结 | 可安全并行 |
| S1 | 15 | Asset 契约和 fixture 冻结 | Backend/SDK 可并行实现 |
| S2 | 17 | Asset Backend + SDK 闭环 | SDK 主能力完成 |
| S3 | 14 | Flutter NFC Writer 首次真实接入 | M1：SDK 进入 APK |
| S4 | 16 | Notification + Entitlement | 平台通用能力扩展 |
| S5 | 15 | Payment Sandbox Foundation | 支付与权益闭环 |
| S6 | 13 | Platform API 契约总收口 | M2：API 基本成型 |
| S7 | 16 | Security & Reliability 加固 | 安全主链完成 |
| S8 | 13 | RC、故障演练、发布交接 | M3：可发布候选 |

## 5. 关键依赖

```text
MA0
 └─ S1 Asset Contract
     ├─ S2 Backend Asset
     ├─ S2 SDK Asset
     └─ S3 APK Integration
          ├─ S4 Notification/Entitlement
          └─ S5 Payment
               └─ S6 API Consolidation
                    └─ S7 Security Hardening
                         └─ S8 Release Candidate
```

## 6. 完成标准

### SDK 可接入 APK

- Flutter App 使用本地或版本化 `nebula_sdk` 依赖。
- 没有 App Secret。
- bootstrap、session、config、asset 由 SDK 提供。
- Token refresh、proof、错误分类不由 App 重复实现。
- 有真机 Staging APK 证据。

### Platform API 基本成型

- 已实现端点均有 contract fixture 和错误映射。
- App scope、installation scope、user scope 清晰。
- Asset/Notification/Entitlement/Payment 有统一移动端入口。
- Capability Matrix 标注 Production/Beta/Contract-only/Deferred。
- 安全加固不改变已经冻结的 SDK 公共语义。
