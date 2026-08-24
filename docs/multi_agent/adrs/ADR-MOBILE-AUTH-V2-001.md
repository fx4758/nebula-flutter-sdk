# ADR-MOBILE-AUTH-V2-001 — Email-First Multi-Provider Mobile Authentication

- Status: ACCEPTED CONTRACT MIRROR
- Decision date: 2026-08-24
- Contract: `../contracts/MOBILE_AUTH_V2.md`
- ACR: `../reports/ACR-MOBILE-AUTH-V2-001.md`
- Accepted exact contract candidate: `ebc207b2587495acc995036e432adc01e393b7b4`
- Independent review: Forgejo Review #372 / `reviewer-agent` / APPROVED / official=true

## Context
The existing mobile auth/session platform has a real PHONE + SMS-code path and installation-bound session trust. OAuth is modeled but the Backend placeholder that treats provider code as identity is intentionally disabled. Nearvia needs EMAIL/password as its primary presentation, Apple and Google as third-party methods, and PHONE/SMS retained as an optional method. NFC Writer already consumes the same shared mobile auth/provider/session platform and must not be broken by the additive V2 contract.

## Decision
Adopt `Mobile Auth V2` as the product-neutral Platform contract.

The Platform supports:
- `EMAIL_PASSWORD` as a first-class credential path;
- `PHONE_CODE` unchanged and not deprecated;
- `APPLE` and `GOOGLE` only through real server-side provider verification;
- existing installation bootstrap/proof, access/refresh session binding, refresh rotation/reuse revocation and logout semantics unchanged.

Apps own presentation order. Nearvia may show EMAIL first and PHONE under other methods; Platform/SDK do not encode that product UI priority.

## Compatibility
Existing mobile PHONE login remains exactly `provider=PHONE + phone + code`. Existing PHONE code-send, first-user creation and session semantics remain valid. No EMAIL prerequisite, identity rewrite, forced migration, or automatic PHONE-to-EMAIL conversion is allowed.

Existing sessions remain valid merely because Auth V2 ships. EMAIL/OAuth may be App-gated during rollout while PHONE/refresh/logout remain available.

## Security decisions
The normative details live only in `MOBILE_AUTH_V2.md`, including:
- deterministic canonical EMAIL identity and authoritative DB uniqueness;
- provider UID storage width/collation migration with no truncation/auto-merge;
- versioned Argon2id password policy;
- production real email-code delivery; sandbox delivery is non-production evidence only;
- authoritative InstallationProof `app_id` selects OAuth provider client/audience/config;
- provider signature/trust-chain, issuer, audience/client, expiry and subject verification;
- no silent account linking by matching provider email;
- password reset invalidates every pre-reset user session authority before success.

This ADR does not redefine those values and cannot override the Contract.

## Alternatives rejected
1. Product-local Nearvia auth authority: rejected because it duplicates identity/session trust and creates two account authorities.
2. Remove/deprecate PHONE when EMAIL ships: rejected for backward compatibility and product choice.
3. Keep OAuth placeholder: rejected because client code cannot be treated as provider identity.
4. Auto-link identities by matching email: rejected because provider email equality is not sufficient account-ownership proof.

## Rollback
Before Backend implementation, rollback is a reviewed contract supersession only. After implementation, EMAIL/OAuth may be disabled per App while preserving PHONE and existing session endpoints. Rollback must not migrate or rewrite existing PHONE identities or silently merge accounts.

## Consequences / sequencing
Implementation is split by repository and authority:
1. Backend Auth V2 implements the frozen server contract.
2. After Backend canonical close, a separate SDK Auth V2 Story freezes/implements typed public APIs.
3. After SDK canonical close, Nearvia integrates only through its App-owned adapter/UI.

No later Story inherits mutation authority across repositories automatically.
