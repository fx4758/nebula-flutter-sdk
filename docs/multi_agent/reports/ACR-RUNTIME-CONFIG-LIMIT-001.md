# ACR-RUNTIME-CONFIG-LIMIT-001

Status: **APPROVED**
Decision: **IMPLEMENT_FROZEN_CONTRACT**
Frozen contract: `docs/12_MOBILE_RUNTIME_CONFIG_CONTRACT.md §8.3`
Backend baseline: `070500e2be02358f711552e5b88b00f784ed7389`
Independent reviewer: Backend Review Agent

## Capability and classification

The capability is generic mobile Runtime Config response-limit enforcement. It is Platform capability, not NFC product behavior: the frozen 8 KiB encoded-value and 64 KiB final-response caps apply to every consumer of the mobile Runtime Config endpoint.

S1-F02-001 audit probes proved two production gaps without changing production behavior:

- encoded value 8195 bytes was accepted despite the frozen 8 KiB cap;
- inner snapshot 65525 bytes produced a final `{code,data}` response of 65543 bytes.

The repair implements already-frozen limits only. It does not change endpoint, request/response fields, error codes, trust source, retry, lifecycle, compatibility, or public API semantics. Existing `12004` is the frozen failure path.

## Adapter-first analysis

No App Adapter or SDK-internal change can enforce server delivery-size boundaries before bytes leave Backend. SDK remains read-only; App remains untouched.

## Authorization

`S1-F02-003` is authorized to make only the two limit checks and focused regression coverage described in its task pack. Independent review is required before merge.
