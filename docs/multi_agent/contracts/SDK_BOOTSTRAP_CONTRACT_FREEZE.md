# SDK Bootstrap Contract Freeze

- **Contract ID**：CONTRACT-SDK-BOOTSTRAP
- **Version**：2
- **Status**：RE-FROZEN / S1-F01-003 DELIVERY CANDIDATE（等待独立 Architecture Review Agent 验收）
- **Original freeze**：2026-08-07
- **Reconciled at**：2026-08-10T11:01:37+08:00
- **Reconciliation Story**：S1-F01-003
- **Backend authority**：FlyPostAPI `origin/Dev @ 956981c119b01a0c1b4bf0793a20bed8f31d1180`
- **Fixture authority**：`test/fixtures/bootstrap_contract_v2.json` + `bootstrap_request*.json` + `bootstrap_response.json`
- **SDK typed authority**：`lib/src/auth/installation.dart`（production read-only in S1-F01-003）

> V2 supersedes the stale V1 request requiredness/type/limit prose. S1-F01-003 is contract/tests/docs only: this file freezes the target truth but does **not** authorize production `lib/**` changes. Production closure belongs to S1-F01-004 after independent review and Coordinator promotion.

## 1. Endpoint and trust boundary

- **Method + path**：`POST /api/v1/mobile/bootstrap`
- **Public pre-installation endpoint**：no App Secret, no installation proof, no user token.
- **Backend chain**：`CoarseIPRateLimit(100, 1m)` → `BodyLimit(32 KiB)` → bootstrap handler.
- **Response envelope**：success and handler business errors use `{code,data}`; rate-limit middleware may use HTTP `429`/`503` with the same envelope.
- `environment` is **not a request wire field**. It is SDK-local configuration (`NebulaOptions.environment`) used with `baseUri`/storage namespace selection.
- `key_algorithm` is **not a request wire field**. V1 bootstrap fixes the key/proof family to ES256 / P-256; the response reports `proof_algorithm = "ES256"`.

## 2. Canonical request shape

The SDK-owned production serializer created by S1-F01-004 MUST emit exactly these 11 canonical keys. Required values are non-null. Optional values are emitted as JSON `null` when absent; the Backend may tolerate omitted/empty optional values, but that tolerance is not the canonical SDK representation.

| Wire field | Canonical wire value | Required value? | Limit / validation | Final V2 decision |
|---|---|---:|---|---|
| `app_id` | string | yes | 1..64 UTF-8 bytes | Public product/app key; not a credential. |
| `installation_id` | string | yes | 1..64 UTF-8 bytes | Stable per-install identity; UUID is the expected producer format. |
| `platform` | string enum | yes | `ios` / `android` / `harmony` / `web` | Exact lowercase wire enum. |
| `app_version` | string or null | no | if present: 1..128 UTF-8 bytes | Diagnostic value. Backend also accepts empty/omitted; SDK canonical unset = `null`. |
| `build_number` | string or null | no | if present: 1..128 UTF-8 bytes | Diagnostic value; canonical unset = `null`. |
| `os_version` | string or null | no | if present: 1..128 UTF-8 bytes | Diagnostic value; canonical unset = `null`. |
| `locale` | string or null | no | if present: 1..64 UTF-8 bytes | Routing/diagnostic hint only; never authorization. |
| `region` | string or null | no | if present: 1..64 UTF-8 bytes | Routing hint only; never authorization. |
| `public_key` | string | yes | 1..1024 UTF-8 bytes + valid key | Base64URL DER SubjectPublicKeyInfo containing an EC P-256 public key. Canonical producer SHOULD use unpadded Base64URL (fixture is 122 chars); Backend accepts padded/unpadded. |
| `attestation` | string or null | no | if present: 1..16384 UTF-8 bytes | Opaque typed-provider evidence encoded as a string. **Not an object.** `null` means no evidence / `not_supported`. |
| `bootstrap_request_id` | string | yes | 1..64 UTF-8 bytes | Stable idempotency key; UUID is the expected producer format. |

### 2.1 Length measurement

Backend validation uses Go `len(string)`, therefore the authoritative limit unit is **UTF-8 bytes after JSON decoding**, not Dart UTF-16 code units. S1-F01-004 must not implement these limits with plain `String.length` where non-ASCII input can differ.

The raw HTTP bootstrap body is capped at **32 KiB** by Backend middleware/handler. SDK serialization must stay inside that body limit in addition to per-field limits.

### 2.2 Requiredness vs Backend tolerance

Backend `BootstrapRequest` uses Go string zero values and validates only the five required logical inputs (`app_id`, `installation_id`, `platform`, `public_key`, `bootstrap_request_id`) as non-empty. Existing Backend success tests omit `locale`, `region`, and `attestation`. The SDK typed model already makes all six diagnostic/routing/evidence fields nullable.

V2 therefore freezes:

- required/non-null: `app_id`, `installation_id`, `platform`, `public_key`, `bootstrap_request_id`;
- optional/nullable: `app_version`, `build_number`, `os_version`, `locale`, `region`, `attestation`;
- canonical SDK serializer emits all 11 keys, using JSON `null` for absent optionals so fixtures and client wire shape remain stable.

## 3. Canonical response shape

All 10 response keys are present on successful Backend serialization. `minimum_supported_build` is the only nullable value.

