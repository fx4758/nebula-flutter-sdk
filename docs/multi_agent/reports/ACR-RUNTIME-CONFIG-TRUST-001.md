# ACR-RUNTIME-CONFIG-TRUST-001

Status: **DEFERRED / NON-RC**  
Blocks 2.4.0: **NO**

The frozen SDK contract text still describes optional `X-App-Platform` selection. Canonical runtime behavior is stricter and remains authoritative:

- SDK does not send caller-controlled `X-App-Platform`;
- Backend ignores forged platform headers;
- Backend trusts `app_installation.platform` and fails closed with `12004` on lookup failure;
- market scope trusts `app_installation.effective_region_code`.

This is governance/documentation drift, not a running security or compatibility gap. Reconciliation is a future `CONTRACT_CHANGE` only if second-consumer evidence is mechanically established; it must not restore caller-controlled platform authority. No trust-source implementation Story is authorized for this RC.
