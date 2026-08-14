# ADR-MOBILE-OBSERVABILITY-001 — Mobile Observability Architecture Boundary

- **ADR ID**: ADR-MOBILE-OBSERVABILITY-001
- **Status**: FREEZE CANDIDATE / INDEPENDENT REVIEW REQUIRED
- **Story**: OBS-CONTRACT-V1-001
- **Architecture authority**: `reports/ACR-MOBILE-OBSERVABILITY-001.md`
- **Implementation authorization**: NONE

## 1. Context

S1-F04-001 established that the SDK already owns an Analytics domain pipeline (`NebulaAnalyticsEvent`, `NebulaAnalyticsSender`, bounded queue/batch/retry behavior), while production mobile ingest semantics are not closed by the legacy Backend analytics endpoint. The same audit found no canonical Error Reporting public capability/ingest contract in the audited SDK/Backend surfaces.

The approved Architecture Review requires observability to remain two independent domains that may reuse the existing Nebula transport/trust foundation. It explicitly rejects a generic telemetry payload/schema and rejects a duplicate `MobileTelemetryTransport` abstraction.

## 2. Decision

Nebula mobile observability is split into two independently versioned contracts:

```text
Existing Nebula transport / request lifecycle / trust foundation
                         |
              +----------+----------+
              |                     |
 Mobile Analytics Contract v1   Error Reporting Contract v1
```

The domains MAY share foundation concerns where applicable: request lifecycle, `request_id`, InstallationProof/trusted-installation identity, transport error envelope, retry framework, and bounded request budgets.

They MUST NOT share domain payload schema, storage model, retention semantics, privacy policy, or deduplication identity merely for implementation convenience.

## 3. Analytics ownership and classification

Mobile Analytics remains a **Nebula-owned capability and product-data SSOT**. Platform API promotion is not granted by this ADR because generic Analytics second-consumer evidence was not verified during ACR review. Crash/Error/Telemetry evidence MUST NOT be relabeled as Analytics second-consumer evidence.

A future Platform promotion requires a separate Platform API Review with mechanically verified second-consumer evidence.

## 4. Error Reporting ownership and classification

Error Reporting V1 is a domain-neutral Platform-capability candidate. Verified FlyPost governance evidence establishes a second consumer for generic Flutter/Dart failure/release telemetry semantics independent of NFC-specific or product-specific payloads.

Error Reporting is not a product-owned bespoke crash platform.

## 5. Provider strategy

Nebula owns the contract, privacy boundary, lifecycle, trusted identity semantics, and cost/budget policy. A replaceable provider adapter MAY own collection backend, dashboard, or storage implementation.

Provider selection MUST consider data residency, regional availability, legal requirements, and export restrictions. No specific provider or jurisdiction mapping is frozen by this ADR.

App product code MUST NOT hard-code provider routing such as region-specific direct Firebase/Sentry/domestic-SDK branching. Provider routing remains behind the Nebula-owned boundary.

Error Reporting V1 MAY later use third-party provider adapters. This ADR does not authorize provider integration and does not authorize building a full in-house crash platform.

Analytics remains Nebula-owned SSOT; third parties MAY later be downstream BI/export/experimentation sinks but are not the Analytics authority.

## 6. Lifecycle and cost principles

Observability payloads, local persistence, upload budgets, and server retention MUST be bounded. Concrete runtime budget values are not architecture invariants unless a later contract explicitly freezes them.

Over-limit behavior MUST be deterministic and statistically/accountably observable. Silent unbounded retention is forbidden.

Error capture is best effort. Architecture MUST NOT claim guaranteed capture after process termination.

Client implementations MUST support server-directed upload reduction policy whose values may evolve without changing this ADR.

## 7. Security and privacy principles

Trusted identity is derived from InstallationProof/trusted installation state; caller-supplied identity fields are not authorization authority.

No user identifier, raw logs, breadcrumbs, screenshots, or user content is included by default in Error Reporting V1. Native crash/minidump/ANR collection is outside V1.

## 8. Consequences

- Analytics and Error Reporting evolve independently.
- Existing `NebulaTransport` remains the foundation; no new generic telemetry transport abstraction is introduced by this Story.
- Durable Analytics retry identity and Error Reporting report identity are domain-specific.
- Provider replacement does not require product-code branching.
- Runtime cost policy can be tuned without rewriting this ADR, within the frozen boundedness/privacy/lifecycle rules.

## 9. Explicit non-decisions

This ADR does **not** freeze or authorize:

- concrete Backend endpoint paths;
- database tables, migrations, indexes, or topology;
- concrete providers;
- SDK public API/export changes;
- Backend/SDK/App/provider implementation;
- implementation Story registration;
- concrete runtime byte/count/TTL values.

## 10. Governance

This document becomes `APPROVED / FROZEN` only after independent Architecture Review and canonical closure of `OBS-CONTRACT-V1-001`. Until then it is a freeze candidate only. No implementation authorization is inherited from this ADR.
