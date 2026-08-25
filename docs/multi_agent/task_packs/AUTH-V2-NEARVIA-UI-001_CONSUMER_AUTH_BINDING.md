# AUTH-V2-NEARVIA-UI-001 — Nearvia Consumer Auth UI Canonicalization + Binding

- ID：AUTH-V2-NEARVIA-UI-001
- Owner: Nearvia Consumer Auth UI Coding Agent
- Reviewer: App Review Agent
- Execution repo：`../Nearvia`
- Execution branch：`auth/v2-nearvia-ui-001`
- Execution remote: `origin`
- Execution worktree: `wt-auth-v2-nearvia-ui-001`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`READ_ONLY`
- Product adapter rule: `ADAPTER_FIRST`
- State write authority: Coordinator only

## Required upstream

- `AUTH-V2-NEARVIA-APP-001 = DONE / CLOSED_REVIEW_PASS`
- Nearvia canonical runtime baseline: `origin/main@aac16afb15092aed2dff0f02e379d67d202df844`
- reviewed Auth Core candidate: `6e4019475ddeb384dd20a3e8078a99b2fec4c18a` / Nearvia PR #8 / Review #462 APPROVED
- immutable SDK: `v0.1.0-rc2@ac96fb5f428cc37293bc5a63e23c90fe40ff8af2`

## Consumer UI source reference

The accepted Consumer R10/057 reference snapshot is:

`origin/implementation/consumer-r10-coding-20260822@5ada1104c510e86634286c19e9d9df3fb4dedfd1`

This historical branch is **reference-only**. It diverged from `3506669241e050c872b5b793a1de29667bf0da97` and contains many unrelated WATCH/Cry/NFC/Routerless/vendor/native experiments. The implementation Agent MUST NOT merge, rebase, or cherry-pick that branch wholesale. Current Nearvia `origin/main` remains runtime authority.

The implementation must mechanically reuse the existing Consumer account surfaces from the reference snapshot, especially `ConsumerLoginPage`, `ConsumerPasswordLoginPage`, `ConsumerRegisterPage` and existing forgot/reset-password affordances. Before creating any page, prove no equivalent accepted Consumer page exists. Duplicate login/register/settings pages are forbidden.

## Goal

Canonicalize only the accepted Consumer UI shell/assets/localization needed to expose account flows on current Nearvia main, then bind those existing account pages to the canonical `NearviaAuthPort` delivered by AUTH-V2-NEARVIA-APP-001.

EMAIL/password is the default Nearvia login. EMAIL registration and password reset use the typed Auth V2 code flows. Apple/Google are third-party options only when the Nearvia-specific provider acquisition/deployment configuration is real; otherwise the existing affordance must fail closed or remain unavailable. PHONE/SMS stays absent.

## Authorized mutation

Primary allowed product UI scope:

- `poc/watch_capability/app/lib/consumer/**`
- `poc/watch_capability/app/assets/consumer/**`
- `poc/watch_capability/app/lib/l10n/**` and localization source/config required by the extracted Consumer UI
- `poc/watch_capability/app/lib/main.dart` only for minimum Consumer shell/root wiring
- `poc/watch_capability/app/lib/app/nearvia_app_services.dart` only for AuthPort access/wiring
- `poc/watch_capability/app/lib/auth/**` only for App-owned UI coordinator/error-state glue; do not redefine the frozen port
- `poc/watch_capability/app/pubspec.yaml` / `pubspec.lock` only for dependencies/assets already required by accepted Consumer UI
- focused tests under `poc/watch_capability/app/test/**`

A file from the reference Consumer snapshot may be copied only if required by the selected Consumer shell/account flow and compatible with current main runtime authority. Remove or adapt references to non-canonical experimental runtime rather than importing unrelated history.

## Explicitly forbidden

- wholesale merge/rebase/cherry-pick of `implementation/consumer-r10-coding-20260822`;
- mutation of `poc/watch_capability/app/lib/src/**` runtime merely to satisfy old Consumer branch assumptions unless a separately authorized corrective Story exists;
- WATCH/Cry/NFC/Routerless transport behavior changes;
- `flutter_webrtc` vendor mutation;
- Android/iOS native WATCH/RTC/Cry/NFC mutation;
- Backend or Nebula SDK mutation;
- PHONE/SMS integration;
- Push/APNs/FCM/PushKit/CallKit;
- Family/Trust/RTC authorization migration into Nebula;
- fake login/register/provider success, delayed mock success, hard-coded user identity/token, or bypassing `NearviaAuthPort`;
- provider client secret/private key in the App;
- duplicate account/login/register/settings pages;
- implementation Agent editing Coordinator Task Board state.

## Required behavior

- EMAIL/password login calls `NearviaAuthPort.loginEmail`.
- Registration uses `sendEmailCode(...register)` then `registerEmail`.
- Forgot/reset uses `sendEmailCode(...resetPassword)` then `resetEmailPassword`.
- UI uses low-cardinality App-owned errors and preserves Backend anti-enumeration semantics.
- Password/code/token/provider authorization code never enters logs, analytics, crash text, or durable plain storage.
- Apple/Google UI delegates to the App-owned acquisition coordinator; missing provider deployment config is a visible fail-closed/unavailable state, never fake success.
- Successful auth returns through the existing `ConsumerAuthIntent.successRoute`; no second navigation authority.
- Auth/bootstrap failure must not block the first frame or anonymous LAN camera acquisition path.
- Existing no-account LAN value path remains usable without login.
- Localizations must cover the Consumer set already accepted in R10: `de, en, es, fr, ja, ko, pt, pt_BR, zh, zh_TW`; check overflow in German/French/Portuguese.

## Verification

Before implementation review, at minimum:

- prove current base is fresh Nearvia `origin/main` and record exact;
- prove UI source reference is exactly `5ada1104...` and no wholesale-history merge occurred;
- diff guard: no unauthorized `lib/src/**`, native WATCH/Cry/NFC, vendor or Backend/SDK mutation;
- existing Consumer account pages reused; no duplicate page regression;
- EMAIL login/register/reset widget/controller tests against fake `NearviaAuthPort`;
- Apple/Google missing-config fail-closed tests;
- PHONE/SMS absence guard;
- anonymous LAN first-frame/no-login regression;
- localization generation + overflow-oriented widget coverage for long locales;
- `flutter analyze` and full/focused Flutter tests on mac-mini-ci;
- Android/iOS build on mac-mini-ci if root/assets/dependencies change;
- exact-head independent App review before merge.

Physical login/provider success evidence remains blocked until dedicated Nearvia deployment values and provider registration exist. Tests must not manufacture production success.

## Exit

Deliver only to `READY_FOR_REVIEW`. No self-review, no self-merge, no Task Board DONE. Deployment configuration, Push and future SMS remain separate authorities.
