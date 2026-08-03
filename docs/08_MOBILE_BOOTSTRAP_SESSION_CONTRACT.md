# Mobile Bootstrap and User Session Contract

Status: **TARGET FROZEN / BACKEND NOT IMPLEMENTED**

Architecture task: F0-02

Last evidence audit: 2026-08-03, flypost branch `codex/sprint-3-product-bindings`

本文只冻结信任边界、协议语义和验收条件。字段和端点标有 `CURRENT` 或 `TARGET`；编码 AI 禁止把 `TARGET` 当作现有后端事实。

## 1. Current evidence

### 1.1 Confirmed routes

| Route | Current middleware | Current fact |
| --- | --- | --- |
| `POST /api/v1/auth/code/send` | global/App HMAC + rate limit | 手机验证码；手机号另有 1/min 限流 |
| `POST /api/v1/auth/login` | global/App HMAC + rate limit | 只接受 `provider=PHONE, phone, code` |
| `POST /api/v1/auth/oauth/login` | global/App HMAC + rate limit | Provider code exchange is placeholder |
| `POST /api/v1/auth/refresh` | global/App HMAC + rate limit | refresh token in JSON body |
| `POST /api/v1/auth/logout` | global/App HMAC + rate limit | route is not under user Token middleware |
| `POST /api/v1/auth/device/register` | HMAC + rate + user Token + idempotent | 登录后登记 device public key |
| `POST /api/v1/app/token` | global/App HMAC + rate limit | server-to-server `client_credentials` |
| `GET /api/v1/sync/bootstrap` | HMAC + rate + user Token | Flypost business snapshot, not mobile trust bootstrap |

Evidence source: flypost `internal/router/router.go`, `internal/core/identity/auth_handler.go`, `internal/core/appidentity/handler.go`.

### 1.2 Confirmed contradictions and blockers

| ID | Severity | Current evidence | Architectural impact |
| --- | --- | --- | --- |
| MB-01 | P0 | all `/api/v1/*` requests require an HMAC App Secret | a public mobile binary cannot safely use the current entry chain |
| MB-02 | P0 | `/auth/logout` is registered outside Token middleware | current handler cannot obtain trusted `user_id/session_id` |
| MB-03 | P0 | refresh calls the normal token issuer, creating a new session row; old refresh session is not atomically rotated/revoked | replayed refresh tokens can remain valid and session rows grow |
| MB-04 | P0 | access/refresh claims omit trusted `app_id` and `installation_id` | multi-App/user scope cannot be derived from the user token alone |
| MB-05 | P1 | old Dart SDK sends username/password; actual user login is phone/code | SDK contract and runtime route disagree |
| MB-06 | P1 | response code returns `{code,data}`; old contract says `{code,msg,data}` | SDK envelope parser must follow runtime truth |
| MB-07 | P1 | nonce replay key is global `nonce:{nonce}` | different Apps/installations can collide; scope is not explicit |
| MB-08 | P1 | idempotency uses caller-provided `X-App-Id + X-Nonce` | trusted App scope is not used; replay nonce and business idempotency are conflated |
| MB-09 | P1 | device rate limit trusts raw `X-Device-Id` | attacker can rotate identifiers; authenticated requests must use installation claims |
| MB-10 | P1 | session comments and behavior disagree on Redis failure; nil Redis can accept sessions | outage behavior is neither consistently secure nor observable |
| MB-11 | P1 | Flutter Web CORS allowlist omits new/legacy App and installation proof headers | web clients cannot use the same contract without explicit header policy |
| MB-12 | P2 | `/oauth/login` provider exchange is placeholder | OAuth must not be advertised as production-ready |

F0-02 does not authorize fixes. Each blocker is assigned in `09_F0_02_IMPLEMENTATION_HANDOFF.md`.

## 2. Frozen trust model

Mobile binaries are public clients. The target chain is:

```text
public app_id
  + installation_id
  + hardware-backed key pair
  + optional platform attestation
        |
        v
short-lived installation token bound to key thumbprint
        |
        + user login/refresh
        v
user access token bound to app + installation + session
```

Rules:

