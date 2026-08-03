# Migration from `flypost/sdk/dart`

目标是迁移事实，不是复制旧实现。旧目录在完成至少两个 App 灰度前保持只读兼容。

## 1. 基线映射

| 旧文件/能力 | 结论 | 新位置/任务 | 原因 |
| --- | --- | --- | --- |
| `client.dart` HTTP/signing | ADAPT | F1 network | 保留请求基础；移除移动端 App Secret HMAC |
| `auth.login` | ADAPT | F1 auth | 增加会话存储、refresh single-flight |
| `auth.appToken()` | REMOVE | server-side SDK | `client_credentials` 不属于移动端 |
| `app.dart` 管理 API | REMOVE | Admin/Go SDK | 凭据/Entitlement 是控制面 |
| notification 用户态 | ADAPT | F3 notification | 加 App scope、Token 生命周期和分页模型 |
| notification 管理态 | REMOVE | Admin SDK/BFF | 移动端不承载管理能力 |
| payment 用户态 | ADAPT | F4 payment | 服务端可信 app scope、幂等、状态恢复 |
| payment 管理态退款 | REMOVE | Admin SDK/BFF | 高权限操作不得进入用户 SDK |

## 2. 迁移步骤

1. 为旧 SDK 公共 API 建立 contract fixture，记录真实响应。
2. 在新 SDK 完成安全等价实现，不共享静态全局状态。
3. App 增加 adapter，使业务 Repository 可切换 old/new client。
4. 仅对一个 App/版本灰度，观察启动、登录、错误率和成本。
5. 回滚窗口结束后扩大灰度。
6. 至少两个 App 稳定后，标记旧 API deprecated。
7. 经过两个小版本兼容窗口后再删除旧实现。

## 3. 禁止的迁移方式

- 复制 `appSecret` 参数后另开任务处理；
- 为了接口一致把管理员 Token 暂存在移动端；
- 同一次发布同时替换 Auth、Payment 和 Notification；
- 没有指标和回滚开关就全量切换；
- 删除旧 SDK 以迫使所有 App 同日升级。
