# AUTH-V2-CN-PROVIDER-ARCH-001 — WeChat / QQ Legacy Auth Migration Review

- Story: `AUTH-V2-CN-PROVIDER-ARCH-001`
- Mode: Architecture/ACR only; Platform API `READ_ONLY`; SDK public API `READ_ONLY`.
- Upstream: `AUTH-V2-SDK-002 = DONE / CLOSED_REVIEW_PASS`.
- Trigger: NFC Writer legacy has real WeChat + QQ login; current Flutter login entries are mock.

## Goal

Put WECHAT/QQ into the governed Auth V2 roadmap without pretending the current APPLE/GOOGLE-only contract already supports Tencent providers. Produce an ACR and a non-production migration contract candidate only.

## Starting facts to verify mechanically

1. Legacy NFC Writer uses WeChat OpenSDK `SendAuth.Req` and receives a temporary authorization code. Its old client also performs provider token exchange itself; that client-side secret/exchange pattern is forbidden in the migrated design.
2. Legacy QQ uses Tencent SDK and receives provider credential/openid/profile client-side before calling the old login endpoint.
3. Current Flutter NFC Writer lists WECHAT/QQ but returns mock identities/tokens.
4. Canonical Auth V2 accepts exactly APPLE/GOOGLE in Backend verifier/config/handler and SDK `NebulaOAuthProvider`.
5. Backend persistence is provider-neutral; do not create a second account/session stack.

## Required decisions

### Provider proof
- WECHAT candidate: mobile OpenSDK authorization code; Backend performs exchange with server-held provider secret.
- QQ must not be blindly mapped to existing `oauth_code`. Verify current Tencent mobile protocol and freeze one typed proof. Candidate direction: Tencent SDK credential -> Backend QQ OpenAPI verification -> server-verified App ID + subject.
- Final ACR must cite current provider protocol evidence; legacy code alone is not contract authority.

### Verified identity
- Client-supplied openid/unionid/nickname/avatar/gender is never authoritative.
- Backend returns a normalized verified provider identity only after provider-side verification and App-scoped config validation.
- Decide provider subject namespace and the role of unionid. Do not silently cross-link accounts across Apps/providers merely because a union identifier exists.

### Legacy account compatibility
- Freeze how old NFC Writer WECHAT/QQ identities map to Nebula identities without duplicate users.
- Ambiguous/colliding legacy identities fail closed; no automatic merge by email/name/profile.
- PHONE/EMAIL/APPLE/GOOGLE behavior remains unchanged.

### Security/privacy/replay
- No provider secret in App/SDK. The exposed legacy WeChat secret must be rotated outside this docs-only Story before production cutover.
- Codes/tokens/secrets must not enter logs, analytics, Error Reporting, push payloads, or persistent client stores.
- Freeze single-use/replay and retry rules for both providers; no automatic replay after ambiguous exchange/introspection.
- Provider raw errors remain server-side; client receives low-cardinality Auth errors.

### Compatibility/rollback
- Extension is additive and App-gated.
- Rollback can disable WECHAT/QQ without invalidating existing PHONE/EMAIL/APPLE/GOOGLE sessions.

### Second-consumer gate
A Platform `CONTRACT_CHANGE` requires a second distinct canonical consumer. Native and Flutter NFC Writer are one product and do not count twice. Local/unmerged product drafts do not count. If no second canonical consumer exists, the ACR verdict must be `DEFERRED_SECOND_CONSUMER_INSUFFICIENT`; no Backend/SDK/App provider implementation may be registered.

## Exact output scope

Only:
- `docs/multi_agent/reports/ACR-MOBILE-AUTH-V2-CN-PROVIDER-001.md`
- `docs/multi_agent/contracts/MOBILE_AUTH_V2_CN_PROVIDER_MIGRATION_CANDIDATE.md`

No Task Board write by Architecture Agent. No `lib/**`, Backend, schema, App, provider SDK/config/credential, release or production mutation.

## Verification

Task Source Guard, Cross Repo Guard, Platform API Guard, API surface, Nebula Governance, Secret Scan and `git diff --check` must pass. Docs must not reproduce any real secret/token.

## Exit

Independent Architecture Review: `APPROVED_FOR_CONTRACT_CHANGE` only if every gate including second-consumer evidence is closed; otherwise `DEFERRED_SECOND_CONSUMER_INSUFFICIENT` or `REQUEST_CORRECTIVE`, with production still blocked.
