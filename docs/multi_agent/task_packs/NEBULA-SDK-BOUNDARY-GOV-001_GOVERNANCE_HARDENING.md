# NEBULA-SDK-BOUNDARY-GOV-001 — SDK Boundary Governance Hardening

ID：NEBULA-SDK-BOUNDARY-GOV-001
Owner：SDK Governance / Quality Agent
Agent：A
Reviewer：SDK Architecture Review Agent
Execution repo：`.`
Execution branch：`governance/NEBULA-SDK-BOUNDARY-GOV-001-implementation`
Execution remote：`hub`
Execution worktree：`wt-nebula-sdk-boundary-gov-001`
Platform API mode：`NONE`
SDK public API mode：`READ_ONLY`
Product adapter rule：`ADAPTER_FIRST`

Status: **READY / GOVERNANCE IMPLEMENTATION**

## Upstream authority

- Architecture freeze: `docs/multi_agent/contracts/SDK_INTERNAL_BOUNDARY_HARDENING.md`.
- Production Repair PR `#118`, exact `8304da4c8de25b38d37e29ce5f79f8be3fb54540`, Formal `#360` SUCCESS, Review `#476` APPROVED / reviewer-agent / official=true, merge `58076edccc18131001ff532b833965b90af56d62`, post-merge `#361` SUCCESS.
- Execution baseline: `nebula-flutter-sdk main@58076edccc18131001ff532b833965b90af56d62`.

## Goal

Turn the reviewed boundary rules into blocking mechanical governance after the production tree is clean. Add one Layer Graph Guard and one Product-Erasure Guard, their policy registry and negative regressions, and bind them to the existing governance entry/PR CI. No product capability or SDK public behavior changes.

## Exact authorized write-set

Only these paths may change:

1. `governance/sdk_boundary_policy.json`
2. `governance/policy.json`
3. `tool/sdk_layer_graph_guard.dart`
4. `tool/sdk_layer_graph_guard_test.dart`
5. `tool/product_erasure_guard.dart`
6. `tool/product_erasure_guard_test.dart`
7. `tool/sdk_boundary_ci_binding_test.dart`
8. `tool/governance.dart`
9. `tool/governance_test.dart` — fixture placement compatibility only: move temporary source probes under a classified module so the new layer guard can run inside the existing governance regression harness.

Implementation Agent must not change `.github/workflows/governance.yml`; it is Coordinator-owned protected state. After the guard implementation is canonical and post-merge green, Coordinator performs a separate CI-binding publication changing only `.github/workflows/governance.yml`. No `lib/**`, `test/**`, API snapshot, public export allowlist, pubspec/lock, release workflow, Backend or consumer App mutation is authorized.

## Layer Graph Guard

Classify base modules `foundation/transport/storage`; sibling capabilities `auth/config/analytics/error_reporting` plus reserved future `asset/notification/payment/ai`; composition `observability`; test domain `testing`; root/contract files `nebula.dart/capabilities.dart/transport.dart`.

Parse production Dart imports under `lib/src/**`, resolve relative internal imports and fail closed on unclassified internal ownership. Fail on at least: foundation -> higher layer; transport -> storage/capability/composition/testing; storage -> transport/capability/composition/testing; sibling capability -> different sibling capability implementation; production -> testing; unclassified new top-level module. Capability -> foundation/transport/storage and explicit composition/root contracts remain allowed.

Negative tests inject transport->auth, analytics->error_reporting, foundation->transport, production->testing and unclassified module; baseline current main must pass with zero exceptions.

## Product-Erasure Guard

Scan production `lib/**` only and strip comments before checking executable code/string literals. Fail on registered consumer/product identifiers, recorded consumer package IDs/product origins, executable hard-coded http/https origins unless reviewed, Flutter/UI/navigation coupling (`package:flutter`, `Widget`, `BuildContext`, `Navigator`, `GoRouter`, `showDialog`), runtime dependency drift from `dependencies: {}`, and production package imports outside the reviewed runtime dependency baseline.

Comments/evidence that merely name NFC Writer or Nearvia must not fail. Negative tests prove comments are ignored while executable strings/identifiers fail, and mutate only temporary pubspec copies for dependency probes.

## Governance / CI binding

`tool/governance.dart` invokes both guards so existing PR/push/release governance immediately executes baseline boundary checks once the implementation lands. The implementation also adds a strict `sdk_boundary_ci_binding_test.dart`, but the current implementation PR must not mutate the Coordinator-owned workflow and therefore must not execute this strict binding test in Formal yet. After implementation merge/post-merge, Coordinator publishes a workflow-only binding PR that adds direct execution of both guards, both negative tests and `sdk_boundary_ci_binding_test.dart`; that Coordinator PR is not complete unless the strict binding test passes. Binding test asserts those commands exist and no self-approve/update mode is used. Existing `tool/governance_test.dart` may only change fixture placement from unclassified `lib/src/<probe>.dart` to a classified temporary module path such as `lib/src/foundation/<probe>.dart`; rule expectations/coverage must remain otherwise unchanged.

## Invariants

- API surface = 131.
- public exports = 39/40.
- runtime dependencies = `{}`.
- proof ownership stays foundation/testing with `auth/proof.dart` compatibility re-export.
- no product/App/Backend mutation.
- no wildcard/self-authorizing exception for current violations.

## Verification

Implementation phase: Task Source/Cross Repo/Platform guards; exact implementation write-set; diff-check; both guards and negative tests on mac-mini; governance + governance regression; API 131; exports 39; dependencies `{}`; format; analyze; full test; secret scan; smoke PASS. The strict CI binding test source is reviewed/analyzed but is expected to become runnable only in the subsequent Coordinator workflow-only publication. Coordinator binding phase: `.github/workflows/governance.yml` only; Formal must directly execute both guards, both negative tests and `sdk_boundary_ci_binding_test.dart` and pass.

## Exit

Implementation Agent delivers frozen guard-code exact to Formal + independent SDK Architecture review without touching Coordinator-owned workflow. After implementation merge/post-merge SUCCESS, Coordinator opens a workflow-only CI-binding publication. Story closes only after both the implementation PR and the Coordinator binding PR have exact Formal SUCCESS, official reviewer-agent APPROVED and post-merge governance SUCCESS.
