# S1-F01-003 — Bootstrap Contract Reconciliation Delivery

- Story: `S1-F01-003`
- Owner: SDK Contract Agent D
- Reviewer: Architecture Review Agent
- Execution repo: `nebula-flutter-sdk`
- Branch: `s1/f01-003-bootstrap-contract-reconcile`
- Backend authority re-fetched at Story execution: `FlyPostAPI origin/Dev @ 956981c119b01a0c1b4bf0793a20bed8f31d1180`
- Delivery status: **RECONCILED / PENDING INDEPENDENT REVIEW**
- Production SDK diff: **forbidden / expected 0**
- Story-owned Backend/App production diff: **0** (Backend worktree had pre-existing unrelated dirtiness; authority evidence was read with `git show` at the exact commit and no Backend write was performed).

## 1. Verdict

The four sources can be reconciled without changing Backend production behavior. Option A from `ACR-SDK-BOOTSTRAP-001` is the delivery recommendation:

`Backend truth + fixture truth -> re-freeze contract/tests -> S1-F01-004 production SDK closure`.

This Agent does **not** self-approve DONE and does not promote S1-F01-004.

## 2. Request field matrix

| Field | Backend type / validation | Backend required? | Fixture | SDK model @ 543894c | Stale V1 freeze | Final V2 decision |
|---|---|---:|---|---|---|---|
| `app_id` | Go `string`; non-empty; max 64 bytes | yes | string | `String` required; generic max 128 code units | string required | required string; max 64 UTF-8 bytes |
| `installation_id` | Go `string`; non-empty; max 64 bytes | yes | UUID string | `String` required; max 128 code units | string required | required string; max 64 UTF-8 bytes |
| `bootstrap_request_id` | Go `string`; non-empty; max 64 bytes | yes | UUID string | `String` required; max 128 code units | string required | required string; max 64 UTF-8 bytes; stable idempotency key |
| `platform` | Go `string`; exact `ios/android/harmony/web` | yes | `ios` | `NebulaPlatform` required | string required | required exact lowercase enum |
| `app_version` | Go `string`; max 128 bytes; empty/omitted accepted | no | string | `String?` | required | optional nullable; present 1..128 UTF-8 bytes |
| `build_number` | Go `string`; max 128 bytes; empty/omitted accepted | no | string | `String?` | required | optional nullable; present 1..128 UTF-8 bytes |
| `os_version` | Go `string`; max 128 bytes; empty/omitted accepted | no | string | `String?` | required | optional nullable; present 1..128 UTF-8 bytes |
| `locale` | Go `string`; max 64 bytes; empty/omitted accepted | no | string | `String?`; generic max 128 | required | optional nullable; present 1..64 UTF-8 bytes |
| `region` | Go `string`; max 64 bytes; empty/omitted accepted | no | string | `String?`; generic max 128 | required | optional nullable; present 1..64 UTF-8 bytes |
| `public_key` | Go `string`; non-empty; max 1024 bytes; Base64URL SPKI parsed and must be EC P-256 | yes | real unpadded Base64URL P-256 SPKI (122 chars) | `String` required; max 4096 code units; encoding not validated | required | required Base64URL P-256 SPKI; max 1024 UTF-8 bytes; canonical producer unpadded |
| `attestation` | Go `string`; max 16KiB; blank means no evidence; verifier receives string | no | `null` | `String?`; non-empty if present; max 16Ki code units | **object required** | optional nullable **string**; canonical no-evidence = `null`; if present 1..16KiB UTF-8 bytes |
| `environment` | absent from Backend request | n/a | absent | exists in `NebulaOptions`, not BootstrapRequest | absent | **not a wire field**; SDK-local environment/baseUri selection |
| `key_algorithm` | absent from Backend request; P-256 verified from key | n/a | absent | absent | absent | **not a wire field**; V1 fixed ES256/P-256, response reports `proof_algorithm` |

### Requiredness evidence

Backend `validRequest()` and handler success paths omit `locale`, `region`, and `attestation`. Service validation checks non-empty only for App ID, installation ID, request ID, platform, and public key. This aligns with SDK nullable diagnostics and contradicts the V1 freeze's “all required” statement.

## 3. Request serialization decision

Canonical SDK production serialization ownership is frozen to S1-F01-004, not the App:

- emit exactly the 11 canonical request keys;
- required values non-null;
- optional values emitted as JSON `null` when unset;
- App must never duplicate the map or endpoint;
- test-local helpers remain reconciliation-only until replaced by production serializer tests.

This preserves a stable fixture shape while remaining compatible with Backend's more permissive omitted/empty optional handling.

## 4. Response reconciliation

