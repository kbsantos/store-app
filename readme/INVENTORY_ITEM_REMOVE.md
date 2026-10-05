# Inventory item removal

The Inventory Items screen now provides a **Remove** action for active items.

- The action requires confirmation.
- Removal marks the item inactive through the existing `update_store_inventory_item` RPC; it does not hard-delete the database row.
- Existing stock, linked references, and historical transaction records are preserved.
- An inactive item can be restored by editing it and turning **Active** back on.
- The action is shown only to users who already have inventory-management permission.

This is intentionally a reversible removal. Hard deletion should only be introduced with a separate database-side review of foreign keys, movement/receiving/consumption history, and catalog links.
