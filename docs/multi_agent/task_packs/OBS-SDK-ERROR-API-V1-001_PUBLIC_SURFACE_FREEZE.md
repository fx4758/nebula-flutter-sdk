# OBS-SDK-ERROR-API-V1-001 Error Reporting SDK Public Surface Freeze
- ID：OBS-SDK-ERROR-API-V1-001
- Owner：SDK Architect Agent
- Execution repo：`.`
- Execution branch：`obs/sdk-error-api-v1-001-public-surface-freeze`
- Platform API mode：`NONE`
- SDK public API mode：`READ_ONLY`
- Governance state：public-surface proposal/freeze only; no SDK production/public export mutation in this Story.
- Required upstream：`OBS-SDK-ERROR-V1-001 = DONE / REVIEW PASS`.
- Domain authority：`docs/multi_agent/contracts/ERROR_REPORTING_CONTRACT_V1.md`.
- Internal core authority：canonical `lib/src/error_reporting/**` from `OBS-SDK-ERROR-V1-001`.

## Purpose
Freeze the minimum Error Reporting V1 SDK public surface before any serial Owner edits `lib/nebula_sdk.dart`, `lib/src/nebula.dart`, `lib/src/capabilities.dart`, or API snapshots.

The internal core is implementation evidence, not automatically a public contract. This Story decides which minimal types/operations are safe and necessary for App adapters while preventing accidental export of internal storage, sender, budget, retry, provider, or transport machinery.

## Required output
Create exactly one independently reviewable public-surface freeze artifact following repository contract conventions, recommended:

- `docs/multi_agent/contracts/ERROR_REPORTING_SDK_PUBLIC_SURFACE_V1.md`

The freeze must define the smallest App-facing Error Reporting capability boundary and explicitly classify every existing internal Error Reporting type as one of:

- PUBLIC V1;
- INTERNAL ONLY;
- DEFERRED.

## Mandatory decisions
The proposal must mechanically answer:

1. What single public capability/interface does App code consume for explicit caught-error reporting?
2. What input/result types, if any, must be public?
3. Which internal types MUST remain hidden, including store/sender/budget/retry/provider/transport details?
4. Whether `Nebula` facade and/or `capabilities.dart` require a new capability member/interface, and the exact minimal signature if so.
5. Which symbols require barrel export from `lib/nebula_sdk.dart`.
6. How the surface preserves the frozen V1 privacy boundary: no raw logs/breadcrumbs/screenshots/user content/user_id by default.
7. How App adapters can report errors without gaining authority over trusted app/installation/platform identity.
8. How the public API avoids promising native crash/minidump/ANR capture or guaranteed post-termination persistence.
9. How provider selection remains invisible to product code.
10. Compatibility/versioning expectations and product-name erasure proof.

## Surface minimization rules
- Do NOT export `ErrorReportStore`, `ErrorReportSender`, runtime budget policy, retry orchestration, provider adapter types, or `NebulaTransport` details merely because they exist internally.
- Do NOT expose server-authoritative fingerprint/issue-grouping controls to App callers.
- Do NOT expose trusted `app_id`, `installation_id`, or platform as caller-authoritative parameters.
- Do NOT introduce NFC Writer/FlyPost/StarSprout-specific fields or names.
- Prefer one capability entry point over exporting internal orchestration classes.

## Forbidden
- Any mutation under `lib/**`.
- `lib/nebula_sdk.dart` mutation.
- `lib/src/nebula.dart` mutation.
- `lib/src/capabilities.dart` mutation.
- `governance/api_surface.snapshot` or `governance/public_api.txt` mutation.
- Running `tool/api_surface.dart --update`.
- Backend/API/schema/migration mutation.
- App/NFC Writer mutation or repin.
- Provider integration.
- Analytics implementation.
- Task Board/Sprint Board mutation by the execution Agent.

## Verification
- Task Source Guard `OBS-SDK-ERROR-API-V1-001` PASS.
- Cross Repo Guard PASS.
- `git diff --check` PASS.
- Production/public API diff = 0.
- Existing API surface check remains 125 symbols unchanged.
- Freeze artifact is internally consistent with `ERROR_REPORTING_CONTRACT_V1.md` and canonical internal core behavior.
- Independent Architecture/SDK surface review PASS on exact candidate.

## Exit
This Story closes only the public-surface design/freeze. It does NOT authorize actual exports or facade/snapshot mutation. After canonical `DONE / REVIEW PASS`, Coordinator may register a separate SDK Architect/surface Owner implementation Story with explicit `sdk_public_api_mode = CHANGE_APPROVED` and exact authorized serial paths.
