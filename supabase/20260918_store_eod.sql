-- Store Management: End of Day summary and close state.
-- EOD is store-scoped and idempotent per business date.

create table if not exists public.store_eod_closings (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null,
  business_date date not null,
  status text not null default 'open' check (status in ('open','completed')),
  sales_total numeric not null default 0,
  transaction_count integer not null default 0,
  payment_total numeric not null default 0,
  inventory_processed boolean not null default false,
  completed_at timestamptz,
  completed_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, business_date)
);

create index if not exists store_eod_closings_store_date_idx
  on public.store_eod_closings(store_id, business_date desc);

alter table public.store_eod_closings enable row level security;

drop policy if exists store_eod_closings_select on public.store_eod_closings;
create policy store_eod_closings_select on public.store_eod_closings
  for select to authenticated
  using (store_id = public.current_management_store_id());

-- Returns the current EOD summary. Sales are derived directly from transactions,
-- while payment and inventory details use the existing store-scoped reporting RPCs.
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
    v_status_condition := 'true';
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
    'payments', v_payments,
    'inventoryConsumption', v_consumption,
    'closing', coalesce(v_closing, '{}'::jsonb)
  );
end;
$$;

create or replace function public.complete_store_eod(p_business_date date)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_role text;
  v_summary jsonb;
  v_consumption jsonb;
  v_sales_total numeric;
  v_transaction_count integer;
  v_payment_total numeric;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  v_store_id := public.current_management_store_id();
  v_role := lower(coalesce(auth.jwt()->'app_metadata'->>'role','staff'));
  if v_store_id is null then raise exception 'Your account is not assigned to a store.'; end if;
  if v_role not in ('owner','manager','admin') then raise exception 'Manager or owner access is required.'; end if;
  if p_business_date is null then raise exception 'Business date is required.'; end if;

  select public.get_store_eod_summary(p_business_date) into v_summary;
  v_sales_total := coalesce((v_summary->>'salesTotal')::numeric,0);
  v_transaction_count := coalesce((v_summary->>'transactionCount')::integer,0);
  v_payment_total := coalesce((v_summary->>'paymentTotal')::numeric,0);

  v_consumption := public.process_store_inventory_consumption(p_business_date);

  insert into public.store_eod_closings(
    store_id,business_date,status,sales_total,transaction_count,payment_total,
    inventory_processed,completed_at,completed_by,updated_at
  ) values (
    v_store_id,p_business_date,'completed',v_sales_total,v_transaction_count,v_payment_total,
    true,now(),auth.uid(),now()
  )
  on conflict (store_id,business_date) do update set
    status='completed', sales_total=excluded.sales_total,
    transaction_count=excluded.transaction_count, payment_total=excluded.payment_total,
    inventory_processed=true, completed_at=now(), completed_by=auth.uid(), updated_at=now()
  returning id into v_id;

  return jsonb_build_object(
    'id', v_id,
    'businessDate', p_business_date,
    'salesTotal', v_sales_total,
    'transactionCount', v_transaction_count,
    'paymentTotal', v_payment_total,
    'inventoryProcessed', true,
    'consumption', v_consumption
  );
end;
$$;

revoke all on function public.get_store_eod_summary(date) from public;
grant execute on function public.get_store_eod_summary(date) to authenticated;
revoke all on function public.complete_store_eod(date) from public;
grant execute on function public.complete_store_eod(date) to authenticated;

notify pgrst, 'reload schema';
