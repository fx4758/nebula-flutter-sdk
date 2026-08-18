# Feedback SDK Public Surface v1

> Story: `FEEDBACK-SDK-SURFACE-V1-001`
> Status: **FREEZE CANDIDATE**
> Architecture authority: `FEEDBACK_PROVIDER_ARCHITECTURE_V1`
> Production/public mutation authority in this Story: **NONE**

## 1. Public V1 decision

Feedback V1 exposes exactly one new top-level SDK symbol:

```dart
final class NebulaFeedback {
  NebulaFeedback({
    required NebulaOptions options,
    required NebulaTransport transport,
    required RequestProofSigner proofSigner,
    required Future<String> Function() installationToken,
    required Future<bool> Function() recoverInstallationTrust,
  });

  Future<Uri?> entry({
    NebulaCancellationToken? cancellationToken,
  });
}
```

The snippet above is the frozen target surface for a later authorized implementation. This Story does not modify `lib/**`.

`NebulaFeedback` is a concrete provider-neutral mobile client, not a provider interface and not a Flutter UI object.

## 2. Why one concrete class

The SDK/App integration already centralizes SDK construction inside each product's Nebula Adapter boundary. In NFC Writer, `lib/platform/nebula/nebula_adapter.dart` is the only product layer allowed to import `package:nebula_sdk/nebula_sdk.dart`; feature/page code consumes App-owned contracts.

A separate public `NebulaFeedbackClient` plus `NebulaFeedback` interface would add a second top-level symbol without buying a product-facing abstraction: product business code must not depend on either type directly.

A public composition/factory class would likewise duplicate the existing explicit constructor-injection pattern used by SDK mobile clients.

Therefore V1 chooses one concrete `NebulaFeedback` class with explicit existing SDK dependencies. Provider implementations remain server-side and invisible.

## 3. Facade decision

`Nebula` facade is **UNCHANGED in V1**.

No `Nebula.feedback` field and no new `Nebula(...)` constructor parameter are added.

Reasons:

1. Existing RC1 consumers remain byte/source compatible at the facade constructor.
2. NFC Writer currently constructs `Nebula(...)` only for validation/DI completeness and discards the facade; adding a member would not improve its actual adapter architecture.
3. The App adapter can construct and retain `NebulaFeedback` exactly like it already constructs `NebulaSessionAuth` and `NebulaConfigClient`.
4. A later facade aggregation may be proposed only if a second real consumer demonstrates that it reduces duplication without widening provider authority.

The product-level call shape is therefore conceptually:

```dart
final Uri? uri = await nebulaAdapter.feedbackEntry();
```

and inside the App's SDK boundary only:

```dart
final Uri? uri = await _feedback.entry();
```

Business pages do not import `NebulaFeedback` directly.

## 4. Constructor inputs

Every constructor input already exists in the SDK public surface and is provider-neutral:

- `NebulaOptions` supplies canonical App/environment/base API configuration;
- `NebulaTransport` supplies the shared HTTP transport;
- `RequestProofSigner` supplies installation proof signing;
- `installationToken` supplies the current installation token without exposing storage;
- `recoverInstallationTrust` supplies the existing bounded trust-recovery seam;
- no provider or product-specific input exists.

The constructor MUST NOT accept:

```text
app_id
installation_id
region routing override
provider/provider name
TXC product ID
TXC private key
TXC URL
Native provider endpoint
user_id
attachments
provider metadata
```

Trusted App/installation/platform/region facts remain Platform/installation authority, not caller-authored Feedback inputs.

## 5. Entry operation semantics

```dart
Future<Uri?> entry({
  NebulaCancellationToken? cancellationToken,
});
```

### 5.1 `null`

`null` has one meaning only:

```text
Feedback is intentionally disabled or unconfigured for the trusted App/environment.
```

`null` MUST NOT represent:

- network failure;
- timeout;
- malformed server response;
- trust/proof failure;
- rate limit;
- provider outage;
- cancellation.

This makes UI behavior deterministic: the App may hide/disable Feedback when `null`, while real failures can surface a retry affordance.

### 5.2 Existing exception surface only

V1 adds **no new public exception type**.

The later implementation MUST preserve the existing SDK error hierarchy:

- caller cancellation -> `NebulaCancelledException`;
- connect/receive timeout -> `NebulaTimeoutException`;
- transport/TLS/HTTP failure -> existing `NebulaHttpException` semantics;
- server business failure -> existing `NebulaApiException` semantics;
- malformed/untrusted entry result -> request fails closed through an existing `NebulaException` subtype selected by the later concrete Platform API contract/implementation; it MUST NOT be converted to `null`.

The public contract does not freeze a provider-specific error code or exception.

