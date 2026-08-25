# AUTH-V2-NEARVIA-IDENTITY-001 — Nearvia Production App Identity + Signing Freeze

- ID：AUTH-V2-NEARVIA-IDENTITY-001
- Owner: Nearvia App Identity Architecture Agent
- Reviewer: App Architecture Review Agent
- Execution repo：`../Nearvia`
- Execution branch：`auth/v2-nearvia-identity-001-freeze`
- Execution remote: `origin`
- Execution worktree: `wt-auth-v2-nearvia-identity-001-freeze`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`READ_ONLY`
- Product adapter rule: `ADAPTER_FIRST`
- State write authority: Coordinator only

## Purpose
Freeze the final public application identity and release-signing contract required by Nearvia overseas V1 before Apple/Google provider registration or App identity mutation.

This is docs-only architecture work. It does not authorize Gradle/Xcode/native mutation, provider-console setup, Backend provider config, or signing secret/private-key material.

## Required upstream
- AUTH-V2-NEARVIA-APP-001 = DONE
- AUTH-V2-NEARVIA-UI-001 = DONE
- AUTH-V2-NEARVIA-OAUTH-001 preflight registration canonical
- Nearvia PR #11 / Review #502 evidence merged as `d5c0c84ad139c4d39a5b3b06155186524e43ec14`

## Current reviewed evidence
- Android is still `com.nearvia.poc.watch_capability_poc`.
- Android release still uses debug signing.
- iOS is still `com.nearvia.poc.watchCapabilityPoc`.
- No canonical tracked Sign in with Apple entitlement exists.
- No production Nearvia App identity is frozen.
- FlyPostAPI has no Nearvia per-App OAuth binding in checked-in environment templates.

No current `*.poc.*` identity may be promoted as production by assumption.

## Freeze decisions required
1. Final Android production `applicationId` and namespace migration target.
2. Final iOS production `PRODUCT_BUNDLE_IDENTIFIER`.
3. Whether WATCH/ASSIST remain one public consumer App identity or require explicitly named companions/extensions.
4. Apple Developer Team ownership for production signing, without key material in Git.
5. Android release-signing custody and public SHA-1/SHA-256 fingerprint evidence contract.
6. Apple Sign in with Apple App ID/capability and public client-identifier strategy.
7. Naming rules for iOS extensions, app groups and associated domains affected by the final identity.
8. Migration impact from current PoC package/bundle IDs, including whether installed PoC data requires migration.
9. Cross-product isolation: never reuse or guess NFC Writer AppKey, numeric App ID, OAuth client, signing identity, package or bundle ID.
10. Downstream split: identity implementation, provider registration/acquisition and Backend deployment binding remain separate Stories.

## Authorized write set
- `docs/AUTH_V2_PRODUCTION_APP_IDENTITY.md`
- `docs/evidence/AUTH-V2-NEARVIA-IDENTITY-001/**`

No `poc/**`, native, Backend, SDK, provider-console or secret mutation is authorized.

## Acceptance gates
- Fresh Nearvia `origin/main` exact recorded.
- Current PoC IDs/debug signing referenced from canonical tracked source.
- Final IDs are non-PoC, Nearvia-owned and internally consistent.
- Android signing custody and public fingerprint evidence contract defined without key material.
- Apple team/App ID/capability ownership defined without private key material.
- No duplicate public App identity for WATCH vs ASSIST without explicit reviewed product decision.
- OAuth-001 remains blocked after this freeze until provider registration and Backend binding evidence exist.
- Exact-head independent architecture review required before merge.

## Exit
`READY_FOR_REVIEW` with docs-only exact candidate. A separate Coordinator publication is required before any App identity implementation or provider acquisition mutation.
