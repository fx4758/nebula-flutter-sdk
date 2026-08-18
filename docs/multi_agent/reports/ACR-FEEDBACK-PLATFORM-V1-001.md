# ACR-FEEDBACK-PLATFORM-V1-001 — Feedback Entry/Session Platform API Review

## Metadata
- Story: `FEEDBACK-PLATFORM-ACR-V1-001`
- Requested future mode: `CONTRACT_CHANGE`
- Current mode in this Story: `READ_ONLY`
- Triggering consumer: NFC Writer
- Candidate second consumer: FlyPost
- Governing policy: `docs/multi_agent/governance/PLATFORM_API_CHANGE_POLICY.md`
- Architecture freeze: `docs/multi_agent/contracts/FEEDBACK_PROVIDER_ARCHITECTURE_V1.md`
- SDK surface freeze: `docs/multi_agent/contracts/FEEDBACK_SDK_PUBLIC_SURFACE_V1.md`
- Decision: **DEFERRED_SECOND_CONSUMER_INSUFFICIENT**

## 1. Observed canonical facts

### 1.1 NFC Writer — triggering consumer is mechanically established
Fresh canonical App ref:

```text
root/flutter_NFC_Writer
origin/dev = 4eb72050b83c5b91873c6af193339f0229578a41
```

Canonical evidence:

- `lib/feature/my/screen.dart` routes the Help item to `RouteName.help` (`origin/dev`, line 323 in the current file layout).
- `lib/app/app_router.dart:328-329` maps `RouteName.help` to `PlaceholderPage(title: AppStrings.myHelp)`.
- canonical App code contains no `txc.qq.com`, `support.qq.com`, `tucao` or `兔小巢` literals under `lib/android/ios`.

Therefore the current canonical Flutter client has a real Help entry but no implemented provider integration. Historical/released TXC usage is product migration context, not used as code evidence for a new Platform contract.

### 1.2 FlyPostAPI — a real product feedback domain exists
Fresh canonical Backend ref:

```text
root/FlyPostAPI
Dev = a49397a53708122ef63a664bedec4bc384ce3c46
```

Canonical evidence:

- `internal/model/social.go:81-93` defines real `Feedback` / `user_feedback`, including `AppID`, `UserID`, `Content`, `Type`, `Status` and timestamps.
- `internal/module/admin/admin_console.go:76-78` exposes real Admin feedback list/reply routes guarded by `PermFeedback`.
- `internal/module/admin/admin_repository.go:659-675` lists feedback by status/page but does not currently scope the query by `app_id`.
- no non-Admin/mobile/user Feedback ingress route exists in canonical `internal/**`; the only feedback HTTP routes are Admin list/reply.

This is strong evidence that FlyPost has a real **feedback processing domain**. It is not yet evidence that FlyPost App consumes the proposed **first-party feedback entry/session** contract.

### 1.3 FlyPost App — candidate second-consumer ingress evidence is absent
Fresh canonical App ref:

```text
root/FlyPost
origin/main = 1d2e728ae9764cdc2be27640150785c5b8170026
```

A fresh canonical grep under `lib`, `docs/governance` and `docs/sprints` finds no `意见反馈`, `提交反馈`, `feedback center`, `帮助中心` or equivalent product feedback-entry contract.

Local non-canonical UX documents elsewhere in the working machine do contain `意见反馈/提交反馈`, but they are not present on canonical `origin/main` and are therefore explicitly excluded from second-consumer evidence.

### 1.4 Other candidate consumers checked
- Nearvia current canonical/worked PoC tree has no production user feedback/help entry; generic `helper/support` hits are platform/PoC terminology.
- StarSprout canonical `origin/dev = 1cc4893b7e6f7c12eeadbccff2cda10423b9ace5` has no user feedback/help-center product entry; `feedback` hits are gameplay/reward feedback semantics.

These products cannot be relabeled as second consumers for this ACR.

## 2. Platform-vs-Product gate