1. `app_id` identifies a product; it is not a credential.
2. Mobile SDK never receives App Secret, Provider Secret or `client_credentials`.
3. The installation private key stays in platform secure hardware/storage and is non-exportable when supported.
4. A user access token cannot change App or installation scope by modifying headers/body.
5. App server tokens remain a separate server-to-server trust class using `X-App-Token`; they never enter the mobile SDK.
6. Admin tokens and APIs remain outside this contract.

## 3. Target protocol surface

The following endpoints are target contracts, not current routes.

| Endpoint | Trust before call | Purpose | Retry |
| --- | --- | --- | --- |
| `POST /api/v1/mobile/bootstrap` | public endpoint + IP/App rate limit + optional attestation | register/renew installation trust | one bounded retry with same bootstrap request ID |
| `POST /api/v1/mobile/auth/code/send` | installation token + proof | send login code | no automatic retry |
| `POST /api/v1/mobile/auth/login` | installation token + proof | PHONE login and session creation | no automatic retry |
| `POST /api/v1/mobile/auth/oauth/login` | installation token + proof | supported Provider login | no retry; disabled until real adapter exists |
| `POST /api/v1/mobile/auth/refresh` | installation token + proof + refresh token | atomic refresh rotation | single-flight; one request only |
| `POST /api/v1/mobile/auth/logout` | user access token + installation proof | revoke current session | idempotent, one bounded retry |
| `POST /api/v1/mobile/auth/device/bind` | user access token + installation proof | bind current installation to user | idempotent；**F0 契约外**（ADR-F008 注记，F1 实现） |

`/sync/bootstrap` keeps its Flypost business meaning and must never be reused for installation bootstrap.

## 4. Mobile bootstrap contract

### 4.1 Request

Required logical fields:

```text
app_id                 public product identifier
installation_id        random UUID generated once per install
platform               ios/android/harmony/web
app_version             semantic display version
build_number            store build identifier
os_version              bounded diagnostic value
locale / region         bounded routing hints, never trusted authorization
public_key              ES256/P-256 public key
attestation             optional typed platform evidence
bootstrap_request_id    UUID idempotency key
```

Limits:

- body maximum: 32 KiB;
- string maximum: 128 characters unless provider evidence requires more;
- attestation maximum: 16 KiB;
- one active key per installation version; replacement requires re-attestation or explicit recovery;
- unknown/disabled App and invalid attestation return indistinguishable public denial categories.

### 4.2 Response

```text
installation_token
expires_at
renew_after
server_time
app_id
installation_id
proof_algorithm = ES256
attestation_state = verified/limited/not_supported
minimum_supported_build (optional)
request_id
```

The installation token is capability-poor. It permits only bootstrap/config/version/auth entry calls. It cannot call payment, AI, asset upload, notification send or Admin APIs.

### 4.3 Token lifetime

- default installation token TTL: 24 hours;
- client renews after 80% TTL with jitter;
- server may shorten TTL by App/risk/platform;
- no permanent offline token;
- reinstall or secure-key loss creates a new installation identity, never recovers the old private key.

## 5. Proof-of-possession

Requests protected by installation trust carry:

```text
X-Installation-Token
X-Proof-Timestamp
X-Proof-Nonce
X-Device-Proof
X-Request-Id
```

Canonical proof input:

```text
VERSION\n
METHOD\n
PATH\n
TIMESTAMP\n
NONCE\n
BODY_SHA256\n
INSTALLATION_TOKEN_SHA256
```

Frozen rules:

- algorithm: ES256/P-256 for V1;
- URL query is canonicalized separately or excluded by explicit endpoint contract; it must not be ambiguous;
- timestamp tolerance: server-configured, maximum 5 minutes;
- replay key scope: `app_id + installation_id + nonce`;
- replay protection is distinct from business idempotency;
- proof failure never falls back to legacy global HMAC;
- key status, installation status and App status are checked before business execution.

## 6. User session contract

### 6.1 Claims

Target access and refresh claims include:

```text
iss / aud / sub / jti / iat / exp
scope = user
app_id
user_id
installation_id
session_id
token_version
```

Tokens for App A are invalid at App B even for the same global user. `aud` identifies the mobile platform API, not an external Provider.

### 6.2 Lifetimes and storage

| Item | Default | Storage |
| --- | --- | --- |
| access token | 15 minutes | memory; encrypted persistence only if startup restoration requires it |
| refresh token | 30 days maximum, server configurable | secure storage only |
| installation token | 24 hours default | secure storage |
| installation private key | installation lifetime | platform secure key store, non-exportable when available |

