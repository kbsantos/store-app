-- Store Management: transaction history and transaction detail.
-- Read-only, store-scoped RPCs. Uses JSON projection so it tolerates the
-- live transaction schema's historical column naming differences.

create or replace function public.get_store_sales_transactions(
  p_start_date date,
  p_end_date date,
  p_search text default null,
  p_status text default null
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

  with tx as (
    select
      t.id,
      to_jsonb(t) as j
    from public.transactions t
    where (t.store_id = v_store_id)
      and coalesce(
        (to_jsonb(t)->>'business_date')::date,
        (to_jsonb(t)->>'transaction_date')::date,
        ((to_jsonb(t)->>'created_at')::timestamptz at time zone 'Asia/Manila')::date
      ) between p_start_date and p_end_date
  ), normalized as (
    select
      id,
      j,
      coalesce(j->>'order_number', j->>'transaction_number', j->>'receipt_number', j->>'reference_number', id::text) as reference_no,
      coalesce(j->>'status', j->>'transaction_status', j->>'payment_status', '') as status,
      coalesce(j->>'device_id', j->>'kiosk_id', j->>'device', '') as device_id,
      coalesce(j->>'payment_method', j->>'payment_type', '') as payment_method,
      coalesce((j->>'total')::numeric, (j->>'grand_total')::numeric, (j->>'total_amount')::numeric, (j->>'amount')::numeric, 0) as total,
      coalesce(j->>'business_date', j->>'transaction_date', j->>'created_at') as date_value
    from tx
  ), filtered as (
    select * from normalized n
    where (nullif(trim(coalesce(p_status,'')), '') is null or lower(n.status)=lower(trim(p_status)))
      and (nullif(trim(coalesce(p_search,'')), '') is null
           or n.reference_no ilike '%'||trim(p_search)||'%'
           or n.id::text ilike '%'||trim(p_search)||'%'
           or n.device_id ilike '%'||trim(p_search)||'%')
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', id,
      'referenceNo', reference_no,
      'status', status,
      'deviceId', device_id,
      'paymentMethod', payment_method,
      'total', total,
      'dateValue', date_value,
      'itemCount', (select count(*) from public.transaction_items ti where ti.transaction_id = f.id)
    ) order by date_value desc, id desc
  ), '[]'::jsonb)
  into v_result
  from filtered f;

  return v_result;
end;
$$;

create or replace function public.get_store_sales_transaction_detail(
  p_transaction_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_tx jsonb;
  v_items jsonb;
  v_payments jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  v_store_id := public.current_management_store_id();
  if v_store_id is null then raise exception 'Your account is not assigned to a store.'; end if;

  select to_jsonb(t) into v_tx
  from public.transactions t
  where t.id=p_transaction_id and t.store_id=v_store_id;

  if v_tx is null then raise exception 'Transaction not found.'; end if;

  select coalesce(jsonb_agg(to_jsonb(ti) order by ti.id), '[]'::jsonb)
    into v_items
  from public.transaction_items ti
  where ti.transaction_id=p_transaction_id;

  select coalesce(jsonb_agg(to_jsonb(p) order by p.id), '[]'::jsonb)
    into v_payments
  from public.payments p
  where p.transaction_id=p_transaction_id;

  return jsonb_build_object('transaction', v_tx, 'items', v_items, 'payments', v_payments);
end;
$$;

revoke all on function public.get_store_sales_transactions(date,date,text,text) from public;
grant execute on function public.get_store_sales_transactions(date,date,text,text) to authenticated;
revoke all on function public.get_store_sales_transaction_detail(uuid) from public;
grant execute on function public.get_store_sales_transaction_detail(uuid) to authenticated;

notify pgrst, 'reload schema';
