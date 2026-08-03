# Mobile Security, Privacy and Cost Model

Status: **BLOCKING**

## 1. 身份模型

移动安装包属于不可信环境。最终身份链：

```text
public app_id
  + installation_id
  + optional platform attestation
  + user access token
  -> trusted server scope(app_id, user_id, installation_id)
```

`client_secret` 只允许存在于接入方服务端或 Secret Manager。Flutter 不提供 `appToken()`，不签发/轮换凭据，不携带 Provider Secret。

兼容旧 SDK 的 HMAC App Secret 只能作为有截止日期的迁移通道，不能复制到新工程。

## 2. 数据隔离

- 服务端 `app_id` 从可信令牌/服务端上下文解析，请求体值只能用于兼容校验。
- 本地 key 命名空间：`environment/app_id/user_id/key`。
- 退出登录清除用户级 Secret；切换环境不得复用 Token、缓存或 installation state。
- 分析、通知、资源、支付、AI 均按 App 隔离；唯一索引和查询必须包含可信 App scope。

## 3. 流量与可用性

SDK 网络层必须支持总超时和取消。默认策略：

| 请求 | 自动重试 |
| --- | --- |
| 配置/幂等 GET | 最多 2 次，指数退避+jitter |
| 分析批次 | 有上限后台重试，可丢弃低优先级事件 |
| 上传分片 | 仅按服务端上传会话恢复 |
| 支付下单/退款 | 禁止，除非使用稳定幂等键 |
| AI 创建任务 | 禁止，除非使用稳定幂等键 |

单 App/设备受到限流时必须尊重 `Retry-After`，不得形成重试风暴。配置和登录使用与 AI/上传不同的服务端资源池，攻击高成本接口不得耗尽普通用户入口。

## 4. 隐私

- 日志默认只记录 request ID、端点模板、结果类别和耗时。
- URL query、Header、body、Token、Prompt、支付凭证、完整设备标识默认不记录。
- Analytics 在获得同意前不持久化可识别事件。
- 队列有数量、字节和 TTL 上限；撤回同意后清理未发送隐私事件。
- 崩溃报告的自定义字段采用白名单。

## 5. 成本资源

SDK 永远不直连 Provider。服务端在调用 AI、OSS、短信、邮件、Push、支付、图片/视频处理前执行：

```text
emergency check -> entitlement -> quota -> reserve budget
-> provider call -> settle/release ledger
```

SDK 对 80% 告警可展示提示；95% 接受降级响应；100% 接受能力关闭。客户端不得绕过或静默改用其他 Provider。

## 6. 应急处置

每个高风险 capability 必须能由远程开关独立关闭。SDK 收到关闭响应后：

- 不自动重试；
- 返回可分类错误；
- 保留基础登录/配置可用；
- 不缓存永久关闭状态，只按服务端 TTL 更新。

## 7. Security Review 问题

每个新增公共方法必须回答：

1. 谁可以调用？
2. App/User/Device 作用域来自哪里？
3. 调用频率和客户端重试上限？
4. 最坏外部成本？
5. 输入、队列和缓存上限？
6. 日志和分析会记录什么？
7. 如何关闭与降级？
