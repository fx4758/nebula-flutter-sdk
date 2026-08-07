# Architecture Change Request

## Metadata
- ACR ID：
- Raised by：
- Related Story：
- Triggering Product：
- Date：
- Severity：BLOCKING / NON-BLOCKING
- Requested Platform API mode：IMPLEMENT_FROZEN_CONTRACT / CONTRACT_CHANGE

## Observed Fact
Give repository + file/line/test evidence. No guesses.

## Platform vs Product Gate — all mandatory
1. Exact capability/change requested:
2. Platform or Product capability, and why:
3. Second consumer(s) and same-semantics use case:
4. Does this still make sense with the triggering product name removed?
5. Why App Adapter cannot solve it:
6. Why SDK-internal implementation cannot solve it without Platform contract change:
7. Frozen contract gap with file/line/test evidence:
8. Endpoint/field/error/trust/idempotency/quota/lifecycle impact:
9. Compatibility/versioning/rollback plan:
10. Security/abuse-cost/privacy/data-scope impact:

If any answer is missing, Decision MUST be REJECTED/DEFERRED.

## Options
### Option A — Keep Platform unchanged
- Adapter/SDK-only solution
- Benefit
- Cost

### Option B — Platform change
- Exact change
- Benefit
- Cost
- Compatibility
- Security/cost impact

## Recommended Decision
Recommend exactly one option. Adapter-first is the default.

## Authorization Evidence
- Existing frozen contract:
- Proposed contract version (CONTRACT_CHANGE only):
- ADR (CONTRACT_CHANGE only):
- Independent Architecture Reviewer:
- Second-consumer evidence:

## Scope Impact
- Platform API
- SDK public API
- Database/migration
- App integration
- Security/cost
- Sprint dependency

## Temporary Workaround
Default: none. Any exception needs expiry + deletion Story.

## Decision
- APPROVED / REJECTED / DEFERRED
- Approved mode:
- ADR:
- Contract version:
- Follow-up Story ID:
- Reviewer/sign-off evidence:
