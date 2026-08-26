# AUTH-V2-NEARVIA-IDENTITY-002 — Nearvia Production Host Identity Implementation

- ID：AUTH-V2-NEARVIA-IDENTITY-002
- Owner: Nearvia App Platform Coding Agent
- Reviewer: App Review Agent
- Execution repo：`../Nearvia`
- Execution branch：`auth/v2-nearvia-identity-002`
- Execution remote: `origin`
- Execution worktree: `wt-auth-v2-nearvia-identity-002`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`READ_ONLY`
- Product adapter rule: `ADAPTER_FIRST`
- State write authority: Coordinator only

## Upstream authority
- AUTH-V2-NEARVIA-IDENTITY-001 is DONE / CLOSED_REVIEW_PASS.
- Corrected frozen public identity: Android/iOS `com.lcloudy.nearvia`.
- Current Nearvia host base: `origin/main@54d4d5ea63d763e0a63fe81ff9b4851ac54962d4`.
- Consumer/Auth currently lives in `poc/watch_capability/app`; it is the production-host candidate for this Story.
- `poc/assist_capability/app` remains a technical PoC and must keep its PoC identity here.

## Android production host
- `namespace` and `applicationId` become `com.lcloudy.nearvia`.
- Move Watch Kotlin production/test package declarations and paths to `com.lcloudy.nearvia`. If correcting an already-migrated wrong host, move from `com.nearvia.app` to `com.lcloudy.nearvia`.
- Launcher label becomes `Nearvia`.
- Release must no longer use debug signing.
- Release signing material stays outside Git; release tasks without required external signing inputs must fail closed instead of falling back to debug or silently producing the production release path.

## iOS production host
- Runner bundle ID becomes `com.lcloudy.nearvia` for all build configurations.
- RunnerTests becomes `com.lcloudy.nearvia.RunnerTests`.
- Native display/bundle name becomes `Nearvia`.
- Apple Team for the production identity is `V4U9V436CM`.
- Do not add Sign in with Apple entitlement, provider client IDs or provider secrets in this Story.

## ASSIST PoC isolation
- `poc/assist_capability/app/**` is read-only.
- Frozen future `com.lcloudy.nearvia.broadcast` and `group.com.lcloudy.nearvia` are reserved for later ASSIST capability integration into the one production host; do not turn the separate ASSIST PoC into a second `com.nearvia.app` binary here.

## Authorized write set
- `poc/watch_capability/app/android/app/build.gradle.kts`
- `poc/watch_capability/app/android/app/src/main/AndroidManifest.xml`
- `poc/watch_capability/app/android/app/src/main/kotlin/com/nearvia/**`
- `poc/watch_capability/app/android/app/src/test/kotlin/com/nearvia/**`
- `poc/watch_capability/app/ios/Runner.xcodeproj/project.pbxproj`
- `poc/watch_capability/app/ios/Runner/Info.plist`
- `poc/watch_capability/app/test/platform/nebula/nearvia_nebula_boundary_guard_test.dart`
- `docs/evidence/AUTH-V2-NEARVIA-IDENTITY-002/**`

## Forbidden
- any `poc/assist_capability/app/**` mutation;
- AuthPort/Auth UI/provider logic mutation;
- Apple/Google provider configuration;
- Backend or Nebula SDK mutation;
- Push/SMS mutation;
- changing the corrected frozen ID away from `com.lcloudy.nearvia`;
- any credential/private key/keystore material in Git.

## Verification
- scope guard including renames/untracked files;
- zero remaining old Watch Android Java/Kotlin package references after migration;
- Android host-security unit test PASS;
- Android debug build PASS;
- negative release-signing test proves missing external signing inputs fail closed;
- iOS debug no-codesign build PASS and resolves Runner bundle as `com.lcloudy.nearvia`;
- Flutter analyze + focused/full tests PASS;
- ASSIST PoC tree byte-identical to base;
- exact-head independent App review before merge.

## Exit
READY_FOR_REVIEW only. No self-review, self-merge or provider authority inherited.