### 5.3 No implicit retry from product intent

`entry()` is initiated by an explicit user action. V1 MUST NOT silently loop or perform unbounded retries.

A single bounded installation-trust recovery opportunity MAY be used through the supplied `recoverInstallationTrust` seam when the later Platform API contract classifies the failure as recoverable installation trust loss. Any further retry is owned by the caller/user action.

## 6. First-party URL rule

The SDK MUST never return an arbitrary absolute provider URL received from a server payload.

To avoid a new public `allowedFeedbackOrigin` configuration parameter, the later Platform API SHOULD return a bounded **relative first-party entry path/session path**, not an arbitrary provider URL.

The SDK resolves that path against `NebulaOptions.baseUri` and returns only a URI whose scheme/origin remains the configured Nebula API origin.

Conceptually:

```text
Platform result:
  /feedback/s/<opaque-session>

SDK result to App:
  https://api.example.com/feedback/s/<opaque-session>
```

After the App opens that first-party URL, server/Nginx/bridge policy may redirect or POST onward to TXC or render a future Native experience. That provider transition occurs in the browser/server path, not in SDK product routing.

This rule buys:

- no provider URL in App data;
- no new SDK origin configuration field;
- production/staging isolation inherited from `NebulaOptions.baseUri`;
- provider/domain replacement without App release;
- fail-closed origin validation by construction.

If a future Platform contract genuinely requires a different first-party origin, that is an explicit contract/public-surface change; V1 does not pre-authorize it.

## 7. Pure-Dart / UI boundary

`NebulaFeedback` MUST NOT import Flutter or expose:

- `BuildContext`;
- WebView/controller types;
- navigation callbacks;
- browser-launch packages;
- Widget types;
- provider SDK types.

The SDK returns a `dart:core` `Uri`; the host App decides how to present it.

For NFC Writer, the later App implementation belongs in the existing adapter-first boundary:

```text
lib/platform/nebula/nebula_adapter.dart
lib/platform/nebula/nebula_contracts.dart
+ App help/feedback presentation route
```

Feature/page code continues to be forbidden from importing the SDK directly.

## 8. Export and symbol delta

Current canonical API surface:

```text
127 top-level symbols
```

V1 predicted delta:

```text
127 -> 128
```

Exactly one new top-level symbol is allowed:

```text
NebulaFeedback
```

No public Feedback input/result/error/provider/composition class is added.

Because the concrete client belongs in a new Feedback source file, the later authorized implementation requires one new barrel export/allowlist entry. Predicted public path:

```text
lib/src/feedback/feedback_client.dart
```

Required future public-surface bookkeeping:

```text
lib/nebula_sdk.dart
  + export 'src/feedback/feedback_client.dart';

governance/public_api.txt
  + src/feedback/feedback_client.dart

governance/api_surface.snapshot
  + src/feedback/feedback_client.dart class NebulaFeedback
```

The exact snapshot remains generated by the surface Owner; this freeze does not run `--update`.

## 9. Public / internal / deferred classification

### PUBLIC V1

Exactly one new symbol:

| Symbol | Classification | Reason |
|---|---|---|
| `NebulaFeedback` | PUBLIC V1 | Provider-neutral entry client required by App adapter. |

Reused existing public types, not new Feedback exports:

```text
NebulaOptions
NebulaTransport
RequestProofSigner
NebulaCancellationToken
NebulaException hierarchy
Uri
```

### INTERNAL ONLY

Future implementation types MUST remain unexported/non-public, including:

```text
feedback endpoint/path constants
wire request/response DTOs
entry-session parser/validator
trust-recovery result mapping
provider routing result
provider identifier
TXC product/community mapping
TXC signature/private-key handling
first-party session token/state
provider ingestion cursor/webhook types
Native provider repository/storage types
Admin normalized provider adapter DTOs
```

### DEFERRED

The following are explicitly outside Feedback SDK Public Surface V1:

```text
submitFeedback(...)
FeedbackInput / FeedbackResult DTO
attachments/screenshots/log bundle
feedback history/thread API
reply API
provider name/status API
community/voting/roadmap API
public provider adapter interface
public Feedback composition/factory class
Nebula.feedback facade member
feedback entitlement/capability ID
Flutter/WebView/navigation helpers
```

## 10. Backward compatibility

This freeze preserves current RC1 constructor/facade behavior:

```text
lib/src/nebula.dart
  no constructor change
  no field change
  no existing member semantic change

lib/src/capabilities.dart
  no change
```

Existing consumers that never use Feedback compile unchanged.

Consumers that opt into Feedback import the same package barrel and construct `NebulaFeedback` only in their SDK adapter/composition boundary.

