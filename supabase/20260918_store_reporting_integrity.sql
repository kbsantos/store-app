-- Store Management: read-only cross-report integrity checks.
-- Compares the independent reporting surfaces for the same store/date range.

create or replace function public.get_store_reporting_integrity(
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
  v_daily_sales numeric := 0;
  v_product_sales numeric := 0;
  v_category_sales numeric := 0;
  v_device_sales numeric := 0;
  v_payment_total numeric := 0;
  v_daily_orders bigint := 0;
  v_device_orders bigint := 0;
  v_product_items bigint := 0;
  v_category_items bigint := 0;
  v_payment_count bigint := 0;
  v_checks jsonb := '[]'::jsonb;
  v_status text := 'PASS';
  v_tolerance numeric := 0.01;
  v_diff numeric;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  v_store_id := public.current_management_store_id();
  if v_store_id is null then raise exception 'Your account is not assigned to a store.'; end if;
  if p_start_date is null or p_end_date is null then raise exception 'Date range is required.'; end if;
  if p_start_date > p_end_date then raise exception 'Start date cannot be after end date.'; end if;

  select coalesce(sum(total_sales),0), coalesce(sum(transaction_count),0)
    into v_daily_sales, v_daily_orders
  from public.report_daily_sales
  where store_id = v_store_id and sales_date between p_start_date and p_end_date;

  select coalesce(sum(total_sales),0), coalesce(sum(quantity_sold),0)
    into v_product_sales, v_product_items
  from public.report_product_sales
  where store_id = v_store_id and sales_date between p_start_date and p_end_date;

  select coalesce(sum(total_sales),0), coalesce(sum(quantity_sold),0)
    into v_category_sales, v_category_items
  from public.report_category_sales
  where store_id = v_store_id and sales_date between p_start_date and p_end_date;

  select coalesce(sum(total_sales),0), coalesce(sum(transaction_count),0)
    into v_device_sales, v_device_orders
  from public.report_device_sales
  where store_id = v_store_id and sales_date between p_start_date and p_end_date;

  with payment_rows as (
    select coalesce(
      nullif(to_jsonb(p)->>'amount','')::numeric,
      nullif(to_jsonb(p)->>'total','')::numeric,
      nullif(to_jsonb(p)->>'paid','')::numeric,
      0
    ) as amount
    from public.payments p
    join public.transactions t on t.id = p.transaction_id
    where t.store_id = v_store_id
      and coalesce(
        nullif(to_jsonb(t)->>'business_date','')::date,
        nullif(to_jsonb(t)->>'transaction_date','')::date,
        (((to_jsonb(t)->>'created_at')::timestamptz) at time zone 'Asia/Manila')::date
      ) between p_start_date and p_end_date
      and lower(coalesce(
        to_jsonb(t)->>'status',
        to_jsonb(t)->>'transaction_status',
        to_jsonb(t)->>'payment_status',''
      )) in ('completed','complete','paid','closed')
  )
  select coalesce(sum(amount),0), count(*) into v_payment_total, v_payment_count from payment_rows;

  v_diff := round(v_daily_sales - v_product_sales, 2);
  v_checks := v_checks || jsonb_build_array(jsonb_build_object(
    'name','Daily vs Product Sales','difference',v_diff,
    'expected',v_daily_sales,'actual',v_product_sales,
    'passed',abs(v_diff) < v_tolerance
  ));
  if abs(v_diff) >= v_tolerance then v_status := 'ATTENTION'; end if;

  v_diff := round(v_daily_sales - v_category_sales, 2);
  v_checks := v_checks || jsonb_build_array(jsonb_build_object(
    'name','Daily vs Category Sales','difference',v_diff,
    'expected',v_daily_sales,'actual',v_category_sales,
    'passed',abs(v_diff) < v_tolerance
  ));
  if abs(v_diff) >= v_tolerance then v_status := 'ATTENTION'; end if;

  v_diff := round(v_daily_sales - v_device_sales, 2);
  v_checks := v_checks || jsonb_build_array(jsonb_build_object(
    'name','Daily vs Device Sales','difference',v_diff,
    'expected',v_daily_sales,'actual',v_device_sales,
    'passed',abs(v_diff) < v_tolerance
  ));
  if abs(v_diff) >= v_tolerance then v_status := 'ATTENTION'; end if;

  v_diff := round(v_daily_sales - v_payment_total, 2);
  v_checks := v_checks || jsonb_build_array(jsonb_build_object(
    'name','Sales vs Payments','difference',v_diff,
    'expected',v_daily_sales,'actual',v_payment_total,
    'passed',abs(v_diff) < v_tolerance
  ));
  if abs(v_diff) >= v_tolerance then v_status := 'ATTENTION'; end if;

  v_diff := v_product_items - v_category_items;
  v_checks := v_checks || jsonb_build_array(jsonb_build_object(
    'name','Product vs Category Items','difference',v_diff,
    'expected',v_product_items,'actual',v_category_items,
    'passed',v_diff = 0
  ));
  if v_diff <> 0 then v_status := 'ATTENTION'; end if;

  v_diff := v_daily_orders - v_device_orders;
  v_checks := v_checks || jsonb_build_array(jsonb_build_object(
    'name','Daily vs Device Orders','difference',v_diff,
    'expected',v_daily_orders,'actual',v_device_orders,
    'passed',v_diff = 0
  ));
  if v_diff <> 0 then v_status := 'ATTENTION'; end if;

  return jsonb_build_object(
    'status',v_status,
    'startDate',p_start_date,
    'endDate',p_end_date,
    'salesTotal',v_daily_sales,
    'paymentTotal',v_payment_total,
    'paymentCount',v_payment_count,
    'orderCount',v_daily_orders,
    'checks',v_checks
  );
end;
$$;

revoke all on function public.get_store_reporting_integrity(date,date) from public;
grant execute on function public.get_store_reporting_integrity(date,date) to authenticated;

notify pgrst, 'reload schema';
