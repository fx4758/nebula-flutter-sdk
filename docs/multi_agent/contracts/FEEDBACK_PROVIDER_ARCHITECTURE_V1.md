# Feedback Provider Architecture v1

> Story: `FEEDBACK-ARCH-V1-001`  
> Status: **FREEZE CANDIDATE**  
> Scope: Architecture / provider-neutral App boundary only  
> Production implementation authority: **NONE**

## 1. Decision summary

Feedback V1 is a **Nebula-owned entry experience**, not a product-owned provider integration.

```text
App
  -> Nebula SDK
  -> trusted Nebula feedback entry/session
  -> first-party HTTPS feedback URL
  -> server-owned provider routing
       CN / existing NFC Writer -> TXC adapter
       Global / future Apps     -> Native adapter
```

The App MUST NOT select TXC/Native/Canny/another provider and MUST NOT branch on region to choose feedback infrastructure.

For V1, the SDK boundary is intentionally **entry/session only**. A generic native `submitFeedback(...)` SDK API is deferred. This preserves the current low-cost TXC user experience and avoids building a second complete feedback UX before there is product evidence that it is needed.

## 2. Why entry/session instead of submit

NFC Writer China already has a mature external feedback experience through Tencent TXC/兔小巢. Replacing it immediately would recreate UI, user history, image/community/reply and moderation behavior that is currently low-cost.

A submit-first SDK contract would force one of two bad outcomes:

1. expose a provider branch to product code (`TXC -> WebView`, `Native -> API submit`); or
2. build a full Native feedback product now only to make the client contract uniform.

V1 instead makes the **experience entry** uniform. Provider replacement then becomes a server policy change rather than an App release.

## 3. App-facing SDK boundary

### 3.1 Pure-Dart rule

`nebula-flutter-sdk` remains a pure-Dart/platform client foundation. It MUST NOT import Flutter UI, own navigation, construct a WebView, or depend on a provider SDK.

The later SDK Public Surface Freeze SHOULD minimize V1 to one feedback capability and one operation equivalent in semantics to:

```dart
abstract interface class NebulaFeedback {
  Future<Uri?> entry({
    NebulaCancellationToken? cancellationToken,
  });
}
```

This snippet freezes **intent only**, not exact symbol names. Public symbols remain unauthorized until a dedicated SDK Public Surface Story.

Semantics:

- non-null `Uri` = short-lived first-party feedback entry/session URL;
- null = feedback is intentionally unavailable/disabled for this App/environment;
- transport/server failures remain distinct from disabled/unconfigured state;
- cancellation reuses the existing SDK cancellation model;
- the SDK MUST validate that the returned URL is HTTPS and belongs to a Nebula-controlled first-party origin policy before returning it to product code.

### 3.2 No public Feedback DTO in V1

V1 SHOULD NOT expose:

- provider name;
- provider product/community ID;
- provider URL;
- provider credentials;
- `app_id` or installation identity inputs;
- region/provider routing inputs;
- attachment schemas;
- reply/channel APIs;
- provider post/thread IDs;
- native feedback persistence/queue types.

This keeps the public surface smaller than a submit-oriented API and leaves room for Native feedback later without changing the App integration point.

## 4. Product App integration

Product code owns only presentation of the first-party URL.

Conceptually:

```dart
final Uri? feedbackEntry = await nebula.feedback.entry();
if (feedbackEntry != null) {
  await appNavigation.openWebView(feedbackEntry);
}
```

The App MAY choose WebView vs system browser according to product UX policy, but it MUST NOT inspect the URL to decide which feedback provider is active.

The App MUST NOT contain literals or direct calls for:

```text
txc.qq.com
support.qq.com
Canny
provider product/community IDs
provider private keys
CN -> TXC / Global -> Native routing
```

## 5. First-party feedback session

The URL returned to the App MUST initially resolve through a Nebula-controlled HTTPS origin. The concrete hostname is deployment configuration, not an SDK constant; `feedback.top22.top` is the intended production naming direction, not an implementation authorization in this freeze.

The future Platform API/session implementation MUST satisfy:

- session established from trusted Nebula installation context;
- works before user login;
- opaque high-entropy session identifier;
- no `app_id`, installation ID, user ID, provider ID or secret in clear URL query parameters;
- bounded lifetime, recommended maximum 10 minutes;
- replay bounded by one-time or equivalently strong server-side state;
- session may be re-created if expired;
- first-party session resolution performs provider routing server-side.

A future concrete Mobile endpoint/path is **not frozen here** and requires a separate Platform API Contract Story.

## 6. Trusted identity and privacy

