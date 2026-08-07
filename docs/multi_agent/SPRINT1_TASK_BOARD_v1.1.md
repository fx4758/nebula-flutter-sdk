# Sprint 1 Task Board v1.1

## Global Rules

- Feature Agent MUST NOT modify SDK public surface without review.
- App pages/features MUST NOT directly import Nebula SDK.
- Runtime Config only provides platform capability, not business workflow.

## S1-F01 APK Nebula Adapter Layer

Owner: Flutter Integration Agent
Reviewer: Architecture Review Agent

Allowed:
- lib/platform/nebula/**
- lib/app/dependency.dart
- test/**
- docs/**

Forbidden:
- lib/features/**
- lib/pages/**
- SDK public exports

Evidence required:
- Adapter source evidence
- Import scan
- Flutter tests

## S1-F02 Runtime Config First Slice

Backend owner:
- Runtime Config API contract
- OpenAPI
- API tests

SDK owner:
- NebulaConfigClient
- cache/fallback tests

Forbidden:
- business rules
- parser rules
- NFC actions

## S1-F03 SDK Release Workflow

Owner: SDK Governance Agent

Deliverables:
- version strategy
- path/tag/release workflow
- API surface CI gate

## Review Requirement
Agent summary is not acceptance evidence.
Reviewer must verify repository files, code, tests and configuration.
