# Task Board Schema V4

> SUPERSEDED by `TASK_BOARD_SCHEMA_V5.md`. Historical reference only; non-executable.
Status: **FROZEN**

`docs/multi_agent/task_board.json` is the only executable task source.

Every active Story MUST have:
- `status`, `owner`, `reviewer`, `branch`, `worktree`, `task_pack`
- `platform_api_mode`: `NONE | READ_ONLY | IMPLEMENT_FROZEN_CONTRACT | CONTRACT_CHANGE`
- `sdk_public_api_mode`: `NONE | READ_ONLY | CHANGE_APPROVED`

For `IMPLEMENT_FROZEN_CONTRACT`, Story must additionally contain `platform_change_authorization` with approved ACR, frozen contract reference, backend baseline and independent reviewer.

For `CONTRACT_CHANGE`, authorization must additionally contain ADR, contract version, adapter-first analysis, compatibility/rollback plan and `second_consumer_evidence` with at least two named consumer/use-case entries including one consumer other than the triggering product.

Implementation Agents may not edit their own authorization or promote a Story's mode. Global task-board/authorization fields are Coordinator-owned.
