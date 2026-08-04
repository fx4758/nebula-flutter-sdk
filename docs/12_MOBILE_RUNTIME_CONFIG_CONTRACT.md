# Mobile Runtime Config Architecture Contract

Status: **FROZEN (F2-00, 2026-08-04)**

本文件是移动端运行时配置（effective config / feature flags / version policy）的**架构冻结契约**。
它冻结端点、信任作用域、响应模型、版本策略、缓存语义、安全/成本边界，以及后续 FB-06（flypost
后端编码）与 FC-02（跨仓 fixture 与集成测试）的验收标准。

编码边界：本文件**不包含任何生产代码**。SDK 侧实现由 F2-01（在 FB-06/FC-02 完成后解除 BLOCKED）执行；
flypost 侧实现由 FB-06 执行。

## 0. 背景与目标

- 现状：`flypost/sdk/CONTRACT.md` 将「产品/配置/Feature 下发」列为待办；已注册的 config/feature
  路由全部是管理端/产品控制面（`/products/:id/effective-configs` 等，`PermProductManage`），按
  ADR-F005 不得进入移动端 SDK。
- 目标：为 App 启动提供**一个**聚合端点，一次拉取同一版本快照中的配置、Feature、版本策略与缓存
  策略；客户端按冻结契约实现离线启动、缓存过期、强制升级与应急关闭语义（docs/04 F2 验收）。
- 设计取向：**单端点、单快照、服务端可信作用域、客户端零决策**。Feature 灰度分桶在服务端完成，
  客户端只收到最终 `enabled`；版本策略使用一等模型，不用任意字符串配置模拟。

## 1. 冻结端点

```text
GET /api/v1/mobile/runtime-config
```

- 无 query、无 body、无 path 参数。客户端不得通过任何请求输入影响选择逻辑。
- 可选条件请求头：`If-None-Match: <revision>`（见 §6 缓存语义）。
- 不提供分页端点、不提供单 key 端点。配置必须整体快照下发（保证跨 section 一致版本）。
- 该端点与 `/api/v1/mobile/bootstrap`、`/api/v1/mobile/auth/*` 同属 ADR-F008 移动端隔离组：
  挂 Installation Proof 中间件链，**不挂** AdminToken、RBAC 或 legacy HMAC `Signature` 中间件。

## 2. 信任作用域

| 事实 | 来源 | 约束 |
| --- | --- | --- |
| `app_id` | 可信令牌（installation token claims） | 绝不从 body/query/header 读取；请求体中的同名值仅可用于兼容校验且不参与选择 |
| `installation_id` | 可信令牌 | 同上；灰度分桶与限流的键 |
| `environment` | 服务端部署环境（`config.Get().Server.Env`） | 客户端不得指定；不接受任何环境参数/头 |
| `region` | 服务端可信绑定（installation/App 注册区域或部署区域） | **不信任** query/header（含 legacy 的 `X-Region`）；这是对 legacy §1「X-Region 透传」的定向豁免，仅适用于 `/api/v1/mobile/*` 新组 |

认证头（docs/08 §5，与 auth 端点一致）：

```text
X-Installation-Token: <installation token>
X-Proof-Timestamp: <unix 秒>
X-Proof-Nonce: <随机 hex>
X-Device-Proof: <ES256 签名>
```

- 无需用户令牌；该端点是安装作用域（capability-poor，预登录启动可用，对应
  `ScopeInstallation` 注释中 bootstrap/config/version/auth 入口）。
- Proof 失败、installation 失效 → `12001`（客户端清 installation token 并重新 bootstrap 一次）。

## 3. 请求

```http
GET /api/v1/mobile/runtime-config HTTP/1.1
Host: <platform-host>
X-Installation-Token: <installation token>
X-Proof-Timestamp: 1785780000
X-Proof-Nonce: <随机 hex>
X-Device-Proof: <签名>
If-None-Match: "rev-42"          # 可选
X-App-Build: 100                 # 可选：客户端构建号（服务端计算 version_policy.action）
X-App-Platform: ios              # 可选：客户端平台（版本/缓存策略作用域，F2-R1）
```

- 请求体为空。所有作用域来自令牌与部署事实（§2）。
- `X-App-Build`（FB-06 实现细节冻结）：可选非负整数构建号。服务端据其计算
  `version_policy.action`（§5）；缺失/非法视为未上报（action=none，服务端不作断言，
  客户端仍可用 minimum/latest 本地比对）。
- `X-App-Platform`（F2-R1 实现细节冻结）：可选平台标识（ios/android/harmony/...）。
  一等运行时策略按 (app, platform, environment) 选择，缺省回退 `all`；客户端不得
  通过它影响区域/环境/安装身份等信任作用域。

## 4. 响应模型（单一版本快照）

