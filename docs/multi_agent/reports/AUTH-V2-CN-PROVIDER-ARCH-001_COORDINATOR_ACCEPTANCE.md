# AUTH-V2-CN-PROVIDER-ARCH-001 — Coordinator Acceptance

## Canonical architecture evidence

```text
Story                    AUTH-V2-CN-PROVIDER-ARCH-001
Architecture exact       6b0fb58eff0947ee15d69dd4e6c836a85f663084
Architecture PR          #99
Formal                   #304 SUCCESS
Independent review       #403 APPROVED
Reviewer                 reviewer-agent
Official                 true
Stale                    false
Merge                    aa600c0a34a699b41f596842df4cc5b607ca4faf
Post-merge governance    #305 SUCCESS
```

The accepted architecture direction is canonical on `main`. WeChat and QQ are therefore formally part of the Nebula Auth migration roadmap, not an informal product follow-up.

## Accepted architecture direction

- WeChat: App obtains only the temporary authorization code; Backend owns AppSecret custody and provider exchange/verification; only Backend-verified `openid` may become Nebula provider identity.
- QQ: do not force QQ into Apple/Google OIDC semantics. A later typed proof must be verified by Backend against Tencent provider authority and the server-selected QQ App ID before `openid` is trusted.
- `unionid` is secondary verified alias metadata only; it is not an automatic cross-App account merge key.
- Existing NFC Writer provider identities require a pre-cutover collision audit and fail-closed ambiguous-match handling.
- Legacy client-exposed WeChat secret material must be rotated before production cutover; no secret value is copied into governance, SDK, App, logs, Analytics or Error Reporting.

## Closure verdict

```text
Architecture direction                     ACCEPTED AS CANONICAL CANDIDATE
Legacy non-regression                      LOCKED
Platform CONTRACT_CHANGE                   NOT AUTHORIZED
Backend implementation                     NOT AUTHORIZED
SDK implementation/public-surface change   NOT AUTHORIZED
NFC Writer production integration          NOT AUTHORIZED
Review verdict                              DEFERRED_SECOND_CONSUMER_INSUFFICIENT
Execution gate                              CLOSED_DEFERRED_SECOND_CONSUMER
```

This is a successful architecture closure with a deferred promotion decision. `DONE` means the authorized READ_ONLY architecture review is complete; it does **not** mean WeChat/QQ production login is implemented.

## Reopen conditions

All of the following are mandatory before a later Coordinator may register a `CONTRACT_CHANGE` implementation chain:

1. mechanically verified second **distinct canonical consumer** requiring the same WeChat/QQ provider-login semantics;
2. current official Tencent QQ proof documentation sufficient to freeze exact proof type, lifetime, expiry and replay semantics;
3. reviewed legacy provider identity collision/migration audit with ambiguous cases failing closed;
4. WeChat legacy secret rotation and server-side credential custody readiness;
5. a new independently reviewed Architecture exact candidate that explicitly authorizes contract promotion;
6. only after that, separate Coordinator registrations for Platform/Backend -> SDK -> consumer App implementation.

No current Backend, SDK, provider-credential, or consumer App mutation authority is inherited from this closure.
