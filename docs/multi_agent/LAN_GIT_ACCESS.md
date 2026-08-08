# 仓库接入说明（Sprint 1 协作入口）

> 状态：本地 git daemon **已停用（DECOMMISSIONED，2026-08-08）**；代码仓库已迁移至局域网 HTTP Git 服务器。
> 新权威远端：`http://192.168.31.102:3000/root/nebula-flutter-sdk.git`

## 1. 仓库地址（新）

```bash
http://192.168.31.102:3000/root/nebula-flutter-sdk.git
```

验证可用：

```bash
git ls-remote http://192.168.31.102:3000/root/nebula-flutter-sdk.git
```

> 该服务器为 HTTP(S) 协议，**推送需要账号凭据**（Gitea/Forgejo 类）。本机已缓存 Basic 凭据可写；
> 其他 agent 首次推送请用 `git` 凭据助手或在 URL 中携带 token，例如：
> `git push https://<user>:<token>@192.168.31.102:3000/root/nebula-flutter-sdk.git <branch>`

## 2. 分支约定

| 分支 | 用途 | Push 权限 |
|---|---|---|
| `architect/f0-02-mobile-session` | 主线（MA0 基线 + Sprint 1 启动） | Coordinator 专用，agent 禁止直推 |
| `main` | 历史基线 | 只读 |
| `archive/*` | 历史归档分支（legacy / obsolete / cross-repo 清理） | 只读，勿在此基础上开发 |

> 注：原 `s1/f01-adapter`、`s1/f02-runtime-config`、`s1/f03-release` 三个 worktree 分支已于 2026-08-08 清理（三次并行子 Agent 启动均被 429 限流阻断、从未产生提交，无工作成果丢失）。如重启 Sprint 1 并行开发，由 Coordinator 重新切出 Story 分支。

## 3. 其他局域网 Agent 加入方式

```bash
# 1) 克隆（需要服务器读权限）
git clone http://192.168.31.102:3000/root/nebula-flutter-sdk.git
cd nebula-flutter-sdk

# 2) 认领 Story：从主线切出自己的工作分支
git checkout -b work/你的名字-s1-f01 architect/f0-02-mobile-session

# 3) 提交
git add -A && git commit -m "..."

# 4) 推送自己的工作分支（不要推主线本身，避免互相覆盖）
git push origin work/你的名字-s1-f01
```

> HTTP 协议支持身份认证，推送者以凭据自证。**同一分支上请先 `git pull --rebase` 再 push**，冲突时优先 rebase 到最新。

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

- S1-F01 / S1-F02 / S1-F03：IN_PROGRESS（见 task_board.json；原 worktree 已清理，需重启时由 Coordinator 重建隔离环境）
- 前置门禁 MA0-A02/A03 = DONE（已满足）

## 6. 历史：本地 git daemon（已停用）

- 原本地 daemon `git://192.168.31.137:9419/nebula-flutter-sdk` 已于 2026-08-08 **停用并关闭**，相关启动脚本 `/Users/sean/git-server/start-lan-git.sh`、plist `~/Library/LaunchAgents/com.nebula.gitdaemon.plist`、bare 仓库 `/Users/sean/git-server/nebula-flutter-sdk.git` 均已不再作为协作入口（bare 仓库可作为本地备份保留，可随时删除）。
- **请勿再依据本文档旧版本从 9419 克隆**——该端口已无服务，会 `connection refused`。

## 7. 其他仓库

- flypost 后端仍在既有服务器 `git://192.168.1.3:9419/flypost`（未迁移，与本 SDK 仓库的独立）。