成功响应（HTTP 200）使用全局信封 `{code, data}`（无 `msg`，docs/08 §8）：

```json
{
  "code": 0,
  "data": {
    "revision": "rev-42",
    "server_time": 1785780000,
    "configs": {
      "feature_payment": {
        "value": { "max_amount": 500000 },
        "updated_at": 1785770000
      }
    },
    "features": [
      { "key": "payment_v2", "enabled": true },
      { "key": "nfc_export", "enabled": false }
    ],
    "version_policy": {
      "minimum_supported_build": 120,
      "latest_build": 121,
      "action": "upgrade",
      "message_key": "upgrade_prompt_v3"
    },
    "cache_policy": {
      "ttl_seconds": 300,
      "stale_if_error_seconds": 86400
    }
  }
}
```

字段冻结（一次性定义，后续变更须走 ADR）：

| 字段 | 类型 | 语义 |
| --- | --- | --- |
| `revision` | string（≤128 字符，不透明） | 快照版本。**F2-R1：由完整作用域+版本事实哈希生成**（app/env/region/platform/build/installation + 有效配置/Feature 的 version/updated_at/rollout + 策略版本）——任一作用域或内容事实变化都会使 revision 变化，正确失效 304/ETag。用于 ETag、If-None-Match 与客户端缓存键 |
| `server_time` | int（Unix 秒） | 服务端时间，客户端校时（时钟偏差校正），不得作为业务值使用 |
| `configs` | map<string, {value, updated_at}> | 可下发配置。`value` 为任意合法 JSON；`updated_at` 为该项最近生效时间。键由「可下发字段白名单」限定（§8） |
| `features` | array<{key, enabled}> | Feature 最终状态。`enabled` 已含灰度分桶结果；**无** `rules_json`/`rollout_percentage`/`updated_by` 等控制面字段 |
| `version_policy` | object | 一等版本策略模型（§5）。**禁止**用任意字符串配置模拟 |
| `cache_policy` | object | 服务端给出的缓存参数：`ttl_seconds`（新鲜窗口）、`stale_if_error_seconds`（网络失败时的 stale 上限，默认 0 = 不允许 stale） |

响应头：

- `ETag: "rev-42"`（与 body `revision` 一致；客户端缓存该值并在下次请求携带）。
- `Cache-Control: private, max-age=<ttl_seconds>, stale-if-error=<stale_if_error_seconds>`（可选，便于 CDN/网关；客户端以 body `cache_policy` 为准）。
- HTTP 304（条件命中）见 §6。

## 5. 版本策略（一等模型）

`version_policy.action` 为冻结枚举，客户端**只**依据该枚举 + 本地 build 号执行：

| action | 条件（服务端计算） | 客户端行为 |
| --- | --- | --- |
| `none` | `build >= latest_build` | 不提示 |
| `upgrade` | `minimum_supported_build <= build < latest_build` | 非阻塞提示升级 |
| `forced_upgrade` | `build < minimum_supported_build` | 阻塞/强提示升级（安全关键） |

- `minimum_supported_build` / `latest_build` 为 App 平台相关构建号（整数）。
- **一等策略模型（F2-R1）**：版本策略、缓存策略与 `security_critical` 列表按
  **(app, platform, environment)** 作用域存储（`product_runtime_policy`），
  取代任何全局键；不同 App/平台互不影响，iOS/Android/Harmony 可有独立构建号。
  服务端按 `X-App-Platform`（缺省回退 `all`）选择；无记录用默认策略
  （min=0/latest=0/ttl=300/stale=0）。
- `action` 由服务端按请求头 `X-App-Build`（§3）计算；客户端未上报时服务端不作断言
  （action=none），合规客户端仍可依据 minimum/latest 本地比对。
- 与业务码 `12003`（client_outdated）的关系：`runtime-config` 的 `version_policy` 是启动时权威来源；
  `12003` 是已冻结的 enforcement 信号（FB-01），用于登录/刷新等受保护端点上提示客户端过旧。两者语义一致，均不得伪造。
- `forced_upgrade` 为**安全关键字段**：不得无限期使用旧缓存（§6 fail-safe 规则）。

## 6. 缓存语义

1. **ETag/revision**：客户端缓存 `(revision, snapshot, received_at)`。下次拉取带
   `If-None-Match: "<revision>"`；服务端快照未变 → `304`（空 body，无信封）；已变 → `200` 新快照。
2. **新鲜窗口**：`cache_policy.ttl_seconds` 内直接使用缓存，不发请求（离线启动）。
3. **stale-if-error**：网络失败且缓存年龄 ≤ `ttl + stale_if_error_seconds` 时，**仅对非安全关键数据**
   允许返回 stale；`stale_if_error_seconds` 缺省 0 = 不提供 stale 兜底。
