-- Bigger Brew Store Management: Sales Reporting Center Phase 3
--
-- Adds read-only report contracts for:
--   1. Discounts & Charges
--   2. End of Day reporting
--
-- The EOD report deliberately wraps the existing get_store_eod_summary()
-- contract. It does not reimplement EOD sales/payment/reconciliation logic.
--
-- No transaction data is modified by this migration.

create or replace function public.get_store_discounts_charges(
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

  /*
   * Transactions have had historical column-name differences, so this report
   * reads the transaction JSON projection. Discount uses the first populated
   * conventional field. Charges similarly use a scalar charge/fee field or,
   * when charges is stored as an array/object, its amount/value/total entries.
   *
   * If the live transaction schema does not record applied charges, charges
   * correctly remain zero; catalog_automatic_charges is configuration, not
   * proof that a charge was actually applied to a sale.
   */
  with normalized as (
    select
      t.id,
      coalesce(
        nullif((to_jsonb(t)->>'business_date'), '')::date,
        nullif((to_jsonb(t)->>'transaction_date'), '')::date,
        (((to_jsonb(t)->>'created_at')::timestamptz at time zone 'Asia/Manila')::date)
      ) as sales_date,
      lower(coalesce(
        to_jsonb(t)->>'status',
        to_jsonb(t)->>'transaction_status',
        to_jsonb(t)->>'payment_status',
        ''
      )) as status,
      coalesce(
        nullif(to_jsonb(t)->>'subtotal', '')::numeric,
        nullif(to_jsonb(t)->>'sub_total', '')::numeric,
        0
      ) as subtotal,
      coalesce(
        nullif(to_jsonb(t)->>'discount', '')::numeric,
        nullif(to_jsonb(t)->>'discount_amount', '')::numeric,
        nullif(to_jsonb(t)->>'discount_total', '')::numeric,
        0
      ) as discount,
      coalesce(
        nullif(to_jsonb(t)->>'charge', '')::numeric,
        nullif(to_jsonb(t)->>'charge_amount', '')::numeric,
        nullif(to_jsonb(t)->>'charges_amount', '')::numeric,
        nullif(to_jsonb(t)->>'service_charge', '')::numeric,
        nullif(to_jsonb(t)->>'service_fee', '')::numeric,
        nullif(to_jsonb(t)->>'fee', '')::numeric,
        nullif(to_jsonb(t)->>'fees', '')::numeric,
        case
          when jsonb_typeof(to_jsonb(t)->'charges') = 'array' then (
            select coalesce(sum(coalesce(
              nullif(e.value->>'amount', '')::numeric,
              nullif(e.value->>'value', '')::numeric,
              nullif(e.value->>'total', '')::numeric,
              0
            )), 0)
            from jsonb_array_elements(to_jsonb(t)->'charges') e
          )
          when jsonb_typeof(to_jsonb(t)->'charges') = 'object' then coalesce(
            nullif(to_jsonb(t)->'charges'->>'amount', '')::numeric,
            nullif(to_jsonb(t)->'charges'->>'value', '')::numeric,
            nullif(to_jsonb(t)->'charges'->>'total', '')::numeric,
            0
          )
          else 0
        end
      ) as charges,
      coalesce(
        nullif(to_jsonb(t)->>'total', '')::numeric,
        nullif(to_jsonb(t)->>'grand_total', '')::numeric,
        nullif(to_jsonb(t)->>'total_amount', '')::numeric,
        nullif(to_jsonb(t)->>'amount', '')::numeric,
        0
      ) as total_sales
    from public.transactions t
    where t.store_id = v_store_id
  ),
  filtered as (
    select *
    from normalized
    where sales_date between p_start_date and p_end_date
      and status in ('completed', 'complete', 'paid', 'closed')
  ),
  grouped as (
    select
      sales_date,
      count(*)::integer as transaction_count,
      coalesce(sum(subtotal), 0) as subtotal,
      coalesce(sum(discount), 0) as discount,
      coalesce(sum(charges), 0) as charges,
      coalesce(sum(total_sales), 0) as total_sales
    from filtered
    group by sales_date
  ),
  dates as (
    select generate_series(p_start_date, p_end_date, interval '1 day')::date as sales_date
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'salesDate', d.sales_date,
        'transactionCount', coalesce(g.transaction_count, 0),
        'subtotal', coalesce(g.subtotal, 0),
        'discount', coalesce(g.discount, 0),
        'charges', coalesce(g.charges, 0),
        'totalSales', coalesce(g.total_sales, 0)
      )
      order by d.sales_date
    ),
    '[]'::jsonb
  )
  into v_result
  from dates d
  left join grouped g on g.sales_date = d.sales_date;

  return v_result;
end;
$$;

revoke all on function public.get_store_discounts_charges(date, date) from public;
grant execute on function public.get_store_discounts_charges(date, date) to authenticated;


-- Central Reporting Center EOD range wrapper.
-- This calls the existing authoritative per-day EOD summary and therefore
-- preserves the current EOD reconciliation and closing behavior.
create or replace function public.get_store_eod_reporting(
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
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  if p_start_date is null or p_end_date is null then
    raise exception 'Date range is required.';
  end if;

  if p_start_date > p_end_date then
    raise exception 'Start date cannot be after end date.';
  end if;

  select coalesce(
    jsonb_agg(public.get_store_eod_summary(d::date)::jsonb order by d),
    '[]'::jsonb
  )
  into v_result
  from generate_series(p_start_date, p_end_date, interval '1 day') as dates(d);

  return v_result;
end;
$$;

revoke all on function public.get_store_eod_reporting(date, date) from public;
grant execute on function public.get_store_eod_reporting(date, date) to authenticated;

notify pgrst, 'reload schema';
