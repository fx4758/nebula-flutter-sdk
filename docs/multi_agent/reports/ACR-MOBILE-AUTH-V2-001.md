# ACR-MOBILE-AUTH-V2-001 — Email-First Multi-Provider Mobile Authentication

## Metadata
- ACR ID: `ACR-MOBILE-AUTH-V2-001`
- Raised by: Architecture Coordinator
- Related Story: `AUTH-V2-ARCH-001`
- Triggering Product: Nearvia
- Date: 2026-08-24
- Severity: BLOCKING
- Requested Platform API mode: CONTRACT_CHANGE

## Observed Fact

Fresh canonical evidence:
- SDK `hub/main = 450dbd2864c1fb8a9fd9ef4bffca327552f132fe`.
- Backend FlyPostAPI `Dev = c9220eaa725a797a40a94c6b1e3970a69b2931f5`.
- SDK `NebulaLoginProvider` currently exposes only `phone | oauth`.
- Backend target `/api/v1/mobile/auth/login` currently accepts only PHONE.
- Backend OAuth code path is an intentionally disabled placeholder; old placeholder semantics treated provider code as provider UID and must not ship.
- Backend `UserAccount` already documents generic providers including PHONE/APPLE/GOOGLE/EMAIL.
- NFC Writer already presents PHONE/APPLE/GOOGLE login methods, so those methods are cross-App capabilities.
- Nearvia requires EMAIL as default presentation while retaining PHONE/SMS as a selectable method and adding real Apple/Google login.

## Platform vs Product Gate

1. Exact change: add EMAIL password registration/login/recovery and real APPLE/GOOGLE OAuth while preserving PHONE/SMS compatibility under current mobile installation/session trust.
2. Platform capability: credential verification, account identity, session issuance, recovery and provider exchange cannot be product-local.
3. Second consumer: NFC Writer already consumes the same PHONE/APPLE/GOOGLE provider semantics; EMAIL is already modeled as a generic Backend account provider rather than a Nearvia-specific field.
4. Remove product name: EMAIL/PHONE/APPLE/GOOGLE account authentication remains a valid multi-App platform capability.
5. App Adapter cannot solve it: Apps cannot securely own password hashes, verification-code authority, provider exchange, account uniqueness, refresh-family revocation or anti-enumeration.
6. SDK-only cannot solve it: authoritative identity lookup, password KDF, OAuth verification, email code authority and session issuance are Backend responsibilities.
7. Frozen gap: current Mobile Auth contract only freezes PHONE plus disabled OAuth direction; email registration/password/recovery is absent.
8. Impact: additive auth endpoints/request variants, EMAIL credential persistence/migration, later SDK typed API expansion, safe errors; installation proof/refresh/logout remain unchanged.
9. Compatibility/rollback: PHONE body/endpoints remain valid; existing sessions remain valid; EMAIL/OAuth can be App-gated and rolled back without disabling PHONE.
10. Security/privacy/cost: password KDF, anti-enumeration, independent email/SMS budgets, provider allowlist, server-side provider exchange, no raw credential logging/persistence, reset revokes sessions.

## Options

### Option A — Keep Platform unchanged
Nearvia implements a second email/password/OAuth authority outside Nebula.

Rejected: duplicates identity/session trust and creates two user-account authorities.

### Option B — Platform Auth V2
Extend canonical Mobile Auth with EMAIL, preserve PHONE, and replace OAuth placeholder semantics with real provider adapters.

Benefit: one account/session authority and one shared SDK contract.
Cost: contract version, Backend migration/provider adapters, SDK public surface update.
Compatibility: additive for PHONE; old sessions remain valid.

## Recommended Decision

**Option B — Platform Auth V2 contract.** Apps consume SDK abstractions and do not hand-author auth HTTP calls.

## Authorization Evidence
- Existing contract: `docs/08_MOBILE_BOOTSTRAP_SESSION_CONTRACT.md`.
- Proposed contract: `docs/multi_agent/contracts/MOBILE_AUTH_V2.md`.
- Independent Architecture Reviewer: pending exact-candidate review.
- Cross-product evidence: Backend generic provider model + NFC Writer PHONE/APPLE/GOOGLE presentation + Nearvia EMAIL-first requirement.

## Scope Impact
- Platform API: CHANGE REQUIRED.
- SDK public API: CHANGE REQUIRED in later Story.
- Database/migration: EMAIL password credential persistence + provider UID width/collation migration + authoritative `user_identity(provider,provider_uid)` uniqueness required; duplicate/collision preflight must fail closed.
- App integration: adapter-only follow-up.
- Security/cost: email/SMS/OAuth budgets bounded independently; production email delivery and per-App OAuth provider credentials are external-resource prerequisites and may not be satisfied by sandbox adapters.
- Dependency: Contract -> Backend -> SDK -> consumer Apps.

## Temporary Workaround
None. A consumer must not ship a second ad-hoc account authority.

## Decision
- Candidate: APPROVE Option B subject to independent architecture review.
- Approved mode after review: CONTRACT_CHANGE.
- Contract version: Mobile Auth V2.
- Follow-up Stories: Backend Auth V2, SDK Auth V2, consumer App adapters.