| Field | Backend @ 956981c | Fixture before S1-F01-003 | SDK | Final decision |
|---|---|---|---|---|
| `expires_at` | unix seconds; default now+24h | +24h | parses unix seconds | aligned |
| `renew_after` | absolute unix seconds; current implementation = 80% TTL point | **only +4320s (72m)** | parses value without semantic check | fixture drift: correct to +69120s (19.2h); client treats server value as authoritative |
| `request_id` | set to incoming `bootstrap_request_id` | **different unrelated req-* value** | plain required String | fixture drift: paired response must echo request fixture `bootstrap_request_id` |
| `proof_algorithm` | `ES256` | `ES256` | enum parser accepts `ES256` | aligned |
| `attestation_state` | `verified/limited/not_supported`; no evidence -> `not_supported` | `not_supported` | enum parser supports all 3 | aligned |
| `minimum_supported_build` | `*string`; current service leaves nil -> JSON null | null | `String?` | aligned; response key present, value nullable |

Two response fixture drifts were not called out in the original ACR and are fixed by this Story: wrong renewal point and wrong request-id pairing.

## 5. Length-unit drift discovered

Backend Go validation uses `len(string)` -> UTF-8 byte length. SDK production validation currently uses Dart `String.length` -> UTF-16 code units. The numeric limits alone are therefore insufficient to reconcile wire behavior, especially for non-ASCII optional strings/attestation.

V2 freezes all Backend field caps in **UTF-8 bytes after JSON decoding**. S1-F01-004 must implement byte-count validation (or a stricter explicitly-frozen ASCII format for a field) rather than silently copying numeric constants with `String.length`.

## 6. Idempotency/retry decision

Backend ledger identity: `(resolved app, bootstrap_request_id)`.

Current Backend rejects same request ID with a different hashed identity/environment body. The current hash includes app, installation, public-key thumbprint, platform, app version, build number, and OS version; it does not include locale/region/attestation.

Canonical SDK rule is intentionally stricter: a retry reuses the exact same request ID **and the same immutable canonical request values**. Backend hash omissions are compatibility tolerance, not a client mutation feature.

V2 carries forward docs/08 §3 as an **at-most-one automatic retry** ceiling using the same immutable request. Transport ambiguity and current `50001` server failure may consume that retry; allocated `12004`, if a future Bootstrap path emits it without a contract change, uses the same bounded-unavailable semantics. No immediate retry for `12001`, `30001`, `12003`, or `40002` / HTTP 429/503 rate-limit boundary.

## 7. Bootstrap error truth

Observed authoritative Bootstrap outputs:

- `200 / 0`: success;
- `200 / 12001`: invalid request validation / unknown App / invalid key or attestation;
- `200 / 30001`: malformed/oversize JSON or idempotency conflict;
- `429 / 40002`: coarse IP limit exceeded;
- `503 / 40002`: coarse limiter dependency failure (fail-closed);
- `200 / 50001`: unclassified server/repository failure.

`12003` and `12004` remain allocated shared mobile error categories but are not current Bootstrap service outputs at the authority commit. The old freeze must not imply otherwise.

## 8. F01-004 required production closure

After independent PASS and Coordinator `WAIT -> READY`, F01-004 must close exactly these production gaps:

1. `BootstrapEndpoints.bootstrap` canonical endpoint;
2. SDK-owned request serializer;
3. SDK-owned typed bootstrap client;
4. exact Backend limits, including locale/region 64 and public key 1024;
5. UTF-8-byte validation unit;
6. nullable string attestation and nullable diagnostic/routing fields;
7. bounded same-ID/same-body retry and bootstrap-specific error mapping;
8. production tests replacing test-local serializer ownership.

No NFC Writer/product semantics belong in that API.

## 9. Evidence anchors

Backend authority (`956981c119...`):

- `internal/core/installation/service.go`: request/result structs, attestation verifier, exact validation, P-256 SPKI validation, idempotency response construction.
- `internal/core/installation/handler.go`: 32KiB body cap and error mapping.
- `internal/core/installation/handler_test.go`: successful request omits locale/region/attestation.
- `internal/core/installation/service_test.go`: `validRequest()` omission and validation tests.
- `internal/core/installation/repository_test.go`: same-request-ID different-body conflict.
- `internal/router/router.go`: public `/api/v1/mobile` group and coarse rate/body middleware.
- `internal/middleware/ratelimit.go`: HTTP 429/503 + code 40002 behavior.
- `internal/pkg/response/response.go`: `{code,data}` envelope / HTTP semantics.

SDK/fixture authority:

- `lib/src/auth/installation.dart` (read-only in this Story).
- `lib/src/foundation/options.dart` (`environment` is SDK-local).
- `test/fixtures/bootstrap_contract_v2.json` (machine-readable V2 oracle; not runtime config).
- `test/fixtures/bootstrap_request.json` / `bootstrap_request_optional_nulls.json`.
- `test/fixtures/bootstrap_response.json`.
- `test/bootstrap_contract_reconciliation_test.dart`.
- `test/cross_repo_contract_test.dart`.
- `test/contract_fixtures_test.dart`.

## 10. Reviewer gate

Reviewer must independently verify the real files/commit and must reject if:

- any `lib/**` production diff exists in S1-F01-003;
- Backend or NFC Writer was modified;
- response fixture pairing does not match Backend behavior;
- V2 still calls attestation an object or makes all diagnostics required;
- numeric limits are copied without the UTF-8-byte unit;
- task board/state was edited by this implementation Agent;
- S1-F01-004 is promoted before independent PASS.
