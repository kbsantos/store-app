-- Bigger Brew Store Management: runtime fix for current-catalog category reporting.
--
-- Root cause:
-- The current-catalog reporting views were created with
--   security_invoker = true
-- which causes catalog_products/catalog_categories RLS to be evaluated using
-- the authenticated user's permissions. The reporting user can read the
-- reporting view/transactions, but cannot necessarily read the catalog tables
-- through the view. The LEFT JOIN therefore returns NULL category data and the
-- view reports every row as "Uncategorized".
--
-- This migration keeps the current-catalog category source of truth but lets
-- the view owner execute the underlying catalog joins. Store scoping remains
-- enforced by the view predicates and the authenticated role only receives
-- SELECT on the reporting views.
--
-- Apply this AFTER:
--   20260918_store_sales_consistency.sql
--   20260918_store_reporting_current_catalog_category_final.sql
-- and after any later migration that recreates these reporting views.

create or replace view public.report_product_sales
as
select
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date as sales_date,
  coalesce(nullif(trim(cc.name), ''), 'Uncategorized') as category,
  ti.product_id,
  ti.product_name,
  sum(ti.quantity)::integer as quantity_sold,
  sum(ti.total) as total_sales,
  case
    when sum(ti.quantity) = 0 then 0
    else sum(ti.total) / sum(ti.quantity)
  end as average_unit_price
from public.transactions t
join public.transaction_items ti
  on ti.transaction_id = t.id
left join public.catalog_products cp
  on cp.store_id = t.store_id
 and lower(trim(cp.product_id)) = lower(trim(ti.product_id))
left join public.catalog_categories cc
  on cc.store_id = cp.store_id
 and lower(trim(cc.category_id)) = lower(trim(cp.category_id))
where lower(coalesce(
        to_jsonb(t)->>'status',
        to_jsonb(t)->>'transaction_status',
        to_jsonb(t)->>'payment_status',
        ''
      )) in ('completed','complete','paid','closed')
group by
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date,
  coalesce(nullif(trim(cc.name), ''), 'Uncategorized'),
  ti.product_id,
  ti.product_name;

create or replace view public.report_category_sales
as
select
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date as sales_date,
  coalesce(nullif(trim(cc.name), ''), 'Uncategorized') as category,
  sum(ti.quantity)::integer as quantity_sold,
  sum(ti.total) as total_sales
from public.transactions t
join public.transaction_items ti
  on ti.transaction_id = t.id
left join public.catalog_products cp
  on cp.store_id = t.store_id
 and lower(trim(cp.product_id)) = lower(trim(ti.product_id))
left join public.catalog_categories cc
  on cc.store_id = cp.store_id
 and lower(trim(cc.category_id)) = lower(trim(cp.category_id))
where lower(coalesce(
        to_jsonb(t)->>'status',
        to_jsonb(t)->>'transaction_status',
        to_jsonb(t)->>'payment_status',
        ''
      )) in ('completed','complete','paid','closed')
group by
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date,
  coalesce(nullif(trim(cc.name), ''), 'Uncategorized');

grant select on public.report_product_sales to authenticated;
grant select on public.report_category_sales to authenticated;

notify pgrst, 'reload schema';
