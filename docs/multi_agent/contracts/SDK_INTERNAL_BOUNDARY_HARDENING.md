# SDK Internal Boundary Hardening — Architecture Freeze

Status: **FROZEN CANDIDATE / ARCHITECTURE ONLY**
Story: `NEBULA-SDK-BOUNDARY-ARCH-001`
Canonical input: `nebula-flutter-sdk main@b08e977ef764fb876a066375fc63f1eae57714d6`

This contract hardens the existing Nebula multi-App architecture. It does **not** add a product capability, change a Platform endpoint, or authorize production mutation in this Story.

## 1. Decision summary

Nebula remains:

```text
Product UI / Use Case / Repository
  -> App-owned Port / Product model
  -> App Nebula Adapter
  -> generic Nebula SDK
  -> trusted /api/v1/mobile/* Platform API
```

The current product boundary is healthy. The defect being corrected is narrower: shared request-proof primitives are physically declared in `lib/src/auth/proof.dart`, causing generic transport/config/analytics/error-reporting code to depend on the Auth module merely to sign InstallationProof requests.

The frozen correction is:

1. move shared runtime request-proof primitives to `foundation`;
2. move the public recording test double to `testing`;
3. retain `auth/proof.dart` as a compatibility re-export, not as the ownership home;
4. preserve proof wire/algorithm semantics exactly;
5. preserve the public symbol set and total API-surface count;
6. after the physical repair is canonical, add blocking layer-graph and product-erasure governance;
7. add deterministic multi-App isolation regression before claiming the repair closed.

## 2. Fresh baseline evidence

Architecture-owner preflight recorded:

```text
SDK canonical main:
09de9379f38ce6624313814e8c8d4d87c008675c

SDK version:
0.1.0-rc2

API surface:
131 symbols

Runtime dependencies:
{}

Backend authority Dev:
d9ad6c3c0e9186e574081e22d88450d93542fd29

NFC Writer consumer dev:
8df28c5ce0c7b8bf5c41ca0ac6175b3cb36476be

Nearvia canonical main observed during freeze:
aac16afb15092aed2dff0f02e379d67d202df844

Nearvia Auth implementation branch observed during freeze:
6e4019475ddeb384dd20a3e8078a99b2fec4c18a
```

Known product tokens are absent from executable SDK production code. The pure-Dart core still has zero runtime package dependencies.

NFC Writer retains a mechanically guarded `lib/platform/nebula/` Adapter boundary. Nearvia is a separate consumer and must retain its own App-owned Auth/Product models; no Nearvia product model is authorized to move into this SDK.

## 3. Confirmed layering debt

Current shared-proof imports include:

```text
transport       -> auth/proof.dart
config          -> auth/proof.dart
analytics       -> auth/proof.dart
error_reporting -> auth/proof.dart
observability   -> auth/proof.dart
nebula facade   -> auth/proof.dart
```

The first four are the architecture debt. `observability` and `nebula.dart` are composition/facade roots, but they should still consume the new neutral proof owner after relocation.

The following symbols are generic request-proof primitives, not Auth business semantics:

```text
nebulaProofVersion
ProofCanonicalInput
RequestProofSigner
```

`RecordingProofSigner` is a generic public test double. It is also not Auth business semantics.

No EMAIL, PHONE, OAuth, refresh, logout, user-session state, provider adapter, or product-specific behavior may move into foundation as part of this correction.

## 4. Frozen physical ownership

### 4.1 Runtime proof primitives

New authoritative home:

```text
lib/src/foundation/request_proof.dart
```

It owns exactly the existing runtime proof primitives:

```text
const nebulaProofVersion
final class ProofCanonicalInput
abstract interface class RequestProofSigner
```

Their behavior is byte-for-byte semantic compatible with the current `auth/proof.dart` contract:

```text
VERSION\nMETHOD\nPATH\nTIMESTAMP\nNONCE\nBODY_SHA256\nINSTALLATION_TOKEN_SHA256
```

The frozen V1 algorithm remains ES256/P-256 through the host-supplied signer Port. No concrete crypto/plugin implementation enters SDK core.

### 4.2 Recording test double

New authoritative home:

```text
lib/src/testing/recording_proof_signer.dart
```

It owns:

```text
final class RecordingProofSigner implements RequestProofSigner
```

Production modules must never import `src/testing/**`.

### 4.3 Compatibility seam

`lib/src/auth/proof.dart` remains present as a compatibility re-export:

```text
auth/proof.dart
  -> export foundation/request_proof.dart
  -> export testing/recording_proof_signer.dart
```

It must contain no independent proof algorithm/state and no duplicated classes. This preserves existing direct source-path consumers as a compatibility courtesy while making ownership unambiguous.

`lib/nebula_sdk.dart` must directly export the authoritative declaration files so the API-surface collector sees the real symbol owners. The compatibility re-export may remain exported as well.

## 5. Public API / snapshot compatibility

Target public **semantic** delta is zero.

