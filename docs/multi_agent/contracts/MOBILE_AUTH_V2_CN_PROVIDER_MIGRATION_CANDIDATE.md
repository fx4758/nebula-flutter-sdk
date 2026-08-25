# Mobile Auth V2 CN Provider Migration Candidate — WECHAT / QQ

> Status: **NON-CANONICAL CANDIDATE / IMPLEMENTATION BLOCKED**
> Story: `AUTH-V2-CN-PROVIDER-ARCH-001`
> Base Auth contract: `MOBILE_AUTH_V2.md`
> Backend baseline: FlyPostAPI `Dev@d9ad6c3c0e9186e574081e22d88450d93542fd29`
> Candidate decision authority: none until a later approved `CONTRACT_CHANGE`.

## 1. Purpose
Describe the smallest provider-proof extension needed to migrate existing NFC Writer WECHAT/QQ login into the existing Nebula account/session authority without copying the legacy client-trust model. This document does not amend `MOBILE_AUTH_V2.md`, authorize public SDK symbols/endpoints, or authorize production code.

## 2. Retained Auth V2 invariants
Unchanged:
```text
PHONE_CODE
EMAIL_PASSWORD
APPLE
GOOGLE
InstallationProof App authority
Nebula access/refresh session lifecycle
refresh/logout/reset revocation semantics
low-cardinality auth errors
```
No WECHAT/QQ work may weaken these or introduce a second session/token authority.

## 3. Acquisition vs verification boundary
```text
Consumer App
  +-- WeChat OpenSDK -> temporary authorization code
  +-- Tencent QQ SDK -> provider credential (exact frozen type pending official evidence)
           |
           v
Nebula SDK typed provider proof
           |
           v
Nebula Backend provider verifier adapter
           |
           v
VerifiedProviderIdentity(app_id, provider, subject, verified_aliases)
           |
           v
existing Nebula user_identity / session issuance
```
App owns provider UI/SDK acquisition only. Backend owns provider secret/config, exchange/introspection, subject verification, identity reconciliation and session issuance.

## 4. Candidate proof model

### 4.1 WECHAT
Candidate typed proof:
```text
WeChatAuthorizationCode(code)
```
Candidate verifier behavior:
1. select WECHAT config by trusted Nebula `app_id` from InstallationProof;
2. exchange temporary code using server-held WeChat AppID/AppSecret;
3. require successful provider response and non-empty `openid`;
4. use returned `openid` as App-scoped verified subject;
5. retain verified `unionid`, if present, only as secondary alias metadata initially;
6. never return provider token/refresh token to SDK/App;
7. never automatically retry an ambiguous consumed authorization code.

### 4.2 QQ
Candidate typed proof category:
```text
QQSdkCredential(<bearer credential>)
```
**Exact public/wire type is intentionally NOT frozen in this candidate.**

Candidate verifier direction:
1. select QQ config by trusted Nebula `app_id`;
2. validate/introspect the Tencent SDK credential against QQ provider API;
3. require provider response to identify both application/client identity and non-empty `openid`;
4. require returned provider application/client identity to equal server-configured QQ App ID;
5. only then use `openid` as App-scoped verified subject;
6. optional verified `unionid` is secondary alias metadata only;
7. never trust caller-supplied openid/appid/profile.

Final proof lifetime, expiry, replay and exact provider endpoint requirements remain blocked pending current official Tencent documentation evidence.

## 5. Candidate normalized identity
```text
VerifiedProviderIdentity {
  appId: trusted Nebula app identity,
  provider: WECHAT | QQ,
  subject: provider-verified App-scoped openid,
  aliases: optional verified provider aliases such as unionid,
}
```
Primary uniqueness key:
```text
(app_id, provider, subject)
```
`unionid` is not a global automatic account-merge key. Provider aliases may support a separately governed linking/migration operation only after collision checks and user-security semantics are frozen.

## 6. Legacy migration candidate
Use migration alias evidence rather than rewriting historical user IDs. Conceptual alias:
```text
LegacyProviderAlias {
  app_id,
  provider,
  legacy_provider_uid,
  nebula_user_id,
  migration_state,
}
```
Cutover algorithm:
```text
verify proof
 -> verified App/provider/subject
 -> existing new identity? use it
 -> else exactly one matching legacy alias? bind to existing user
 -> else zero? normal new-user policy
 -> else ambiguous/collision? fail closed
```
Forbidden automatic ownership inputs: nickname, avatar, gender, unverified email, client-supplied openid/unionid, or unionid alone across Nebula Apps. A pre-cutover duplicate/collision report is mandatory.

## 7. Candidate Backend adapter boundary
A future contract-change may add provider-specific verifiers behind the existing Auth service, conceptually:
```text
ProviderProofVerifier.verify(appID, proof)
  -> VerifiedProviderIdentity
```
APPLE/GOOGLE OIDC may remain specialized internally. Platform contract must not force QQ into OIDC/JWT semantics it does not provide. Provider secrets/config remain server-side and App-scoped.

## 8. Candidate SDK direction
A future SDK amendment should expose typed acquisition proof rather than caller-authored identity fields. Direction only:
```text
NebulaAuth.loginWithProviderProof(...)
WeChatAuthorizationCode
QQSdkCredential
```
or equivalent typed constructors integrated into `NebulaLoginRequest` after public-surface review.

Forbidden direction:
```text
login(provider: "QQ", openid: callerValue, nickname: ...)
login(provider: "WECHAT", unionid: callerValue, ...)
```
No exact public symbol or wire field here is frozen by this Story.

## 9. Secret / privacy rules
- provider AppSecret/client secret stays Backend-only;
- legacy exposed WeChat secret must be rotated before production cutover;
- provider code/access token/refresh token never enters persistent SDK token storage;
- provider credentials are excluded from logs, Analytics, Error Reporting, crash context and push payloads;
- provider profile is optional presentation metadata, not identity authority;
- raw provider failure bodies are not surfaced to App.

## 10. Replay / retry
WECHAT:
- authorization code is single-use;
- no automatic provider exchange replay after ambiguous consumption;
- terminal invalid/reused proof requires fresh App authorization.

QQ:
- final replay/expiry rules are **UNFROZEN** pending official protocol evidence;
- Backend must at minimum bind verified provider application/client identity to trusted Nebula App config before accepting subject.

## 11. Rollout / rollback candidate
Rollout gates per App/provider:
```text
provider config present
+ secret rotation complete
+ verifier health check
+ legacy collision audit clean
+ contract/backend/sdk/app exact reviews closed
```
Rollback disables provider acquisition/verification only. It must not delete existing provider identities or invalidate unrelated PHONE/EMAIL/APPLE/GOOGLE sessions.

## 12. Promotion blockers
This candidate cannot become a frozen Platform contract until:
1. second distinct canonical consumer evidence exists;
2. current official Tencent QQ proof documentation closes proof-type/replay gap;
3. legacy identity migration/collision evidence is reviewed;
4. independent Architecture Review approves a later `CONTRACT_CHANGE` exact candidate.

Current disposition:
```text
Candidate useful for migration planning     YES
Canonical Platform contract                 NO
Backend implementation authorization        NO
SDK public API authorization                NO
Consumer App implementation authorization   NO
```
