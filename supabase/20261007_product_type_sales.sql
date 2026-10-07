-- Bigger Brew Store Management: Product Type Sales reporting.
--
-- Product Type Sales is derived from the same reconciled transaction layer used
-- by Product Sales and Category Sales. Product type comes from the current
-- catalog_products record, scoped by store and stable product_id.
--
-- Apply this migration AFTER:
--   20260922_store_reporting_transaction_reconciliation.sql
--   20260922_store_reporting_transaction_reconciliation_category_fix.sql
--
-- No transaction data is modified.

create or replace view public.report_product_type_sales
as
select
  r.store_id,
  r.device_id,
  r.sales_date,
  coalesce(nullif(trim(cp.product_type), ''), 'Uncategorized') as product_type,
  sum(r.quantity)::integer as quantity_sold,
  sum(r.reconciled_item_total) as total_sales
from public.report_reconciled_transaction_items r
left join public.catalog_products cp
  on cp.store_id = r.store_id
 and lower(trim(cp.product_id)) = lower(trim(r.product_id))
group by
  r.store_id,
  r.device_id,
  r.sales_date,
  coalesce(nullif(trim(cp.product_type), ''), 'Uncategorized');

grant select on public.report_product_type_sales to authenticated;

notify pgrst, 'reload schema';
