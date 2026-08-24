# AUTH-V2-SDK-002 Final Acceptance

## Verdict

`AUTH-V2-SDK-002` is eligible for canonical closure.

The final implementation PR candidate received exact Formal SUCCESS and independent official exact-head approval, was merged by Coordinator, and the merge commit passed post-merge governance. This report authorizes no consumer App or provider mutation.

## Canonical evidence

- Implementation PR: `#94`
- Final reviewed exact: `559d88497fce25e454f8a36a8c33b9e27732e2de`
- PR base at merge gate: `df94d81d13042f6ea8fc6901fbcd10e019d3bcd2`
- Formal: governance UI `#286` — `SUCCESS` on exact `559d88497fce25e454f8a36a8c33b9e27732e2de`
- Independent Review: `#395 APPROVED`
- Reviewer: `reviewer-agent`
- Review authority: `official=true`, `stale=false`
- Reviewed commit: `559d88497fce25e454f8a36a8c33b9e27732e2de`
- Merge commit / canonical main: `0ee33686c35e49e29d9eb38034c3c16c300a969d`
- Candidate ancestry: `559d88497fce25e454f8a36a8c33b9e27732e2de` is an ancestor of canonical main
- Post-merge governance: governance UI `#287` — `SUCCESS` on exact main `0ee33686c35e49e29d9eb38034c3c16c300a969d`

## Canonical SDK result

The frozen Mobile Auth V2 SDK surface is implemented and canonical:

- PHONE/SMS behavior remains preserved.
- EMAIL/password login is typed and implemented.
- EMAIL verification-code send, registration, and password reset are implemented through `NebulaAuth`.
- Apple/Google authorization-code login is typed through `NebulaOAuthProvider`.
- Invalid credentials map to stable SDK code `10001` / `InvalidCredentialsError`.
- Password-reset success clears user session scope while preserving installation identity.
- Existing InstallationProof transport remains the transport authority.

Public API closure is exactly `127 -> 131`, with four additions and zero removals:

- `NebulaOAuthProvider`
- `NebulaEmailCodePurpose`
- `nebulaCodeInvalidCredentials`
- `InvalidCredentialsError`

Canonical hashes remain:

- `lib/nebula_sdk.dart`: `2ab4b77edb82ce32f46c6bac76dca2bc19e2220ce3e6dd39a6a436395c63fab5`
- `governance/public_api.txt`: `4aa2e72323e175fed0e0e4b3c87a85d7db0fdeb954b59f35517ba8976408daf4`

## Verification inherited from reviewed delivery

The independently reviewed delivery records:

- Task Source Guard: PASS
- Cross Repo Guard: PASS
- Platform API Guard: PASS
- API surface: PASS (`131`)
- Focused Auth V2 + compatibility tests: PASS (`44/44`)
- Full `dart analyze`: PASS
- Full test directory: PASS (`273/273`)
- Nebula Governance: PASS
- Secret scan: PASS
- `git diff --check`: PASS

The compatibility amendment remained test-only. Backend mutation, consumer App mutation, provider credential/configuration mutation, and provider authorization-code acquisition were all `0` for this Story.

## Closure boundary

After this closure becomes canonical:

- `AUTH-V2-SDK-002` is `DONE / PASS / CLOSED_REVIEW_PASS`.
- SDK production/public mutation authority from this Story is closed.
- Consumer App repin/integration is **not** inherited and requires a dedicated downstream Story.
- Provider acquisition/migration, including any deferred WeChat/QQ or provider-specific integration, is **not** inherited and requires a dedicated downstream contract/migration Story.
- Reviewer does not merge and does not write Task Board state.
