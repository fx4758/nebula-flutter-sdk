# Acceptance Criteria

## Global Definition of Done

每个任务必须同时满足：

- 变更范围与任务 ID 一致；
- 公共 API 有文档、错误语义和兼容性判断；
- 正常、边界、失败、取消/超时路径有测试；
- 不新增静态 Secret、敏感日志或无限队列；
- `dart format`、`dart analyze`、测试/烟雾检查通过；
- `STATUS.md` 与实际代码一致；
- PR 交接块完整。

## F0 验收

- [ ] 公共构造器没有 `appSecret/clientSecret/providerSecret`。
- [ ] Flutter 公共 API 没有凭据签发、轮换、Entitlement 管理。
- [ ] 客户端与服务端身份边界有 sequence/contract 说明。
- [ ] 旧 SDK 每个公共能力都有 `keep/adapt/remove` 结论。
- [ ] 未落地的后端能力标记为 BLOCKED，不提供假实现。

## G0 治理验收

- [x] AI 入口文档在上下文行数预算内。
- [x] 公共导出、敏感模式、文件复杂度和任务状态可自动检查。
- [x] 守卫失败返回非零退出码并给出稳定 Rule ID。
- [x] 临时例外包含 owner、issue、精确 path 和到期时间。
- [x] CI 与本地使用同一个治理入口，不维护两套规则。

## F1 验收

- [ ] 生产环境拒绝非 HTTPS base URL。
- [ ] 每个请求有连接/响应总超时和取消路径。
- [ ] 非幂等请求不被默认重试。
- [ ] 401 并发风暴只执行一次 refresh，其余请求等待同一结果。
- [ ] Token 使用 Secure Storage port，退出后清除用户作用域。
- [ ] 错误保留服务端 code/request ID，但不泄漏响应敏感体。

## F2 验收

- [ ] Config 作用域包含 environment/app/version/user segment。
- [ ] 缓存有 TTL、schema version 和最大字节数。
- [ ] 远端不可用时只使用允许 stale 的配置。
- [ ] Analytics 队列有条数、字节、TTL 和重试上限。
- [ ] 未同意或撤回同意时不发送可识别事件。

## F3 验收

- [ ] 上传前获得短期 ticket；客户端无 OSS Secret。
- [ ] 类型、大小、数量、并发、超时均有限制。
- [ ] 下载 URL 短期有效，不持久化为永久业务地址。
- [ ] Push Token 与 environment/app/user/installation 绑定。
- [ ] Notification payload 不直接实例化业务页面。

## F4 验收

- [ ] 支付金额、币种、商品和权益由服务端确认。
- [ ] 支付创建/恢复场景有稳定幂等键。
- [ ] AI API 只接受已登记 capability，不接受 Provider Secret/模型密钥。
- [ ] AI 创建/重试/取消不会突破服务端预算或客户端重试上限。
- [ ] 80/95/100 阈值和 emergency disabled 错误可区分。

## 多 App 隔离测试

对于所有带状态 capability，至少验证：

1. App A 的 Token 无法读取 App B 数据；
2. 修改请求体 `app_id` 不改变可信作用域；
3. User A 无法读取 User B 数据；
4. App A 达到限额不会关闭 App B；
5. development/staging/production 本地缓存互不复用。
