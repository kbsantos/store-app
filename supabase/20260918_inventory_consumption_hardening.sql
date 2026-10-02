-- Store Management: inventory/sales consumption integrity hardening.
-- Provides a store-scoped audit check without changing recorded quantities.
-- The check verifies that each consumption record has its matching usage movement
-- and that inventory usage movements reconcile to consumption records.

create or replace function public.get_store_inventory_consumption_integrity(
  p_business_date date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_recorded_lines integer := 0;
  v_recorded_quantity numeric := 0;
  v_usage_lines integer := 0;
  v_usage_quantity numeric := 0;
  v_missing_usage_lines integer := 0;
  v_orphan_usage_lines integer := 0;
  v_difference numeric := 0;
  v_result jsonb;
  v_external_col text;
  v_sql text;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  v_store_id := public.current_management_store_id();
  if v_store_id is null then raise exception 'Your account is not assigned to a store.'; end if;
  if p_business_date is null then raise exception 'Business date is required.'; end if;

  select count(*)::int, coalesce(sum(quantity),0)
    into v_recorded_lines, v_recorded_quantity
  from public.inventory_consumption_records
  where store_id=v_store_id and business_date=p_business_date;

  if not exists (
    select 1 from information_schema.tables
    where table_schema='public' and table_name='inventory_movements'
  ) then
    return jsonb_build_object(
      'businessDate', p_business_date,
      'recordedConsumptionLines', v_recorded_lines,
      'recordedConsumptionQuantity', v_recorded_quantity,
      'usageMovementLines', 0,
      'usageMovementQuantity', 0,
      'missingUsageMovementLines', v_recorded_lines,
      'orphanUsageMovementLines', 0,
      'quantityDifference', 0,
      'isBalanced', false,
      'status', 'MISSING_MOVEMENT_TABLE'
    );
  end if;

  select column_name into v_external_col
  from information_schema.columns
  where table_schema='public' and table_name='inventory_movements'
    and column_name in ('external_movement_id','external_inventory_movement_id')
  order by case column_name when 'external_movement_id' then 1 else 2 end
  limit 1;

  if v_external_col is null then
    return jsonb_build_object(
      'businessDate', p_business_date,
      'recordedConsumptionLines', v_recorded_lines,
      'recordedConsumptionQuantity', v_recorded_quantity,
      'usageMovementLines', 0,
      'usageMovementQuantity', 0,
      'missingUsageMovementLines', v_recorded_lines,
      'orphanUsageMovementLines', 0,
      'quantityDifference', 0,
      'isBalanced', false,
      'status', 'MISSING_MOVEMENT_LINK'
    );
  end if;

  v_sql := format($q$
    with records as (
      select
        md5(transaction_item_id::text || ':' || inventory_item_id::text)::text as movement_key,
        inventory_item_id,
        quantity
      from public.inventory_consumption_records
      where store_id=$1 and business_date=$2
    ), usage as (
      select
        m.%I::text as movement_key,
        m.inventory_item_id,
        m.quantity
      from public.inventory_movements m
      where m.store_id=$1
        and lower(m.movement_type::text)='usage'
        and m.%I is not null
    )
    select
      (select count(*)::int from usage u where exists (
        select 1 from records r where r.movement_key=u.movement_key and r.inventory_item_id=u.inventory_item_id
      )),
      (select coalesce(sum(u.quantity),0) from usage u where exists (
        select 1 from records r where r.movement_key=u.movement_key and r.inventory_item_id=u.inventory_item_id
      )),
      (select count(*)::int from records r where not exists (
        select 1 from usage u where u.movement_key=r.movement_key and u.inventory_item_id=r.inventory_item_id
      )),
      (select count(*)::int from usage u where not exists (
        select 1 from records r where r.movement_key=u.movement_key and r.inventory_item_id=u.inventory_item_id
      )),
      (select coalesce(sum(r.quantity),0) from records r)
  $q$, v_external_col, v_external_col);

  execute v_sql using v_store_id, p_business_date
    into v_usage_lines, v_usage_quantity, v_missing_usage_lines, v_orphan_usage_lines, v_recorded_quantity;

  v_difference := round(v_recorded_quantity - v_usage_quantity, 4);

  select jsonb_build_object(
    'businessDate', p_business_date,
    'recordedConsumptionLines', v_recorded_lines,
    'recordedConsumptionQuantity', v_recorded_quantity,
    'usageMovementLines', v_usage_lines,
    'usageMovementQuantity', v_usage_quantity,
    'missingUsageMovementLines', v_missing_usage_lines,
    'orphanUsageMovementLines', v_orphan_usage_lines,
    'quantityDifference', v_difference,
    'isBalanced', (v_missing_usage_lines=0 and v_orphan_usage_lines=0 and abs(v_difference) < 0.0001),
    'status', case when v_missing_usage_lines=0 and v_orphan_usage_lines=0 and abs(v_difference) < 0.0001 then 'BALANCED' else 'ATTENTION' end
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.get_store_inventory_consumption_integrity(date) from public;
grant execute on function public.get_store_inventory_consumption_integrity(date) to authenticated;
notify pgrst, 'reload schema';
