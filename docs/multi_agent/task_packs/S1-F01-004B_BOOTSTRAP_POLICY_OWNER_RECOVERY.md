# S1-F01-004B Bootstrap Policy Owner Recovery
- ID：S1-F01-004B
- Owner：`Architecture/PM Agent`
- Reviewer：`Governance Review Agent`
- Depends：`S1-F01-003`
- Execution repo：`.`
- Execution branch：`s1/f01-004b-policy-owner`
- Platform API mode：`NONE`
- SDK public API mode：`NONE`

## Goal
Independently decide and own the narrow policy authorization for the public Bootstrap `app_id` wire field without weakening trusted App-scope protection.

## Exact write set
Only `governance/policy.json`.

Input proposal: `03-architecture-pm-policy.patch` SHA-256 `86edf41ddfbd1efdfe473c938d5b04d0f275ee4e5f42d942807b02591ec5cff6`.

## Acceptance
- exact path exception only; wildcard forbidden;
- reason required;
- occurrence budget remains exactly one authorized `app_id` mapping;
- no SDK production, tool, snapshot, Task Board, Backend, or App diff;
- deliver an owner-authored commit on the assigned branch for Coordinator serial assembly, not standalone feature publication.