4. **刷新去重（single-flight）**：同一 namespace（environment/app/installation）的并发 `getEffectiveConfig`
   共享一次网络请求（复用 F1 会话 single-flight 模式）。
5. **安全关键字段不得 stale**：`version_policy.action == forced_upgrade` 与标记
   `security_critical: true` 的 feature（灾难/应急开关）在超过 `ttl_seconds` 后**必须**重新拉取确认；
   拉取失败时采用 **fail-safe 默认**：forced_upgrade 保持生效（不降级为 none），kill-switch feature
   保持关闭（不因 stale 恢复启用）。
6. **304 续期**：收到 304 时，客户端将快照视为重新新鲜 `ttl_seconds`；若缓存中无 `cache_policy`，
   使用客户端默认重校验间隔（5 分钟）。
7. **不缓存关闭状态**：应急关闭（§8）返回的可分类错误不被客户端当作永久状态缓存，仅按 TTL 更新
   （docs/02 §6）。

## 7. 错误码

复用已冻结错误码（FB-01 / 全局码表），**不新增**：

| code | 含义 | 客户端行为 |
| --- | --- | --- |
| `12001` | installation 失效 / proof 无效 | 清 installation token，重新 bootstrap 一次 |
| `12003` | 客户端过旧 | 按 `version_policy` 的强制升级语义处理（与启动快照一致） |
| `12004` | 服务暂时不可用（含应急关闭） | 有界退避；保留本地合法快照；安全关键字段不 stale |
| `40002` | 限流 | 尊重 Retry-After，禁止重试风暴 |
| `50001` | 服务端错误 | 可重试，但非幂等重试默认不自动；走全局重试策略 |
| `30001` | 参数错误 | 正常请求不应出现（客户端无参数）；出现即视为契约漂移，登记缺陷 |

- 全部经标准信封返回；HTTP 状态与业务码映射遵循既有规则（429↔40002 等）。
- 不新增「配置不存在/未发布」类错误：未发布配置对客户端**不可见**（视为不存在，返回空快照或当前已发布版本），不暴露内部状态。

## 8. 安全与成本边界

1. **可下发字段白名单（F2-R1 双重拒绝）**：每个 config/feature 键在发布时登记
   App 级白名单（`product_delivery_allowlist`）；**发布阶段**拒绝未登记键的发布，
   **读取阶段**未登记键不下发——密钥/内部地址/Provider 配置即使被误发布也到不了客户端。
2. **禁止字段（永不下发）**：密钥、Provider 配置（渠道密钥/回调密钥）、内部地址/主机名、`rules_json`、
   `rollout_percentage`、`created_by`/`updated_by`、内部自增 ID、审核状态、`environment`/`region` 原始配置。
3. **响应硬上限**（服务端强制 + 客户端校验，超限客户端按畸形响应处理并记日志，绝不部分信任）：
   - 总响应体 ≤ 64 KiB（客户端以紧凑编码近似校验）；
   - `configs` 项数 ≤ 128；
   - 单个 `value` ≤ 8 KiB（**任意 JSON 含嵌套**，客户端按序列化字节校验）；
   - `features` 项数 ≤ 256；
   - 键长度 ≤ 64，`revision` ≤ 128 字符；
   - 客户端持久化缓存条目 ≤ 64 KiB（超限不落盘，防存储放大）。
4. **限流**：per-IP（ClientIP，内存，反伪造）与 per-installation（以令牌内 `installation_id` 为键）
   双重限流；使用与 bootstrap/auth 不同的资源池语义（docs/02 §3），攻击高成本接口不得耗尽普通入口。
5. **存储故障隔离**：Redis/DB 异常时该端点快速失败（`12004`），不得挂起、不得拖垮普通接口；
   per-IP 粗限流不依赖 Redis。禁止形成重试风暴。
6. **应急关闭（kill switch）**：服务端开关可关闭下发且**无需发版**——关闭时返回 `12004`（或空快照 +
   标记），客户端按 §6.7 处理（不自动重试、保留基础登录/配置可用、不缓存关闭状态）。
7. **隐私/日志**：响应值不得被服务端/客户端日志记录；SDK 日志只含 request id/端点模板/结果类别/耗时
   （F1-04 已冻结）。

## 9. 与既有契约的关系

- 端点归入 ADR-F008 `/api/v1/mobile/*` 隔离组：与 legacy `/api/v1/auth/*` 认证链完全隔离、可共存；
  proof 失败绝不 fallback。
- 对 legacy §1「`X-Region` 透传」的**定向豁免**：仅本端点（及未来 `/api/v1/mobile/*` 配置类端点）的
  region 一律来自服务端可信绑定，不信任 header/query（见 ADR-F011）。
