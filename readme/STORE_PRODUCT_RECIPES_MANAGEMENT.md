# Store Product Recipe Management

The Store app is the authoritative editor for inventory-facing product recipes.

## Scope

- Uses the neutral catalog `productId` and `recipeRef` as identifiers.
- Only catalog products with a non-empty `recipeRef` are presented as recipe products.
- Supports size-specific recipes (`Regular`, `Go Big`, `Go Bigger`) through `size_id`.
- Numeric quantities are stored in the inventory item's unit.
- Qualitative quantities such as `Full` and `Fill` are stored in `quantity_text` and are not converted into numeric stock consumption.
- Saving a recipe replaces the selected product/size recipe atomically from the user's perspective through `save_store_product_recipe`.
- Clearing a recipe is supported by saving an empty ingredient list.

## Consumption relationship

Sales consumption uses the Store recipe bridge:

`transaction item -> product_id + size_id -> store_product_recipe_items -> inventory item`

Numeric recipe lines create inventory consumption records and usage movements. Qualitative lines remain non-numeric and are skipped by the inventory consumption process.

## UI behavior

- Recipe list can be searched by product or size.
- Recipe products are limited to catalog products that have `recipeRef`.
- Ingredient quantities show the inventory unit when selected.
- Quantity entry accepts both numeric values and text values such as `Full` or `Fill`.

## Recipe integrity check

The Product Recipes page now includes **CHECK INTEGRITY**. The check is read-only and validates the loaded catalog/recipe/inventory data for:

- a recipe row for every active catalog size of every product with `recipeRef`
- non-empty recipe rows
- active inventory item references
- duplicate inventory ingredients within a product/size recipe
- numeric quantities greater than zero or non-empty qualitative `quantity_text`

The check does not modify recipes, inventory, consumption records, or movements.
