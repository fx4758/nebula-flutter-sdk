# NEBULA-SDK-RELEASE-GATE-002 — Coordinator Acceptance / RC2 Authority

## Reviewed gate implementation

```text
Story                  NEBULA-SDK-RELEASE-GATE-002
Exact                  84852208681e73a1fbe62100fde6d1d85b8a1de9
PR                     #102
Formal                 #316 SUCCESS
Independent review     #417 APPROVED
Reviewer               reviewer-agent
Official               true
Stale                  false
Merge                  5d59c6ecf3535a3391d8dbd2bb897e69bb1cb1fe
Post-merge governance  #317 SUCCESS
```

The tag-triggered release gate no longer trusts a historical hard-coded release Story. It resolves the release authority from the tagged package's exact version/tag metadata, fails closed on zero/multiple or revoked/drifted authority, and binds closed historical release metadata back to the actual tag/HEAD commit.

## RC2 authority publication

Coordinator now sets `NEBULA-SDK-RELEASE-002.tag_publication_authorized=true` for a **newly rebuilt** `v0.1.0-rc2` candidate only.

This authority does not validate or revive PR #97 / exact `5184ca05470c121d9a284cd2e641f154e40550cf`. That candidate predates the canonical release-gate corrective and is superseded.

RC2 must be rebuilt from canonical SDK `main@5d59c6ecf3535a3391d8dbd2bb897e69bb1cb1fe`, retain API surface 131 with no `lib/**` or snapshot mutation, then pass fresh Formal and official exact-head independent release review before Coordinator may publish the immutable tag.

No Backend, consumer App, provider acquisition, WeChat/QQ, or SDK public-surface mutation is authorized here.