- **不复用管理端 DTO**：`/products/:id/effective-configs` 等产品控制面响应（含 `rules_json`、
  `rollout_percentage`、`updated_by`、客户端可传的 `environment`/`region_code`）与本契约无关，禁止
  作为本端点的数据源 DTO 直接暴露。
- 灰度分桶服务端稳定化：`bucket = stable_hash(installation_id, feature_key) % 100`（实现细节由 FB-06
  冻结并测试），同一 installation 跨请求结果稳定；客户端不参与桶计算。

## 10. FB-06 验收标准（flypost 后端编码）

1. 新路由**不挂** AdminToken、RBAC 或 legacy HMAC；仅 Installation Token + Installation Proof 中间件链。
2. 隔离测试：App A 无法经 App B 令牌获取配置；跨 environment、跨 installation 均不可越权。
3. 未发布配置不可见（客户端视角不存在）。
4. GLOBAL 与区域配置覆盖规则确定（GLOBAL 默认 + 区域覆盖）且有正反例测试。
5. 灰度分桶对同一 installation 稳定（两次请求结果一致；不同 installation 允许不同）。
6. 响应**不含** `rules_json`、`rollout_percentage`、`created_by`/`updated_by`、内部 ID、审核状态。
7. `304/ETag`、发布后 revision 变化、缓存失效均有测试。
8. 强制升级 / 普通升级 / 无升级三个场景均有测试。
9. 应急开关可关闭下发且无需发版（测试验证）。
10. `flypost/sdk/CONTRACT.md` 登记完整请求、响应、错误码与缓存语义（本契约 §1-§8 的 flypost 侧镜像）。
11. 响应上限（§8.3）在服务端强制并有测试（超限拒绝/截断策略确定）。
12. ArchGuard、Sentinel、全量 Go 测试通过。

## 11. FC-02 验收标准（跨仓契约 fixture 与集成测试）

1. Fixture 集与 flypost 契约逐项对账（对齐 FC-01 流程）：成功快照（全 section）、
   `forced_upgrade`/`upgrade`/`none` 三版本策略、304/ETag、`12001`/`12003`/`12004`/`40002`/`50001`
   错误 fixture、超限/畸形响应 fixture。落地于 `test/fixtures/runtime_config/`。
2. 错误码映射表冻结：扩展 `test/fixtures/error_mapping.json`（复用现有码，不新增；
   新增 `runtime_config` 小节覆盖 §7 全部码，session `table` 不动）。
3. 契约测试（`test/runtime_config_contract_test.dart`，wire/结构层，FC-02 交付）：
   - 快照顶层与各 section 字段恰为冻结集合；`features` 仅含 `{key, enabled, security_critical?}`；
   - 控制面字段（`rules_json`/`rollout_percentage`/`created_by`/`updated_by` 等）在任意 fixture 中
     递归不得出现；
   - 错误 fixture 均为合法信封且 code ∈ 冻结集，与 `error_mapping.json` 对账；
   - 分类：`classifyNebulaError`/`classifySessionError` 对 §7 各码的可恢复类别断言；
   - 客户端硬上限（§8.3）的**可执行定义**：超限快照必须被判定为畸形（拒绝，绝不部分信任）。
   - **边界（F2-01）**：客户端模型 1:1 映射（`NebulaEffectiveConfig` 等）与缓存行为
     （stale-if-error、安全关键字段 no-stale、并发刷新单飞）由 F2-01 实现并在 F2-01
     消费本批 fixtures 的测试中验证——FC-02 不实现生产模型。
4. 跨仓一致：`nebula-flutter-sdk/test/fixtures/` 与 flypost contract fixture 同名同值（revision 除外），
   任何漂移使 CI 失败（flypost 锚点：`internal/module/runtimeconfig`、`sdk/CONTRACT.md` §4.7、
   `internal/router/runtime_config_http_test.go`）。

## 12. 客户端契约映射（F2-01 冻结范围，待 FB-06/FC-02 后实现）

- `NebulaEffectiveConfig`（immutable）：`revision`、`serverTime`、`configs`（白名单键→值）、
  `features`（key→enabled）、`versionPolicy`（一等模型：minimumSupportedBuild/latestBuild/action 枚举）、
  `cachePolicy`（ttl/staleIfError）。
- 能力方法（命名以 F2-01 实现为准）：启动拉取 + 缓存 + stale-if-error + 单飞去重 + 安全关键 no-stale。
- 错误映射复用 `NebulaErrorCategory`（F1-04）与冻结错误码。
- 本契约冻结 wire 层；Dart 类型与方法签名属 F2-01，不得提前实现。

---

_变更任何冻结字段/端点/语义须新增 ADR 并经架构评审（docs/07 §3）。_
