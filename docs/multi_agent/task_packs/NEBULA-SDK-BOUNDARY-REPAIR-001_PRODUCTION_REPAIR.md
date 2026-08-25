# NEBULA-SDK-BOUNDARY-REPAIR-001 — SDK Internal Boundary Production Repair

ID：NEBULA-SDK-BOUNDARY-REPAIR-001
Owner：SDK Boundary Repair Implementation Agent
Agent：A
Reviewer：SDK Review Agent
Execution repo：`.`
Execution branch：`architecture/NEBULA-SDK-BOUNDARY-REPAIR-001-implementation`
Execution remote：`hub`
Execution worktree：`wt-nebula-sdk-boundary-repair-001`
Platform API mode：`NONE`
SDK public API mode：`CHANGE_APPROVED`
Product adapter rule：`ADAPTER_FIRST`

Status: **READY / CHANGE_APPROVED**

## Upstream authority

- Architecture freeze: `docs/multi_agent/contracts/SDK_INTERNAL_BOUNDARY_HARDENING.md`.
- Freeze PR: `#115`.
- Freeze exact: `d572b893dc83651b7d6fcc8462b137f98c1d6cae`.
- Formal: governance run `#352` SUCCESS on that exact.
- Independent review: `#469 APPROVED / reviewer-agent / official=true / exact=d572b893dc83651b7d6fcc8462b137f98c1d6cae`.
- Freeze merge: `8f45d55c95148c6f5365919b62c7b40d1bfe2c62`.
- Post-merge governance: run `#353` SUCCESS.
- Execution baseline: `nebula-flutter-sdk main@8f45d55c95148c6f5365919b62c7b40d1bfe2c62`.

## Goal

Repair the SDK physical dependency direction without changing public symbol semantics or any Platform/App behavior. Move generic request-proof ownership out of Auth, preserve compatibility, update source-path snapshot ownership under explicit `CHANGE_APPROVED`, and add deterministic multi-App isolation regression coverage.

This Story deliberately does **not** implement the Layer Graph Guard or Product-Erasure Guard. Those are a separate governance Story after this production tree is canonical-clean.

## Exact authorized production/public write-set

Only these production/public paths may change:

1. `lib/src/foundation/request_proof.dart` — new authoritative runtime proof primitives.
2. `lib/src/testing/recording_proof_signer.dart` — new authoritative recording test double.
3. `lib/src/auth/proof.dart` — compatibility re-export only; no runtime ownership remains.
4. `lib/src/auth/session_auth.dart` — switch proof import to neutral owner only.
5. `lib/src/transport/proof_headers.dart` — switch proof import to neutral owner only.
6. `lib/src/config/config_client.dart` — switch proof import to neutral owner only.
7. `lib/src/analytics/mobile_analytics_sender.dart` — switch proof import to neutral owner only.
8. `lib/src/error_reporting/mobile_error_report_sender.dart` — switch proof import to neutral owner only.
9. `lib/src/observability/mobile_observability_composition.dart` — switch proof import to neutral owner only.
10. `lib/src/nebula.dart` — switch proof import to neutral owner only.
11. `lib/nebula_sdk.dart` — direct exports of the authoritative runtime/testing declaration owners while preserving package public names.
12. `governance/api_surface.snapshot` — source-path ownership migration only.
13. `governance/public_api.txt` — export-path allowlist synchronization only: preserve `src/auth/proof.dart` and add exactly `src/foundation/request_proof.dart` + `src/testing/recording_proof_signer.dart` so the frozen direct barrel exports pass governance.

No other `lib/**`, governance or package file is authorized. `pubspec.yaml`, `pubspec.lock`, Platform Backend and consumer Apps must remain unchanged.

## Authorized focused tests

Test mutation is limited to:

- `test/proof_test.dart`
- `test/auth_proof_test.dart`
- `test/analytics/mobile_analytics_sender_test.dart`
- `test/error_reporting/mobile_error_report_sender_test.dart`
- `test/observability/mobile_observability_durable_trust_test.dart`
- `test/multi_app_isolation_test.dart` (new)

Existing tests outside this list must pass unchanged. If another test file must change for compilation, STOP and return a scope-gap note rather than widening the Story.

## Frozen ownership

`lib/src/foundation/request_proof.dart` owns exactly:

```text
nebulaProofVersion
ProofCanonicalInput
RequestProofSigner
```

