# ACR-MOBILE-AUTH-V2-CN-PROVIDER-001 — WeChat / QQ Legacy Auth Migration

## Metadata
- Story: `AUTH-V2-CN-PROVIDER-ARCH-001`
- Requested future mode: `CONTRACT_CHANGE`
- Current mode: `READ_ONLY`
- Triggering consumer: NFC Writer
- Governing policy: `docs/multi_agent/governance/PLATFORM_API_CHANGE_POLICY.md`
- Existing Auth contract: `docs/multi_agent/contracts/MOBILE_AUTH_V2.md`
- Candidate extension: `docs/multi_agent/contracts/MOBILE_AUTH_V2_CN_PROVIDER_MIGRATION_CANDIDATE.md`
- Backend authority: FlyPostAPI `Dev@d9ad6c3c0e9186e574081e22d88450d93542fd29`
- SDK baseline: nebula-flutter-sdk `main@8f92e8096e810161262b6cde30fdd014c4b9afc5`
- Decision: **DEFERRED_SECOND_CONSUMER_INSUFFICIENT**
- Production authorization: **FALSE**

## 1. Observed facts

### NFC Writer has a shipped compatibility obligation
Legacy native Android has real provider flows. WeChat OpenSDK receives an authorization callback and the old client performs provider token/user-info exchange. QQ uses Tencent SDK login, obtains provider credential/openid/profile, then sends legacy third-party fields to the old Backend. The old API uses `/user/registerAndLogin`.

The legacy client also contains a WeChat App secret and performs secret-bearing exchange client-side. The value is intentionally not reproduced here. That architecture is forbidden for migration and the exposed credential must be rotated before production cutover.

Current Flutter NFC Writer is not equivalent yet: `lib/app/services/auth_service.dart` exposes WECHAT/QQ but returns mock identities/tokens; China region configuration still presents WECHAT/QQ. Therefore these providers are legacy-auth migration/non-regression requirements, not speculative features.

### Canonical Auth V2 is Apple/Google-only
`MOBILE_AUTH_V2.md` freezes OAuth providers exactly APPLE and GOOGLE. Canonical SDK closure exposes typed Apple/Google providers only. FlyPostAPI `Dev@d9ad6c3...` has an OIDC verifier/config/handler path that accepts APPLE/GOOGLE and rejects other OAuth providers.

Backend account/identity persistence is provider-neutral and already has WECHAT/QQ vocabulary. The missing capability is trustworthy proof verification plus contract semantics, not a reason to create a second account/session authority.

## 2. Provider protocol evidence

### WeChat
Available WeChat Open Platform documentation mirrors and Tencent Cloud documentation agree on the mobile authorization-code flow: mobile OpenSDK returns a temporary authorization code; a server exchanges code + AppID + AppSecret for provider credentials/openid; unionid may be present for Apps under the same WeChat Open Platform account. Evidence consulted:
- https://wdk-docs.github.io/wxopen-docs/mobile/login/guide.html
- https://wdk-docs.github.io/wxopen-docs/mobile/login/UnionID.html
- https://cloud.tencent.com/document/product/1441/68675

Architecture implication: App acquires only the temporary authorization code. Provider secret and token exchange belong to Backend authority.

### QQ
Legacy NFC Writer proves the mobile Tencent SDK returns an access token/openid client-side. Public QQ-connect references describe `https://graph.qq.com/oauth2.0/me` taking an access token and returning `client_id` and `openid`, optionally `unionid`. However this review did not obtain a current canonical QQ official documentation page sufficient to freeze exact proof lifetime/replay semantics. QQ production proof semantics therefore remain an evidence gap. Candidate direction is Backend verification of a Tencent SDK credential against QQ OpenAPI plus server-authoritative App-ID binding; it is not frozen wire here.

## 3. Platform gate
1. Requested capability: trustworthy WECHAT/QQ proofs under existing Nebula identity/session authority while preserving existing users and PHONE/EMAIL/APPLE/GOOGLE.
2. Platform-shaped: verification, uniqueness, account binding, secret custody and session issuance are not safe App-local concerns.
3. Adapter-first: App adapter may acquire provider proof only; it may not verify identity or mint Nebula sessions.
4. SDK-only is insufficient because provider verification and legacy reconciliation require Backend authority.
5. One auth subsystem remains mandatory.

