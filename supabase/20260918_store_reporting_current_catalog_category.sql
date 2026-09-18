-- Bigger Brew Store Management: use the current catalog category for sales reporting.
--
-- Transaction item category values are historical snapshots and may become stale
-- when a product is re-categorized in the current catalog. Sales reports should
-- classify a transaction item by its current catalog product/category instead.
--
-- The join is store-scoped and uses the stable catalog_products.product_id text
-- key, not the catalog_products UUID primary key. If a historical product can no
-- longer be found in the current catalog, the line is reported as Uncategorized
-- rather than reusing the stale transaction category.

create or replace view public.report_product_sales
with (security_invoker = true)
as
select
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date as sales_date,
  coalesce(nullif(cc.name, ''), 'Uncategorized') as category,
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
 and cp.product_id = ti.product_id
left join public.catalog_categories cc
  on cc.store_id = cp.store_id
 and cc.category_id = cp.category_id
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
  coalesce(nullif(cc.name, ''), 'Uncategorized'),
  ti.product_id,
  ti.product_name;

create or replace view public.report_category_sales
with (security_invoker = true)
as
select
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date as sales_date,
  coalesce(nullif(cc.name, ''), 'Uncategorized') as category,
  sum(ti.quantity)::integer as quantity_sold,
  sum(ti.total) as total_sales
from public.transactions t
join public.transaction_items ti
  on ti.transaction_id = t.id
left join public.catalog_products cp
  on cp.store_id = t.store_id
 and cp.product_id = ti.product_id
left join public.catalog_categories cc
  on cc.store_id = cp.store_id
 and cc.category_id = cp.category_id
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
  coalesce(nullif(cc.name, ''), 'Uncategorized');

grant select on public.report_product_sales to authenticated;
grant select on public.report_category_sales to authenticated;

notify pgrst, 'reload schema';
