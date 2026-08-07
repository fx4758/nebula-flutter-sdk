## AI handoff

- Task ID:
- Baseline commit:
- Scope/owned files:
- Public API changed: no / yes (describe)
- Platform API mode (from task_board):
- SDK public API mode (from task_board):
- Platform/API ACR + ADR (if applicable):
- Adapter-first analysis (if Platform change proposed):
- Second consumer evidence (CONTRACT_CHANGE only):
- Security/privacy/worst-case cost:
- Known residual risk:
- Rollback:
- Next ready task:

## Evidence

```text
dart run tool/governance.dart
dart run tool/task_source_guard.dart --story <STORY_ID>
dart run tool/platform_api_guard.dart --story <STORY_ID> [--backend-repo ../flypost_backend]
dart format --output=none --set-exit-if-changed .
dart analyze
<tests relevant to this task>
```

Paste concise results; do not mark checkboxes from expectation.

- [ ] Story is registered in `docs/multi_agent/task_board.json` and task-source guard passes.
- [ ] Required acceptance criteria are linked.
- [ ] Public API allowlist was reviewed if exports changed.
- [ ] New dependency/exception/debt includes owner and exit plan.
- [ ] No real credentials, private endpoints or user data were used.
- [ ] READ_ONLY Story has zero protected production Platform diff.
- [ ] Any Platform write is authorized by a separate approved Story/ACR; implementation Agent did not self-promote scope.
- [ ] CONTRACT_CHANGE has ADR + versioning/rollback + named second-consumer evidence.
