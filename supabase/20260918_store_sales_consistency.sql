-- Bigger Brew Store Management: sales/reporting consistency hardening.
--
-- All management sales surfaces use the same definition of a completed sale:
-- completed, complete, paid, or closed. Cancelled/void/refunded/draft/pending
-- transactions are not included in sales totals, product/category/hourly sales,
-- payment summaries, or EOD totals.

create or replace view public.report_product_sales
with (security_invoker = true)
as
select
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date as sales_date,
  ti.category,
  ti.product_id,
  ti.product_name,
  sum(ti.quantity)::integer as quantity_sold,
  sum(ti.total) as total_sales,
  case
    when sum(ti.quantity) = 0 then 0
    else sum(ti.total) / sum(ti.quantity)
  end as average_unit_price
from public.transactions t
join public.transaction_items ti on ti.transaction_id = t.id
where lower(coalesce(to_jsonb(t)->>'status', to_jsonb(t)->>'transaction_status', to_jsonb(t)->>'payment_status', ''))
      in ('completed','complete','paid','closed')
group by
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date,
  ti.category,
  ti.product_id,
  ti.product_name;

create or replace view public.report_category_sales
with (security_invoker = true)
as
select
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date as sales_date,
  coalesce(nullif(ti.category, ''), 'Uncategorized') as category,
  sum(ti.quantity)::integer as quantity_sold,
  sum(ti.total) as total_sales
from public.transactions t
join public.transaction_items ti on ti.transaction_id = t.id
where lower(coalesce(to_jsonb(t)->>'status', to_jsonb(t)->>'transaction_status', to_jsonb(t)->>'payment_status', ''))
      in ('completed','complete','paid','closed')
group by
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date,
  coalesce(nullif(ti.category, ''), 'Uncategorized');

create or replace view public.report_daily_sales
with (security_invoker = true)
as
select
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date as sales_date,
  count(distinct t.id)::integer as transaction_count,
  coalesce(sum(t.subtotal), 0) as subtotal,
  coalesce(sum(t.discount), 0) as discount,
  coalesce(sum(t.total), 0) as total_sales
from public.transactions t
where lower(coalesce(to_jsonb(t)->>'status', to_jsonb(t)->>'transaction_status', to_jsonb(t)->>'payment_status', ''))
      in ('completed','complete','paid','closed')
group by
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date;

create or replace view public.report_device_sales
with (security_invoker = true)
as
select
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date as sales_date,
  count(distinct t.id)::integer as transaction_count,
  coalesce(sum(t.subtotal), 0) as subtotal,
  coalesce(sum(t.discount), 0) as discount,
  coalesce(sum(t.total), 0) as total_sales
from public.transactions t
where lower(coalesce(to_jsonb(t)->>'status', to_jsonb(t)->>'transaction_status', to_jsonb(t)->>'payment_status', ''))
      in ('completed','complete','paid','closed')
group by
  t.store_id,
  t.device_id,
  (t.transaction_date at time zone 'Asia/Manila')::date;

create or replace function public.get_store_payment_summary(
  p_start_date date,
  p_end_date date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  v_store_id := public.current_management_store_id();
  if v_store_id is null then raise exception 'Your account is not assigned to a store.'; end if;
  if p_start_date is null or p_end_date is null then raise exception 'Date range is required.'; end if;
  if p_start_date > p_end_date then raise exception 'Start date cannot be after end date.'; end if;

  with payment_rows as (
    select
      p.id,
      coalesce(
        nullif(trim(to_jsonb(p)->>'payment_method'), ''),
        nullif(trim(to_jsonb(p)->>'payment_type'), ''),
        nullif(trim(to_jsonb(p)->>'method'), ''),
        'Unknown'
      ) as payment_method,
      coalesce(
        nullif(to_jsonb(p)->>'amount', '')::numeric,
        nullif(to_jsonb(p)->>'total', '')::numeric,
        nullif(to_jsonb(p)->>'paid', '')::numeric,
        0
      ) as amount
    from public.payments p
    join public.transactions t on t.id = p.transaction_id
    where t.store_id = v_store_id
      and coalesce(
        nullif(to_jsonb(t)->>'business_date', '')::date,
        nullif(to_jsonb(t)->>'transaction_date', '')::date,
        (((to_jsonb(t)->>'created_at')::timestamptz) at time zone 'Asia/Manila')::date
      ) between p_start_date and p_end_date
      and lower(coalesce(
        to_jsonb(t)->>'status',
        to_jsonb(t)->>'transaction_status',
        to_jsonb(t)->>'payment_status',
        ''
      )) in ('completed','complete','paid','closed')
  ), grouped as (
    select payment_method, count(*)::integer as payment_count, sum(amount) as total_amount
    from payment_rows
    group by payment_method
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'paymentMethod', payment_method,
        'paymentCount', payment_count,
        'totalAmount', total_amount
      ) order by total_amount desc, payment_method
    ), '[]'::jsonb
  ) into v_result
  from grouped;

  return v_result;