Raw tokens are never logged, included in Analytics, crash breadcrumbs or error messages.

### 6.3 Refresh rotation

Refresh is an atomic state transition:

```text
validate current refresh hash + session + app + installation
  -> mark current refresh generation consumed
  -> issue next access/refresh generation in same session
  -> persist next hash
  -> commit
```

Rules:

- SDK permits one refresh Future per session; concurrent callers await it;
- a consumed refresh token reused later revokes the session family and emits a security audit event;
- network ambiguity uses the same refresh request ID; client never launches parallel refresh attempts;
- rotation does not create an unrelated session row;
- refresh failure categories distinguish expired/revoked from retryable platform unavailable, without exposing account existence.

### 6.4 Logout

- logout is under user Token + installation proof middleware;
- revocation is scoped to current `app_id + user_id + installation_id + session_id`;
- repeated logout returns success;
- local access/refresh state is cleared even when the network call fails;
- “logout all devices” is a separate high-risk operation and not implied by normal logout.

## 7. SDK session state machine

```text
UNINITIALIZED
  -> BOOTSTRAPPING
  -> INSTALLATION_ACTIVE
  -> AUTHENTICATING
  -> AUTHENTICATED
  -> REFRESHING -> AUTHENTICATED
  -> SIGNING_OUT -> INSTALLATION_ACTIVE

Any state -> RECOVERABLE_FAILURE
Any trusted state -> REVOKED -> BOOTSTRAPPING
```

Rules for implementation AI:

- state transitions are serialized per SDK instance;
- a refresh failure never loops back into interceptor refresh recursively;
- changing environment or App ID creates a different storage namespace and SDK instance;
- no global mutable token singleton;
- capability clients receive session state through a Port, not by reading storage directly.

## 8. Error and HTTP semantics

Current flypost envelope truth is:

```json
{"code": 0, "data": {}}
```

There is no response `msg`. SDK localizes known codes and preserves unknown integer code plus request ID.

Target categories:

| Category | Examples | Client action |
| --- | --- | --- |
| invalid_installation | revoked/expired/proof invalid | clear installation token and bootstrap once |
| authentication_required | access missing/expired | single-flight refresh if refresh exists |
| session_revoked | refresh reuse/logout/token version | clear user session; do not retry |
| rate_limited | HTTP 429/code 40002 | honor `Retry-After`; no immediate loop |
| client_outdated | minimum build policy | block or recommend upgrade by server policy |
| temporarily_unavailable | auth state store/provider unavailable | bounded backoff; preserve safe local state |
| invalid_request | bounded validation failure | no retry |

Exact new integer codes are a flypost contract task. SDK implementation must not invent them before F0-04 fixtures are frozen.

## 9. Availability and abuse isolation

- bootstrap, login/config and high-cost capabilities use separate server rate-limit buckets and concurrency pools;
- authenticated rate limits derive installation/App from verified claims, not raw device headers;
- public bootstrap applies IP, App and risk limits before database writes;
- unknown installation attempts do not create unlimited rows; accepted creation has per-IP/App/device budgets and retention;
- Redis/session-store failure never silently converts into unlimited trusted access;
- access validation may use a bounded, observable fallback to the authoritative session record;
- login/refresh cannot report success until revocable session state is durably recorded;
- every denial includes request ID and low-cardinality reason metrics; no PII labels.

## 10. Compatibility boundary

Legacy HMAC and target installation proof are separate authentication schemes:

```text
legacy client -> legacy HMAC middleware -> compatibility routes
new client    -> installation proof middleware -> target mobile routes
```

They may coexist during migration, but a failed new proof must never fall back to legacy HMAC. The legacy scheme receives a version/store-build cutoff in F0-03.

## 11. F0-02 architecture acceptance

- current and target routes are explicitly separated;
- mobile App Secret and mobile `client_credentials` are prohibited;
- trusted App/User/Installation/Session scope is defined;
- bootstrap, proof, refresh rotation and logout semantics are frozen;
- replay nonce and business idempotency are separated;
- response-envelope contradiction is resolved in favor of runtime evidence;
- all current blockers have an owner task and objective acceptance evidence;
- no SDK or flypost implementation is included in this architecture task.
