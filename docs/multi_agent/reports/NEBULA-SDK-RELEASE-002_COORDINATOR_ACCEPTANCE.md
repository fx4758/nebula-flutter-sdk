# NEBULA-SDK-RELEASE-002 — Coordinator Release Acceptance

## Immutable release identity

```text
Version                 0.1.0-rc2
Tag                     v0.1.0-rc2
Tag commit              ac96fb5f428cc37293bc5a63e23c90fe40ff8af2
Release PR              #106
Formal                  #326 SUCCESS
Independent review      #430 APPROVED
Reviewer                reviewer-agent
Official                true
Stale                   false
Canonical landing       fast-forward-only
Canonical main          ac96fb5f428cc37293bc5a63e23c90fe40ff8af2
Post-merge governance   #327 SUCCESS
Tag release gate        #328 SUCCESS
Distribution            immutable Forgejo Git tag / publish_to:none
API surface             131
```

`v0.1.0-rc2` is a lightweight immutable tag and resolves exactly to the independently reviewed canonical release candidate. It does not point at an unreviewed merge commit.

## Package scope

RC2 is packaging-only relative to its resolved fresh canonical baseline. `lib/**`, `governance/api_surface.snapshot`, `lib/nebula_sdk.dart`, and `governance/public_api.txt` remained byte-identical to that baseline. API surface remains 131.

Auth V2 capabilities already canonical before packaging remain present:

- PHONE/SMS compatibility preserved;
- EMAIL/password login plus email code/register/reset typed operations;
- typed Apple authorization-code OAuth;
- typed Google authorization-code OAuth.

WeChat/QQ production SDK/API support is **not** part of RC2. Their migration architecture is separately canonical as deferred and remains blocked from production mutation until its own promotion gates close.

## Verification

The rebuilt RC2 core passed on mac-mini-ci:

```text
release regression tests   14/14 PASS
dart analyze               0 issues
full SDK tests             273/273 PASS
API surface                131 PASS
governance                 PASS
secret scan                PASS
smoke                      PASS
```

Formal PR governance #326, official exact-head Review #430, canonical push governance #327, and tag-triggered release-gate #328 all succeeded.

## Closure

```text
status                     DONE
execution_gate             CLOSED_RELEASE_PASS
review_state               PASS
review_verdict             PASS
implementation_authorized  false
release_packaging          false
tag_publication            false
```

The release Story is closed. `v0.1.0-rc2` must not be moved or recreated. Consumer Apps may now repin this exact tag through their own dependency/integration governance. Any later SDK capability change requires a new Story and a new immutable release tag.
