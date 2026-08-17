# NEBULA-SDK-RELEASE-001 — Coordinator Acceptance

## First released SDK identity

```text
version                    0.1.0-rc1
tag                        v0.1.0-rc1
reviewed/canonical SHA     64df49af6ff7554da94d5fa2ebaef27bdba35465
PR                         #68
Formal CI                  UI #211 SUCCESS
Independent Review         #155 APPROVED / reviewer-agent / official=true
landing                    fast-forward-only
post-merge governance      UI #212 SUCCESS
release-gate               UI #213 / internal 817 / verify-tag job 1080 SUCCESS
public API                 127 symbols
full release tests         261 PASS
registry                   none (`publish_to: none`)
```

The remote tag resolves exactly to the independently reviewed canonical SHA. It was not retargeted and no merge commit was inserted between review and release.

Tag-triggered release CI mechanically reported:

```text
API surface: PASS (127 symbol(s) match snapshot)
SDK-RELEASE-GATE PASS: channel=beta version=0.1.0-rc1 tag=v0.1.0-rc1 commit=64df49af...
Secret scan: PASS
261 tests passed
verify-tag job: SUCCESS
```

## Decision

```text
NEBULA-SDK-RELEASE-001 = DONE / REVIEW PASS / CLOSED_RELEASE_PASS
release_packaging_authorized = false
tag_publication_authorized = false
```

Consumer repositories may now adopt `v0.1.0-rc1` only through their own reviewed immutable dependency pin/repin process. `S1-F01-002` remains unrelated and is not implicitly authorized by this release closure.