### Q1. What exact capability/change is requested?
A new generic Mobile Platform operation that, for the current trusted App installation, creates/resolves a short-lived Feedback entry/session and returns only a bounded **relative first-party path**.

Target semantics from reviewed SDK surface:

```text
SDK NebulaFeedback.entry()
  -> Platform trusted Feedback entry/session
  -> disabled/unconfigured OR relative first-party path
```

Provider routing (TXC China / future Native Global) remains server-side and is not part of the App request.

### Q2. Platform or Product capability, and why?
The proposed semantics are **Platform-shaped**: App identity, installation trust, environment and provider routing are product-neutral and meaningful without the name NFC Writer.

However Platform-shaped semantics alone do not satisfy promotion policy; the second-consumer gate is separately mandatory.

### Q3. Which second consumer can use the same semantics without product translation?
**Not mechanically verified yet.**

FlyPost is a credible candidate because canonical FlyPostAPI already owns a real feedback domain. But the current canonical FlyPost App does not establish that it requires the same entry/session contract. A storage/Admin feedback domain does not prove an App-side need for this exact Mobile entry/session lifecycle.

Therefore policy §4 is not satisfied at this time.

### Q4. Does the API make sense if the triggering product name is removed?
Yes. `create feedback entry for current trusted App installation` is product-neutral.

This passes the name-erasure test but does not override Q3.

### Q5. Why can this not be solved in the App Adapter?
For NFC Writer alone, it **can** currently be solved product-specifically by keeping/directly opening the existing TXC experience from an App adapter.

What the App Adapter cannot safely own is the reviewed target architecture's trusted server session, provider routing, server-side TXC credentials/login-state generation and later provider replacement without App release.

Because the only verified consumer is NFC Writer, adapter-first policy requires keeping this option available rather than changing Platform now.

### Q6. Why can this not be solved by SDK-internal implementation without Platform contract change?
The SDK has no server secret and cannot mint a server-authoritative short-lived session by itself. It also must not expose installation tokens/IDs/provider secrets in a URL.

A trusted one-time/replay-bounded server session therefore requires server contract support.

This proves a real technical gap **if** Platform promotion is justified; it does not satisfy the second-consumer requirement by itself.

### Q7. Which frozen contract is insufficient?
No existing frozen Mobile Platform contract provides generic Feedback entry/session creation.

Existing Bootstrap, Runtime Config, Analytics and Error Reporting contracts must not be overloaded with per-entry one-time session semantics merely to avoid a new endpoint.

The gap is real, but promotion remains gated.

### Q8. Endpoint/field/error/trust/idempotency/quota/lifecycle impact
If eventually approved, this is a real contract change because it adds a new trusted Mobile operation and lifecycle semantics.

A future contract would need to freeze:

```text
request trust:
  InstallationProof / current installation token
success:
  enabled=false OR bounded relative entry path
session:
  short TTL + one-time/equivalent replay bound
  no provider secret / installation ID in clear URL
errors:
  invalid proof / disabled / rate-limited / temporary unavailable
limits:
  response-size and session-creation rate bounds
```

These semantics cannot be smuggled into Runtime Config without changing Runtime Config caching/lifecycle semantics.

### Q9. Compatibility/versioning/rollback plan
If promotion is later approved:

- add a new versioned Feedback contract/endpoint; do not change Bootstrap/Runtime Config behavior;
- old Apps remain on existing provider/product behavior;
- new SDK/App adapter adopts the endpoint optionally;
- server kill switch returns disabled/unconfigured and SDK maps that to `null`;
- rollback disables the entry service without moving existing provider credentials/data;
- no capability entitlement ID is added in V1.

The plan is viable but remains hypothetical until the second-consumer gate passes.

### Q10. Security / abuse-cost / privacy / data-scope impact
Risks include session-minting abuse, replay, URL leakage, provider amplification/cost, third-party metadata exposure, and future Native spam/attachment abuse.

