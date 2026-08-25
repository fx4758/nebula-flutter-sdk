# AUTH-V2-NEARVIA-APP-001 — Nearvia Nebula Auth V2 Production Integration

- ID: `AUTH-V2-NEARVIA-APP-001`
- Owner: Nearvia Auth V2 Implementation Agent
- Reviewer: App Review Agent
- Execution repo: `../Nearvia`
- Execution branch: `auth/v2-nearvia-app-001-implementation`
- Execution remote: `origin`
- Execution worktree: `wt-auth-v2-nearvia-app-001`
- Platform API mode: `READ_ONLY`
- SDK public API mode: `READ_ONLY`
- Product adapter rule: `ADAPTER_FIRST`
- State write authority: Coordinator only

## Required upstream

- `AUTH-V2-NEARVIA-ARCH-001 = DONE / CLOSED_REVIEW_PASS`
- `AUTH-V2-BE-001 = DONE / CLOSED_REVIEW_PASS`
- `AUTH-V2-SDK-002 = DONE / CLOSED_REVIEW_PASS`
- `NEBULA-SDK-RELEASE-002 = DONE / CLOSED_RELEASE_PASS`
- immutable SDK target: `v0.1.0-rc2@ac96fb5f428cc37293bc5a63e23c90fe40ff8af2`
- Nearvia architecture canonical: `main@7d947059aea27f2cd3794b11a13797908853cae8`
- architecture exact review: `root/Nearvia#7` exact `dd609c93ce3d00695d77f9dbe74d157fc80c1e21`, Review `#439 APPROVED / reviewer-agent / official=true / stale=false`

## Fresh-base rule

Execution MUST fresh-fetch Nearvia `origin/main` and record the exact SHA before mutation. Registration-time canonical is `7d947059aea27f2cd3794b11a13797908853cae8`.

The implementation may not treat the separate Consumer/Nearby feature branch as canonical. The existing Consumer login UI on `implementation/consumer-r10-coding-20260822@5ada1104c510e86634286c19e9d9df3fb4dedfd1` is product-intent/reference evidence only until that UI is independently accepted into the implementation baseline. Do not create duplicate login/register/password pages to work around that branch boundary.

## Current product scope

Nearvia current delivery is exactly:

1. EMAIL + password as the primary account login;
2. EMAIL registration + verification code;
3. EMAIL password reset;
4. Apple third-party login;
5. Google third-party login;
6. session restore / refresh / sign-out;
7. App-owned OS secure installation identity and token storage.

PHONE/SMS is **DEFERRED for Nearvia**. No SMS UI, PHONE adapter path, SMS provider configuration, or direct `/api/v1/mobile/auth/code/send` workaround is authorized. Nebula platform PHONE support remains untouched for other consumers/future use.

Push / `PushPort` / `IncomingRequestPort`, APNs, PushKit, CallKit and FCM are separate Stories and are not inherited by this Auth Story.

## Required architecture

```text
Nearvia product/UI
  -> NearviaAuthPort (App-owned types only)
  -> NearviaNebulaAuthAdapter
  -> immutable nebula_sdk v0.1.0-rc2
  -> Nebula Platform

Nearvia OS security
  Android Keystore P-256 + secure token vault
  iOS SecKey/Keychain P-256 + Keychain token vault
  -> InstallationKeyPort / RequestProofSigner / SecureTokenStore
```

`package:nebula_sdk` imports must stay behind the Nearvia platform/auth adapter boundary. Consumer pages, WATCH/ASSIST/RTC code and trusted-relationship models must not consume Nebula SDK types directly.

Account authentication does not authorize camera/microphone/screen capture, trusted-family access, WATCH viewing, ASSIST requests, or RTC sessions.

## Authorized App mutation

Primary scope under `poc/watch_capability/app/**`:

```text
pubspec.yaml
pubspec.lock
lib/platform/nebula/**
lib/auth/**
lib/app/**                         # composition/root wiring only
android/app/src/main/**/nebula/**
android/app/src/main/**/MainActivity.kt   # plugin registration only
ios/Runner/NebulaSecurityPlugin.swift
ios/Runner/AppDelegate.swift              # plugin registration only
config/**                          # non-secret runtime profile/schema only
test/auth/**
test/platform/nebula/**
```

Existing account UI may be bound only when its exact source has been reconciled into the implementation baseline. At that point minimal wiring changes to the already-existing Consumer account/login pages and localization resources are allowed. Before creating any page, mechanically confirm no equivalent page already exists.