end;
$$;

create or replace function public.get_store_hourly_sales(
  p_start_date date,
  p_end_date date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  v_store_id := public.current_management_store_id();
  if v_store_id is null then raise exception 'Your account is not assigned to a store.'; end if;
  if p_start_date is null or p_end_date is null then raise exception 'Date range is required.'; end if;
  if p_start_date > p_end_date then raise exception 'Start date cannot be after end date.'; end if;

  with normalized as (
    select
      t.id,
      coalesce(
        (to_jsonb(t)->>'business_date')::date,
        (to_jsonb(t)->>'transaction_date')::date,
        ((to_jsonb(t)->>'created_at')::timestamptz at time zone 'Asia/Manila')::date
      ) as sales_date,
      coalesce(
        (to_jsonb(t)->>'created_at')::timestamptz,
        (to_jsonb(t)->>'transaction_date')::timestamptz,
        (to_jsonb(t)->>'business_date')::timestamptz
      ) as event_time,
      coalesce(to_jsonb(t)->>'device_id', to_jsonb(t)->>'kiosk_id', to_jsonb(t)->>'device', '') as device_id,
      coalesce((to_jsonb(t)->>'total')::numeric, (to_jsonb(t)->>'grand_total')::numeric, (to_jsonb(t)->>'total_amount')::numeric, (to_jsonb(t)->>'amount')::numeric, 0) as total,
      lower(coalesce(to_jsonb(t)->>'status', to_jsonb(t)->>'transaction_status', to_jsonb(t)->>'payment_status', '')) as status
    from public.transactions t
    where t.store_id = v_store_id
  ), filtered as (
    select * from normalized n
    where n.sales_date between p_start_date and p_end_date
      and n.status in ('completed','complete','paid','closed')
  ), hourly as (
    select
      extract(hour from (f.event_time at time zone 'Asia/Manila'))::int as hour_of_day,
      count(*)::int as transaction_count,
      coalesce(sum((select count(*) from public.transaction_items ti where ti.transaction_id=f.id)),0)::int as item_count,
      coalesce(sum(f.total),0) as total_sales
    from filtered f
    where f.event_time is not null
    group by 1
  ), hours as (
    select generate_series(0,23) as hour_of_day
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'hour', h.hour_of_day,
      'label', lpad(h.hour_of_day::text,2,'0') || ':00',
      'transactionCount', coalesce(a.transaction_count,0),
      'itemCount', coalesce(a.item_count,0),
      'totalSales', coalesce(a.total_sales,0)
    ) order by h.hour_of_day
  ), '[]'::jsonb) into v_result
  from hours h
  left join hourly a on a.hour_of_day = h.hour_of_day;

  return v_result;
end;
$$;

