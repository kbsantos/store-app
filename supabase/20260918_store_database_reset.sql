-- MyCoffeeShop Store Management App
-- Store-scoped operational database reset RPC.
-- Master catalog/configuration data is intentionally preserved.

create or replace function public.reset_store_operational_data(p_confirmation text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_role text;
  v_deleted jsonb := '{}'::jsonb;
  v_count bigint;
  v_table text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  v_store_id := public.current_management_store_id();
  if v_store_id is null then
    raise exception 'Your account is not assigned to a store.';
  end if;

  v_role := lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', 'staff'));
  if v_role not in ('owner', 'admin') then
    raise exception 'Owner or admin access is required.';
  end if;

  if upper(trim(coalesce(p_confirmation, ''))) <> 'RESET' then
    raise exception 'Reset confirmation must be RESET.';
  end if;

  delete from public.transaction_item_options where transaction_item_id in (
    select id from public.transaction_items where transaction_id in (
      select id from public.transactions where store_id = v_store_id
    )
  );
  get diagnostics v_count = row_count;
  v_deleted := v_deleted || jsonb_build_object('transaction_item_options', v_count);

  delete from public.transaction_items where transaction_id in (
    select id from public.transactions where store_id = v_store_id
  );
  get diagnostics v_count = row_count;
  v_deleted := v_deleted || jsonb_build_object('transaction_items', v_count);

  delete from public.payments where transaction_id in (
    select id from public.transactions where store_id = v_store_id
  );
  get diagnostics v_count = row_count;
  v_deleted := v_deleted || jsonb_build_object('payments', v_count);

  delete from public.transactions where store_id = v_store_id;
  get diagnostics v_count = row_count;
  v_deleted := v_deleted || jsonb_build_object('transactions', v_count);

  delete from public.inventory_movements where store_id = v_store_id;
  get diagnostics v_count = row_count;
  v_deleted := v_deleted || jsonb_build_object('inventory_movements', v_count);

  -- Reporting/stock summary objects are allowed to be either physical tables or
  -- database views. Views are derived from operational data and must not be
  -- deleted; physical summary tables are cleared when present.
  for v_table in
    select unnest(array[
      'inventory_stock_summary',
      'daily_sales_summary',
      'device_sales_summary',
      'hourly_sales_summary',
      'payment_summary',
      'order_sales_summary',
      'product_sales_summary'
    ])
  loop
    if exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = v_table
        and c.relkind in ('r', 'p')
        and exists (
          select 1
          from information_schema.columns ic
          where ic.table_schema = 'public'
            and ic.table_name = v_table
            and ic.column_name = 'store_id'
        )
    ) then
      execute format('delete from public.%I where store_id = $1', v_table) using v_store_id;
      get diagnostics v_count = row_count;
      v_deleted := v_deleted || jsonb_build_object(v_table, v_count);
    else
      v_deleted := v_deleted || jsonb_build_object(v_table, 'derived_view_or_not_present');
    end if;
  end loop;

  -- Sync logs are also schema-tolerant. Some MyCoffeeShop deployments use a
  -- store-scoped table, while others expose sync_logs without a store_id column.
  -- Only delete it when it is a physical table with an explicit store_id scope.
  if exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'sync_logs'
      and c.relkind in ('r', 'p')
      and exists (
        select 1
        from information_schema.columns ic
        where ic.table_schema = 'public'
          and ic.table_name = 'sync_logs'
          and ic.column_name = 'store_id'
      )
  ) then
    delete from public.sync_logs where store_id = v_store_id;
    get diagnostics v_count = row_count;
    v_deleted := v_deleted || jsonb_build_object('sync_logs', v_count);
  else
    v_deleted := v_deleted || jsonb_build_object('sync_logs', 'not_store_scoped_or_not_present');
  end if;

  return jsonb_build_object(
    'storeId', v_store_id,
    'resetAt', now(),
    'resetBy', auth.uid(),
    'deleted', v_deleted
  );
end;
$$;

revoke all on function public.reset_store_operational_data(text) from public;
grant execute on function public.reset_store_operational_data(text) to authenticated;

notify pgrst, 'reload schema';