| Wire field | Type / nullability | V2 semantics |
|---|---|---|
| `installation_token` | string, non-null | Short-lived installation capability token. |
| `expires_at` | int64 unix seconds | Server-authoritative expiry. Current default TTL = 24h. |
| `renew_after` | int64 unix seconds | Server-authoritative renewal point. Client consumes it as returned; it must not derive a different schedule from prose. Current Backend computes the 80% TTL point. |
| `server_time` | int64 unix seconds | Server time used for the response. |
| `app_id` | string, non-null | Echo of public `app_id`. |
| `installation_id` | string, non-null | Authoritative installation identity. |
| `proof_algorithm` | string, non-null | V1 fixed wire value `ES256`. |
| `attestation_state` | string enum, non-null | `verified` / `limited` / `not_supported`. |
| `minimum_supported_build` | string or null | Optional policy; current Bootstrap service returns `null`. |
| `request_id` | string, non-null | **Echo of `bootstrap_request_id` for this bootstrap operation**, not a second independently-generated request identifier. |

The response fixture is a paired exchange with the request fixture: `app_id`, `installation_id`, and `request_id == bootstrap_request_id` must agree. V2 also corrects the stale `renew_after` fixture to the Backend's current 80% TTL result.

## 4. Idempotency and retry

### 4.1 Server idempotency

- Idempotency scope is `(resolved app, bootstrap_request_id)`.
- Replaying the same request ID returns the authoritative existing/renewed installation fact and must not create a second installation.
- Reusing one request ID for a materially different identity/environment body is a conflict (`30001`).
- Current Backend request-hash comparison covers resolved App, installation ID, public-key thumbprint, platform, app version, build number, and OS version. Locale/region/attestation are not part of that hash.

The last point is an implementation tolerance, **not** permission for a client to mutate a retry. SDK V1 rule is stricter: once a `bootstrap_request_id` is assigned, the SDK MUST retry the **same immutable request object / same canonical serialized values**.

### 4.2 SDK automatic retry input

V2 client decision (carrying forward docs/08 §3 “one bounded retry with same bootstrap request ID”): S1-F01-004 must enforce **at most one automatic retry**:

- allowed: transport ambiguity (timeout/I/O failure with no definitive application response), current `50001` server failure, or allocated `12004` temporarily-unavailable category if returned;
- same `bootstrap_request_id` and same canonical request values are mandatory;
- `12001`, `30001`, client-outdated `12003`, and rate-limit `40002` are not immediate automatic retry inputs;
- HTTP `429` / code `40002` must honor rate-limit semantics; no immediate loop;
- HTTP `503` + code `40002` from the coarse limiter's fail-closed dependency path is also not an immediate retry loop.

No retry may generate a new request ID for the same logical bootstrap attempt.

## 5. Bootstrap error mapping truth

Authoritative Backend bootstrap currently exposes these concrete outputs:

| HTTP | code | Current cause class | SDK action input |
|---:|---:|---|---|
| 200 | `0` | success | parse `BootstrapResult` |
| 200 | `12001` | request validation failure, unknown/disabled App, invalid public key, invalid attestation | invalid bootstrap/install identity; no automatic retry |
| 200 | `30001` | malformed/oversize JSON at handler or idempotency/body conflict | invalid request; no retry |
| 429 | `40002` | coarse IP rate limit exceeded | rate limited; no immediate retry |
| 503 | `40002` | coarse rate-limit backend unavailable (fail-closed) | unavailable/rate-limit boundary; bounded external backoff, no immediate loop |
| 200 | `50001` | unclassified repository/server failure | V2 client decision: may consume the single bounded retry; must never map to authentication-required |

`12003` (client outdated) and `12004` (temporarily unavailable) remain allocated platform error categories and SDK classifiers, but the authoritative Bootstrap service at `956981c...` does not currently emit them. V2 must not describe them as observed Bootstrap outputs.

## 6. Serialization ownership

Canonical request serialization is an **SDK production responsibility**. S1-F01-004 must provide one SDK-owned serializer (`BootstrapRequest.toJson()` or an equivalent non-App-owned production serializer) and a typed Bootstrap client. The transport continues to JSON-encode the SDK-owned map.

Test-local `bootstrapRequestToWire` / `bootstrapRequestFromWire` helpers are reconciliation oracles only. They are not a supported production seam and must not be copied into NFC Writer, StarSprout, FlyPost, or another consumer.

## 7. Endpoint constant obligation

S1-F01-004 must define an SDK-owned canonical endpoint surface equivalent to:

```dart
BootstrapEndpoints.bootstrap == '/api/v1/mobile/bootstrap'
```

Consumers must not hardcode that path.

## 8. Product-name erasure / scope

This contract contains only platform foundation concepts: App, installation, environment selection, key/proof, bootstrap, runtime trust. No NFC Writer/NDEF/tag/passport/dynamic-note semantics are permitted in the SDK request or client.

## 9. S1-F01-004 carry-forward production deltas

The reconciled contract intentionally leaves these production diffs for S1-F01-004:

1. add SDK-owned bootstrap endpoint constant;
2. add SDK-owned canonical request serialization;
3. add typed SDK bootstrap client and bounded retry/error mapping;
4. change request validation limits to Backend truth (`64/128/64/1024/16KiB` as applicable);
5. measure string limits in UTF-8 bytes, not plain Dart `String.length`;
6. preserve nullable optional fields and string/null attestation semantics;
7. keep `environment` and `key_algorithm` out of the request wire;
8. test paired fixture semantics (`request_id` echo, server-authoritative `renew_after`).

No App production implementation is authorized by this contract freeze.

## 10. Change control

Any future request field/type/nullability/limit, endpoint, proof algorithm, idempotency, or response semantic change requires a new ACR/ADR path and independent review. Backend permissiveness alone is not authorization to expand the canonical SDK wire.
