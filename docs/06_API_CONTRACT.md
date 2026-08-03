# Client API Contract Rules

本文件约束 SDK 公共 API 形态；具体 HTTP 路径仍以 flypost 的已测试契约为准。

## 1. 公共入口

App 最终只需要一个组合根：

```dart
final Nebula nebula = Nebula(
  options: options,
  transport: transport,
  auth: auth,
  config: config,
  analytics: analytics,
);
```

F1 完成前不冻结便利型 `Nebula.initialize()`；它需要先确定 Storage、Transport 和原生 adapter 的注入策略。

## 2. API 设计规则

- 对外返回 typed model，不返回裸 `dynamic/Map`。
- 输入对象不可变，并在网络请求前本地校验长度和枚举。
- 服务端业务错误映射为可穷举类别，同时保留原始 code/request ID。
- 不以异常承载分页结束、Feature 关闭等正常状态。
- 取消必须能传播到 transport；不得只忽略 Future 结果。
- 时间统一使用 UTC `DateTime`；金额使用最小货币单位整数和 currency。
- ID 在契约确认前保持服务端类型，不擅自转 int/string。

## 3. 兼容规则

- 追加可选字段：minor；
- 新增可选能力：minor；
- 删除/重命名公共符号或改变默认行为：major；
- 修复实现且契约不变：patch；
- deprecated API 至少保留两个小版本，并给迁移示例。

## 4. 请求语义

每个端点契约必须登记：

```text
method/path
auth scope
capability
timeout
idempotency
retry policy
input limits
error categories
cost/emergency behavior
```

缺任一高成本字段的 AI/Asset/Notification/Payment 端点不得进入实现。
