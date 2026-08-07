# Sprint 1 Agent Assignment v1.0

Status: READY

## Global Acceptance Rule

Agent delivery message is not acceptance evidence. Reviewer must verify files, code, configuration and tests.

## Agent A — Flutter Integration

Story:
- S1-F01-001 APK Nebula Adapter Layer
- S1-F01-002 Bootstrap Lifecycle

Allowed:
- lib/platform/nebula/**
- app dependency/bootstrap integration
- tests/**

Forbidden:
- parser
- NFC runtime
- business feature migration
- SDK public export changes

Evidence:
- changed files list
- import boundary check
- startup tests

## Agent B — Runtime Config

Story:
- S1-F02 Runtime Config First Slice

Allowed:
- backend runtime config API
- SDK config client
- related tests

Forbidden:
- Asset
- Payment
- Notification
- AI
- business workflow

Evidence:
- API contract
- API tests
- client/cache tests

## Agent C — SDK Governance

Story:
- S1-F03 SDK Release Workflow

Allowed:
- docs/**
- tool/**
- CI governance files

Forbidden:
- business source
- capability expansion

Evidence:
- release workflow
- CI gate definition
- API surface process

## Review Gate

Only reviewer can move REVIEW to DONE.
