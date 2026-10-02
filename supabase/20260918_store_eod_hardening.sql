-- Store Management: EOD workflow hardening.
-- Keeps EOD completion store-scoped and idempotent, and exposes a read-only
-- pre-close integrity check for sales, payments, inventory consumption and closing state.

create or replace function public.get_store_eod_integrity(p_business_date date)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_summary jsonb;
  v_sales_total numeric := 0;
  v_payment_total numeric := 0;
  v_payment_difference numeric := 0;
  v_transaction_count integer := 0;
  v_consumption_integrity jsonb;
  v_closing jsonb := '{}'::jsonb;
  v_is_completed boolean := false;
  v_payment_balanced boolean := false;
  v_inventory_balanced boolean := false;
  v_status text := 'ATTENTION';
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  v_store_id := public.current_management_store_id();
  if v_store_id is null then raise exception 'Your account is not assigned to a store.'; end if;
  if p_business_date is null then raise exception 'Business date is required.'; end if;

  v_summary := public.get_store_eod_summary(p_business_date);
  v_sales_total := coalesce((v_summary->>'salesTotal')::numeric, 0);
  v_payment_total := coalesce((v_summary->>'paymentTotal')::numeric, 0);
  v_payment_difference := round(v_sales_total - v_payment_total, 2);
  v_transaction_count := coalesce((v_summary->>'transactionCount')::integer, 0);
  v_payment_balanced := abs(v_payment_difference) < 0.01;

  begin
    v_consumption_integrity := public.get_store_inventory_consumption_integrity(p_business_date);
    v_inventory_balanced := coalesce((v_consumption_integrity->>'isBalanced')::boolean, false);
  exception when undefined_function then
    v_consumption_integrity := jsonb_build_object('status', 'NOT_AVAILABLE', 'isBalanced', false);
    v_inventory_balanced := false;
  end;

  select to_jsonb(c) into v_closing
  from public.store_eod_closings c
  where c.store_id = v_store_id and c.business_date = p_business_date;
  v_closing := coalesce(v_closing, '{}'::jsonb);
  v_is_completed := coalesce(v_closing->>'status', '') = 'completed';

  if v_is_completed then
    v_status := 'COMPLETED';
  elsif v_payment_balanced and v_inventory_balanced then
    v_status := 'READY';
  end if;

  return jsonb_build_object(
    'businessDate', p_business_date,
    'transactionCount', v_transaction_count,
    'salesTotal', v_sales_total,
    'paymentTotal', v_payment_total,
    'paymentDifference', v_payment_difference,
    'paymentBalanced', v_payment_balanced,
    'inventoryIntegrity', v_consumption_integrity,
    'inventoryBalanced', v_inventory_balanced,
    'closing', v_closing,
    'isCompleted', v_is_completed,
    'status', v_status
  );
end;
$$;

-- Completion is idempotent: once a business date is closed, retrying the RPC
-- returns the existing close record rather than reprocessing inventory consumption.
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
  v_existing public.store_eod_closings%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  v_store_id := public.current_management_store_id();
  v_role := lower(coalesce(auth.jwt()->'app_metadata'->>'role','staff'));
  if v_store_id is null then raise exception 'Your account is not assigned to a store.'; end if;
  if v_role not in ('owner','manager','admin') then raise exception 'Manager or owner access is required.'; end if;
  if p_business_date is null then raise exception 'Business date is required.'; end if;

  select * into v_existing
  from public.store_eod_closings c
  where c.store_id = v_store_id and c.business_date = p_business_date;

  if found and v_existing.status = 'completed' then
    return jsonb_build_object(
      'id', v_existing.id,
      'businessDate', v_existing.business_date,
      'salesTotal', v_existing.sales_total,
      'transactionCount', v_existing.transaction_count,
      'paymentTotal', v_existing.payment_total,
      'inventoryProcessed', v_existing.inventory_processed,
      'completedAt', v_existing.completed_at,
      'completedBy', v_existing.completed_by,
      'alreadyCompleted', true
    );
  end if;

  select public.get_store_eod_summary(p_business_date) into v_summary;
  v_sales_total := coalesce((v_summary->>'salesTotal')::numeric,0);
  v_transaction_count := coalesce((v_summary->>'transactionCount')::integer,0);
  v_payment_total := coalesce((v_summary->>'paymentTotal')::numeric,0);

  -- Payment reconciliation is intentionally a warning, not a hard block.
  -- The store can close after reviewing a difference, while the snapshot preserves
  -- the exact sales/payment totals used at close time.
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
    'alreadyCompleted', false,
    'consumption', v_consumption
  );
end;
$$;

revoke all on function public.get_store_eod_integrity(date) from public;
grant execute on function public.get_store_eod_integrity(date) to authenticated;
revoke all on function public.complete_store_eod(date) from public;
grant execute on function public.complete_store_eod(date) to authenticated;

notify pgrst, 'reload schema';
