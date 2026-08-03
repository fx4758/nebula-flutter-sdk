## AI handoff

- Task ID:
- Baseline commit:
- Scope/owned files:
- Public API changed: no / yes (describe)
- Security/privacy/worst-case cost:
- Known residual risk:
- Rollback:
- Next ready task:

## Evidence

```text
dart run tool/governance.dart
dart format --output=none --set-exit-if-changed .
dart analyze
<tests relevant to this task>
```

Paste concise results; do not mark checkboxes from expectation.

- [ ] Task is registered in `docs/STATUS.md`.
- [ ] Required acceptance criteria are linked.
- [ ] Public API allowlist was reviewed if exports changed.
- [ ] New dependency/exception/debt includes owner and exit plan.
- [ ] No real credentials, private endpoints or user data were used.
