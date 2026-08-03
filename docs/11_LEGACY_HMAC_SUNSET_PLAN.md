# Legacy HMAC Compatibility and Sunset Plan

Architecture task: F0-03 · Status: **PLAN** · Depends: F0-02 (frozen)

本文是协议/认证方案层的兼容与下线计划，与 `docs/05`（SDK 能力层迁移）互补。
事实锚点：`docs/08 §1`（legacy routes）、`docs/08 §10`（compatibility boundary）、
flypost `internal/middleware/signature.go`（V1.3 HMAC）、`internal/router/router.go`。

## 1. 兼容边界（冻结，docs/08 §10）

```text
legacy client -> legacy HMAC middleware -> compatibility routes
new client    -> installation proof middleware -> target mobile routes
```

- 两套认证方案**分离并存**，可跨迁移期共存；
- **新 proof 失败绝不回退 legacy HMAC**（FB-03 已落地：proof failure never falls
  back to legacy global HMAC；FB-05 路由清单测试固化 `bootstrap ≠ 40001 链`）；
- legacy 方案在 **F0-03 定义的 cutoff** 到达后下线。

## 2. Legacy 现状清单（docs/08 §1.1 confirmed routes）

| 端点 | Legacy 中间件 | 下线处理 |
| --- | --- | --- |
| `POST /api/v1/auth/code/send` | global/App HMAC + rate | target 落地后迁移（FB-04 链） |
| `POST /api/v1/auth/login` | global/App HMAC + rate | 同上 |
| `POST /api/v1/auth/oauth/login` | global/App HMAC + rate | 占位；无真实 adapter 前保持 disabled |
| `POST /api/v1/auth/refresh` | global/App HMAC + rate | target 单飞刷新（FB-04 已实现服务端语义） |
| `POST /api/v1/auth/logout` | global/App HMAC + rate | 已迁移至 Token 中间件下（FB-04） |
| `POST /api/v1/auth/device/register` | HMAC + rate + user Token + idempotent | 被 `/auth/device/bind`（target）取代 |
| `POST /api/v1/app/token` | global/App HMAC + rate | **REMOVE from mobile**（server-to-server 专属，docs/08 §2 rule 5） |
| `GET /api/v1/sync/bootstrap` | HMAC + rate + user Token | **KEEP 独立语义**（Flypost business snapshot，禁止与 mobile bootstrap 混用） |

Legacy 签名机制（V1.3）：`HMAC-SHA256(AppSecret, METHOD\nPATH\nTIMESTAMP\nNONCE\nBODY_HASH)`
+ `X-App-Key` 多 App 支撑 + Redis Nonce 防重。移动端 App Secret 是该方案的根本问题（MB-01）。

## 3. 协议层 keep / adapt / remove 结论

| 旧 SDK 认证能力 | 结论 | 新位置/任务 | 原因 |
| --- | --- | --- | --- |
| `client.dart` HMAC signing（App Secret） | REMOVE | 无（target 用 installation proof） | 移动端不得持有 App Secret（MB-01，docs/08 §2） |
| `auth.login(phone, code)` | ADAPT | F1-02 auth + target `/auth/login` | 换 proof 认证；响应语义对齐 12001-12004 |
| `auth.appToken()` | REMOVE | server-side SDK | `client_credentials` 不属于移动端（docs/08 §2 rule 5） |
| `auth.refresh` | ADAPT | F1-02 single-flight（FS-02 已冻结语义） | 原子轮换、族吊销（FB-04） |
| `auth.logout` | ADAPT | F1-02 | 挂 Token 中间件、幂等、作用域吊销（FB-04/MB-02） |
| `device/register`（HMAC 链） | REMOVE→ADAPT | `/auth/device/bind`（target, FB-04） | 用户令牌 + installation proof 绑定 |
| `sync/bootstrap` | KEEP | 原语义不动 | 与 mobile bootstrap 严格分离（docs/08 §3） |

## 4. Cutoff 机制（version / store-build）

服务端对 legacy 链施加 **store-build cutoff**（已具备能力：FB-01 分配 `12003
client_outdated`；`minimum_supported_build` 已在 bootstrap 响应契约 docs/08 §4.2）：

1. 服务端配置 `legacy.cutoff_build`（按平台/App 维度，白名单升级）；
2. legacy HMAC 请求携带 `X-App-Version` + `X-App-Build`（由旧 SDK 原生字段上报）；
3. 请求 build < cutoff → 拒绝并返回 `12003 client_outdated` + `minimum_supported_build`，
   SDK 提示升级；不提供"再试一次 legacy"降级路径；
4. target 链（installation proof）不受 cutoff 影响——`12003` 仅作用于 legacy 端点；
5. cutoff 前至少两个 App 完成迁移并稳定一个小版本（对齐 docs/05 §2 步骤 6-7）。

新 SDK 侧：`minimum_supported_build` 已在 `BootstrapResult` 契约（F0-04 fixture），
客户端据此本地阻断旧构建（`ClientOutdatedError`，FS-02 分类）。

## 5. 迁移阶段与时间线

| 阶段 | 动作 | 验收 |
| --- | --- | --- |
| P0 并存（当前） | legacy HMAC + target proof 分离共存，无回退 | FB-05 route inventory 全绿；`go test ./...` 通过 |
| P1 target 落地 | `/auth/code/send、login、refresh、logout、device/bind` 挂 InstallationProof（FB-04 后置） | target 端点 proof 链通过；legacy 端点保持 40001 链 |
| P2 灰度 | 单 App 切 target；观察启动/登录/错误率 | 错误率不劣化；无 fallback 事件 |
| P3 deprecated | 全量 App 上 target；legacy 端点日志告警计数 | legacy 流量 < 阈值；无新增接入方 |
| P4 cutoff | 服务端启用 `legacy.cutoff_build`（12003） | 低于 cutoff 的 legacy 请求被拒 |
| P5 移除 | 删除 legacy HMAC 中间件与兼容路由 | 路由清单不再含 legacy 端点；测试更新 |

P1 的挂载由 FS-01 之后的任务承接（FS-02 已冻结 SDK 状态机；服务端挂载属 flypost 侧）。

## 6. 风险与回滚

| 风险 | 缓解 | 回滚 |
| --- | --- | --- |
| App 未升级被 cutoff 拦截 | cutoff 按 App 白名单分阶段；`minimum_supported_build` 提前下发 | 回滚配置 `legacy.cutoff_build` 为空 = 取消 cutoff |
| legacy/target 语义混用 | FB-05 路由清单测试固化端点类别；`/sync/bootstrap` 语义隔离 | 无代码回滚，仅还原配置 |
| proof 失败被误回退 legacy | FB-03 测试固化"proof failure never falls back" | 还原中间件链装配 |
| cutoff 误伤 target 客户端 | `12003` 仅作用于 legacy 端点；target 走 `12004` 可用性语义 | 同上 |

## 7. 引用与后续

- `docs/08 §10` 兼容边界（冻结）；`docs/05` 能力层迁移；`docs/10` 跨仓库对账；
- flypost：`internal/middleware/signature.go`、`internal/router/router.go`、
  `internal/pkg/errcode/errcode.go`（12003 client_outdated）；
- SDK：`BootstrapResult.minimum_supported_build`（F0-04 fixture）、
  `ClientOutdatedError`（FS-02）。
