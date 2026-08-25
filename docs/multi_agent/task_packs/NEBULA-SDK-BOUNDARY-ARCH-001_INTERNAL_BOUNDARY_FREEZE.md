# NEBULA-SDK-BOUNDARY-ARCH-001 — SDK Internal Boundary Hardening Freeze

ID：NEBULA-SDK-BOUNDARY-ARCH-001
Execution repo：`.`
Execution branch：`architecture/NEBULA-SDK-BOUNDARY-ARCH-001-freeze`
Platform API mode：`READ_ONLY`
SDK public API mode：`READ_ONLY`

- ID: `NEBULA-SDK-BOUNDARY-ARCH-001`
- Owner: SDK Boundary Architecture Agent
- Reviewer: SDK Architecture Review Agent
- Execution repo: `.`
- Execution branch: `architecture/NEBULA-SDK-BOUNDARY-ARCH-001-freeze`
- Execution remote: `hub`
- Execution worktree: `wt-nebula-sdk-boundary-arch-001`
- Platform API mode: `READ_ONLY`
- SDK public API mode: `READ_ONLY`
- Product adapter rule: `ADAPTER_FIRST`
- State write authority: Coordinator only
- Story type: architecture freeze only

## Triggering evidence

Fresh architecture audit on `nebula-flutter-sdk main@115cc1ef0f36ead0ac11800016197826b659b5c4` found that the multi-App/product boundaries remain healthy, but the shared request-proof Port is physically owned by `lib/src/auth/proof.dart`. This creates current import edges `transport -> auth`, `config -> auth`, `analytics -> auth`, and `error_reporting -> auth` even though the dependency is a product-neutral proof-signing Port rather than Auth business behavior.

This is a P1 internal layering debt, not permission to redesign public Auth/Platform semantics.

## Required freeze output

Create exactly one architecture contract:

`docs/multi_agent/contracts/SDK_INTERNAL_BOUNDARY_HARDENING.md`

The contract MUST freeze all of the following without changing production code.

### 1. Shared proof Port ownership

Freeze a security-neutral/foundation-level physical home for shared request-proof abstractions currently rooted in `auth/proof.dart`, including at minimum `RequestProofSigner` and its canonical proof input/value types.

The later implementation must:

- remove lower-layer/capability dependence on Auth solely to obtain the shared proof Port;
- preserve the existing proof algorithm/wire semantics;
- preserve umbrella `package:nebula_sdk/nebula_sdk.dart` consumer semantics;
- preserve existing public symbols and compatibility unless a separately reviewed public-surface Story proves an unavoidable change;
- not move user-session, EMAIL/PHONE/OAuth, refresh/logout, or provider logic into foundation.

### 2. Layer Graph Guard

Freeze a mechanical import-graph gate for SDK production code. At minimum it must fail when:

- foundation depends on transport/storage/capabilities;
- transport or storage depend on Auth/Config/Analytics/Error Reporting/Asset/Notification/Payment/AI product-capability modules;
- one sibling capability directly imports another sibling capability when the dependency can be expressed as a shared Port/event;
- a new exception is added without explicit architecture registration.

Composition roots/facades may wire capabilities, but the exception set must be explicit and minimal. The freeze must define how existing transitional edges are removed before the guard becomes blocking so the guard never blesses its own violation.

### 3. Product-Erasure Guard

Freeze a production-SDK guard that rejects product-specific semantics from `lib/**`. It must cover at minimum:

- registered consumer/product names and product-domain models/verbs;
- Flutter UI/navigation types or product UI routing;
- direct runtime plugin dependencies in the pure-Dart core unless separately approved by architecture/package governance;
- provider/product secrets or App-specific identifiers;
- product behavior pushed upward merely to reduce Adapter mapping.

The guard must support explicit reviewed exceptions to avoid brittle keyword-only false positives, but default behavior is fail-closed for new product coupling.

### 4. Multi-App Isolation Regression

Freeze a deterministic regression suite proving two distinct App identities cannot share mutable SDK state accidentally. At minimum cover:

- token namespace by environment + app identity;
- Runtime Config cache by environment + app identity plus existing installation/build/schema dimensions;
- Analytics consent/queue isolation;
- Error Reporting queue isolation;
- user-scoped storage separation where applicable;
- Backend trusted `app_id + installation_id` separation remains a cross-repo invariant, without Backend mutation in this Story.

The implementation test may use fake/in-memory storage; it must not require production provider credentials.

## Public API compatibility rule

This architecture Story freezes an **internal boundary repair**. Target public API delta is `0`.

The implementation plan must prefer physical relocation/internal imports plus compatibility re-export where necessary. If the Architecture owner concludes any public symbol addition/removal/rename is required, this Story must stop and raise a separate SDK public-surface change Story before production mutation.

## Explicitly forbidden

- `lib/**` mutation;
- `governance/api_surface.snapshot` mutation;
- Backend mutation;
- NFC Writer mutation;
- Nearvia mutation;
- new Asset/Notification/Payment/AI capability;
- Auth V2 behavior change;
- Platform endpoint/request/response/error/trust-scope change;
- provider acquisition or provider credentials;
- product-specific model promotion into SDK;
- implementation Agent editing Task Board state.

## Architecture freeze verification

Before exact SHA is frozen, the owner must mechanically record:

1. fresh canonical SDK main exact SHA;
2. current API surface count and product/runtime dependency baseline;
3. current import edges that motivated the debt;
4. current consumer Adapter evidence for at least NFC Writer, plus Nearvia canonical/candidate status if relevant, as evidence that the hardening preserves Adapter-first rather than redesigning it;
5. `Task Source Guard`;
6. `Cross Repo Guard`;
7. `git diff --check`;
8. production/API snapshot delta = 0.

## Exit / handoff

Architecture owner delivers docs-only PR + frozen exact SHA. Then:

`Formal CI / Execution Coordinator -> terminal SUCCESS/FAILURE -> independent SDK Architecture Review`.

Only after exact-head APPROVED review and canonical Coordinator closure may a separate implementation Story authorize `lib/**`, guard tooling and regression-test changes. No self-review and no self-merge.
