# FEEDBACK-ARCH-V1-001 Provider-Neutral Feedback Entry Architecture Freeze
- ID：FEEDBACK-ARCH-V1-001
- Owner：Feedback Architecture Agent
- Execution repo：`.`
- Execution branch：`feedback/arch-v1-001-provider-neutral-entry-freeze`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`READ_ONLY`
- Governance state：architecture/contract freeze only; no SDK/Backend/App/provider production mutation in this Story.
- Triggering consumer：NFC Writer `帮助与反馈` entry; current Flutter route is a placeholder while legacy released clients use Tencent TXC/兔小巢.
- Provider direction：TXC remains a supported China legacy/provider option; Global/other Apps may use a future Native provider. Product code must not branch on provider or region.

## Purpose
Freeze one multi-App feedback architecture that preserves the current low-cost TXC path without binding product code to TXC, while keeping a later Native/Global provider possible without another App integration rewrite.

Owner-selected direction:

```text
App product UI
  -> Nebula SDK public feedback entry
  -> Nebula Platform feedback entry/session boundary
  -> provider routing owned by Platform policy
       - TXC adapter (China / existing NFC Writer path)
       - Native adapter (Global / future Apps)
```

The App MUST NOT call `txc.qq.com`, `support.qq.com`, Canny, or a Native feedback endpoint directly and MUST NOT contain region/provider selection logic.

## Required output
Create exactly one independently reviewable artifact:

- `docs/multi_agent/contracts/FEEDBACK_PROVIDER_ARCHITECTURE_V1.md`

## Mandatory decisions
The freeze MUST define:

1. App consumes a Nebula SDK feedback abstraction only.
2. SDK is pure Dart and does not own Flutter/WebView UI; freeze the smallest provider-neutral entry/session descriptor the App host can present.
3. Decide whether V1 exposes only an entry/session operation rather than a native submit API, because NFC Writer China continues using TXC initially.
4. No TXC product ID/private key, provider name, regional branch or provider SDK type enters App-facing inputs.
5. CN/TXC vs Global/Native routing is server/platform policy, not App code.
6. Freeze a first-party feedback session origin (for example `feedback.top22.top`) so provider replacement does not require an App release.
7. App must not author `app_id`, installation identity, platform, region, build or provider identity; existing Nebula installation trust is authoritative.
8. Feedback entry works before user login; optional user identity may enrich later flows but is not mandatory V1 input.
9. TXC private key/signature/login-state construction is server-side only.
10. Future Native implementation must fit behind the same App/SDK entry.
11. Nebula Admin remains the unified operator surface even if provider is TXC.
12. Reply semantics must not assume FlyPost `user_notification`; reply channel is provider policy.
13. Define future SR-008 controls required before any Native submit endpoint ships: rate limit, payload cap, attachment policy, spam/abuse handling.
14. Preserve the zero/low-cost TXC path where available; do not authorize building a full in-house community/roadmap/helpdesk product.
15. Concrete new Mobile Platform API remains a separate Story under `PLATFORM_API_CHANGE_POLICY`; this freeze does not bypass the second-consumer requirement.

## Expected minimum SDK shape to evaluate
Prefer a minimal provider-neutral shape equivalent in intent to:

```dart
abstract interface class NebulaFeedback {
  Future<NebulaFeedbackEntry> entry();
}

final class NebulaFeedbackEntry {
  final Uri url; // first-party, short-lived feedback entry/session URL
}
```

This is architecture input, not an authorized public API declaration. Exact names, result shape, cancellation/error semantics and facade placement require a later dedicated SDK Public Surface Story before any `lib/**` mutation.

## Forbidden
- Any mutation under `lib/**`.
- `lib/nebula_sdk.dart`, `lib/src/nebula.dart`, `lib/src/capabilities.dart` mutation.
- API surface snapshot/public API mutation.
- Backend route/schema/migration/provider implementation.
- NFC Writer/App mutation or SDK repin.
- TXC credential access, storage or invocation.
- Native feedback endpoint implementation.
- New capability ID / entitlement whitelist mutation.
- Treating `feedback` as an existing capability ID; current canonical capability set remains unchanged.
- Task Board/Sprint Board mutation by the execution Agent.

## Verification
- Task Source Guard `FEEDBACK-ARCH-V1-001` PASS.
- Cross Repo Guard PASS.
- `git diff --check` PASS.
- Production/API/public-surface diff = 0.
- Contract proves product/provider name erasure at App boundary.
- Independent Architecture Review PASS on exact candidate.

## Exit
This Story closes only the provider-neutral Feedback architecture freeze.

After canonical `DONE / REVIEW PASS`, Coordinator may separately register:

1. Feedback SDK Public Surface Freeze (READ_ONLY first, then CHANGE_APPROVED implementation if reviewed);
2. Feedback Platform API Contract Story (subject to Platform API change governance / second-consumer rule);
3. TXC Provider Adapter / Admin Aggregation Story;
4. NFC Writer App Adapter Story after SDK/Platform contracts are canonical.

No implementation authority is inherited automatically from this Story.
