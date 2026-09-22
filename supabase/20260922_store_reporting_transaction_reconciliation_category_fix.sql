-- Bigger Brew Store Management: category visibility fix for reconciled sales reports.
--
-- The transaction reconciliation migration correctly made transactions.total the
-- financial authority, but its product/category views were created with
-- security_invoker = true. That caused catalog_products/catalog_categories RLS to
-- be evaluated using the authenticated reporting user and the current-catalog
-- join returned NULL categories, producing only "Uncategorized".
--
-- Keep the transaction reconciliation layer and current-catalog category source,
-- but execute the catalog joins with the view owner's privileges. Store scoping
-- remains explicit in the joins.
--
-- Apply this AFTER:
--   20260922_store_reporting_transaction_reconciliation.sql
--
-- Do not modify transactions or transaction_items.

create or replace view public.report_product_sales
as
select
  r.store_id,
  r.device_id,
  r.sales_date,
  coalesce(nullif(trim(cc.name), ''), 'Uncategorized') as category,
  r.product_id,
  r.product_name,
  sum(r.quantity)::integer as quantity_sold,
  sum(r.reconciled_item_total) as total_sales,
  case
    when sum(r.quantity) = 0 then 0
    else sum(r.reconciled_item_total) / sum(r.quantity)
  end as average_unit_price
from public.report_reconciled_transaction_items r
left join public.catalog_products cp
  on cp.store_id = r.store_id
 and lower(trim(cp.product_id)) = lower(trim(r.product_id))
left join public.catalog_categories cc
  on cc.store_id = cp.store_id
 and lower(trim(cc.category_id)) = lower(trim(cp.category_id))
group by
  r.store_id,
  r.device_id,
  r.sales_date,
  coalesce(nullif(trim(cc.name), ''), 'Uncategorized'),
  r.product_id,
  r.product_name;

create or replace view public.report_category_sales
as
select
  r.store_id,
  r.device_id,
  r.sales_date,
  coalesce(nullif(trim(cc.name), ''), 'Uncategorized') as category,
  sum(r.quantity)::integer as quantity_sold,
  sum(r.reconciled_item_total) as total_sales
from public.report_reconciled_transaction_items r
left join public.catalog_products cp
  on cp.store_id = r.store_id
 and lower(trim(cp.product_id)) = lower(trim(r.product_id))
left join public.catalog_categories cc
  on cc.store_id = cp.store_id
 and lower(trim(cc.category_id)) = lower(trim(cp.category_id))
group by
  r.store_id,
  r.device_id,
  r.sales_date,
  coalesce(nullif(trim(cc.name), ''), 'Uncategorized');

grant select on public.report_product_sales to authenticated;
grant select on public.report_category_sales to authenticated;

notify pgrst, 'reload schema';
