# NEBULA-SDK-RELEASE-GATE-002 — Dynamic Release Story Binding

- ID：NEBULA-SDK-RELEASE-GATE-002
- Owner: SDK Governance Agent
- Agent: C
- Reviewer: Governance Review Agent
- Execution repo：`.`
- Execution branch：`sdk-governance/NEBULA-SDK-RELEASE-GATE-002`
- Execution remote：`hub`
- Execution worktree：`wt-nebula-sdk-release-gate-002`
- Platform API mode：`NONE`
- SDK public API mode：`READ_ONLY`
- State write authority: Coordinator only.

## Trigger
Independent Review #401 on RC2 PR #97 found that the tag-triggered release gate still validates historical `S1-F03-001` authority. The gate can therefore pass even if the current release Story is revoked or its expected branch/tag/version drifts.

## Goal
Make the immutable tag release gate bind mechanically to the **current release Story represented by the tagged package metadata**, rather than to a hard-coded historical Story ID or branch.

## Exact authorized write-set
Only:

1. `governance/sdk_release_policy.json`
2. `tool/sdk_release_gate.dart`
3. `tool/sdk_release_gate_test.dart`
4. `.github/workflows/release.yml`

No `lib/**`, API snapshot, package version, release docs, Task Board, Backend, App, provider, or product mutation is authorized to the implementation Agent.

## Required behavior
Given the tagged checkout's `pubspec` version and pushed Git tag, the gate must:

1. require exact `tag == v<pubspec version>`;
2. locate **exactly one** Task Board Story whose governed release metadata matches `expected_version` and `expected_tag`;
3. require that Story to retain `platform_api_mode=NONE`, `sdk_public_api_mode=READ_ONLY`, `state_write_authority=COORDINATOR_ONLY`, and `agent_may_edit_task_board=false`;
4. require release/package authority and expected execution branch to be present and not revoked;
5. reject zero matching Stories;
6. reject multiple matching Stories;
7. reject version/tag drift;
8. reject revoked/closed-without-release authority;
9. never hard-code `S1-F03-001`, `NEBULA-SDK-RELEASE-002`, or any release branch in the validator;
10. preserve existing immutable tag/HEAD/API-surface/channel checks.

The release workflow must call this same validator on the tag checkout. Do not create a second release authority path in shell/YAML.

## Required tests
Focused regression must prove:

- RC1 historical release Story can still validate its own immutable metadata;
- a READY/authorized RC2-style Story validates only its own expected version/tag;
- current Story revoked -> FAIL;
- wrong version/tag -> FAIL;
- duplicate matching release Stories -> FAIL;
- missing matching Story -> FAIL;
- branch metadata drift -> FAIL;
- Platform/API/state-write invariants remain blocking.

## Exit
Delivery goes to independent Governance Review. Agent C does not merge, close the Story, publish RC2, or create any tag. Coordinator closes this Story only after exact Formal SUCCESS + official exact-head APPROVED + canonical merge + post-merge governance SUCCESS. RC2 must then be rebuilt from the new canonical base and independently reviewed again.
