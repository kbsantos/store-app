-- Store Management: Hourly Sales timezone correction.
--
-- transaction_date / created_at are stored as timestamptz (UTC in the live
-- database). Hourly Sales is a store-local report and must group/filter using
-- Asia/Manila local time. The previous RPC could expose UTC hours, which made
-- September 17 activity appear around 03:00-04:00 instead of the actual
-- 08:00-20:00 Manila operating hours.
--
-- This migration intentionally redefines the RPC after the earlier hourly
-- quantity fix so this is the final deployed contract.

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
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  v_store_id := public.current_management_store_id();
  if v_store_id is null then
    raise exception 'Your account is not assigned to a store.';
  end if;

  if p_start_date is null or p_end_date is null then
    raise exception 'Date range is required.';
  end if;

  if p_start_date > p_end_date then
    raise exception 'Start date cannot be after end date.';
  end if;

  with normalized as (
    select
      t.id,
      -- Always derive the reporting date from the same local event timestamp
      -- used for the hourly bucket. This prevents date/hour boundary drift.
      (
        coalesce(
          (to_jsonb(t)->>'transaction_date')::timestamptz,
          (to_jsonb(t)->>'created_at')::timestamptz
        ) at time zone 'Asia/Manila'
      ) as local_event_time,
      coalesce(
        (to_jsonb(t)->>'total')::numeric,
        (to_jsonb(t)->>'grand_total')::numeric,
        (to_jsonb(t)->>'total_amount')::numeric,
        (to_jsonb(t)->>'amount')::numeric,
        0
      ) as total,
      lower(coalesce(
        to_jsonb(t)->>'status',
        to_jsonb(t)->>'transaction_status',
        to_jsonb(t)->>'payment_status',
        ''
      )) as status
    from public.transactions t
    where t.store_id = v_store_id
  ), filtered as (
    select *
    from normalized n
    where n.local_event_time::date between p_start_date and p_end_date
      and n.status in ('completed', 'complete', 'paid', 'closed')
  ), item_totals as (
    select
      ti.transaction_id,
      coalesce(sum(ti.quantity), 0)::int as item_count
    from public.transaction_items ti
    join filtered f on f.id = ti.transaction_id
    group by ti.transaction_id
  ), hourly as (
    select
      extract(hour from f.local_event_time)::int as hour_of_day,
      count(*)::int as transaction_count,
      coalesce(sum(it.item_count), 0)::int as item_count,
      coalesce(sum(f.total), 0) as total_sales
    from filtered f
    left join item_totals it on it.transaction_id = f.id
    group by 1
  ), hours as (
    select generate_series(0, 23) as hour_of_day
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'hour', h.hour_of_day,
        'label', lpad(h.hour_of_day::text, 2, '0') || ':00',
        'transactionCount', coalesce(a.transaction_count, 0),
        'itemCount', coalesce(a.item_count, 0),
        'totalSales', coalesce(a.total_sales, 0)
      ) order by h.hour_of_day
    ),
    '[]'::jsonb
  )
  into v_result
  from hours h
  left join hourly a on a.hour_of_day = h.hour_of_day;

  return v_result;
end;
$$;

revoke all on function public.get_store_hourly_sales(date, date) from public;
grant execute on function public.get_store_hourly_sales(date, date) to authenticated;

notify pgrst, 'reload schema';