Feedback entry is an installation-scoped basic service. V1 does **not** introduce a new entitlement/capability ID.

Canonical capability IDs remain unchanged:

```text
identity
payment
notification
ai
storage
analytics
```

Feedback availability is controlled by platform/provider configuration plus a kill switch, not by adding `feedback` to the current entitlement whitelist.

The App MUST NOT author trusted context. A future Platform implementation derives from server-validated Nebula trust where available:

- App identity;
- installation identity;
- platform;
- App version/build;
- environment;
- region;
- optional authenticated user context.

Only the minimum provider-permitted subset may be mapped into the provider experience. Provider-specific privacy restrictions override convenience metadata.

No unique hardware identifier, IMEI, Android ID, IDFA, MAC, SIM IMSI or similar device identifier may be forwarded to TXC or another provider merely because the App can access it.

## 7. TXC provider adapter

TXC remains a valid low-cost provider for existing China NFC Writer feedback.

### 7.1 Server-only credentials

TXC configuration such as:

- product/community ID;
- private key;
- API signature material;
- encrypted login-state construction;

MUST remain server-side. It MUST NOT enter SDK runtime config or App code.

### 7.2 User experience bridge

When routing a first-party feedback session to TXC, the server MAY:

- redirect to the provider experience; or
- return a first-party bridge page that performs a controlled POST to the provider.

The bridge MAY map safe context such as App version, platform/OS and other provider-permitted fields. Provider user/login state, if ever used, must be generated server-side.

### 7.3 Data aggregation

The TXC user-feedback read API is a provider ingestion source, not Nebula's public App contract.

Nebula Admin SHOULD normalize TXC feedback into a provider-neutral operator view using:

- provider source;
- external/provider feedback ID internally;
- Nebula `app_id` mapping;
- content/type/status timestamps;
- safe client/version metadata where available.

Raw TXC response shape MUST NOT become an SDK or App-facing model.

### 7.4 Reply limitation

The currently evaluated TXC feedback-data API documents feedback retrieval, not a generic provider-neutral reply-write contract. V1 MUST NOT fabricate a unified reply operation.

Until a supported provider write path is independently verified:

- TXC feedback may be viewed/triaged in Nebula Admin;
- reply/advanced community operations may deep-link operators to TXC management;
- Nebula MUST NOT report "reply sent" unless a real provider/native delivery path succeeded.

## 8. Future Native provider

Native Feedback is a future provider behind the same first-party session URL.

Its first release SHOULD be deliberately small:

```text
feedback type
text content
optional contact
trusted App/platform/version context
processing status
internal operator note
```

Native V1 does not need to recreate TXC community, public voting, roadmap, social identity, rich threads or other mature-provider features.

If a later product need requires a direct native submit SDK API, that is a **new public-surface version/change**. It MUST NOT alter the meaning of the existing provider-neutral entry operation.

## 9. Admin platform boundary

Feedback is a common App-level operational domain, unlike FlyPost-specific `权限点` or `安全审计`.

The intended Admin placement is:

```text
Current App
  - 接入状态
  - 运行中心
  - 用户反馈   (when a feedback provider is configured/enabled)
```

The unified operator view MUST scope all records by current `product_app/app_id`.

Provider configuration is platform-owned. It is not an App-visible capability entitlement and MUST NOT be inferred from product code.

Provider-specific diagnostics/actions may appear to operators where necessary, but product-facing SDK contracts remain provider-neutral.

## 10. Reply semantics

Feedback processing and user reply are separate concerns.

V1 common operational states may include provider-neutral triage facts such as:

```text
NEW
IN_PROGRESS
RESOLVED
CLOSED
```

A state transition is not proof that a user received a reply.

FlyPost `user_notification` MUST NOT be reused as the generic Feedback reply mechanism. A future outbound reply may use:

- provider-native reply;
- Nebula Notification capability when the App/user relationship supports it;
- email/contact channel with explicit user consent;
- no outbound reply at all, only internal processing.

Each delivery path requires its own verified contract.

## 11. Native Feedback security gate (SR-008)

The prior security baseline intentionally did not create Feedback abuse controls because no real entry existed. This architecture creates the first legitimate future trigger, but still authorizes no implementation.

Before any Native submit endpoint ships, a separate implementation Story MUST freeze and test at least:

- per-installation/IP rate limiting;
- request/content byte caps;
- content type validation;
- attachment disabled by default;
- if attachments are later enabled: bounded count/size/type, malware/content policy and private storage;
- spam/automation abuse handling;
- duplicate/replay policy;
- retention/deletion policy;
- contact/PII redaction and operator access;
- auditability for moderation/status actions;
- deterministic overload behavior that rejects before expensive provider/storage work.

