-- MyCoffeeShop Store Management App
-- Inventory movement audit trail.
-- Returns normalized movement rows for the current management store.

create or replace function public.get_store_inventory_movements()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_note_expr text;
  v_created_expr text;
  v_sql text;
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  v_store_id := public.current_management_store_id();
  if v_store_id is null then
    raise exception 'Your account is not assigned to a store.';
  end if;

  if not exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'inventory_movements'
  ) then
    raise exception 'inventory_movements table is not configured.';
  end if;

  v_note_expr := 'null::text';
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'inventory_movements'
      and column_name = 'note'
  ) then
    v_note_expr := 'm.note::text';
  elsif exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'inventory_movements'
      and column_name = 'notes'
  ) then
    v_note_expr := 'm.notes::text';
  end if;

  v_created_expr := 'null::text';
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'inventory_movements'
      and column_name = 'created_at'
  ) then
    v_created_expr := 'm.created_at::text';
  elsif exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'inventory_movements'
      and column_name = 'updated_at'
  ) then
    v_created_expr := 'm.updated_at::text';
  end if;

  v_sql := format($query$
    select coalesce(jsonb_agg(row_data order by sort_at desc nulls last, movement_id desc), '[]'::jsonb)
    from (
      select
        jsonb_build_object(
          'id', m.id,
          'inventory_item_id', m.inventory_item_id,
          'item_name', i.name,
          'category', i.category,
          'unit', i.unit,
          'movement_type', lower(m.movement_type::text),
          'quantity', m.quantity,
          'note', %s,
          'recorded_at', %s
        ) as row_data,
        %s as sort_at,
        m.id::text as movement_id
      from public.inventory_movements m
      left join public.inventory_items i on i.id = m.inventory_item_id
      where m.store_id = $1
      order by sort_at desc nulls last, m.id desc
      limit 500
    ) q
  $query$, v_note_expr, v_created_expr, v_created_expr);

  execute v_sql into v_result using v_store_id;
  return coalesce(v_result, '[]'::jsonb);
end;
$$;

revoke all on function public.get_store_inventory_movements() from public;
grant execute on function public.get_store_inventory_movements() to authenticated;

notify pgrst, 'reload schema';
