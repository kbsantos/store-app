-- MyCoffeeShop Store Management App
-- Inventory wastage workflow. A positive quantity is recorded as a `waste`
-- movement; the existing stock-level calculation subtracts waste movements.

create or replace function public.waste_store_inventory_item(
  p_inventory_item_id uuid,
  p_quantity numeric,
  p_reason text,
  p_note text default null
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
  v_movement_id uuid;
  v_external_id text;
  v_reason text;
  v_note text;
  v_columns text := '';
  v_values text := '';
  v_sql text;
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
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Wastage quantity must be greater than zero.';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'Wastage reason is required.';
  end if;
  if lower(v_reason) not in ('damaged', 'expired', 'spillage', 'spoilage', 'other') then
    raise exception 'Invalid wastage reason.';
  end if;

  v_note := nullif(trim(coalesce(p_note, '')), '');

  select name, unit
    into v_item_name, v_unit
  from public.inventory_items
  where id = p_inventory_item_id
    and store_id = v_store_id
    and is_active = true;

  if not found then
    raise exception 'Active inventory item was not found for this store.';
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
    'waste', p_quantity, v_external_id,
    concat(v_reason, case when v_note is null then '' else ': ' || v_note end);

  return jsonb_build_object(
    'id', v_movement_id,
    'inventory_item_id', p_inventory_item_id,
    'item_name', v_item_name,
    'unit', v_unit,
    'movement_type', 'waste',
    'quantity', p_quantity,
    'reason', v_reason,
    'note', v_note,
    'recorded_at', now()
  );
end;
$$;

revoke all on function public.waste_store_inventory_item(uuid, numeric, text, text) from public;
grant execute on function public.waste_store_inventory_item(uuid, numeric, text, text) to authenticated;

notify pgrst, 'reload schema';