A future Native provider does not change the public method signature because provider selection remains server-side behind the first-party entry path.

Adding direct native submit/history/reply later is additive public API work and requires a separately reviewed surface version/change; it MUST NOT repurpose `entry()`.

## 11. App adapter contract expectation

The SDK surface deliberately does not become the product contract.

For NFC Writer, the later App-side adapter SHOULD expose an App-owned operation semantically equivalent to:

```dart
Future<Uri?> feedbackEntry();
```

Only `lib/platform/nebula/**` may import the SDK. The Help/Feedback page consumes the App contract and opens the returned first-party URL; it must not receive `NebulaFeedback`, `NebulaException`, provider names or TXC identifiers as product model state.

This preserves the existing adapter-first invariant:

```text
Platform contract
-> SDK generic client
-> App NebulaAdapter
-> App/product UI
```

## 12. Later implementation write-set

A later `CHANGE_APPROVED` SDK implementation, after the concrete Feedback Platform API contract is canonical, may be authorized for the minimum set:

```text
lib/src/feedback/feedback_client.dart       NEW
lib/src/feedback/**                         only minimal internal parser/endpoints if mechanically required
lib/nebula_sdk.dart                         add one feedback_client export
governance/public_api.txt                   add one exported file allowlist entry
governance/api_surface.snapshot             generated 127 -> 128 update
test/feedback/**                            focused tests
```

Required unchanged serial/core paths:

```text
lib/src/nebula.dart
lib/src/capabilities.dart
lib/src/analytics/**
lib/src/error_reporting/**
lib/src/config/**
lib/src/auth/**
```

`lib/src/transport/**` and `lib/src/foundation/**` are reuse-only unless a separate SDK Architect change is registered; Feedback must not invent another HTTP stack, proof scheme, cancellation primitive or error hierarchy.

## 13. Implementation test obligations

The future implementation must mechanically cover at least:

1. enabled entry -> trusted relative path resolves against `NebulaOptions.baseUri`;
2. disabled/unconfigured -> `null`;
3. arbitrary absolute/provider URL from wire -> fail closed, never returned;
4. scheme-relative, path traversal or malformed path -> fail closed;
5. production/staging base origin remains unchanged;
6. installation proof uses the shared SDK proof mechanism;
7. caller cancellation aborts the request;
8. timeout/network/business errors remain non-null failures;
9. bounded trust recovery executes at most once when contract-authorized;
10. repeated user calls do not implicitly reuse an expired session;
11. no provider/TXC literals or credentials in SDK source/public API;
12. FakeTransport covers success/disabled/business error/network error/cancel;
13. governance and secret scan PASS;
14. generated API surface contains exactly one new top-level symbol.

## 14. Product/provider erasure proof

The target public signature contains none of:

```text
NFC Writer
FlyPost
Nearvia
StarSprout
TXC
兔小巢
Canny
China/CN provider branch
Global provider branch
provider ID
product/community ID
private key
```

`NebulaFeedback` means only: obtain the trusted first-party feedback entry for the current Nebula App installation.

## 15. Platform dependency gate

This SDK surface freeze does not invent a Mobile endpoint.

Concrete implementation remains blocked until a separately governed Feedback Platform API contract freezes at least:

- proof/auth scope;
- enabled/disabled response semantics;
- relative first-party entry path/session shape and bounds;
- business/error codes;
- session TTL/replay behavior;
- trust recovery semantics;
- payload/response limits.

The existing `PLATFORM_API_CHANGE_POLICY` and second-consumer rule remain authoritative. This Story does not create or infer a second consumer merely to bypass that gate.

## 16. Freeze result

Target Feedback SDK Public Surface V1:

```dart
final class NebulaFeedback {
  NebulaFeedback({
    required NebulaOptions options,
    required NebulaTransport transport,
    required RequestProofSigner proofSigner,
    required Future<String> Function() installationToken,
    required Future<bool> Function() recoverInstallationTrust,
  });

  Future<Uri?> entry({
    NebulaCancellationToken? cancellationToken,
  });
}
```

Frozen deltas:

```text
new top-level symbols:        +1 (`NebulaFeedback`)
API surface:                  127 -> 128 predicted
Nebula facade change:         0
capabilities.dart change:     0
new public Feedback DTOs:     0
new public error types:       0
provider-facing public types: 0
Flutter/UI dependencies:      0
Native submit API:            0
capability entitlement IDs:   0
```

`FEEDBACK_SDK_PUBLIC_SURFACE_V1` is a **FREEZE CANDIDATE** only. It becomes canonical after exact independent SDK Architecture/Public Surface Review, merge and Coordinator closure. This Story authorizes no production/public implementation by itself.
