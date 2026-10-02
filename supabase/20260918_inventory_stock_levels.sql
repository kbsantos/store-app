-- MyCoffeeShop Store Management App
-- Inventory stock-level reporting.
-- Current stock is derived from inventory movements:
-- stock_in + adjustment - usage - waste.
-- stock_count is intentionally not included here because it is an absolute
-- count event and will be handled by the stock-count workflow.

create or replace function public.get_store_inventory_stock_levels()
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
        'reorder_level', coalesce(i.reorder_level, 0),
        'is_active', i.is_active,
        'current_quantity', coalesce(m.current_quantity, 0),
        'is_low_stock', coalesce(m.current_quantity, 0) <= coalesce(i.reorder_level, 0),
        'stock_status', case
          when coalesce(m.current_quantity, 0) <= coalesce(i.reorder_level, 0) then 'low_stock'
          else 'in_stock'
        end
      ) order by (coalesce(m.current_quantity, 0) <= coalesce(i.reorder_level, 0)) desc,
                 lower(i.name), i.id
    ),
    '[]'::jsonb
  )
  into v_result
  from public.inventory_items i
  left join (
    select
      inventory_item_id,
      sum(
        case lower(movement_type)
          when 'stock_in' then quantity
          when 'adjustment' then quantity
          when 'usage' then -quantity
          when 'waste' then -quantity
          else 0
        end
      ) as current_quantity
    from public.inventory_movements
    where store_id = v_store_id
    group by inventory_item_id
  ) m on m.inventory_item_id = i.id
  where i.store_id = v_store_id
    and i.is_active = true;

  return v_result;
end;
$$;

revoke all on function public.get_store_inventory_stock_levels() from public;
grant execute on function public.get_store_inventory_stock_levels() to authenticated;

notify pgrst, 'reload schema';