Required future controls include per-installation/IP rate limits, short TTL/replay controls, opaque session identity, no installation/user/provider secret in clear query parameters, server-only provider credentials, minimum metadata mapping, and SR-008 before Native submit.

These risks are manageable but do not justify bypassing Q3.

## 3. Options

### Option A — keep Platform unchanged now
NFC Writer remains on product-specific/legacy TXC integration until a second consumer is canonical.

Benefits: obeys adapter-first/second-consumer policy, preserves the low-cost TXC path and adds no new Platform compatibility risk.

Cost: the provider-neutral SDK path remains blocked until the Platform gate later clears.

### Option B — promote Feedback entry/session to Platform now
Benefits: clean provider-neutral App path, server-owned TXC/Native routing and provider replacement without App release.

Blocker: current canonical evidence does not satisfy the mandatory second-consumer rule. **Option B is not authorized in this ACR.**

## 4. Second-consumer evidence disposition

| Candidate | Canonical evidence | Same entry/session semantics verified? | Disposition |
|---|---|---:|---|
| NFC Writer | `origin/dev@4eb7205...` Help route exists but is placeholder | YES, triggering consumer | TRIGGER |
| FlyPost | `FlyPostAPI Dev@a49397a...` real `user_feedback` + Admin processing; `FlyPost main@1d2e728...` lacks App feedback entry evidence | NO | INSUFFICIENT |
| Nearvia | PoC capability code; no production feedback/help requirement | NO | NOT EVIDENCE |
| StarSprout | `dev@1cc4893...`; feedback hits are runtime/reward semantics | NO | NOT EVIDENCE |

FlyPost's `user_feedback` domain is real and should remain a candidate second-consumer lead. It is not sufficient to claim the exact Mobile entry/session lifecycle is already a FlyPost requirement.

## 5. Recommended decision

**DEFERRED_SECOND_CONSUMER_INSUFFICIENT**

Keep Platform API `READ_ONLY` for Feedback.

Do not register a `CONTRACT_CHANGE` Feedback endpoint yet.

Do not implement the frozen `NebulaFeedback` production client yet, because its trusted session contract has no authorized Platform endpoint.

Do not rewrite capability IDs or overload Runtime Config/Bootstrap as a workaround.

## 6. What would unblock promotion

Any one of the following may reopen the ACR with fresh evidence:

1. FlyPost canonical App/product governance explicitly registers a real user Feedback/Help entry that can consume the same provider-neutral first-party entry/session contract; or
2. another canonical Nebula consumer registers the same semantics without product-specific fields; or
3. architecture changes the proposed capability so an existing second consumer can mechanically use exactly the same contract — this itself requires review.

Evidence must be canonical and independently reviewable; creating a fake/stub consumer solely to satisfy policy is forbidden.

## 7. Work that remains independently possible

This ACR blocks only the new Mobile Platform entry/session contract and the SDK production client that depends on it.

It does not authorize other Feedback work. Separately scoped Stories may still be proposed for work that does not require a new Mobile contract, for example:

- read-only TXC provider data ingestion/normalization into Nebula Admin;
- provider configuration inventory/audit;
- FlyPost existing feedback-domain hardening under its own product scope.

Those Stories need their own write authority and must not become a backdoor to the blocked Mobile entry contract.

## 8. Decision

```text
ACR-FEEDBACK-PLATFORM-V1-001
========================================
Decision:
DEFERRED_SECOND_CONSUMER_INSUFFICIENT

Platform API mode after review:
READ_ONLY

Feedback Platform CONTRACT_CHANGE:
NOT AUTHORIZED

Feedback SDK production implementation:
BLOCKED_PENDING_PLATFORM_CONTRACT

NFC Writer App provider-neutral SDK integration:
BLOCKED_PENDING_PLATFORM_CONTRACT

Verified second consumer:
NONE

FlyPost candidate evidence:
REAL FEEDBACK DOMAIN / SAME ENTRY CONTRACT NOT YET VERIFIED
```
