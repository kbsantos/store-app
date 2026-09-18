-- MyCoffeeShop Store Management App
-- Inventory physical stock-count / adjustment workflow.
-- The physical count is converted into a signed adjustment movement so the
-- existing stock-level calculation remains compatible with stock_in, usage,
-- and waste movements.

create or replace function public.adjust_store_inventory_stock(
  p_inventory_item_id uuid,
  p_counted_quantity numeric,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_role text;
  v_item_name text;
  v_unit text;
  v_current numeric := 0;
  v_adjustment numeric;
  v_movement_id uuid;
  v_external_id text;
  v_reason text;
  v_columns text := '';
  v_values text := '';
  v_sql text;
  v_movement_type text := 'adjustment';
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  v_store_id := public.current_management_store_id();
  if v_store_id is null then
    raise exception 'Your account is not assigned to a store.';
  end if;

  v_role := lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', 'staff'));
  if v_role not in ('owner', 'manager', 'admin') then
    raise exception 'Owner, manager or admin access is required.';
  end if;

  if p_inventory_item_id is null then
    raise exception 'Inventory item is required.';
  end if;
  if p_counted_quantity is null or p_counted_quantity < 0 then
    raise exception 'Physical count must be zero or greater.';
  end if;

  select name, unit
    into v_item_name, v_unit
  from public.inventory_items
  where id = p_inventory_item_id
    and store_id = v_store_id
    and is_active = true;

  if not found then
    raise exception 'Active inventory item was not found for this store.';
  end if;

  select coalesce(sum(
    case lower(movement_type)
      when 'stock_in' then quantity
      when 'adjustment' then quantity
      when 'usage' then -quantity
      when 'waste' then -quantity
      else 0
    end
  ), 0)
  into v_current
  from public.inventory_movements
  where store_id = v_store_id
    and inventory_item_id = p_inventory_item_id;

  v_adjustment := p_counted_quantity - v_current;
  v_reason := nullif(trim(coalesce(p_reason, '')), '');

  if v_adjustment = 0 then
    return jsonb_build_object(
      'id', null,
      'inventory_item_id', p_inventory_item_id,
      'item_name', v_item_name,
      'unit', v_unit,
      'current_quantity', v_current,
      'counted_quantity', p_counted_quantity,
      'adjustment_quantity', 0,
      'movement_type', v_movement_type,
      'reason', v_reason,
      'changed', false,
      'adjusted_at', now()
    );
  end if;

  v_movement_id := gen_random_uuid();
  v_external_id := v_movement_id::text;

  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='inventory_movements' and column_name='id') then
    v_columns := 'id'; v_values := '$1';
  end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='inventory_movements' and column_name='store_id') then
    v_columns := v_columns || case when v_columns='' then '' else ', ' end || 'store_id';
    v_values := v_values || case when v_values='' then '' else ', ' end || '$2';
  end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='inventory_movements' and column_name='inventory_item_id') then
    v_columns := v_columns || case when v_columns='' then '' else ', ' end || 'inventory_item_id';
    v_values := v_values || case when v_values='' then '' else ', ' end || '$3';
  end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='inventory_movements' and column_name='movement_type') then
    v_columns := v_columns || case when v_columns='' then '' else ', ' end || 'movement_type';
    v_values := v_values || case when v_values='' then '' else ', ' end || '$4';
  end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='inventory_movements' and column_name='quantity') then
    v_columns := v_columns || case when v_columns='' then '' else ', ' end || 'quantity';
    v_values := v_values || case when v_values='' then '' else ', ' end || '$5';
  end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='inventory_movements' and column_name='external_movement_id') then
    v_columns := v_columns || case when v_columns='' then '' else ', ' end || 'external_movement_id';
    v_values := v_values || case when v_values='' then '' else ', ' end || '$6';
  elsif exists (select 1 from information_schema.columns where table_schema='public' and table_name='inventory_movements' and column_name='external_inventory_movement_id') then
    v_columns := v_columns || case when v_columns='' then '' else ', ' end || 'external_inventory_movement_id';
    v_values := v_values || case when v_values='' then '' else ', ' end || '$6';
  end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='inventory_movements' and column_name='note') then
    v_columns := v_columns || case when v_columns='' then '' else ', ' end || 'note';
    v_values := v_values || case when v_values='' then '' else ', ' end || '$7';
  elsif exists (select 1 from information_schema.columns where table_schema='public' and table_name='inventory_movements' and column_name='notes') then
    v_columns := v_columns || case when v_columns='' then '' else ', ' end || 'notes';
    v_values := v_values || case when v_values='' then '' else ', ' end || '$7';
  end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='inventory_movements' and column_name='created_at') then
    v_columns := v_columns || case when v_columns='' then '' else ', ' end || 'created_at';
    v_values := v_values || case when v_values='' then '' else ', ' end || 'now()';
  end if;
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='inventory_movements' and column_name='updated_at') then
    v_columns := v_columns || case when v_columns='' then '' else ', ' end || 'updated_at';
    v_values := v_values || case when v_values='' then '' else ', ' end || 'now()';
  end if;

  if v_columns = '' then
    raise exception 'inventory_movements table is not configured.';
  end if;

  v_sql := format('insert into public.inventory_movements (%s) values (%s)', v_columns, v_values);
  execute v_sql using v_movement_id, v_store_id, p_inventory_item_id,
    v_movement_type, v_adjustment, v_external_id,
    concat('Physical count: ', p_counted_quantity, '. Adjustment: ', v_adjustment,
           case when v_reason is null then '' else '. ' || v_reason end);

  return jsonb_build_object(
    'id', v_movement_id,
    'inventory_item_id', p_inventory_item_id,
    'item_name', v_item_name,
    'unit', v_unit,
    'current_quantity', v_current,
    'counted_quantity', p_counted_quantity,
    'adjustment_quantity', v_adjustment,
    'movement_type', v_movement_type,
    'reason', v_reason,
    'changed', true,
    'adjusted_at', now()
  );
end;
$$;

revoke all on function public.adjust_store_inventory_stock(uuid, numeric, text) from public;
grant execute on function public.adjust_store_inventory_stock(uuid, numeric, text) to authenticated;

notify pgrst, 'reload schema';
