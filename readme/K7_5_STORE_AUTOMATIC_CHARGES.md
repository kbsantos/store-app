# K7.5 — Store-Managed Automatic Charges / Fees

This checkpoint adds mandatory catalog charges as a separate concept from product auto-apply add-ons.

## Behavior

- Auto-apply add-on: product-specific, selected by default, removable by the customer.
- Automatic charge/fee: centrally managed catalog charge intended to be applied automatically by the kiosk and not treated as a selectable add-on.

## Store Management

Product Options / Add-ons now has:

- SHARED OPTIONS
- PRODUCT ASSIGNMENT
- CHARGES & FEES

Charges support scopes:

- category
- product
- product_type

Each charge has an ID, name, amount, active flag, scope, and target IDs/types.

## Supabase

Apply:

`supabase/20260920_automatic_charges.sql`

The migration creates `catalog_automatic_charges` and updates Store Management and shared master-catalog read/write RPCs to carry `automaticCharges`.

## Validation

Run:

```bash
flutter analyze
flutter test
```

K7.5 does not yet change kiosk checkout behavior; the kiosk consumption step is a later checkpoint.


## Kiosk master-read contract regression fix

The final `get_store_catalog(uuid)` migration must expose the top-level
`automaticCharges` array. `20260920_automatic_charges.sql` defines the charge
table and shared master read, but `20260920_product_option_auto_apply_master_read.sql`
also replaces `get_store_catalog()`. The final migration therefore preserves
both contracts. Without this field, Store can save and publish Charges & Fees
successfully while the kiosk receives an empty `automaticCharges` list.