## 4. Candidate identity decision
Primary identity key candidate:
```text
WECHAT = (nebula_app_id, WECHAT, verified openid)
QQ     = (nebula_app_id, QQ, verified openid)
```
Only Backend-verified provider responses may produce subject. Caller openid/unionid/nickname/avatar/gender/email is never authoritative. Verified unionid is secondary alias metadata initially and must not silently merge identities across Nebula Apps or providers. Any cross-App linking needs a separate account-linking contract.

## 5. Legacy migration candidate
On first verified WECHAT/QQ login after migration:
1. verify proof server-side;
2. derive App-scoped provider subject;
3. use an existing migrated identity if present;
4. otherwise match exactly one legacy alias for same App/provider/subject;
5. exactly one match binds to the existing user;
6. zero matches may follow normal new-user creation policy;
7. multiple/colliding/ambiguous matches fail closed.

Automatic ownership decisions must not use nickname, avatar, gender, unverified email, client-supplied openid/unionid, or unionid alone across Apps. A pre-cutover collision report is mandatory; user IDs are not rewritten merely to adopt the new verifier.

## 6. Security / replay
- WeChat AppSecret/provider secrets are Backend-only and exposed legacy secret material must be rotated before cutover.
- Provider codes/access/refresh tokens never enter persistent SDK storage, logs, Analytics, Error Reporting or push payloads.
- Raw provider errors remain server-side and map to low-cardinality auth errors.
- WeChat authorization code is single-use; no automatic re-exchange after ambiguous consumption.
- QQ verification must validate returned provider client/application identity against server-selected App config before subject is trusted.
- QQ replay/expiry rules remain unfrozen pending current official Tencent evidence.
- InstallationProof remains authoritative App selector.

## 7. Compatibility / rollback
PHONE/EMAIL/APPLE/GOOGLE stay unchanged. WECHAT/QQ are additive and App-gated. Rollback disables provider acquisition/verification without deleting provider identities or invalidating unrelated sessions.

## 8. Second-consumer gate
Platform policy requires a second distinct canonical consumer for CONTRACT_CHANGE. NFC Writer native + Flutter are one product and cannot count twice. Fresh FlyPost `origin/main@1d2e728ae9764cdc2be27640150785c5b8170026` does not establish canonical WECHAT/QQ login requirements; a local/unmerged UX draft mentioning WeChat is excluded. No second distinct canonical consumer was mechanically established.

Therefore the promotion gate is not satisfied.

## 9. Options
- **A: copy legacy provider logic into Flutter NFC Writer — REJECTED.** Repeats client-held secret/client-authoritative identity.
- **B: add both providers directly to Apple/Google `oauth_code` — REJECTED AS FREEZE.** WeChat code fits authorization-code shape; QQ proof class is not proven equivalent.
- **C: typed provider-proof extension under existing Nebula identity/session authority — RECOMMENDED CANDIDATE.** App acquires proof, Backend verifies/normalizes, existing Nebula session issuance is reused.

Option C is not implementation-authorized until second-consumer and QQ official-protocol evidence close.

## 10. Decision
```text
Architecture direction                     ACCEPTED AS CANDIDATE
Platform CONTRACT_CHANGE                   NOT AUTHORIZED
Backend / SDK / App production mutation    NOT AUTHORIZED
Second canonical consumer                  INSUFFICIENT
QQ official proof evidence                 INCOMPLETE
Legacy secret rotation                     REQUIRED BEFORE CUTOVER
Verdict                                    DEFERRED_SECOND_CONSUMER_INSUFFICIENT
```

Coordinator must not register WECHAT/QQ Backend/SDK/App implementation Stories from this ACR in its current state.

## 11. Unblock conditions
1. second distinct canonical consumer for the same semantics;
2. current official Tencent QQ proof evidence with exact proof/replay/expiry semantics;
3. legacy provider identity collision audit/migration key proven;
4. provider secret rotation/config custody plan ready;
5. independent Architecture Review approves a later contract-change exact candidate;
6. Coordinator separately registers Backend -> SDK -> consumer App implementation Stories.