`lib/src/testing/recording_proof_signer.dart` owns exactly:

```text
RecordingProofSigner
```

`lib/src/auth/proof.dart` remains a compatibility seam and may only re-export the above declarations. It must not duplicate classes/constants or add Auth behavior. Production modules must not import `auth/proof.dart` after the repair.

The existing request-proof canonical bytes, V1 version, ES256/P-256 host signer Port, headers, nonce/body/token hash behavior and wire semantics remain unchanged. No concrete crypto dependency enters the SDK.

## Public API invariant

Current public API count is `131`. The implementation must preserve all public symbol names and kinds. The snapshot will record source-owner movement only:

```text
removed path records:
  src/auth/proof.dart const nebulaProofVersion
  src/auth/proof.dart class ProofCanonicalInput
  src/auth/proof.dart class RequestProofSigner
  src/auth/proof.dart class RecordingProofSigner

added path records:
  src/foundation/request_proof.dart const nebulaProofVersion
  src/foundation/request_proof.dart class ProofCanonicalInput
  src/foundation/request_proof.dart class RequestProofSigner
  src/testing/recording_proof_signer.dart class RecordingProofSigner
```

Required proof:

```text
public symbol names added   = 0
public symbol names removed = 0
symbol kind changes         = 0
API surface total           = 131
```

Any actual public symbol add/remove/rename, member semantic change, proof version change, wire change or dependency addition is outside this Story.

## Multi-App isolation regression

Add one deterministic combined regression using two distinct App identities (`app-a`, `app-b`) sharing the same physical fake/in-memory storage. It must prove at minimum:

1. secure token namespace is distinct by environment + App identity; writing/clearing A cannot read/delete B;
2. generic `StorageNamespace.app/user` remains isolated by environment/app/user;
3. two Runtime Config clients sharing one cache cannot read each other's snapshot;
4. analytics consent/persisted state for A does not alter B;
5. Error Reporting queue flush/delete/corruption handling for A does not delete B.

Do not opportunistically redesign namespace formats or Backend scope. Existing Backend authority remains read-only.

## Explicitly forbidden

- Layer Graph Guard implementation;
- Product-Erasure Guard implementation;
- `.github/**`, `tool/**`, Task Board or coordinator-state mutation by the implementation Agent;
- Backend or consumer App mutation;
- Asset/Notification/Payment/AI capability work;
- Auth V2 provider/session semantics change;
- WeChat/QQ enablement;
- new runtime/dev dependency solely for this repair;
- service locator/global mutable singleton;
- product identifiers/models/config pushed into SDK;
- broad formatting/refactor outside the exact write-set.

## Verification

Before delivery:

- `dart run tool/task_source_guard.dart --story NEBULA-SDK-BOUNDARY-REPAIR-001` PASS;
- `dart run tool/cross_repo_guard.dart --story NEBULA-SDK-BOUNDARY-REPAIR-001 --repo . --check-branch` PASS;
- `dart run tool/platform_api_guard.dart --story NEBULA-SDK-BOUNDARY-REPAIR-001` PASS;
- exact production/public path diff matches the authorized set;
- `git diff --check` PASS;
- no production import of `src/auth/proof.dart`; compatibility import remains test-proven;
- proof canonical fixture/headers behavior unchanged;
- API surface total exactly `131` with 4 path removals + 4 path additions and symbol-name/kind equality;
- deterministic multi-App isolation test PASS;
- `pubspec.yaml` and `pubspec.lock` byte-identical to base;
- `governance/public_api.txt` changes exactly from 37 to 39 allowed export paths by adding only `src/foundation/request_proof.dart` and `src/testing/recording_proof_signer.dart`; existing `src/auth/proof.dart` compatibility export remains allowlisted; total export budget stays <= 40;
- `dart format --output=none --set-exit-if-changed .`;
- `dart analyze`;
- full `dart test`;
- governance, secret scan and smoke PASS;
- Delivery Note records exact base/candidate and zero Backend/App mutation.

## Exit

Deliver only to `READY_FOR_REVIEW`. Do not self-review, self-merge or mark the Task Board DONE. Coordinator may merge only after Formal SUCCESS on the frozen exact and an official exact-head independent reviewer-agent APPROVED verdict. After canonical closure, Coordinator may separately register the governance-hardening Story for Layer Graph/Product-Erasure guards.
