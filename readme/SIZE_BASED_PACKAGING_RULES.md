# Size-based packaging rules

This additive migration creates `store_size_packaging_rules`, a store-scoped table linking catalog size IDs to tracked inventory items and quantities per sold unit. It includes RLS and validates that each packaging item is active, tracked, and belongs to the same store.

## Compatibility finding
The uploaded Flutter Recipe Manager calls `save_store_product_recipe` with `p_product_id`, `p_size_id`, `p_items`, and `p_steps`. However, the included base migration `20260918_product_recipes.sql` only defines `save_store_product_recipe(p_product_id text, p_items jsonb)` and has no size-specific recipe rows or preparation-step schema. Therefore this migration intentionally does not alter the live recipe RPCs or End-of-Day consumption function, and it does not seed cup/lid/straw rules. Automatically deducting packaging before reconciling the deployed recipe and transaction-item size schemas could deduct the wrong packaging.

Next: inspect deployed recipe RPC overloads and `transaction_items` size/variant columns; then add a packaging rules UI and update the consumption RPC with idempotent, size-aware deductions and product-level overrides.
