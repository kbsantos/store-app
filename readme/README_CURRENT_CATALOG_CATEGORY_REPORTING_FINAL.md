# Current Catalog Category Reporting — Final Migration

## Why this migration is required

The September 17 investigation confirmed that historical transaction items can contain a stale category:

- `transaction_items.category = accessories`
- while the current catalog resolves the same `product_id` to `coffee` or `milk_tea`.

The sales reports must therefore derive category from the current catalog using the stable `product_id`.

## Source of truth

```text
transaction_items.product_id
        ↓
catalog_products.product_id
        ↓
catalog_products.category_id
        ↓
catalog_categories.category_id
        ↓
catalog_categories.name
```

The join is store-scoped and case/whitespace tolerant.

## Important migration order

Run this migration **after**:

```text
supabase/20260918_store_sales_consistency.sql
```

The sales-consistency migration recreates the same reporting views using the historical transaction category. If it is run after this migration, it will overwrite the desired definition.

Run:

```text
supabase/20260918_store_reporting_current_catalog_category_final.sql
```

last among the migrations that modify `report_product_sales` or `report_category_sales`.

## Reports affected

Because Store Management reads these views through `ReportingApiService`, this fixes:

- Dashboard Category Sales
- Product Sales
- Category Sales
- Dashboard reporting integrity category totals
- Dashboard PDF data that uses these reporting results

No historical transaction rows are modified.

## Expected September 17 result

Products such as:

- Iced Americano
- Iced Spanish Latte
- Iced Salted Caramel Latte
- Iced Coffee Latte
- Iced Matcha Latte
- Dark Chocolate

will be classified using their current catalog categories instead of the stale `transaction_items.category` value.
