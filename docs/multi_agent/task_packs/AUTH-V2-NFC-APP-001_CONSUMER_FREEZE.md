# AUTH-V2-NFC-APP-001 — NFC Writer Auth V2 Consumer Freeze

- ID：AUTH-V2-NFC-APP-001
- Owner: NFC Writer Auth V2 Consumer Architecture Agent
- Agent: B
- Reviewer: App Architecture Review Agent
- Execution repo：`../flutter NFC Writer`
- Execution branch：`auth/v2-nfc-app-001-freeze`
- Execution remote：`origin`
- Execution worktree：`wt-auth-v2-nfc-app-001-freeze`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`READ_ONLY`
- State write authority: Coordinator only.

## Required upstream

- `AUTH-V2-BE-001 = DONE / CLOSED_REVIEW_PASS`
- `AUTH-V2-SDK-002 = DONE / CLOSED_REVIEW_PASS`
- `NEBULA-SDK-RELEASE-002 = DONE / CLOSED_RELEASE_PASS`
- immutable SDK target: `v0.1.0-rc2@ac96fb5f428cc37293bc5a63e23c90fe40ff8af2`

## Fresh consumer baseline

At registration time NFC Writer canonical is `origin/dev@d40f87ff407539114f1ecf334685c0b4d6913045` and still consumes `v0.1.0-rc1@64df49af6ff7554da94d5fa2ebaef27bdba35465` through its existing embedded-bare-git distribution.

The implementation Agent must refresh `origin/dev` before producing the freeze. If canonical moves, the report must record the new exact and reconcile the scope; it may not silently use this registration-time SHA as implementation evidence.

## Goal

Freeze the App-owned migration plan from the existing NFC Writer Nebula integration to Auth V2 / RC2 without creating a second authentication authority or changing Nebula Backend/SDK contracts.

The freeze must mechanically inspect and reuse the existing `lib/platform/nebula/**` Adapter boundary, `lib/app/services/auth_service.dart`, existing auth/login UI before proposing any new page, and the embedded SDK distribution.

## Required product semantics

- EMAIL/password and typed email code/register/reset flows use canonical Auth V2 APIs.
- Apple and Google remain typed provider login candidates through App-owned acquisition bridges; provider secrets never enter the client repo.
- PHONE/SMS compatibility remains available and must not be deleted.
- WeChat/QQ production integration is excluded and remains governed by `AUTH-V2-CN-PROVIDER-ARCH-001`.
- Existing NFC Writer account identity must not be silently duplicated, merged, or remapped.

## Authorized mutation

Architecture/evidence only in NFC Writer: `docs/reports/AUTH-V2-NFC-APP-001-ARCHITECTURE-FREEZE.md`. No production/App dependency/native/UI mutation is authorized by this freeze.

## Required output

Freeze the exact current consumer baseline and SDK pin/tree; RC2 target identity and repin mechanics; existing App Auth/Adapter/UI surfaces to reuse; minimum implementation write-set split into immutable RC2 repin, generic Auth V2 App adaptation, and Apple/Google provider acquisition/config if separately required; PHONE/SMS non-regression; migration/rollback and identity constraints; required tests/guards; and explicit WeChat/QQ exclusion.

## Exit

Independent architecture review must approve the exact freeze before Coordinator registers any NFC Writer Auth V2 production implementation Story. Implementation may not begin from this registration alone.
