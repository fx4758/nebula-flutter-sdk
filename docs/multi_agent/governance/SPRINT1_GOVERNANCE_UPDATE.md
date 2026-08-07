# Sprint 1 Governance Update v1.0

Status: FROZEN
ID: GOV-S1-001

## Evidence First Principle
Agent delivery message is not acceptance evidence. Reviewer must verify files, code, tests, configs and governance artifacts.

Evidence priority:
Code/Test/Config/Document > Agent summary

## Delivery Requirements
Every Story delivery must include:
- Changed Files
- Code Evidence (file and line range)
- Test Evidence (command and result)
- Config/Governance Evidence when applicable
- Risks and follow-ups

## Reviewer Independence
Reviewer must independently inspect:
- git diff
- changed files
- tests
- contracts

Agent self-report cannot be the only acceptance basis.

## Merge Gates
MG-S1-01 Evidence Gate: no evidence, no review.
MG-S1-02 Ownership Gate: forbidden path modification fails review.
MG-S1-03 API Gate: public API changes require ADR and review.

## Status Transition
READY -> IN_PROGRESS -> DELIVERED -> REVIEW -> DONE

Only reviewer/orchestrator can move REVIEW -> DONE.

## Board Ownership
Agent may update own delivery status. Global sprint state, dependency graph and release gates require orchestrator ownership.
