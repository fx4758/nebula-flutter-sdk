# LAN GIT 服务接入说明（Sprint 1 协作入口）

> 状态：ACTIVE（2026-08-07 17:35 CST 由 Coordinator 建立并验证）
> 服务：本机 192.168.31.137:9419 git daemon（`receive-pack` 已启用，支持 push）

## 1. 仓库地址

```bash
git://192.168.31.137:9419/nebula-flutter-sdk
```

验证可用：

```bash
git ls-remote git://192.168.31.137:9419/nebula-flutter-sdk
```

## 2. 分支约定

| 分支 | 用途 | Push 权限 |
|---|---|---|
| `architect/f0-02-mobile-session` | 主线（MA0 基线 + Sprint 1 启动） | Coordinator 专用，LAN agent 禁止直推 |
| `s1/f01-adapter` | Sprint 1 Story：APK Nebula Adapter（Agent A） | Agent A / 参与该 Story 的 agent |
| `s1/f02-runtime-config` | Sprint 1 Story：Runtime Config（Agent B，Backend + SDK） | Agent B / 参与该 Story 的 agent |
| `s1/f03-release` | Sprint 1 Story：SDK Release Workflow（Agent C） | Agent C / 参与该 Story 的 agent |
| `main` | 历史基线 | 只读 |

## 3. 其他局域网 Agent 加入方式

```bash
# 1) 克隆
git clone git://192.168.31.137:9419/nebula-flutter-sdk.git
cd nebula-flutter-sdk

# 2) 认领 Story：从对应分支切出自己的工作分支
git checkout -b work/你的名字-s1-f01 s1/f01-adapter

# 3) 提交
git add -A && git commit -m "..."

# 4) 推送自己的工作分支（不要推 Story 分支本身，避免互相覆盖）
git push git://192.168.31.137:9419/nebula-flutter-sdk work/你的名字-s1-f01
```

> git:// 协议不支持身份认证，推送者以分支名自证。**同一 Story 分支上请先 `git pull` 再 push**，冲突时优先 rebase 到 Story 分支最新。

## 4. 协作铁律（必须遵守）

1. **Agent 交付消息 ≠ 验收证据**：必须提供文件路径、代码、测试输出，由 Reviewer 复核后才可进 DONE。
2. **禁止直推主线** `architect/f0-02-mobile-session`：由 Coordinator 合并验收。
3. **禁止修改 board**：`docs/multi_agent/task_board.json`、`docs/multi_agent/02_SPRINT_BOARD.md` 由 Coordinator 持有。
4. **禁止越界**：
   - 禁止修改 `core/parser/**`、NFC Runtime。
   - 禁止 Asset / Upload / Payment / AI 抢跑。
   - 禁止改 SDK 公共导出（`lib/src/*` public surface）无评审。
   - 禁止业务页直连 SDK（必须走 `lib/platform/nebula/**` 适配层）。
5. **编码前先读**：Story Task Pack（`docs/multi_agent/task_packs/S1-*.md`）、`SPRINT1_AGENT_ASSIGNMENT.md`、`SPRINT1_TASK_BOARD_v1.1.md`、对应 `contracts/*` 冻结契约。

## 5. 当前 Sprint 1 看板（机器可读：task_board.json）

- S1-F01-001（+002 Bootstrap）：IN_PROGRESS — wt-s1f01
- S1-F02-001（Backend）+ S1-F02-002（SDK Config）：IN_PROGRESS — wt-s1f02
- S1-F03-001 + S1-F03-002：IN_PROGRESS — wt-s1f03
- 前置门禁 MA0-A02/A03 = DONE（已满足）

## 6. 服务维护

- Daemon 以后台任务运行于本机（192.168.31.137:9419），`receive-pack` 已启用。
- 本机 bare 仓库：`/Users/sean/git-server/nebula-flutter-sdk.git`（所有分支的权威落点）。
- 如需重启 daemon：`/usr/bin/git daemon --reuseaddr --base-path=/Users/sean/git-server --export-all --enable=receive-pack --port=9419 --verbose`。
- 服务端 SSH 等强认证方案未启用；当前信任局域网环境，若需收严再评估。

## 7. 其他仓库

- flypost 后端仍在既有服务器 `git://192.168.1.3:9419/flypost`（未迁移，仅本 SDK 仓库挂在本机 LAN 服务）。
