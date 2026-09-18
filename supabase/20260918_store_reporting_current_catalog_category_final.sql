-- Bigger Brew Store Management: FINAL category source for sales reporting.
--
-- IMPORTANT:
-- Apply this migration AFTER 20260918_store_sales_consistency.sql and any
-- later migration that recreates report_product_sales/report_category_sales.
-- The sales-consistency migration historically used transaction_items.category;
-- this final definition intentionally replaces that behavior.
--
-- Category source of truth for reporting:
--   transaction_items.product_id
--       -> catalog_products.product_id (store-scoped)
--       -> catalog_products.category_id
--       -> catalog_categories.category_id (store-scoped)
--       -> catalog_categories.name
--
-- Historical transaction_items.category is NOT used for category reporting.
-- If a product no longer exists in the current catalog, report it as
-- "Uncategorized" rather than trusting a stale historical category snapshot.

create or replace view public.report_product_sales
with (security_invoker = true)
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
with (security_invoker = true)
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
