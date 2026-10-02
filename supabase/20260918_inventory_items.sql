-- MyCoffeeShop Store Management App
-- Inventory item master management.
-- Uses the existing public.inventory_items table.
-- Expected columns: id, store_id, name, category, unit, reorder_level,
-- is_active, created_at, updated_at.

create or replace function public.get_store_inventory_items()
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

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', i.id,
        'name', i.name,
        'category', i.category,
        'unit', i.unit,
        'reorder_level', i.reorder_level,
        'is_active', i.is_active,
        'created_at', i.created_at,
        'updated_at', i.updated_at
      ) order by lower(i.name), i.id
    ),
    '[]'::jsonb
  )
  into v_result
  from public.inventory_items i
  where i.store_id = v_store_id;

  return v_result;
end;
$$;

revoke all on function public.get_store_inventory_items() from public;
grant execute on function public.get_store_inventory_items() to authenticated;

create or replace function public.create_store_inventory_item(
  p_name text,
  p_category text,
  p_unit text,
  p_reorder_level numeric,
  p_is_active boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_role text;
  v_id uuid;
  v_external_inventory_id text;
  v_result jsonb;
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

  if nullif(trim(coalesce(p_name, '')), '') is null then
    raise exception 'Inventory item name is required.';
  end if;
  if nullif(trim(coalesce(p_unit, '')), '') is null then
    raise exception 'Inventory unit is required.';
  end if;
  if coalesce(p_reorder_level, 0) < 0 then
    raise exception 'Reorder level cannot be negative.';
  end if;

  v_id := gen_random_uuid();
  v_external_inventory_id := v_id::text;

  insert into public.inventory_items (
    id, store_id, external_inventory_id, name, category, unit, reorder_level, is_active
  ) values (
    v_id,
    v_store_id,
    v_external_inventory_id,
    trim(p_name),
    nullif(trim(coalesce(p_category, '')), ''),
    trim(p_unit),
    coalesce(p_reorder_level, 0),
    coalesce(p_is_active, true)
  )
  returning id into v_id;

  select jsonb_build_object(
    'id', i.id,
    'external_inventory_id', i.external_inventory_id,
    'name', i.name,
    'category', i.category,
    'unit', i.unit,
    'reorder_level', i.reorder_level,
    'is_active', i.is_active,
    'created_at', i.created_at,
    'updated_at', i.updated_at
  )
  into v_result
  from public.inventory_items i
  where i.id = v_id and i.store_id = v_store_id;

  return v_result;
end;
$$;

revoke all on function public.create_store_inventory_item(text, text, text, numeric, boolean) from public;
grant execute on function public.create_store_inventory_item(text, text, text, numeric, boolean) to authenticated;

create or replace function public.update_store_inventory_item(
  p_id uuid,
  p_name text,
  p_category text,
  p_unit text,
  p_reorder_level numeric,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_role text;
  v_result jsonb;
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

  if p_id is null then
    raise exception 'Inventory item id is required.';
  end if;
  if nullif(trim(coalesce(p_name, '')), '') is null then
    raise exception 'Inventory item name is required.';
  end if;
  if nullif(trim(coalesce(p_unit, '')), '') is null then
    raise exception 'Inventory unit is required.';
  end if;
  if coalesce(p_reorder_level, 0) < 0 then
    raise exception 'Reorder level cannot be negative.';
  end if;

  update public.inventory_items
  set name = trim(p_name),
      category = nullif(trim(coalesce(p_category, '')), ''),
      unit = trim(p_unit),
      reorder_level = coalesce(p_reorder_level, 0),
      is_active = coalesce(p_is_active, true),
      updated_at = now()
  where id = p_id and store_id = v_store_id;

  if not found then
    raise exception 'Inventory item was not found for this store.';
  end if;

  select jsonb_build_object(
    'id', i.id,
    'external_inventory_id', i.external_inventory_id,
    'name', i.name,
    'category', i.category,
    'unit', i.unit,
    'reorder_level', i.reorder_level,
    'is_active', i.is_active,
    'created_at', i.created_at,
    'updated_at', i.updated_at
  )
  into v_result
  from public.inventory_items i
  where i.id = p_id and i.store_id = v_store_id;

  return v_result;
end;
$$;

revoke all on function public.update_store_inventory_item(uuid, text, text, text, numeric, boolean) from public;
grant execute on function public.update_store_inventory_item(uuid, text, text, text, numeric, boolean) to authenticated;

notify pgrst, 'reload schema';
