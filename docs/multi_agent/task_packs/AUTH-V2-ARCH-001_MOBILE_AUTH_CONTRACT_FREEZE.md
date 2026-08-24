# AUTH-V2-ARCH-001 — Mobile Auth V2 Contract Freeze

## Story
- ID：AUTH-V2-ARCH-001
- Owner Role: Auth Architecture Agent
- Reviewer: Architecture Review Agent
- Depends: `NEBULA-SDK-RELEASE-001`

## Execution Boundary
- Execution repo：`.`
- Execution branch：`auth/v2-arch-001-freeze`
- Execution remote：`hub`
- Governance state: architecture/contract only
- Platform API mode：`CONTRACT_CHANGE`
- SDK public API mode：`READ_ONLY`

## Goal
Freeze one product-neutral Mobile Auth V2 contract that adds email/password as a supported primary account method without deleting phone/SMS login, and defines real Apple/Google OAuth boundaries while preserving current installation-bound session semantics.

## Facts / Context
- SDK canonical: `450dbd2864c1fb8a9fd9ef4bffca327552f132fe`.
- Backend canonical Dev: `c9220eaa725a797a40a94c6b1e3970a69b2931f5`.
- PHONE/SMS target login exists and is real behavior.
- OAuth placeholder is disabled and not production-ready.
- Backend generic account model already lists EMAIL/APPLE/GOOGLE/PHONE providers.
- Nearvia requires email-first + Apple/Google, with phone/SMS retained as a selectable method.
- NFC Writer already presents PHONE/APPLE/GOOGLE login methods.

## Required Outputs
- `docs/multi_agent/contracts/MOBILE_AUTH_V2.md`
- `docs/multi_agent/reports/ACR-MOBILE-AUTH-V2-001.md`

## Mandatory Decisions
1. EMAIL is a supported primary mobile auth provider.
2. PHONE/SMS remains supported and wire-compatible; no deprecation/removal.
3. APPLE and GOOGLE are the allowed V2 OAuth providers.
4. OAuth code is exchanged/verified by server adapters; placeholder code-as-UID is forbidden.
5. Email registration, verification and password reset are distinct from login.
6. Password reset revokes existing session authority.
7. Existing bootstrap, InstallationProof, refresh rotation and logout semantics remain unchanged.
8. Dedicated password credential persistence is private server state.
9. No auto-link solely by matching provider email.
10. Anti-enumeration and independent email/SMS/provider rate limits are frozen.
11. Apps choose provider UI order; Platform does not encode default UI.
12. Push registration is downstream and outside Auth V2.
13. EMAIL identity canonicalization is deterministic and database-enforced; 254-byte canonical keys require provider UID storage migration with no truncation or collation-dependent identity.
14. Production email verification/reset requires a real email sender; sandbox acceptance is non-production evidence only.
15. OAuth trust is App-scoped from authoritative InstallationProof app_id and validates provider issuer/audience/signature/expiry/subject; provider-required PKCE/nonce cannot be silently omitted.
16. Password credentials use the frozen versioned Argon2id policy, random per-credential salt and rehash-on-policy-upgrade semantics.

## Allowed Paths
- `docs/multi_agent/contracts/MOBILE_AUTH_V2.md`
- `docs/multi_agent/reports/ACR-MOBILE-AUTH-V2-001.md`
- this task pack

## Forbidden
- `lib/**`
- Backend production code/schema
- App production code
- provider credentials
- Task Board mutation by execution Agent
- removal or semantic rewrite of PHONE/SMS
- enabling placeholder OAuth

## Verification
- `git diff --check`
- source/contract review proving PHONE compatibility
- independent Architecture Review on exact candidate
- production/public API diff = 0

## Exit
After independent ACCEPT, Coordinator may register separate Backend and SDK implementation Stories. No implementation authority is inherited automatically.
