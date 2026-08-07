# Sprint 1 Agent Dispatch — Epoch 2

> NON-SSOT human mirror. Coordinator owns persisted state in `task_board.json`.

Implementation Agent startup:
1. Read Story from Task Board; do not edit it.
2. `dart run tool/task_source_guard.dart --story <ID>`
3. `dart run tool/cross_repo_guard.dart --story <ID> --repo <execution_repo> --check-branch`
4. Run Platform/API guard if required.
5. Commit only in that Story's execution repo + feature branch.
6. Return Delivery Note; Coordinator updates DELIVERED/REVIEW/DONE.

No combined F01/F02/F03 branch is authoritative for new delivery. No direct shared `main/dev` push.
