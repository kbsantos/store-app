# Store Management — Current Catalog Category Runtime Fix

## Root cause

The current-catalog reporting views were correctly joining transaction items to the current catalog, but the views were created with `security_invoker = true`.

That made the catalog joins execute using the authenticated user's RLS permissions. The reporting user could read the reporting view and transaction data, but catalog rows were not necessarily visible through the invoker context. The LEFT JOIN then produced NULL category values and the reporting view fell back to `Uncategorized`.

This explains why:

- The same category join returned real categories in Supabase SQL Editor.
- The Store Dashboard showed all 200 items as `Uncategorized`.
- The application source already correctly reads `row['category']`.

## Fix

`20260918_store_reporting_current_catalog_category_runtime_fix.sql` recreates:

- `public.report_product_sales`
- `public.report_category_sales`

without `security_invoker = true`.

The current catalog remains the category source of truth:

`transaction_items.product_id`
→ `catalog_products.product_id`
→ `catalog_products.category_id`
→ `catalog_categories.category_id`
→ `catalog_categories.name`

No historical transaction rows are changed.

## Migration order

Apply this migration AFTER the migrations that previously recreated these views, especially:

1. `20260918_store_sales_consistency.sql`
2. `20260918_store_reporting_current_catalog_category_final.sql`
3. `20260918_store_reporting_current_catalog_category_runtime_fix.sql` ← final runtime fix

If a later migration recreates either reporting view, this runtime fix must be reapplied afterward.

## Verification

After applying the migration, run:

```sql
select pg_get_viewdef(
  'public.report_category_sales'::regclass,
  true
);
```

The definition should no longer contain `security_invoker = true` and should contain the current-catalog joins.

Then:

```sql
select
  category,
  quantity_sold,
  total_sales
from public.report_category_sales
where sales_date between '2026-09-17' and '2026-09-18'
order by total_sales desc;
```

The results should contain the actual category rows rather than a single 200-item `Uncategorized` row.

## Flutter dashboard

The current Store Management source already:

- reads the `category` column correctly;
- groups categories correctly;
- keeps the Category Sales drill-down;
- uses product sales for the drill-down product list.

No Dart category parser change is required for this runtime issue.

## Testing

After applying the SQL migration, rebuild the web application:

```bash
flutter clean
flutter pub get
flutter run -d chrome
```

Then select the desired date range on Store Dashboard and verify that Category Sales displays separate category rows. Click a category row to verify the retained drill-down.

No GitHub commit or push is included in this change.
