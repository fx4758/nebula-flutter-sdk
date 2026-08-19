# FEEDBACK-TXC-AGG-BE-V1-001 — Schema Name Reconciliation

Status: **ARCHITECTURE RECONCILIATION CANDIDATE**

## Trigger

Implementation review found a conflict between the registered Backend implementation Task Pack and the fresh canonical FlyPostAPI database naming guard.

The Feedback Provider Aggregation V1 contract describes these structures conceptually:

```text
feedback_provider
app_feedback_provider_item
feedback_provider_sync_state
```

The implementation Task Pack copied those conceptual identifiers into the migration section as if they were exact physical table names.

Fresh authenticated FlyPostAPI `Dev` is:

```text
6d2ddd3a6c626b7918b29da6e92e13684bc3ef7a
```

Its blocking `architecture/database_name_test.go` allows only the established physical prefixes:

```text
sys_
user_
product_
pay_
ai_
asset_
app_
notification_
pigeon_
nfc_
focus_
learning_
analytics_
```

`pendingRename = {}` and `blocking = true`.

Therefore physical tables named `feedback_provider` or `feedback_provider_sync_state` cannot pass canonical Backend CI without changing the database naming architecture, which this Story does not authorize.

## Decision

Preserve the frozen logical/domain structures and map them onto existing physical database domains:

```text
logical / contract identifier       physical FlyPostAPI table
----------------------------------------------------------------
feedback_provider                  -> product_feedback_provider
app_feedback_provider_item         -> app_feedback_provider_item
feedback_provider_sync_state       -> app_feedback_provider_sync_state
```

Rationale:

- provider resources participate in `product_resource_binding`, so the provider resource SSOT belongs to the existing `product_` control-plane domain;
- App-scoped normalized feedback cache already naturally belongs to `app_`;
- provider/App sync cursor and backfill state are App-scoped operational state and belong to `app_`;
- no new global `feedback_` database domain is introduced;
- no `architecture/database_name_test.go`, `architecture.yaml`, `pendingRename`, or naming-prefix policy mutation is authorized or required.

## Contract compatibility

This is a **physical schema naming reconciliation**, not a behavior/contract redesign.

The logical identifiers remain the contract vocabulary:

```text
feedback_provider
app_feedback_provider_item
feedback_provider_sync_state
```

All frozen behavior remains unchanged, including:

- provider resource type `feedback_provider` in `product_resource_binding`;
- idempotency `(feedback_provider_id, external_feedback_id)`;
- normalized-cache-only Admin reads;
- bounded explicit sync/backfill;
- encrypted provider secret reuse through existing `secretcrypto`;
- no Mobile/SDK/App/BFF/UI implementation in this Story.

The resource type string `feedback_provider` is **not** renamed. Only physical SQL/GORM table names are reconciled.

## Implementation effect

After this reconciliation is canonical, `FEEDBACK-TXC-AGG-BE-V1-001` remains the same implementation Story and may continue from the existing reviewed branch/candidate lineage.

Agent A must use these exact physical table names in migration/models/tests:

```text
product_feedback_provider
app_feedback_provider_item
app_feedback_provider_sync_state
```

The already identified provider-status corrective also remains required:

```text
backfill_next_page != "" -> sync_state = backfill
backfill complete          -> sync_state = idle
```

No implementation may modify Backend naming guards to make alternative physical names pass.

## Forbidden by this reconciliation

- adding `feedback_` to the Backend allowed-prefix regex;
- adding a `pendingRename` exception;
- changing `architecture.yaml`;
- changing the conceptual provider resource type `feedback_provider`;
- widening Mobile/SDK/App/BFF/UI scope;
- using this document as approval to mutate any path outside the existing Story write-set.

## Exit

This reconciliation requires independent Architecture/Backend review and canonical merge before Agent A applies the schema/backfill corrective and produces a new exact Backend candidate.