TXC provider traffic remains subject to provider controls plus Nebula session-creation limits.

## 12. Cost boundary

V1 optimizes for low incremental cost:

- keep TXC where it already provides sufficient free/low-cost functionality;
- build only a first-party routing/session seam and normalized Admin aggregation;
- defer Native provider until required for Global/new-App needs;
- do not clone TXC community/roadmap/helpdesk features;
- no always-on high-frequency polling when webhook/incremental pull can satisfy ingestion;
- provider secrets and API calls stay server-side so pricing/provider policy can change without App release.

## 13. NFC Writer migration

Current facts entering this freeze:

- current Flutter `RouteName.help` resolves to `PlaceholderPage`;
- historical/released China NFC Writer feedback used TXC/兔小巢;
- the Nebula SDK public surface currently has no Feedback capability;
- the canonical capability whitelist contains no `feedback` ID.

Migration target:

```text
Old released App versions
  -> existing TXC path (unchanged)

New NFC Writer version
  -> App Help/Feedback page
  -> Nebula SDK feedback entry
  -> first-party Nebula session URL
  -> server routes China provider to TXC

Nebula Admin
  -> normalized TXC ingestion for unified viewing
```

This permits legacy clients and new clients to coexist during migration.

No current App mutation or SDK repin is authorized by this freeze.

## 14. Global/region behavior

Provider routing is evaluated on trusted platform policy, not a client-supplied country switch.

The platform may consider:

- product/App configuration;
- deployment environment;
- trusted region policy;
- provider availability/compliance;
- emergency/kill-switch state.

The App sees only availability plus a first-party entry URL.

A future Global Native provider can therefore replace or complement TXC without changing product routing logic.

## 15. Failure semantics to preserve in later contracts

A later SDK/Platform contract MUST distinguish at least:

1. intentionally disabled/unconfigured Feedback;
2. session creation validation/auth/trust failure;
3. rate-limited/temporarily unavailable service;
4. network/timeout/cancellation failure;
5. malformed or untrusted first-party entry URL.

Provider internal failures MUST NOT cause the SDK to return a third-party credential or a provider-direct fallback URL that bypasses the first-party policy boundary.

## 16. Deferred decisions

This freeze deliberately does not decide:

- concrete Mobile API path/request/response wire;
- concrete first-party DNS record;
- session persistence implementation (DB/cache/signed opaque token);
- exact SDK symbol names/facade field/API-surface delta;
- TXC webhook vs scheduled incremental ingestion details;
- Native database schema;
- attachments;
- public feature voting/roadmap;
- unified provider write/reply API;
- adding `feedback` as an entitlement capability.

Each requires a separately scoped reviewed Story.

## 17. Required follow-up sequence

After this freeze is independently reviewed and canonical-closed, Coordinator may register in order:

```text
FEEDBACK-SDK-SURFACE-V1-001
  READ_ONLY public-surface freeze

FEEDBACK-PLATFORM-API-V1-001
  concrete first-party entry/session API contract
  subject to Platform API second-consumer governance

FEEDBACK-TXC-ADAPTER-V1-001
  server-side provider config/session bridge + ingestion/admin adapter

FEEDBACK-SDK-SURFACE-V1-002
  CHANGE_APPROVED SDK implementation only after surface + platform contract close

NFC Writer App Feedback Adapter
  only after immutable SDK/API identities are available

Native Provider
  separately deferred until Global/product demand justifies it
```

## 18. Acceptance assertions

The freeze is acceptable only if all are true:

- App has exactly one provider-neutral Feedback integration concept;
- App contains no TXC/provider/region routing authority;
- SDK remains UI-framework independent;
- V1 does not require a Native submit API;
- provider secrets never enter SDK/App;
- first-party session origin is mandatory;
- unauthenticated users can reach Feedback;
- current capability IDs remain unchanged;
- TXC remains usable as the low-cost China provider;
- Global Native can be added without another product-code routing branch;
- Admin common Feedback is scoped by `app_id`;
- TXC reply is not falsely represented as unified until a real write path exists;
- SR-008 is explicitly required before Native submit implementation;
- production/API/public-surface mutation in this Story is zero.

## 19. Freeze disposition

`FEEDBACK_PROVIDER_ARCHITECTURE_V1` is a **FREEZE CANDIDATE** only.

It becomes canonical only after exact independent Architecture Review, merge and Coordinator closure. Even after closure it authorizes no production code by itself; follow-up Stories must carry their own explicit write sets and review gates.
