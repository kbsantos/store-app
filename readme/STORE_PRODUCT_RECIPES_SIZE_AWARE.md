# Store Product Recipes — Size-Aware Recipe Bridge

The Store recipe manager is now aligned with the Bigger Brew recipe migration.

## Responsibilities

The Store owns the inventory-facing recipe bridge:

- product ID
- product size
- inventory item
- numeric quantity, or qualitative quantity text

The Barista app remains the preparation guide. The Kiosk does not load recipe instructions.

## Database migration

Apply these migrations to Supabase after the existing Store recipe migrations:

1. `supabase/20260925_product_recipes_size_aware.sql`
2. `supabase/20260925_inventory_consumption_size_aware.sql`

The first migration upgrades `store_product_recipe_items` to support:

- `size_id`
- `quantity`
- `quantity_text`
- size-aware uniqueness

The second migration makes inventory consumption use the exact size sold when the transaction item exposes `size_id`, `product_size_id`, or `size`.

If a transaction item does not expose a size while the product has size-specific recipes, consumption is skipped rather than guessing.

Qualitative quantities such as `Full` are retained for recipe reference but are not converted into numeric inventory movements.

## Store UI

`Product Recipes` now:

- reads products from the Store catalog
- shows every active product size, including sizes with no recipe yet
- lets authorized inventory managers create/edit a recipe per product and size
- supports numeric quantities
- supports qualitative quantities such as `Full`
- prevents duplicate inventory items within one product/size recipe
- preserves the existing inventory permission model

## Important

The source migration `20260918_product_recipes.sql` is retained as historical migration context. The `20260925_*` migrations are the upgrade path for the size-aware schema.

## Validation

After applying the two size-aware migrations, run:

`supabase/20260925_recipe_bridge_validation.sql`

The validation script checks the bridge schema, expected physical row shape, orphan inventory references, invalid quantities, duplicate recipe lines, the normalized Matcha/Strawberry cases, qualitative quantities, and the deployed function signatures.
