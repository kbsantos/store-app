-- Store Management: payment summary, derived from the transaction/payment
-- records rather than relying on a pre-aggregated summary table.

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
      and lower(coalesce(to_jsonb(t)->>'status', to_jsonb(t)->>'transaction_status', ''))
          not in ('cancelled', 'canceled', 'refunded')
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
    ),
    '[]'::jsonb
  )
  into v_result
  from grouped;

  return v_result;
end;
$$;

revoke all on function public.get_store_payment_summary(date,date) from public;
grant execute on function public.get_store_payment_summary(date,date) to authenticated;

notify pgrst, 'reload schema';
