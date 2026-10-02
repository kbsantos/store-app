# Current Catalog Category in Sales Reports

Sales reporting now derives product/category classification from the **current Store catalog** using:

- `transaction_items.product_id`
- `catalog_products.product_id`
- `catalog_products.category_id`
- `catalog_categories.category_id`

The historical `transaction_items.category` value is no longer used for the product/category sales reports.

## Applies to

- Store Dashboard → Category Sales
- Store Dashboard → Top Products category grouping
- Store Dashboard → Category Sales drill-down
- Sales → Product Sales
- Sales → Category Sales
- Reporting Dashboard category/product views
- Dashboard PDF data that is sourced from the reporting API

## Migration

Apply:

`supabase/20260918_store_reporting_current_catalog_category.sql`

Apply it after the existing sales consistency migration:

`supabase/20260918_store_sales_consistency.sql`

## Behavior

If a transaction item has a matching current catalog product, the report uses the product's current catalog category name.

If the product is no longer present in the current catalog, the report uses `Uncategorized`. It does not fall back to the historical transaction category because that value may be stale.

The product lookup is store-scoped to prevent matching a product from another store with the same `product_id`.

## September 17 verification

After applying the migration, rerun the Store Dashboard for September 17 and inspect Accessories. The drink products previously shown under Accessories should now be classified according to their current catalog categories, such as Coffee or Milk Tea.

Do not manually update historical transaction rows solely to correct reporting classification; the reporting views now resolve the current category from the catalog.
