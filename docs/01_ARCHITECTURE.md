# Nebula Multi-App Client Architecture

Status: **FROZEN FOR F0-F2**

## 1. 目标拓扑

```text
Business App
  UI -> App Use Case -> App Repository
                         |
                         v
                    Nebula SDK
  foundation -> network/auth/storage/config/analytics
                         |
            asset/notification/payment/ai
                         |
                         v
                flypost platform API
                         |
             MySQL/Redis/Provider adapters

Admin Web -> server BFF -> flypost /admin/*
```

SDK 不经过 `server` BFF。管理 Web 不依赖本移动端 SDK。

## 2. 逻辑模块

| 模块 | SDK 职责 | 不属于 SDK |
| --- | --- | --- |
| foundation | 初始化、环境、错误、时钟、生命周期契约 | 业务启动流程 |
| network | 信封解析、超时、取消、幂等、受控重试 | 业务端点定义 |
| auth | 用户会话、刷新、退出、会话事件 | App Secret、管理凭据 |
| storage | 命名空间、Secure/Cache 接口、生命周期 | App 业务数据库 Repository |
| config | Feature、远程配置、版本策略、缓存 | 产品业务规则 |
| analytics | 同意管理、事件队列、批量发送 | 业务指标解释 |
| asset | 上传票据、进度、取消、受控下载 | OSS 密钥、公共 Bucket URL |
| notification | Push Token、站内信、点击 payload | 业务页面跳转 |
| payment | 创建订单、查单、恢复购买 | 商品定价、权益真相 |
| ai | capability 请求、任务状态、取消 | Prompt 业务、Provider 选择 |

## 3. 依赖方向

```text
foundation
    ^
transport + storage ports
    ^
auth + config + analytics
    ^
asset + notification + payment + ai
    ^
App repositories/use cases
```

- 基础层不得依赖 capability。
- capability 之间不得互相 import；协作通过小型 Port 或事件。
- `lib/nebula_sdk.dart` 是唯一稳定公共出口。
- `lib/src` 类型默认内部；只有经 API Review 冻结后才导出。
- 不使用全局 Service Locator；依赖在组合根注入。

## 4. 物理打包策略

F0-F4 保持一个 `nebula_sdk` package，内部逻辑模块化。只有同时满足以下条件才拆独立 package：

1. 有独立原生依赖或平台发布周期；
2. 至少两个 App 使用；
3. 公共契约稳定两个 Sprint；
4. 拆包能降低依赖体积或故障影响；
5. 有独立 owner、测试和版本策略。

原生能力优先通过 adapter package（例如 `nebula_secure_storage_flutter`）实现，不让纯 Dart 内核依赖具体插件。

## 5. 公共模块准入

进入 SDK 的能力必须：

- 被两个 App 实际复用，或第三个 App 已有批准的接入计划；
- 名称和模型中没有产品业务语义；
- 可脱离任一 App 独立测试；
- 数据、成本和开关作用域明确；
- 有兼容、弃用、owner 和失败降级策略。

未满足条件的实现留在 App 内。禁止“预想未来可能复用”成为抽取理由。

## 6. 后端对齐

当前后端已存在 `identity/appidentity/notification/payment`；AI 与 Storage 尚在收口，Config/Analytics/Risk 尚未完整形成。SDK 不得把目标后端模块写成已可调用能力。

后端端点只有在以下三项同时满足后才能进入 SDK：

1. flypost route 已存在；
2. `flypost/sdk/CONTRACT.md` 已登记；
3. contract/integration test 已通过。
