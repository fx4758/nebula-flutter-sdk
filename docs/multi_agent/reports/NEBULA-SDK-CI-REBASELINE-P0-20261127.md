# NEBULA-SDK-CI-REBASELINE-P0-20261127 — candidate evidence

**State: development draft, not merged/activated.**

## Root cause and constraints

The historical repository-specific `nebula-sdk-ci` Runner record is offline and the original private image `flypost/nebula-sdk-ci:20260810-v1` is absent on M1. The two existing general-purpose Forgejo Runners remain healthy. Their configuration files have been backed up and were amended only with the old Docker-qualified SDK label; neither service has been restarted. M4 lacks Docker; do not advertise SDK capability until parity. Avoid duplicate Runners and new blocking workspace locks.

## Independently tested candidate on M1

New `local/nebula-sdk-ci:20261127-rc1` ARM64 candidate image ID `sha256:675b62b38cf4ccc51c0a0406c84d6b8e5c9c4c2e036712796ad7b036b0c592e1`. The image combines official SHA-pinned Dart3.12.0 and Python3.13 with exactly 47 cached Dart packages and 47 hosted checksum files, and uses new marker `nebula-sdk-ci-candidate-20261127-v1`. Its Dockerfile SHA256 is `d2a1346fe60e880a5f6467df09a9b7d7560408d2fe4280b0768443805845df10`.

Tested in a network-disabled ephemeral container against exact SDK main `f95138da7e0eaa5a0ba9f51a4225f1b553de54a1` and registration PR #162 `b8bae350662c0d940bd98a8de44a5eb9324b9109`. The original identity marker is intentionally rejected by production guard; a **separate, copied source fixture** was updated to the distinct candidate marker for local checks, never the canonical SDK source. Results for PR #162:

| Check | Local result |
|---|---|
| Dart 3.12.0, pinned 47 dependencies, offline pub get | PASS |
| Governance, Task Source, Cross Repo (58 Stories) | PASS |
| Coordinator State Guard (explicit Coordinator publication) | PASS |
| Publication mode regression | PASS |
| Dart format (118 files, zero changes), analyze (zero issues) | PASS |
| API Surface (131 symbols), Secret Scan, SDK Smoke | PASS |
| Dart unit tests | **278/278 PASS** |

Evidence exists on M1 `/Users/fengshawn/Documents/project/forAI/.ci-infra/nebula-sdk-ci-recovery-20261127` and an independent SHA256-verified copy on coordinator `/Users/sean/Documents/project/forAI/.ci-infra/nebula-sdk-ci-recovery-20261127/candidate`. Validation JSON SHA256 `0dd879326ba3d70c7ad62695bc189bc5d4b6274973606c42467e801390aa761a`; full test log SHA256 `0e362206a06d14dc8f8205ba9e402c3f7b75b169e3b02db55f7e858bcfdb549a`. MCP issue evidence: `http://192.168.31.102:3000/root/mcp-bridge/issues/1373#issuecomment-12451`.

## Release hard gates

Coordinator must finalize registered Story `NEBULA-SDK-CI-REBASELINE-P0-20261127` through the `docs/multi_agent/task_board.json` and Task Pack, verify image/cached packages, and publish a protected baseline PR with genuine `coordinator-publication` server label, real exact-head Forgejo Guard and independent Reviewer. The SDK Task Board cross_repo_governance runner image/image identity must match the new snapshot; Implementation Agents are not authorized to modify Task Board state. Then repoint only the existing M1 Runner's SDK label to the reviewed OCI candidate with approved restart and validate that jobs run. Do not claim current registration PR #163 or T08 PR #162 completed; both last observed Guard PENDING. After new canonical baseline, refresh/review/merge #162 separately. No NFC Writer phone login/TEST/user data changes.