-- EOD uses the same completed-sale definition and also exposes reconciliation
-- metadata so the UI can warn when recorded payments differ from sales.
create or replace function public.get_store_eod_summary(p_business_date date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_sales_total numeric := 0;
  v_transaction_count integer := 0;
  v_payment_total numeric := 0;
  v_payment_difference numeric := 0;
  v_status_col text;
  v_date_col text;
  v_date_is_date boolean := false;
  v_status_condition text;
  v_sql text;
  v_closing jsonb;
  v_payments jsonb;
  v_consumption jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  v_store_id := public.current_management_store_id();
  if v_store_id is null then raise exception 'Your account is not assigned to a store.'; end if;
  if p_business_date is null then raise exception 'Business date is required.'; end if;

  select column_name into v_status_col
  from information_schema.columns
  where table_schema='public' and table_name='transactions'
    and column_name in ('status','transaction_status','payment_status')
  order by case column_name when 'status' then 1 when 'transaction_status' then 2 else 3 end
  limit 1;

  select column_name into v_date_col
  from information_schema.columns
  where table_schema='public' and table_name='transactions'
    and column_name in ('business_date','transaction_date','created_at')
  order by case column_name when 'business_date' then 1 when 'transaction_date' then 2 else 3 end
  limit 1;

  if v_date_col is null then raise exception 'transactions table does not expose a usable date field.'; end if;

  select data_type = 'date' into v_date_is_date
  from information_schema.columns
  where table_schema='public' and table_name='transactions' and column_name=v_date_col;

  if v_status_col is null then
    v_status_condition := 'false';
  else
    v_status_condition := format('(lower(coalesce(t.%I::text, '''')) in (''completed'',''complete'',''paid'',''closed''))', v_status_col);
  end if;

  if v_date_is_date then
    v_sql := format($q$
      select count(*)::integer, coalesce(sum(coalesce((to_jsonb(t)->>'total')::numeric,
        (to_jsonb(t)->>'grand_total')::numeric,
        (to_jsonb(t)->>'total_amount')::numeric,
        (to_jsonb(t)->>'amount')::numeric, 0)),0)
      from public.transactions t
      where t.store_id=$1 and %s and t.%I=$2
    $q$, v_status_condition, v_date_col);
  else
    v_sql := format($q$
      select count(*)::integer, coalesce(sum(coalesce((to_jsonb(t)->>'total')::numeric,
        (to_jsonb(t)->>'grand_total')::numeric,
        (to_jsonb(t)->>'total_amount')::numeric,
        (to_jsonb(t)->>'amount')::numeric, 0)),0)
      from public.transactions t
      where t.store_id=$1 and %s and (t.%I::timestamptz at time zone 'Asia/Manila')::date=$2
    $q$, v_status_condition, v_date_col);
  end if;

  execute v_sql into v_transaction_count, v_sales_total using v_store_id, p_business_date;

  v_payments := public.get_store_payment_summary(p_business_date, p_business_date);
  select coalesce(sum(coalesce((x->>'totalAmount')::numeric,0)),0)
    into v_payment_total
  from jsonb_array_elements(v_payments) x;
  v_payment_difference := round(v_sales_total - v_payment_total, 2);

  v_consumption := public.get_store_inventory_consumption_summary(p_business_date);

  select to_jsonb(c) into v_closing
  from public.store_eod_closings c
  where c.store_id=v_store_id and c.business_date=p_business_date;

  return jsonb_build_object(
    'storeId', v_store_id,
    'businessDate', p_business_date,
    'salesTotal', v_sales_total,
    'transactionCount', v_transaction_count,
    'paymentTotal', v_payment_total,
    'paymentDifference', v_payment_difference,
    'payments', v_payments,
    'inventoryConsumption', v_consumption,
    'closing', coalesce(v_closing, '{}'::jsonb)
  );
end;
$$;

revoke all on function public.get_store_payment_summary(date,date) from public;
grant execute on function public.get_store_payment_summary(date,date) to authenticated;
revoke all on function public.get_store_hourly_sales(date,date) from public;
grant execute on function public.get_store_hourly_sales(date,date) to authenticated;
revoke all on function public.get_store_eod_summary(date) from public;
grant execute on function public.get_store_eod_summary(date) to authenticated;

grant select on public.report_product_sales to authenticated;
grant select on public.report_category_sales to authenticated;
grant select on public.report_daily_sales to authenticated;
grant select on public.report_device_sales to authenticated;

notify pgrst, 'reload schema';
