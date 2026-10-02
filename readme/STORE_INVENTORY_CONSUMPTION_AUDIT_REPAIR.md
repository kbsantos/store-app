# Store Inventory Consumption — Recoverable Audit Repair

## Purpose

The size-aware inventory consumption flow is now recoverable when an earlier run created an `inventory_consumption_records` row but did not create its matching `inventory_movements` row.

The canonical movement key remains:

```text
md5(transaction_item_id + ':' + inventory_item_id)::uuid
```

## Behavior

For each numeric recipe line:

1. Resolve the recipe using the exact `product_id + size_id` sold.
2. Preserve an existing `inventory_consumption_records.quantity` when repairing historical data.
3. Check for the deterministic `inventory_movements.external_movement_id`.
4. If the movement exists, treat the line as already processed.
5. If the movement is missing, create the missing usage movement.
6. New usage movements populate `reason = Sales consumption` and `reference_id = transaction_item_id` when those columns exist.
7. Qualitative recipe values such as `Full` and `Fill` remain excluded from numeric inventory movements.

## Historical metadata backfill

The migration also fills missing `reason` and `reference_id` values for existing usage movements that can be safely matched to an `inventory_consumption_records` row. Quantities are not changed.

## Important

Run this migration only after the existing size-aware recipe migration:

```text
20260925_product_recipes_size_aware.sql
20260925_inventory_consumption_size_aware.sql
20260925_inventory_consumption_audit_repair.sql
```

The RPC remains protected by the existing authenticated-user, store-assignment, and owner/manager/admin checks.
