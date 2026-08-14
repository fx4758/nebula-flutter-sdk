# S1-F02-002 SDK Runtime Config Client Closure

Status: **DELIVERED FOR INDEPENDENT REVIEW**

Canonical governance base: `main@ea6b46fdb6e6455ca7c131906017fceb8c44e907`
Pre-delivery verification subject: `9caf81ddfcd490d61168df7e4619ee1880bf0522`

## Delivery decision

The existing `NebulaConfigClient` and `NebulaEffectiveConfig` already satisfy the
Sprint 1 Runtime Config client contract. This Story therefore closes by reuse and
verification. It makes no SDK production-code change and no public API change.

The historical blockers recorded in
`S1-F02-002_SDK_RUNTIME_CONFIG_PRECHECK.md` are now closed:

- S1-F02-003 Backend frozen 8 KiB encoded-value and 64 KiB final-envelope limits
  are merged in FlyPostAPI PR #14 at
  `c8c6cdc7413ffef1b63729b6b3de54596a3a9ed9`.
- The independent review passed on exact Backend candidate
  `872badfd12d61af9fd3b7bdc0e61288d7770b992`.
- Backend post-merge Quality #73 passed for backend, go-sdk, and dart-sdk.
- Canonical SDK governance marks S1-F02-003 `DONE / REVIEW PASS`.

## Reuse map

| Required capability | Existing implementation | Verification |
| --- | --- | --- |
| Canonical aggregate endpoint and Installation Proof headers | `lib/src/config/config_endpoints.dart`, `lib/src/config/config_client.dart` | Runtime Config contract/client tests |
| Strict immutable snapshot mapping and client hard limits | `lib/src/config/effective_config.dart` | `runtime_config_contract_test.dart`, `f2r1_closure_test.dart` |
| TTL and ETag/304 revalidation | `NebulaConfigClient` | `config_client_test.dart` |
| Single-flight and bounded idempotent retry | `NebulaConfigClient` | client and hardening tests |
| stale-if-error with security-critical no-stale | `NebulaConfigClient` | client and hardening tests |
| Kill-switch non-caching and classified 12004 | `NebulaConfigClient` | client tests |
| Optional persistent cache and offline restart | `NebulaConfigClient` + `CacheStorage` | client and hardening tests |
| App-specific mapping | App Adapter from `NebulaEffectiveConfig` | No NFC/product fields added to SDK |

## Exact verification

Executed on `mac-mini-ci` through
`.ci-agent-tools/checkout-exact.sh` against the pre-delivery verification
subject:

- Task Source Guard: PASS
- Cross-repo Guard: PASS
- Governance: PASS
- API surface: PASS, 125 symbols match the frozen snapshot
- Focused Runtime Config suite: 39 tests passed
- `dart analyze`: no issues
- Full `dart test`: 211 tests passed
- `git diff --check`: PASS
- Production/public-surface diff from canonical base: empty

The final delivery commit adds only this closure report and the previously
reviewed precheck; formal PR CI remains authoritative for the exact PR head.

## Boundaries

- No changes under `lib/`.
- No changes to `lib/nebula_sdk.dart`.
- No update to `governance/api_surface.snapshot`.
- No Backend, App, NFC, public capability, or wire-contract mutation.
- No App repin: the SDK Runtime Config implementation remains byte-identical.
- Task Board and Sprint Board remain Coordinator-owned and untouched.
