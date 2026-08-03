# F0-02 Implementation Handoff

Status: **READY FOR CODING AIs**

Architecture source: `08_MOBILE_BOOTSTRAP_SESSION_CONTRACT.md`

此文件拆分编码任务和文件所有权。架构师不实现这些任务；编码 AI 一次只领取一个任务，不能跨任务顺手重构。

## 1. Merge order

```text
FB-01 contract/error fixtures
  -> FB-02 mobile bootstrap persistence/service
  -> FB-03 installation proof middleware
  -> FB-04 session claims/rotation/logout
  -> FB-05 router and abuse-isolation integration
  -> FS-01 SDK installation ports/models
  -> FS-02 SDK session state machine
  -> FC-01 end-to-end compatibility fixtures
```

Backend work happens in flypost feature branches. SDK work happens in this repository. Do not combine both repositories in one commit.

## 2. Backend work packages

### FB-01 — Protocol fixtures and error allocation

Ownership: flypost identity/appidentity HTTP contract tests and contract documentation.

Deliverables:

- freeze request/response fixtures for target bootstrap/auth flows;
- allocate integer error codes for installation invalid, session revoked, client outdated and temporarily unavailable;
- reconcile `{code,data}` as the only runtime envelope;
- prove old and target routes cannot silently share/fallback authentication schemes.

Forbidden: production handler implementation, schema changes, SDK edits.

Acceptance: failing contract tests exist first; every target route is marked not implemented until its owner task lands.

### FB-02 — Installation identity owner module

Ownership: one platform owner module, its migration, repository, service and handler. Final directory is selected by flypost Architecture Guard; no generic CRUD.

Required facts:

- installation record keyed by trusted App + installation ID;
- public key thumbprint, platform, status, attestation state, last seen and expiry;
- idempotent bootstrap request ID;
- bounded creation/retention and cleanup policy;
- no App Secret returned or stored on device.

Acceptance: cross-App same installation ID cannot collide; invalid attestation creates no active installation; concurrent same request ID creates one fact.

### FB-03 — Installation proof and replay middleware

Ownership: middleware + small identity Port, injected in router composition.

Required chain:

```text
rate protection -> installation token -> key status -> ES256 proof
-> scoped replay check -> trusted context injection
```

Acceptance: proof mutation, token swap, App swap, path/body mutation, expired timestamp and nonce replay all fail before handler; Redis failure follows the frozen availability policy and emits metrics.

Forbidden: middleware reading GORM directly; fallback to global HMAC after a target header is present.

### FB-04 — User session rotation and logout

Ownership: `core/identity` service/repository/handler plus migration only if required.

Required changes:

- App/installation-bound claims;
- atomic refresh generation rotation and reuse detection;
- current-session idempotent logout under Token middleware;
- durable revocation fact and bounded fallback behavior;
- old session-row growth eliminated.

Acceptance: concurrency tests, replayed refresh family revocation, App/installation mismatch rejection, logout route contract, Redis degradation tests.

### FB-05 — Router and abuse isolation

Ownership: router composition, rate-limit key strategy, CORS header policy and integration tests.

Required changes:

- target mobile group does not inherit legacy HMAC middleware;
- legacy and target chains coexist without fallback;
- trusted claim scopes replace raw `X-Device-Id/X-App-Id` on authenticated limits/idempotency;
- `X-Idempotency-Key` is separate from proof nonce;
- Flutter Web preflight explicitly allows only required headers and origins.

Acceptance: route inventory test asserts exact middleware class per endpoint; an AI/asset flood cannot consume bootstrap/login bucket in load tests.

## 3. SDK work packages

### FS-01 — Installation contracts and secure adapters

Ownership: SDK foundation/auth contracts, storage/key Ports and fake implementations.

Depends: FB-01 frozen fixtures.

Deliverables:

- typed bootstrap request/result and installation identity;
- key-generation/signing Port; no concrete plugin in core;
- secure token store Port with environment/App namespace;
- request proof Port and deterministic canonicalization tests.

Forbidden: hard-coded endpoints without fixture, App Secret compatibility in new core, Provider SDK dependency.

### FS-02 — User session state machine

Ownership: SDK auth implementation and tests.

Depends: FB-04 fixtures and FS-01.

Deliverables:

- serialized state machine defined by architecture contract;
- single-flight refresh;
- local logout cleanup and session event stream;
- typed error categories without invented backend codes.

Acceptance: concurrent 401, refresh ambiguity, revoked installation, environment switch and cancellation tests.

## 4. Cross-repository validation

### FC-01 — Compatibility and end-to-end fixtures

Ownership: contract artifacts only; no duplicate production implementation.

Scenarios:

1. fresh install -> bootstrap -> phone login -> authenticated request;
2. access expiry -> one refresh -> all callers resume;
3. refresh replay -> session family revoked;
4. logout -> old access and refresh rejected;
5. App A token at App B rejected;
6. installation key loss -> new bootstrap, old key rejected;
7. legacy build remains on legacy chain until cutoff;
8. high-cost endpoint saturation does not block bootstrap/login.

## 5. Required coding-AI handoff

```text
Task ID and repository:
Architecture contract version/commit:
Owned files:
Contract fixtures used:
Security and availability decisions:
Tests and exact results:
Migration/rollback if any:
Known residual risk:
Next dependency unblocked:
```

Any implementation that changes target semantics must stop and request an ADR. Coding AI cannot rewrite the architecture contract to make its implementation pass.
