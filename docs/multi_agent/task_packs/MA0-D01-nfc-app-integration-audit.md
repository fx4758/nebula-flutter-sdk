# Task Pack — MA0-D01 Flutter NFC Writer 接入点审计

- Epic：EPIC-GOV
- Owner：APK Integration Agent
- SP：2

## Goal

找到 Flutter App 中最小、低冲突、可构建的 Nebula SDK 接入路径。

## Inputs

- `/Users/sean/Documents/project/forAI/flutter NFC Writer/pubspec.yaml`
- Flutter 根项目 `lib/**`、`android/**`、tests
- `nebula-flutter-sdk/example/**`
- `nebula-flutter-sdk/docs/05_MIGRATION_FROM_FLYPOST.md`

## Allowed Paths

- `nebula-flutter-sdk/docs/multi_agent/reports/MA0_D01_NFC_APP_INTEGRATION_AUDIT.md`
- 本 Story 状态字段

## Forbidden

- 不修改 Flutter App。
- 不修改嵌套旧 Android 项目 `flutter NFC Writer/NFCWriter/**`。
- 不执行 reset/clean 删除用户工作树内容。

## Tasks

1. 确认 Flutter 根 App 的启动入口、DI/state management、network/storage 现状。
2. 找到 bootstrap、登录、runtime config、附件上传的候选接入点。
3. 定义唯一 composition root 候选路径。
4. 确认一个可构建的 Android flavor/variant 和命令。
5. 记录与现有未提交修改的碰撞风险。
6. 输出 S3-D01..D04 的 allowed paths 建议。

## Acceptance

- [ ] 明确 Flutter 根项目与旧 Android 子工程边界。
- [ ] 给出一个最小接入切片，不迁移所有业务。
- [ ] 给出构建命令和预期 APK 输出位置。
- [ ] 所有接入点均有文件路径。
- [ ] 不产生代码修改。

## Deliverable

`docs/multi_agent/reports/MA0_D01_NFC_APP_INTEGRATION_AUDIT.md`
