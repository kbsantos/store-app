# Linked Inventory Item in Product Editor

## Changes
- Added `inventoryItemId` to the catalog product model and JSON serialization.
- Product add/edit dialogs load inventory through the existing `get_store_inventory_items` RPC.
- Added an optional Linked inventory item dropdown, using inventory UUIDs rather than names so duplicate names remain distinct.
- The selected item's unit and reorder level populate the editor as initial values; the reorder level remains editable.
- Selecting `Not linked` clears the link in the catalog payload.
- The catalog RPC definitions in the supplied database schema already expose `inventoryItemId` and the publish function reads it. The database must have the `store_catalog_inventory_links` table and its validation/synchronization triggers installed for the link and reorder-level propagation to work.

## Verify before deployment
1. Run `flutter pub get`, `flutter analyze`, and `flutter test`.
2. In Product Manager, edit a direct-inventory product and select the intended inventory row. The label includes a short UUID prefix to distinguish duplicate names.
3. Set the reorder level, save, publish, refresh Inventory, and verify the exact UUID-selected item.
4. Confirm another inventory row with the same name remains unchanged.
5. Test `Not linked` and verify it clears only the product link.

This change does not merge, create, or delete inventory items. The SQL migration has not been applied to Supabase as part of this package.
