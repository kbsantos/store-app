-- Bigger Brew Store Management: transaction-authoritative product/category sales.
--
-- The Store Dashboard's financial sales total is sourced from transactions.total.
-- Product/category reports historically summed transaction_items.total directly.
-- That can cause a report breakdown to exceed the actual transaction total when an
-- item row is stale/corrupted or when the transaction contains a discount.
--
-- This migration keeps transaction_items as the source for product/category
-- identity and quantity, but reconciles item sales amounts to the authoritative
-- transaction total on a per-transaction basis.
--
-- Rules:
--   1. Completed/paid/closed transactions only.
--   2. If item total == transaction total, keep the recorded item total.
--   3. If they differ, allocate the transaction total proportionally using the
--      recorded item totals. This preserves the item's relative contribution
--      while guaranteeing that product/category sales reconcile to transactions.
--   4. If an anomalous transaction has zero item total, allocate its transaction
--      total evenly across its item rows.
--   5. Quantity and product/category identity remain unchanged.
--
-- This is intentionally a new migration. Do not rewrite deployed migrations.

drop view if exists public.report_reconciled_transaction_items;

create view public.report_reconciled_transaction_items
with (security_invoker = true)
as
with completed_items as (
  select
    t.id as transaction_id,
    t.store_id,
    t.device_id,
    (t.transaction_date at time zone 'Asia/Manila')::date as sales_date,
    coalesce(
      nullif(to_jsonb(t)->>'total', '')::numeric,
      nullif(to_jsonb(t)->>'grand_total', '')::numeric,
      nullif(to_jsonb(t)->>'total_amount', '')::numeric,
      nullif(to_jsonb(t)->>'amount', '')::numeric,
      0
    ) as transaction_total,
    ti.id as transaction_item_id,
    ti.product_id,
    ti.product_name,
    ti.quantity,
    coalesce(ti.total, 0) as recorded_item_total,
    sum(coalesce(ti.total, 0)) over (partition by t.id) as recorded_transaction_item_total,
    count(*) over (partition by t.id) as transaction_item_count
  from public.transactions t
  join public.transaction_items ti
    on ti.transaction_id = t.id
  where lower(coalesce(
    to_jsonb(t)->>'status',
    to_jsonb(t)->>'transaction_status',
    to_jsonb(t)->>'payment_status',
    ''
  )) in ('completed','complete','paid','closed')
)
select
  transaction_id,
  store_id,
  device_id,
  sales_date,
  transaction_item_id,
  product_id,
  product_name,
  quantity,
  transaction_total,
  recorded_item_total,
  recorded_transaction_item_total,
  case
    when abs(recorded_transaction_item_total - transaction_total) <= 0.01
      then recorded_item_total
    when recorded_transaction_item_total <> 0
      then recorded_item_total
        * transaction_total
        / recorded_transaction_item_total
    when transaction_item_count > 0
      then transaction_total / transaction_item_count
    else 0
  end as reconciled_item_total
from completed_items;

grant select on public.report_reconciled_transaction_items to authenticated;

create or replace view public.report_product_sales
with (security_invoker = true)
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
with (security_invoker = true)
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
