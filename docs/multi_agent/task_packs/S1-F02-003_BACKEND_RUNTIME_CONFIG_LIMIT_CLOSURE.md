# S1-F02-003 Backend Runtime Config Frozen Limit Closure
- ID：S1-F02-003
- Owner：Backend Runtime Config Agent
- Depends：S1-F02-001
- Execution repo：`../flypost_backend`
- Execution branch：`s1/f02-003-runtime-config-limits`
- Governance state：`READ_ONLY` for Implementation Agent; Task Board is Coordinator-owned.
- Delivery：execution-repo commit plus Delivery Note only; no Task Board mutation.
- Platform API mode：**`IMPLEMENT_FROZEN_CONTRACT`**
- SDK public API mode：`NONE`
- Adapter-first：`ADAPTER_FIRST`
- Goal：enforce two already-frozen Runtime Config delivery limits only:
  1. encoded config value over 8 KiB rejects the whole response via existing `12004` path;
  2. final serialized successful `{code,data}` response over 64 KiB rejects via the same existing `12004` path.
- Allowed：`internal/module/runtimeconfig/**`, `internal/router/runtime_config_http_test.go`, focused Runtime Config tests, Delivery Note.
- May minimally reuse an existing response serialization abstraction solely to measure final `{code,data}` bytes.
- Required boundaries：encoded 8192 accepted; 8193 rejected; final body <=65536 accepted; >65536 rejected; no truncation and no partial snapshot.
- Required regressions：ETag/304, GLOBAL plus trusted regional override, effective installation region, trusted installation platform, forged region/platform ignored, version policy, allowlist, kill switch.
- Forbidden：new error code; endpoint/DTO/wire-field/trust-source change; caller-controlled `X-App-Platform`; SDK/App/NFC mutation; global response-package refactor.
- Evidence：focused Go tests, exact candidate/base diff, existing 12004 error assertion, no partial delivery, independent review and post-merge CI.