## SDK pin

The dependency must resolve immutably to `nebula_sdk v0.1.0-rc2@ac96fb5f428cc37293bc5a63e23c90fe40ff8af2`. No sibling-path dependency and no floating branch/tag resolution. The implementation must record the resolved exact in lock/evidence. SDK/Backend mutation is forbidden by this Story.

## Installation bootstrap and secure session

Nearvia must provide production OS-backed host security. Private-key bytes never cross into Dart. Required behavior:

- stable installation ID per installed App identity;
- P-256/ES256 installation key in Android Keystore / iOS Keychain/SecKey;
- token storage scoped by environment + Nearvia App identity;
- key loss / reinstall fails closed into a new installation identity rather than recovering/exporting an old private key;
- installation bootstrap obtains and securely stores the installation token before proof-protected Auth calls;
- refresh token secure-store only; access token memory-only;
- session restore uses SDK session behavior; refresh remains single-flight;
- logout clears the local user scope and performs best-effort remote logout;
- revoked/recoverable states map to App-owned session states without exposing SDK enums to product code.

The previously proven NFC Writer host-security bridge may be used as a reference pattern only. Do not copy NFC Writer product IDs, package IDs, App keys or product semantics.

## EMAIL flows

Use only canonical SDK Auth V2 operations: `NebulaLoginRequest.email(...)`, `sendEmailCode(... register)`, `registerEmail(...)`, `sendEmailCode(... resetPassword)`, and `resetEmailPassword(...)`. No direct HTTP from UI/pages. Passwords/codes/tokens must not enter logs, analytics, crash text or durable plain storage. UI errors must use low-cardinality App-owned meanings and preserve Backend anti-enumeration behavior.

## Apple / Google

Nearvia may add App-owned provider acquisition adapters for Apple and Google only. The client obtains a short-lived authorization code; Nebula Backend remains authoritative for exchange, JWKS/signature/issuer/audience/replay verification and provider subject identity.

Forbidden: provider client secret/private key in source/assets/logs; treating client-supplied email/openid/subject as authoritative; auto-linking provider accounts to EMAIL because emails match; fake provider success or placeholder provider UID mapping; enabling a provider when deployment/client configuration is incomplete. Provider acquisition must fail closed until the Nearvia-specific Apple/Google deployment registration exists.

## Deployment prerequisites

Real end-to-end authentication is not launch-ready until deployment authority provides mechanically verified Nearvia values for: dedicated `product_app.app_key`; API environment/base URL profile; EMAIL SMTP sender + Nearvia App allowlist; Apple client/service/audience configuration; Google client/audience configuration; and server-side provider secrets/keys via external secret custody. No implementation Agent may guess, borrow or reuse NFC Writer values.

## Explicitly forbidden

- Backend mutation;
- Nebula SDK/public API mutation;
- PHONE/SMS integration in Nearvia;
- direct Backend auth HTTP bypass;
- Push/APNs/FCM/PushKit/CallKit implementation;
- Family/Trust/RTC/session authorization migration into Nebula;
- duplicate account authority/database;
- provider secrets or production credentials in Git;
- unrelated Nearby/Routerless/WATCH/ASSIST refactors;
- implementation Agent editing Coordinator Task Board state;
- direct push to Nearvia protected `main`.

## Verification

At minimum before implementation review:

- exact SDK dependency resolution = `ac96fb5f...`;
- adapter-boundary guard: no Nebula imports outside authorized adapter layer;
- Dart tests for App session-state mapping and auth request delegation;
- secure-store namespace and no-secret diagnostics tests;
- Android host-security unit tests for key identity/sign/token behavior;
- iOS host-security focused tests or deterministic bridge contract tests;
- bootstrap restore / login / refresh / logout state tests with fake transport/platform adapters;
- EMAIL login/register/reset delegation and error mapping tests;
- Apple/Google acquisition adapter tests with no real provider secret;
- PHONE/SMS absence guard in current Nearvia auth UI/adapter scope;
- `flutter analyze` and focused/full tests on the governed execution target;
- Android/iOS build on `mac-mini-ci` when native bridge/provider dependencies change;
- exact-head independent App review before merge.

Physical-device login evidence is required once Nearvia deployment/provider configuration exists; tests must not manufacture a production success before that prerequisite is real.

## Exit

Deliver the Nearvia App implementation to `READY_FOR_REVIEW` only. No self-review, no self-merge, no Task Board DONE. Push remains separately unauthorized.
