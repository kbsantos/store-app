# Bigger Brew Store Management — Sales & EOD Integration Hardening

This update is based on the Store Dashboard baseline.

## Integration hardening
- Standardized completed-sale status handling across product, category, daily, device, hourly, payment, dashboard, and EOD reporting.
- Draft/pending transactions are excluded from sales and payment totals.
- Cancelled/canceled/void/voided/refunded transactions are excluded.
- EOD now exposes `paymentDifference` for reconciliation.
- EOD UI shows a warning when recorded payments differ from sales by at least ₱0.01.
- Inventory consumption continues to use the explicit completed/paid/closed status gate and idempotent transaction-item/inventory-item key.

## Supabase
Run `supabase/20260918_store_sales_consistency.sql` after the existing Store reporting/EOD migrations.

No GitHub commit or push was made.


## Catalog Sync / Multi-Kiosk Hardening

The Store Management app now includes a **Catalog Sync** status screen. It compares the current Supabase Store Master Catalog version with the last catalog version reported by each registered kiosk. Registered kiosks can appear as `SYNCED`, `OUTDATED`, `NEVER SYNCED`, or `INACTIVE`.

Apply `supabase/20260918_catalog_sync_state.sql` before using the status screen. The migration adds the per-device sync state table, a kiosk reporting RPC, and a manager-only status RPC. The kiosk reporting RPC is designed to be called only after a kiosk has successfully validated and cached the master catalog.

## Users / Auth workflow update

The Users page now supports a manager/admin action to send a Supabase password setup/recovery email to an employee who is already linked to the store. Store Management does not create or store employee passwords.

Pending employees remain separate from Supabase Auth until the employee's Auth account exists and is linked through the existing **LINK AUTH USER** workflow.

## Permission hardening checkpoint

This checkpoint centralizes the Store Management UI permission mapping and aligns it with the current Supabase RPC security rules. Server-side RPC authorization remains authoritative.

- Owner/Admin: employee management, store profile, operating hours, database reset.
- Owner/Admin/Manager: catalog, inventory, recipes, EOD completion, kiosks/printers.
- Editor: catalog-specific role; Store Management catalog remains read-only because publishing is manager/admin/owner restricted.
- Staff/Editor: permitted reporting/read-only screens remain accessible.

No GitHub commit or push was performed.

## Inventory / Sales Integration Hardening — 2026-09-18

The inventory consumption workflow was hardened for production validation:

- Recipe consumption now fails closed if the deployed `transactions` table has no recognizable status column. This prevents inventory consumption from processing unverified draft/pending transactions.
- Added `supabase/20260918_inventory_consumption_hardening.sql` with `get_store_inventory_consumption_integrity(date)`.
- Inventory Consumption now has a **CHECK INTEGRITY** action for a selected business date.
- The integrity check verifies consumption records against their deterministic usage movement audit records and reports missing/orphan movement lines and quantity differences.
- This validation does not modify sales, inventory quantities, recipes, or consumption records.

Apply the hardening migration after the existing inventory consumption migration. Then run `flutter pub get`, `flutter analyze`, `flutter test`, and `flutter run -d chrome` locally.

## EOD hardening checkpoint

- Added `supabase/20260918_store_eod_hardening.sql`.
- Added a read-only `get_store_eod_integrity(date)` RPC covering payment reconciliation, inventory-consumption integrity, and EOD close state.
- EOD completion is idempotent at the RPC level: a completed business date returns its existing snapshot instead of reprocessing inventory consumption.
- The Store EOD page now exposes **CHECK INTEGRITY** and displays the reconciliation checklist.
- Payment differences remain warnings rather than automatic blockers; the close snapshot preserves the sales/payment totals used at completion.
- Apply this migration after the existing EOD, sales-consistency, and inventory-consumption hardening migrations.


### Catalog Health hardening
The Catalog Health validator now checks catalog schema/version compatibility, required pricing, drink temperature values, duplicate SKUs/names, size volumes, variant pricing completeness, shared-option compatibility, inactive shared options, empty active categories, and other structural catalog integrity issues. Product-specific options remain valid without a shared option definition.
