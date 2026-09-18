-- MyCoffeeShop Store Management App
-- Inventory consumption from completed/paid transaction items using store product recipes.
-- Idempotent at transaction-item + inventory-item level.

create table if not exists public.inventory_consumption_records (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null,
  transaction_id uuid not null,
  transaction_item_id uuid not null,
  inventory_item_id uuid not null,
  business_date date not null,
  quantity numeric(14,4) not null check (quantity > 0),
  created_at timestamptz not null default now(),
  unique(store_id, transaction_item_id, inventory_item_id)
);

create index if not exists idx_inventory_consumption_records_store
  on public.inventory_consumption_records(store_id, created_at desc);
create index if not exists idx_inventory_consumption_records_transaction
  on public.inventory_consumption_records(store_id, transaction_id);

create or replace function public.process_store_inventory_consumption(
  p_business_date date
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_role text;
  v_status_col text;
  v_date_col text;
  v_product_col text;
  v_qty_col text;
  v_tx_store_col text;
  v_date_is_date boolean := false;
  v_note_col text;
  v_sql text;
  v_status_condition text;
  v_tx record;
  v_item record;
  v_recipe record;
  v_status text;
  v_consumed numeric;
  v_processed_items int := 0;
  v_usage_movements int := 0;
  v_skipped_no_recipe int := 0;
  v_already_processed int := 0;
  v_total_quantity numeric := 0;
  v_movement_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  v_store_id := public.current_management_store_id();
  v_role := lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', 'staff'));
  if v_store_id is null then
    raise exception 'Your account is not assigned to a store.';
  end if;
  if v_role not in ('owner','manager','admin') then
    raise exception 'Manager or owner access is required.';
  end if;
  if p_business_date is null then
    raise exception 'Business date is required.';
  end if;

  -- Resolve the actual transaction schema without assuming one historical naming convention.
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

  select data_type = 'date' into v_date_is_date
  from information_schema.columns
  where table_schema='public' and table_name='transactions'
    and column_name = v_date_col;

  select column_name into v_tx_store_col
  from information_schema.columns
  where table_schema='public' and table_name='transactions'
    and column_name='store_id'
  limit 1;

  select column_name into v_product_col
  from information_schema.columns
  where table_schema='public' and table_name='transaction_items'
    and column_name in ('product_id','catalog_product_id')
  order by case column_name when 'product_id' then 1 else 2 end
  limit 1;

  select column_name into v_qty_col
  from information_schema.columns
  where table_schema='public' and table_name='transaction_items'
    and column_name in ('quantity','qty')
  order by case column_name when 'quantity' then 1 else 2 end
  limit 1;

  if v_date_col is null or v_tx_store_col is null then
    raise exception 'transactions table does not expose the required date and store_id fields.';
  end if;

  -- Only apply a status filter when the deployed transactions table actually
  -- has a status column. A NULL status must not automatically be treated as a
  -- completed sale; doing so could consume draft/pending transactions.
  if v_status_col is null then
    raise exception 'transactions table does not expose a status field; inventory consumption is disabled until completed-sale status can be verified.';
  else
    v_status_condition := format(
      '(lower(coalesce(t.%I::text, '''')) in (''completed'',''complete'',''paid'',''closed''))',
      v_status_col
    );
  end if;
  if v_product_col is null or v_qty_col is null then
    raise exception 'transaction_items table does not expose product_id and quantity fields.';
  end if;

  -- Build a normalized transaction-item stream.
  if v_date_is_date then
    v_sql := format($q$
      select t.id as transaction_id, ti.id as transaction_item_id,
             ti.%I::text as product_id, ti.%I::numeric as item_quantity
      from public.transactions t
      join public.transaction_items ti on ti.transaction_id=t.id
      where t.%I=$1
        and %s
        and t.%I::date=$2
      order by t.id, ti.id
    $q$, v_product_col, v_qty_col, v_tx_store_col, v_status_condition, v_date_col);
  else
    v_sql := format($q$
      select t.id as transaction_id, ti.id as transaction_item_id,
             ti.%I::text as product_id, ti.%I::numeric as item_quantity
      from public.transactions t
      join public.transaction_items ti on ti.transaction_id=t.id
      where t.%I=$1
        and %s
        and (t.%I::timestamptz at time zone 'Asia/Manila')::date=$2
      order by t.id, ti.id
    $q$, v_product_col, v_qty_col, v_tx_store_col, v_status_condition, v_date_col);
  end if;

  for v_tx in execute v_sql using v_store_id, p_business_date loop
    if v_tx.item_quantity is null or v_tx.item_quantity <= 0 then
      continue;
    end if;

    if not exists (
      select 1 from public.store_product_recipe_items r
      where r.store_id=v_store_id and r.product_id=trim(v_tx.product_id)
    ) then
      v_skipped_no_recipe := v_skipped_no_recipe + 1;
      continue;
    end if;

    for v_recipe in
      select r.inventory_item_id, r.quantity
      from public.store_product_recipe_items r
      join public.inventory_items i on i.id=r.inventory_item_id and i.store_id=v_store_id
      where r.store_id=v_store_id
        and r.product_id=trim(v_tx.product_id)
        and i.is_active=true
    loop
      v_consumed := v_recipe.quantity * v_tx.item_quantity;
      v_movement_id := md5(v_tx.transaction_item_id::text || ':' || v_recipe.inventory_item_id::text)::uuid;

      -- The unique key is the idempotency boundary. ON CONFLICT makes two
      -- concurrent EOD/consumption runs safe: only the session that inserts
      -- the record proceeds to create the usage movement.
      insert into public.inventory_consumption_records(
        store_id, transaction_id, transaction_item_id, inventory_item_id, business_date, quantity
      ) values (
        v_store_id, v_tx.transaction_id, v_tx.transaction_item_id,
        v_recipe.inventory_item_id, p_business_date, v_consumed
      )
      on conflict (store_id, transaction_item_id, inventory_item_id) do nothing
      returning id into v_movement_id;

      if v_movement_id is null then
        v_already_processed := v_already_processed + 1;
        continue;
      end if;

      -- Use the deterministic movement key for the inventory audit record.
      v_movement_id := md5(v_tx.transaction_item_id::text || ':' || v_recipe.inventory_item_id::text)::uuid;

      -- inventory_movements has historically used external_movement_id in the live schema.
      -- Build the insert dynamically so the note and external-id column match the deployed schema.
      select column_name into v_note_col
      from information_schema.columns
      where table_schema='public' and table_name='inventory_movements'
        and column_name in ('note','notes')
      order by case column_name when 'note' then 1 else 2 end
      limit 1;

      if exists (select 1 from information_schema.columns where table_schema='public' and table_name='inventory_movements' and column_name='external_movement_id') then
        if v_note_col is not null then
          v_sql := format('insert into public.inventory_movements (store_id, inventory_item_id, movement_type, quantity, external_movement_id, %I) values ($1,$2,$3,$4,$5,$6)', v_note_col);
          execute v_sql using v_store_id, v_recipe.inventory_item_id, 'usage', v_consumed, v_movement_id, format('Sales consumption: transaction %s, item %s', v_tx.transaction_id, v_tx.transaction_item_id);
        else
          v_sql := 'insert into public.inventory_movements (store_id, inventory_item_id, movement_type, quantity, external_movement_id) values ($1,$2,$3,$4,$5)';
          execute v_sql using v_store_id, v_recipe.inventory_item_id, 'usage', v_consumed, v_movement_id;
        end if;
      elsif exists (select 1 from information_schema.columns where table_schema='public' and table_name='inventory_movements' and column_name='external_inventory_movement_id') then
        if v_note_col is not null then
          v_sql := format('insert into public.inventory_movements (store_id, inventory_item_id, movement_type, quantity, external_inventory_movement_id, %I) values ($1,$2,$3,$4,$5,$6)', v_note_col);
          execute v_sql using v_store_id, v_recipe.inventory_item_id, 'usage', v_consumed, v_movement_id, format('Sales consumption: transaction %s, item %s', v_tx.transaction_id, v_tx.transaction_item_id);
        else
          v_sql := 'insert into public.inventory_movements (store_id, inventory_item_id, movement_type, quantity, external_inventory_movement_id) values ($1,$2,$3,$4,$5)';
          execute v_sql using v_store_id, v_recipe.inventory_item_id, 'usage', v_consumed, v_movement_id;
        end if;
      else
        if v_note_col is not null then
          v_sql := format('insert into public.inventory_movements (store_id, inventory_item_id, movement_type, quantity, %I) values ($1,$2,$3,$4,$5)', v_note_col);
          execute v_sql using v_store_id, v_recipe.inventory_item_id, 'usage', v_consumed, format('Sales consumption: transaction %s, item %s', v_tx.transaction_id, v_tx.transaction_item_id);
        else
          insert into public.inventory_movements(store_id, inventory_item_id, movement_type, quantity)
          values(v_store_id, v_recipe.inventory_item_id, 'usage', v_consumed);
        end if;
      end if;

      v_processed_items := v_processed_items + 1;
      v_usage_movements := v_usage_movements + 1;
      v_total_quantity := v_total_quantity + v_consumed;
    end loop;
  end loop;

  return jsonb_build_object(
    'storeId', v_store_id,
    'businessDate', p_business_date,
    'processedRecipeLines', v_processed_items,
    'usageMovements', v_usage_movements,
    'skippedItemsWithoutRecipe', v_skipped_no_recipe,
    'alreadyProcessedRecipeLines', v_already_processed,
    'totalConsumedQuantity', v_total_quantity
  );
end;
$$;

create or replace function public.get_store_inventory_consumption_summary(
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
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required.'; end if;
  v_store_id := public.current_management_store_id();
  if v_store_id is null then raise exception 'Your account is not assigned to a store.'; end if;

  select coalesce(jsonb_agg(x order by x.item_name), '[]'::jsonb)
  into v_result
  from (
    select
      i.id as inventory_item_id,
      i.name as item_name,
      i.unit,
      sum(c.quantity) as consumed_quantity,
      count(*)::int as usage_lines
    from public.inventory_consumption_records c
    join public.inventory_items i on i.id=c.inventory_item_id and i.store_id=v_store_id
    where c.store_id=v_store_id and c.business_date=p_business_date
    group by i.id, i.name, i.unit
  ) x;

  return v_result;
end;
$$;

revoke all on public.inventory_consumption_records from public;
grant select on public.inventory_consumption_records to authenticated;
revoke all on function public.process_store_inventory_consumption(date) from public;
grant execute on function public.process_store_inventory_consumption(date) to authenticated;
revoke all on function public.get_store_inventory_consumption_summary(date) from public;
grant execute on function public.get_store_inventory_consumption_summary(date) to authenticated;

notify pgrst, 'reload schema';