Current snapshot ownership:

```text
src/auth/proof.dart const nebulaProofVersion
src/auth/proof.dart class ProofCanonicalInput
src/auth/proof.dart class RequestProofSigner
src/auth/proof.dart class RecordingProofSigner
```

Expected implementation snapshot ownership:

```text
src/foundation/request_proof.dart const nebulaProofVersion
src/foundation/request_proof.dart class ProofCanonicalInput
src/foundation/request_proof.dart class RequestProofSigner
src/testing/recording_proof_signer.dart class RecordingProofSigner
```

Therefore the API snapshot will show **4 removed path records + 4 added path records**, while all of the following must hold:

```text
public symbol names removed = 0
public symbol names added   = 0
symbol kind changes         = 0
behavior/signature changes  = 0
API surface total           = 131
```

Because the current snapshot tool records source ownership, the implementation Story must use `sdk_public_api_mode=CHANGE_APPROVED` specifically for this reviewed path migration. An implementation Agent must not update the snapshot under `READ_ONLY`.

Any actual symbol add/remove/rename, signature behavior change, proof-version change, or wire change is outside this contract and requires a new public-surface/contract change.

## 6. Required import repair

After relocation, these generic modules must no longer import Auth solely for request proof:

```text
lib/src/transport/proof_headers.dart
lib/src/config/config_client.dart
lib/src/analytics/mobile_analytics_sender.dart
lib/src/error_reporting/mobile_error_report_sender.dart
```

They import the neutral foundation proof Port instead.

Auth itself may import foundation proof primitives. Composition/facade roots (`nebula.dart`, `observability/mobile_observability_composition.dart`) also switch to the neutral owner.

The compatibility `auth/proof.dart` must not be used by new production code after this migration.

## 7. Layer Graph Guard freeze

A later governance Story must add a mechanical import-graph gate over `lib/src/**`. It becomes blocking only **after** the production relocation above is canonical; the guard must not ship with an allowlist that blesses the exact violation it is intended to remove.

### 7.1 Module classes

Base modules:

```text
foundation
transport
storage
```

Sibling capabilities:

```text
auth
config
analytics
error_reporting
asset
notification
payment
ai
```

Composition/test domains:

```text
observability
testing
root facade/contract files
```

### 7.2 Blocking rules

The guard must fail on at least:

1. `foundation -> transport/storage/capability`;
2. `transport -> auth/config/analytics/error_reporting/asset/notification/payment/ai`;
3. `storage -> transport/capability`;
4. sibling capability -> sibling capability direct implementation import;
5. production module -> `testing`;
6. new cross-module exception not recorded in a reviewed policy.

Allowed direction is conceptually:

```text
foundation
  ^
transport + storage
  ^
auth / config / analytics / error_reporting / future capabilities
  ^
explicit composition roots
  ^
App Adapter / Product
```

If a capability needs another capability's session/proof behavior, it must depend on a small neutral Port/event. It must not directly import that sibling implementation merely because the code already exists there.

### 7.3 Explicit root exceptions

The guard may model these as composition/contract roots rather than ordinary modules:

```text
lib/src/nebula.dart
lib/src/capabilities.dart
lib/src/observability/mobile_observability_composition.dart
lib/src/transport.dart
lib/src/testing/**
```

Exceptions are structural, not wildcard permission to add product logic. Negative regression tests must prove an injected `transport -> auth` edge and a sibling-capability edge fail.

## 8. Product-Erasure Guard freeze

A later governance Story must add a production-SDK product-erasure gate. It is defense in depth for the existing `ADAPTER_FIRST` + second-consumer policy, not a replacement for architecture review.

### 8.1 Mechanical checks

At minimum the guard must fail on new production `lib/**` code containing:

- registered consumer/product identifiers in executable identifiers/string literals;
- consumer package IDs, App-specific API origins or App secrets;
- Flutter UI/navigation coupling (`Widget`, `BuildContext`, `Navigator`, router/page/dialog ownership or `package:flutter/...` imports);
- direct product runtime/plugin packages in the pure-Dart core without explicit architecture dependency approval;
- product models/fields promoted upward solely to reduce App Adapter mapping.

The first implementation should maintain a reviewed policy/registry rather than hard-code an unreviewable giant regex. Known consumers include NFC Writer and Nearvia, but comments/evidence that merely name a consumer must not create false positives; scanning must distinguish executable code/string literals from documentation comments where practical.

### 8.2 Runtime dependency baseline

Current runtime dependencies are exactly:

```yaml
dependencies: {}
```

Any future runtime dependency addition requires explicit architecture/dependency review. The product-erasure guard must not silently accept a Flutter/native/provider plugin because one App needs it. Platform-specific implementations remain host/adapter packages until independent multi-App evidence justifies a package split.

### 8.3 Negative regression

The governance tests must inject at least:

```text
known product identifier in executable lib code -> FAIL
package:flutter import in SDK core               -> FAIL
new runtime plugin dependency                    -> FAIL unless reviewed policy allows it
product UI/navigation symbol                     -> FAIL
```

