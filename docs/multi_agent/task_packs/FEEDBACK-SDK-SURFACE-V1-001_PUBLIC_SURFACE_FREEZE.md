# FEEDBACK-SDK-SURFACE-V1-001 Feedback SDK Public Surface Freeze
- ID：FEEDBACK-SDK-SURFACE-V1-001
- Owner：SDK Architect Agent
- Execution repo：`.`
- Execution branch：`feedback/sdk-surface-v1-001-freeze`
- Platform API mode：`READ_ONLY`
- SDK public API mode：`READ_ONLY`
- Governance state：public-surface proposal/freeze only; no SDK production/public export mutation in this Story.
- Required upstream：`FEEDBACK-ARCH-V1-001 = DONE / REVIEW PASS`.
- Architecture authority：`docs/multi_agent/contracts/FEEDBACK_PROVIDER_ARCHITECTURE_V1.md`.

## Purpose
Freeze the smallest App-facing SDK surface for provider-neutral Feedback V1 before any serial Owner edits `lib/nebula_sdk.dart`, `lib/src/nebula.dart`, `lib/src/capabilities.dart`, or API snapshots.

The architecture has already selected **entry/session only** for V1. This Story must turn that decision into an exact, backward-compatible public SDK shape without exposing provider routing, provider IDs, trusted identity inputs, Flutter UI, or Native submit models.

## Required output
Create exactly one independently reviewable artifact:

- `docs/multi_agent/contracts/FEEDBACK_SDK_PUBLIC_SURFACE_V1.md`

## Mandatory decisions
The freeze MUST mechanically decide:

1. Whether the public capability is named `NebulaFeedback` or another generic product-neutral name.
2. Whether the entry operation returns `Uri?`, a tiny result type, or another minimal shape; justify every new public symbol.
3. Exact cancellation semantics using the existing `NebulaCancellationToken` public type if needed.
4. Exact disabled/unconfigured semantics versus transport/API failure semantics.
5. Whether `Nebula` facade gains an optional or required Feedback member, with backward-compatibility proof for existing RC1 consumers.
6. Whether `Nebula` constructor needs a new optional parameter and the exact default behavior.
7. Whether any new barrel export from `lib/nebula_sdk.dart` is necessary.
8. API-surface symbol delta prediction and exact serial-owned paths for later implementation.
9. HTTPS / first-party origin validation responsibility exposed by public semantics without exposing provider URL selection.
10. Proof that App code cannot pass `app_id`, installation identity, region, provider name, TXC product ID/private key or provider URL.
11. Proof that the SDK remains pure Dart and does not own WebView/navigation/UI.
12. Proof that V1 exposes no native submit/attachment/reply/provider DTOs.
13. Error/versioning behavior if a later Native provider is added behind the same entry operation.
14. Product-name erasure proof: no NFC Writer/FlyPost/Nearvia/StarSprout-specific symbol or field.

## Surface minimization preference
The reviewed architecture prefers a shape semantically no larger than:

```dart
abstract interface class NebulaFeedback {
  Future<Uri?> entry({
    NebulaCancellationToken? cancellationToken,
  });
}
```

This is an input constraint, not permission to edit production code in this Story. The freeze may choose an even smaller/equally safe representation if it proves disabled/error semantics and backward compatibility.

## Forbidden
- Any mutation under `lib/**`.
- `lib/nebula_sdk.dart`, `lib/src/nebula.dart`, `lib/src/capabilities.dart` mutation.
- `governance/api_surface.snapshot` or `governance/public_api.txt` mutation.
- Running API-surface update.
- Backend/API/provider/App mutation.
- Adding `feedback` to capability entitlement IDs.
- Native submit implementation.
- TXC integration/credentials.
- Task Board/Sprint Board mutation by execution Agent.

## Verification
- Task Source Guard `FEEDBACK-SDK-SURFACE-V1-001` PASS.
- Cross Repo Guard PASS.
- `git diff --check` PASS.
- Production/public API diff = 0.
- Architecture contract consistency PASS.
- Independent SDK Architecture/Public Surface Review PASS on exact candidate.

## Exit
This Story ends at reviewed SDK public-surface freeze. It authorizes no actual `lib/**` mutation.

After canonical `DONE / REVIEW PASS`, Coordinator may register a separate `CHANGE_APPROVED` SDK surface implementation only after any required concrete Platform API dependency is also canonical, or explicitly structure the implementation so transport binding remains unavailable until that dependency closes.
