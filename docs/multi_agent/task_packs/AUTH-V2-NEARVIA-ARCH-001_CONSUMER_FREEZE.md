# AUTH-V2-NEARVIA-ARCH-001 — Nearvia Auth V2 Consumer Architecture Freeze

- ID：AUTH-V2-NEARVIA-ARCH-001
- Owner: Nearvia Auth V2 Consumer Architecture Agent
- Agent: A
- Reviewer: App Architecture Review Agent
- Execution repo：`../Nearvia`
- Execution branch：`auth/v2-nearvia-arch-001-freeze`
- Execution remote：`origin`
- Execution worktree：`wt-auth-v2-nearvia-arch-001-freeze`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`READ_ONLY`
- State write authority: Coordinator only.

## Required upstream

- `AUTH-V2-BE-001 = DONE / CLOSED_REVIEW_PASS`
- `AUTH-V2-SDK-002 = DONE / CLOSED_REVIEW_PASS`
- `NEBULA-SDK-RELEASE-002 = DONE / CLOSED_RELEASE_PASS`
- immutable SDK target: `v0.1.0-rc2@ac96fb5f428cc37293bc5a63e23c90fe40ff8af2`

## Fresh consumer baseline

At registration time Nearvia canonical is `origin/main@3506669241e050c872b5b793a1de29667bf0da97`. Nearvia remains explicitly outside complete V1 production implementation and its current repository rules prohibit production account/family implementation. This Story does not override that product gate.

## Goal

Freeze a first-time Nearvia consumer boundary for stable Nebula Auth V2 capabilities without modifying Nebula Backend/SDK or authorizing production account/login implementation.

## Required product semantics

- EMAIL/password is the primary login path.
- Apple and Google are third-party login options.
- PHONE/SMS remains an optional login path and is not deleted.
- Nebula is consumed through an App-owned adapter/composition root.
- Provider credentials/secrets remain outside source control and outside the SDK.
- Product-specific ASSIST/WATCH/RTC/trusted-relationship/session authorization remains Nearvia-owned and separate from account authentication.

WeChat/QQ is not a required Nearvia overseas-V1 provider semantic in this Story. This Story must not be cited as satisfying `AUTH-V2-CN-PROVIDER-ARCH-001`'s second-distinct-consumer gate for the same WeChat/QQ provider-login semantics.

## Authorized mutation

Architecture/evidence only in Nearvia: `docs/AUTH_V2_CONSUMER_ARCHITECTURE.md` and `docs/evidence/AUTH-V2-NEARVIA-ARCH-001/**`.

Forbidden: production Flutter account/login code; production account/family backend model; SDK/Backend mutation; provider secret or production credential material; Apple/Google/PHONE native production configuration; WeChat/QQ production integration; RTC/session model migration into Nebula.

## Required output

Freeze exact Nearvia canonical baseline; App-owned Nebula adapter/composition boundary; EMAIL-first + Apple/Google + optional SMS flows; separation of account identity from trusted relationships/media-session authorization; provider acquisition/config prerequisites and secret custody; localization/overflow implications without production UI coding; production authorization prerequisites; and an explicit finding that this overseas consumer does not close the WeChat/QQ second-consumer gate.

## Exit

Independent architecture review may close this Story as reviewed consumer architecture. Production implementation remains blocked until a separate Nearvia production authorization/implementation Story is explicitly registered by Coordinator.
