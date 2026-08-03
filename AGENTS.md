# AI Collaboration Rules

本文件对整个 `nebula-flutter-sdk` 工程生效。

## 1. 每轮开始

1. 读取 `docs/00_AI_HANDOFF.md` 和 `docs/STATUS.md`。
2. 只读取当前任务路由到的文档，不把所有治理文件注入上下文。
3. 检查工作树，保留其他 AI 或用户的未提交修改。
4. 一次只领取一个可独立验收的任务 ID。
5. 修改代码前运行 `dart run tool/governance.dart` 获取治理基线。

## 2. 硬边界

- 公共 SDK 不得出现 Flypost、NFC Writer、Focus、StarSprout 的业务模型或流程。
- 移动端不得保存 App Secret、Provider Secret 或 App `client_credentials`。
- SDK 不得直连 OSS、AI、短信、邮件、支付 Provider。
- 服务端资源作用域来自可信令牌，不信任请求体中的 `app_id`。
- 非幂等请求默认不自动重试；新增重试必须说明幂等依据和成本上限。
- 日志、异常和分析事件不得包含 Token、密码、完整手机号、邮箱、支付凭证或用户内容。
- 未冻结的公共 API 不得从 `lib/nebula_sdk.dart` 导出。

## 3. 变更规模

- 每个 PR 只处理一个任务 ID。
- 新增公共模块前必须通过 `docs/01_ARCHITECTURE.md` 的准入条件。
- 优先增加现有模块的能力；禁止为单个类创建新 package。
- 新依赖必须在 PR 中说明：用途、体积、许可证、替代方案和平台影响。

## 4. 完成要求

- 更新 `docs/STATUS.md`，但不得把“计划”写成“已完成”。
- 运行 README 中的本地检查。
- 如果守卫误报，登记有期限例外或修正规则；禁止删除检查绕过失败。
- 提交交接块：任务 ID、改动、验证、遗留风险、下一任务。
- 不连接生产环境，不提交密钥，不修改 flypost/server，除非任务明确授权。
