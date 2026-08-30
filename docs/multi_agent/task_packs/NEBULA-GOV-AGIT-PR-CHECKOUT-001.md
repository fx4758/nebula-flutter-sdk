# NEBULA-GOV-AGIT-PR-CHECKOUT-001

ID：NEBULA-GOV-AGIT-PR-CHECKOUT-001

Owner：Coordinator Agent

Reviewer：Governance Review Agent

Execution repo：`.`

Execution branch：`coordinator/nebula-gov-agit-pr-checkout-001`

Platform API mode：`NONE`

SDK public API mode：`READ_ONLY`

Product adapter rule：`ADAPTER_FIRST`

## Objective

Correct the Coordinator-owned Nebula governance workflow so pull-request runs do not treat Forgejo AGit `pull_request.head.ref` (`refs/pull/<n>/head`) as a normal branch ref. Pull-request checkout must fetch the immutable PR ref by pull-request number, verify it resolves to the event's exact `head.sha`, and detach at that exact SHA. Push-event checkout remains branch-based.

## Authorized write set

- `.github/workflows/governance.yml`
- `tool/governance_pr_checkout_contract_test.dart`
- `docs/multi_agent/task_board.json`
- `docs/multi_agent/task_packs/NEBULA-GOV-AGIT-PR-CHECKOUT-001.md`

## Required behavior

- For `pull_request` events, read `number` and exact `pull_request.head.sha`; never use `pull_request.head.ref` as a `refs/heads/*` branch.
- Fetch only `refs/pull/<number>/head` into an isolated remote-tracking ref, verify the fetched SHA equals event `head.sha`, then checkout detached at that SHA.
- For `push` events, preserve the existing `refs/heads/*` checkout behavior.
- Keep Forgejo token use confined to the existing authenticated fetch step; no new credential source or API mutation is authorized.
- Add a contract regression that fails if the AGit PR ref/exact-SHA checkout invariant is removed.
- No Backend, staging runtime, DB schema, provider configuration, SDK public API, App, release artifact or migration mutation is authorized.

## Gate

Coordinator publication only. Formal governance CI must succeed on the exact candidate, followed by independent official non-stale exact-head review and mechanical mcp-architect merge.