## 9. Multi-App isolation regression freeze

The production-repair Story must add one deterministic combined regression using shared fake/in-memory storage and at least two distinct App identities (`app-a`, `app-b`).

It must prove:

### 9.1 Secure token namespace

For the same environment and physical fake store:

```text
tokenNamespace(env, app-a) != tokenNamespace(env, app-b)
```

Writing/clearing App A installation or refresh token must not read/delete App B token state. Existing colon-style token namespace is compatibility-preserved in this Story; do not opportunistically rewrite it to the slash-style generic StorageNamespace.

### 9.2 Generic storage namespace

`StorageNamespace.app` and `StorageNamespace.user` must isolate:

```text
environment
app_id
user_id (when applicable)
```

Scope-breaking `/` and NUL rejection remains fail-closed.

### 9.3 Runtime Config

Two `NebulaConfigClient` instances sharing one `CacheStorage` but using different `NebulaOptions.appId` must never read each other's snapshot. Existing installation-token hash, app build and schema dimensions remain in the cache key.

### 9.4 Analytics

`CacheConsentStore` and any persisted analytics queue/state must remain isolated by environment + App identity. Revoking/clearing consent for App A must not change App B.

### 9.5 Error Reporting

`CacheErrorReportStore` queues for App A and App B must remain independent in the same physical `CacheStorage`. Flush/delete/corruption recovery in A must not delete B.

### 9.6 Backend invariant

No Backend mutation is authorized here. Existing Backend authority remains:

```text
FlyPostAPI Dev@d9ad6c3c0e9186e574081e22d88450d93542fd29
```

The cross-repo invariant remains: mobile trust scope comes from InstallationProof / trusted token claims, and mutable data/session/idempotency authority is scoped by trusted `app_id + installation_id` (plus user/session where applicable), never by an untrusted body/query app selector.

The bootstrap public `app_id`/app-key exception remains exactly that: a public product identifier resolved server-side to trusted numeric AppID before installation authority is issued. This contract does not broaden it.

## 10. Consumer Adapter non-regression

This hardening must not move App-owned content into SDK.

NFC Writer remains:

```text
feature/UI/product model
  -> NebulaAdapter + nebula_contracts.dart
  -> package:nebula_sdk
```

Its existing mechanical boundary that keeps direct SDK imports inside `lib/platform/nebula/` is the reference consumer behavior. Product parser rules, NFC actions, Timer/Pomodoro behavior, media behavior and UI remain App-owned.

Nearvia remains a separate consumer with its own Auth/ASSIST/WATCH/RTC/Family product models and App-owned adapter. No Nearvia product behavior is authorized to become an SDK primitive through this hardening.

## 11. Downstream execution split

Architecture freezes two serial downstream concerns; do not combine them into one self-authorizing implementation.

### 11.1 Production repair Story

A Coordinator may register a dedicated SDK production Story only after this freeze is independently approved and canonical. Required mode:

```text
platform_api_mode = NONE/READ_ONLY
sdk_public_api_mode = CHANGE_APPROVED
product_adapter_rule = ADAPTER_FIRST
```

Authorized behavior is limited to:

- proof primitive relocation + compatibility re-export;
- direct barrel exports of authoritative declarations;
- import repair;
- API snapshot path migration with symbol/kind/count equality proof;
- focused/full tests;
- deterministic multi-App isolation regression.

It must not implement the new governance guards or edit protected Coordinator state in the same production Story.

### 11.2 Governance hardening Story

Only after the production tree is clean may a separate Governance/Quality Story add and bind:

```text
Layer Graph Guard
Product-Erasure Guard
policy/negative regression tests
CI/governance binding
```

This ordering prevents the implementation Agent from writing an allowlist that excuses its own current violation. Governance changes require their own exact-head independent review.

## 12. Explicit non-goals

This contract does not authorize:

- new Asset, Notification, Payment or AI capability;
- new Backend route/model/migration;
- Auth V2 behavior/provider changes;
- WeChat/QQ enablement;
- NFC Writer or Nearvia mutation;
- Flutter/native plugin dependency inside SDK core;
- service locator/global mutable singleton;
- product config/schema pushed upward into SDK;
- changes to `ui_locale`, `market_region`, service/data-region ownership;
- proof algorithm/version/wire change.

## 13. Architecture acceptance criteria

This freeze is acceptable only if its own candidate proves:

```text
changed production lib/** = 0
API snapshot delta        = 0
Backend delta             = 0
App delta                 = 0
Task Board delta          = 0
only contract artifact    = changed
Task Source Guard         = PASS
Cross Repo Guard          = PASS
git diff --check          = PASS
```

Architecture owner then freezes the PR exact SHA and stops. Formal terminal belongs to Formal CI / Execution Coordinator. Independent approval belongs to SDK Architecture reviewer. No self-review and no self-merge.
