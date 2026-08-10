# S1-F01-004C Bootstrap Governance Surface Owner Recovery
- ID：S1-F01-004C
- Owner：`Quality Agent`
- Reviewer：`Governance Review Agent`
- Depends：`S1-F01-003`
- Execution repo：`.`
- Execution branch：`s1/f01-004c-governance-owner`
- Platform API mode：`NONE`
- SDK public API mode：`CHANGE_APPROVED`

## Goal
Independently own the governance scanner/regressions and final API-surface registration required by Bootstrap V2 R2.

## Exact write set
Only:
- `governance/api_surface.snapshot`
- `governance/public_api.txt`
- `tool/governance.dart`
- `tool/governance_test.dart`

Input proposal: `04-quality-governance-surface.patch` SHA-256 `a40c139d8bcfa07f1f04c6bf4ab7c1262d24f7de243fd732d63a783b739270ed`.

## Acceptance
- second same-file `app_id` mutation must fail `DATA-TRUST-BODY-APP-ID`;
- wildcard/missing reason/missing positive match budget remain blocking;
- public API registration contains only approved Bootstrap files/symbols;
- no SDK Core production, policy, Task Board, Backend, or App diff;
- deliver an owner-authored commit on the assigned branch. Do not merge standalone to `main`; Coordinator assembles the final owner-authored integration stack and runs full gates there.

## Closure
**DONE / Coordinator accepted owner contribution.** Owner delivery `2f417e51067f74a41f26ee86ea13f96dba3c0769` byte-matched the frozen proposal and was serially assembled as `f11fb53` into owner-authorized baseline `f11fb53d6ff6e6ec689797133e78f6b7a9219a05`. This Story is no longer executable.
