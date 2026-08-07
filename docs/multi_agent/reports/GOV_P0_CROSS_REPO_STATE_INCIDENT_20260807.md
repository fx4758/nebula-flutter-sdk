# GOV-P0 Cross-Repository State / Shared-Branch Incident — 2026-08-07

Status: **CONTAINED / CLOSED FOR EXECUTION GOVERNANCE**

## Facts independently verified

1. NFC Writer delivery commit `ef3d0f5` exists on LAN `dev` and contains S1-F01-001 App adapter work.
2. GitHub `origin/dev` remained at `b4ba98d`; the accidental direct push affected LAN `dev`, not GitHub dev.
3. SDK LAN branch `s1/f01-adapter` contains Agent-authored commits `6a86cb3` and `4bb7a62` that only mutate `docs/multi_agent/task_board.json` to claim/deliver the Story.
4. Existing governance was contradictory: execution policy allowed an implementation Agent to mutate its own READY→IN_PROGRESS→DELIVERED state, while Ownership Matrix reserved `docs/multi_agent/**` for Architecture/PM serial writes.
5. NFC Writer repository already stated App Agent MUST NOT modify `nebula-flutter-sdk/**` without explicit cross-repo authorization.

## Root cause

Cross-repo Story orchestration conflated two different concepts:

- governance/control repository, and
- implementation/execution repository.

The Task Board stored SDK worktree/branch for S1-F01 even though the implementation target was the App repository. The Agent therefore treated board mutation in SDK + implementation in App as one valid delivery.

## Correction

- Freeze GOV-CROSS-REPO-001.
- Coordinator owns all Task Board state; Agents return Delivery Notes only.
- Every Story has exactly one execution repository and one feature branch.
- Split Backend/SDK work into separate Stories rather than one Agent writing both repositories in one Story.
- Direct pushes to shared `dev/main` are forbidden for implementation delivery.
- S1-F01-001 App commit is isolated on LAN branch `s1/f01-001-adapter` for review.

## Acceptance principle

Implementation quality and governance compliance are reviewed separately. A technically valid App commit is not discarded merely because orchestration was wrong; instead it is isolated, independently reviewed, and only then integrated by Coordinator.

## Containment refs

- App review branch: `lan/s1/f01-001-adapter` → `bddb0f8` (Agent code `ef3d0f5` + Coordinator handoff correction).
- App LAN dev quarantine: `00c0dc0`; code tree restored to pre-delivery baseline except governance handoff doc.
- Invalid SDK Agent state-write branch archived as `lan/archive/agent-cross-repo-board-write-s1-f01-20260807`; active `lan/s1/f01-adapter` removed.

## Independent code review note

S1-F01-001 remains REVIEW / CHANGES_REQUIRED for a separate architecture issue: public `NebulaAdapter.debugClient` leaks an SDK type through the Adapter boundary, while ARCH-010 only scans direct imports. Governance containment does not convert technical delivery into PASS.
