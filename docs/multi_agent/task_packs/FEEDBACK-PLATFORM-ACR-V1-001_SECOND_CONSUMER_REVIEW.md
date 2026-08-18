# FEEDBACK-PLATFORM-ACR-V1-001 Feedback Platform ACR / Second-Consumer Review
- ID：FEEDBACK-PLATFORM-ACR-V1-001
- Owner：Platform Architecture Agent
- Execution repo：`.`
- Execution branch：`feedback/platform-acr-v1-001-second-consumer`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`READ_ONLY`
- Governance state：ACR/evidence only; no Platform API/SDK/App/provider production mutation.
- Required upstream：`FEEDBACK-ARCH-V1-001 = DONE / REVIEW PASS` and `FEEDBACK-SDK-SURFACE-V1-001 = DONE / REVIEW PASS`.

## Purpose
Determine whether a new product-neutral Feedback entry/session Platform API may be promoted to `CONTRACT_CHANGE` under `PLATFORM_API_CHANGE_POLICY`, especially whether FlyPost provides mechanically credible second-consumer evidence for the same semantics as NFC Writer.

This Story MUST NOT assume that FlyPost qualifies. It must independently verify or reject that evidence.

## Required output
Create exactly one review artifact:

- `docs/multi_agent/reports/ACR-FEEDBACK-PLATFORM-V1-001.md`

The report MUST answer all ten Platform-vs-Product gate questions in `governance/PLATFORM_API_CHANGE_POLICY.md` and conclude exactly one of:

```text
APPROVED_FOR_CONTRACT_FREEZE
DEFERRED_SECOND_CONSUMER_INSUFFICIENT
REJECTED_ADAPTER_ONLY
```

## Triggering consumer evidence to verify
### NFC Writer
- current Flutter Help/Feedback route is a placeholder in the current source tree;
- historical/released China feedback uses Tencent TXC/兔小巢;
- reviewed Feedback Architecture/SKD Surface freeze requires a provider-neutral first-party entry/session.

### Candidate second consumer: FlyPost
Fresh canonical evidence MUST be read from `root/FlyPostAPI` and `root/FlyPost`, not stale local docs.

Candidate facts to verify include:
- FlyPostAPI has a real `user_feedback` domain/model with `app_id`;
- FlyPostAPI has real Admin feedback management/reply routes and `feedback.manage` permission;
- FlyPostAPI currently lacks a mobile/user Feedback ingress route;
- determine whether the same generic first-party entry/session semantics can serve FlyPost without FlyPost-specific request fields or translation;
- fresh FlyPost App canonical evidence must be checked separately and any absence must be disclosed rather than filled from stale local UX files.

The reviewer must decide whether Backend/Admin feedback-domain existence is enough to be a credible second consumer under policy §4, or whether a canonical App-side product requirement is additionally required.

## Mandatory ACR questions
1. Exact capability/change requested.
2. Platform vs Product classification.
3. Second consumer and same-semantics use case, with exact repo/SHA/file evidence.
4. Product-name erasure test.
5. Why App Adapter cannot solve provider-neutral trusted session routing alone.
6. Why SDK-internal implementation cannot create a trusted server session without Platform contract support.
7. Exact frozen-contract gap.
8. Endpoint/field/error/trust/idempotency/quota/lifecycle impact.
9. Compatibility/versioning/rollback plan.
10. Security/abuse-cost/privacy/data-scope impact, including session TTL/replay and SR-008 boundary.

## Adapter-first options to compare
- A: keep Platform unchanged; current App uses direct TXC/adapter-specific route.
- B: introduce a generic Feedback entry/session Platform contract returning only a bounded relative first-party entry path.

The report must explain why B is or is not justified across at least two consumers.

## Forbidden
- Any mutation under `lib/**`.
- Any Backend/App repository mutation.
- Platform endpoint/schema/error/contract implementation.
- SDK public API/snapshot mutation.
- TXC credentials/API invocation.
- New capability ID.
- Native Feedback implementation.
- Treating stale/non-canonical FlyPost UX documents as second-consumer evidence.
- Task Board mutation by execution Agent.

## Verification
- exact canonical SHA evidence for every named consumer;
- product/provider name erasure analysis;
- `git diff --check` PASS;
- docs-only diff;
- independent Architecture Review PASS.

## Exit
If `APPROVED_FOR_CONTRACT_FREEZE`, Coordinator may register a separate `CONTRACT_CHANGE` Feedback Platform API Contract/ADR freeze Story carrying the accepted second-consumer evidence. No production implementation is authorized by this ACR.

If deferred/rejected, Platform remains READ_ONLY. SDK production implementation remains blocked; TXC legacy may continue unchanged and any non-Platform aggregation work requires its own separately reviewed Story.
