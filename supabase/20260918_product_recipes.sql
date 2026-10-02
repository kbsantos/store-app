-- Store Management: product recipe composition.
-- This is the management-side recipe bridge between catalog products and inventory items.
create table if not exists public.store_product_recipe_items (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null,
  product_id text not null,
  inventory_item_id uuid not null,
  quantity numeric(14,4) not null check (quantity > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(store_id, product_id, inventory_item_id)
);

create index if not exists idx_store_product_recipe_items_store_product
  on public.store_product_recipe_items(store_id, product_id);

create or replace function public.get_store_product_recipes()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
begin
  v_store_id := public.current_management_store_id();
  if v_store_id is null then raise exception 'Authentication required and store access is missing.'; end if;

  return coalesce((
    select jsonb_agg(x order by x.product_name)
    from (
      select
        p.product_id,
        p.name as product_name,
        count(r.id)::int as ingredient_count,
        coalesce(jsonb_agg(jsonb_build_object(
          'inventory_item_id', r.inventory_item_id,
          'inventory_item_name', i.name,
          'unit', i.unit,
          'quantity', r.quantity
        ) order by r.created_at) filter (where r.id is not null), '[]'::jsonb) as items
      from public.catalog_products p
      left join public.store_product_recipe_items r
        on r.store_id = p.store_id and r.product_id = p.product_id
      left join public.inventory_items i
        on i.id = r.inventory_item_id and i.store_id = v_store_id
      where p.store_id = v_store_id
      group by p.product_id, p.name
    ) x
  ), '[]'::jsonb);
end;
$$;

create or replace function public.save_store_product_recipe(
  p_product_id text,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_role text;
  v_item jsonb;
  v_inventory_id uuid;
  v_qty numeric;
begin
  v_store_id := public.current_management_store_id();
  v_role := lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', 'staff'));
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  if v_store_id is null then raise exception 'Your account is not assigned to a store.'; end if;
  if v_role not in ('owner','manager','admin') then raise exception 'Manager or owner access is required.'; end if;

  if not exists (
    select 1 from public.catalog_products
    where store_id = v_store_id and product_id = trim(p_product_id) and active = true
  ) then
    raise exception 'Active catalog product not found: %', p_product_id;
  end if;

  if jsonb_typeof(p_items) <> 'array' then raise exception 'Recipe ingredients must be an array.'; end if;

  delete from public.store_product_recipe_items
  where store_id = v_store_id and product_id = trim(p_product_id);

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_inventory_id := (v_item ->> 'inventory_item_id')::uuid;
    v_qty := (v_item ->> 'quantity')::numeric;
    if v_qty is null or v_qty <= 0 then raise exception 'Recipe quantity must be greater than zero.'; end if;
    if not exists (
      select 1 from public.inventory_items
      where id = v_inventory_id and store_id = v_store_id and is_active = true
    ) then
      raise exception 'Active inventory item not found: %', v_inventory_id;
    end if;
    insert into public.store_product_recipe_items(store_id, product_id, inventory_item_id, quantity)
    values(v_store_id, trim(p_product_id), v_inventory_id, v_qty);
  end loop;

  return jsonb_build_object('storeId', v_store_id, 'productId', trim(p_product_id), 'ingredientCount', jsonb_array_length(p_items));
end;
$$;

revoke all on public.store_product_recipe_items from public;
grant select on public.store_product_recipe_items to authenticated;
revoke all on function public.get_store_product_recipes() from public;
grant execute on function public.get_store_product_recipes() to authenticated;
revoke all on function public.save_store_product_recipe(text,jsonb) from public;
grant execute on function public.save_store_product_recipe(text,jsonb) to authenticated;
notify pgrst, 'reload schema';
