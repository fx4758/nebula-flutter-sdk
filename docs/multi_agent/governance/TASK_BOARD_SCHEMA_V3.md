# Task Board Schema V3

> SUPERSEDED by `TASK_BOARD_SCHEMA_V5.md`. Historical reference only; non-executable.
Status: **FROZEN**

`docs/multi_agent/task_board.json` is the only executable task source. Every active Story MUST have `status`, `owner`, `reviewer`, `branch`, `worktree`, and a one-to-one `task_pack`. Optional `depends_on` must reference another registered Story. Historical SDK roadmap IDs are non-executable unless registered here.
