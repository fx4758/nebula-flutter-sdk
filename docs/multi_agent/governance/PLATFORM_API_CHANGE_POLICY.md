# Platform API Change Policy — GOV-PLATFORM-API-001

Status: **FROZEN / BLOCKING**
Effective: 2026-08-07

## 1. Core rule

**Product integration does not authorize Platform API changes.**

NFC Writer, FlyPost, StarSprout and Focus are consumers of Nebula. A consumer Story may expose a platform gap, but it MUST NOT repair that gap by reshaping Platform API for the current product.

Default decision order:

`App Adapter -> existing SDK internal implementation -> existing frozen Platform contract -> architecture change request`

If the need can be solved in the App Adapter, Platform API MUST NOT change.

## 2. Three Platform API modes

### READ_ONLY
Default for integration/audit Stories. Production Platform API code and contract surface are immutable. Tests, evidence and audit docs may be added. If a real gap is found: mark the Story BLOCKED/DELIVERED-WITH-GAP and raise an ACR. Do not fix it inside the same Story.

### IMPLEMENT_FROZEN_CONTRACT
Allowed only by a separately registered Story after architecture approval. Production implementation may change solely to conform to an already frozen contract. Endpoint, request/response fields, error semantics, trust scope and public behavior MUST NOT change.

### CONTRACT_CHANGE
Highest gate. Requires an APPROVED ACR, ADR, new/updated contract version, compatibility plan, rollback plan, independent architecture reviewer, and second-consumer evidence before implementation begins.

An implementation Agent cannot promote its own Story from READ_ONLY to either write mode.

## 3. Platform vs Product classification gate

Before any proposed Platform change, the ACR MUST answer all of these:

1. What exact capability is being changed?
2. Is it Platform capability or Product capability? Why?
3. Which second consumer, other than the current App, can use the same semantics without product-specific translation?
4. Does the API still make sense if the current product name is removed from the requirement?
5. Why can this not be solved in the App Adapter?
6. Why can this not be solved by SDK-internal implementation without changing public Platform contract?
7. Which frozen contract is insufficient, with file/line/test evidence?
8. Does it add/change endpoint, field, error code, trust scope, retry/idempotency, quota/cost or lifecycle semantics?
9. What is the compatibility/versioning/rollback plan for existing consumers?
10. What security, abuse/cost, privacy and data-scope risks change?

Failure to answer any item means **REJECT / keep Platform read-only**.

## 4. Second-consumer rule

A Platform capability must be domain-neutral and have at least one credible consumer beyond the product that exposed the need. Evidence must name the consumers/use cases and show the same contract semantics; merely saying “other apps may use it later” is insufficient.

Examples:
- Platform: installation identity, runtime feature flag, minimum build policy, generic asset lifecycle, entitlement query.
- Product: NFC parser rule, write mode, card behavior, door-card sector config, StarSprout story director rule.

## 5. Adapter-first rule

Product-specific models are mapped downward:

`Platform contract -> SDK generic model -> App Adapter -> Product model`

The reverse direction is forbidden. Product models/fields MUST NOT be pushed upward into SDK public API or Platform API merely to reduce App-side mapping code.

## 6. Change authorization

A Platform API write Story must be created by Coordinator/Architecture Owner. It must carry in `task_board.json`:

- `platform_api_mode`
- approved ACR ID/path
- ADR ID/path when contract semantics change
- frozen contract reference/version
- second-consumer evidence
- adapter-first rejection reason
- independent reviewer
- backend baseline commit

No Agent self-approval. Delivery message is not evidence.

## 7. Sprint 1 freeze

For S1-A Foundation Integration:
- App Adapter Stories: Platform API = READ_ONLY/NONE; SDK public API = READ_ONLY.
- Runtime Config backend Story S1-F02-001: **READ_ONLY audit + tests only**. Existing API is presumed authoritative until evidence proves a gap.
- SDK Runtime Config S1-F02-002: reuse existing client; public API is READ_ONLY.
- Any discovered Platform gap creates a new follow-up Story after ACR review; it does not expand S1-F02-001 in place.

## 8. Reviewer acceptance

Reviewer must independently inspect cross-repo diff. A READ_ONLY Story with production Platform API changes is automatically **CHANGES REQUIRED**, even if tests pass and the App works.
