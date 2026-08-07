# Sprint 1 Agent Dispatch Sheet v1.0

Status: READY (not started)

## Global Rule
Agent response is not acceptance evidence. Reviewer must verify files, code, config and tests.

## Agent 1 Flutter Integration
Story: S1-F01-001 / S1-F01-002
Input:
- SPRINT1_GOVERNANCE_UPDATE.md
- SPRINT1_TASK_BOARD_v1.1.md
- MA0-D01 report
Allowed:
- lib/platform/nebula/**
- app bootstrap related files
- tests
Forbidden:
- parser/runtime/business feature migration
- SDK public surface changes
Evidence required:
- changed files
- import scan
- startup test

## Agent 2 Backend Runtime Config
Story: S1-F02-001
Allowed:
- mobile runtime config API scope
- DTO/service/test
Forbidden:
- asset/payment/notification domains
Evidence required:
- API contract
- OpenAPI
- integration test

## Agent 3 SDK Runtime Config
Story: S1-F02-002
Allowed:
- config client implementation
- tests
Forbidden:
- capabilities.dart
- public exports without review
Evidence required:
- client code
- cache tests
- offline tests

## Agent 4 Governance
Story: S1-F03-001 / S1-F03-002
Allowed:
- docs
- tool
- CI governance
Forbidden:
- business source
Evidence required:
- workflow document
- CI gate evidence

No Agent may start until Story status changes from READY to IN_PROGRESS by owner.