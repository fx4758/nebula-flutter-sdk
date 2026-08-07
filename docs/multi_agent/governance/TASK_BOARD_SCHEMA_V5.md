# Task Board Schema V5

Status: **FROZEN**

`docs/multi_agent/task_board.json` remains the only executable task source, but it is **Coordinator-owned state**.

Every active Story MUST include:

- `status`, `owner`, `reviewer`, `task_pack`
- `execution_repo`, `execution_branch`, `execution_remote`
- `state_write_authority = COORDINATOR_ONLY`
- `agent_may_edit_task_board = false`
- `platform_api_mode`, `sdk_public_api_mode`, `product_adapter_rule`

Optional after delivery/review:

- `execution_base_commit`
- `delivery_commit`
- `delivery_evidence`
- `review_state`

A Story has exactly one `execution_repo`. A second-repository implementation change requires another Story.

Coordinator-owned paths are never implementation output:

- `docs/multi_agent/task_board.json`
- `docs/multi_agent/02_SPRINT_BOARD.md`
- `docs/multi_agent/SPRINT1_AGENT_ASSIGNMENT.md`
- `docs/multi_agent/SPRINT1_AGENT_DISPATCH.md`
- architecture authorization state
