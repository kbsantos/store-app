-- Bigger Brew Store Management App
-- Secure catalog read/write RPCs for authenticated store-management users.
-- Requires the Store Master Catalog Phase 1 and Phase 2 migrations to already exist.

create or replace function public.current_management_store_id()
returns uuid
language sql
stable
security invoker
set search_path = public
as $$
  select nullif(auth.jwt() -> 'app_metadata' ->> 'store_id', '')::uuid;
$$;

revoke all on function public.current_management_store_id() from public;
grant execute on function public.current_management_store_id() to authenticated;

create or replace function public.require_management_store_id()
returns uuid
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_store_id uuid;
  v_role text;
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
    raise exception 'Manager or owner access is required.';
  end if;

  return v_store_id;
end;
$$;

revoke all on function public.require_management_store_id() from public;
grant execute on function public.require_management_store_id() to authenticated;

create or replace function public.get_store_management_catalog_version()
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_version text;
begin
  v_store_id := public.current_management_store_id();
  if v_store_id is null then
    raise exception 'Authentication required and app_metadata.store_id is missing.';
  end if;

  select catalog_version into v_version
  from public.store_catalog_versions
  where store_id = v_store_id;

  if v_version is null then
    raise exception 'No master catalog exists for store %.', v_store_id;
  end if;
  return v_version;
end;
$$;

revoke all on function public.get_store_management_catalog_version() from public;
grant execute on function public.get_store_management_catalog_version() to authenticated;

create or replace function public.get_store_management_catalog()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_version text;
  v_result jsonb;
begin
  v_store_id := public.current_management_store_id();
  if v_store_id is null then
    raise exception 'Authentication required and app_metadata.store_id is missing.';
  end if;

  select catalog_version into v_version
  from public.store_catalog_versions
  where store_id = v_store_id;

  if v_version is null then
    raise exception 'No master catalog exists for store %.', v_store_id;
  end if;

  select jsonb_build_object(
    'schemaVersion', 1,
    'catalogVersion', v_version,
    'categories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'categoryId', c.category_id,
        'name', c.name,
        'subtitle', c.subtitle,
        'active', c.active,
        'icon', c.icon
      ) order by c.sort_order, c.name)
      from public.catalog_categories c where c.store_id = v_store_id
    ), '[]'::jsonb),
    'optionDefinitions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'optionId', o.option_id,
        'name', o.name,
        'productTypes', o.product_types,
        'price', o.price,
        'active', o.active,
        'kitchenPrepared', o.kitchen_prepared
      ) order by o.name)
      from public.catalog_option_definitions o where o.store_id = v_store_id
    ), '[]'::jsonb),
    'products', coalesce((
      select jsonb_agg(jsonb_build_object(
        'productId', p.product_id,
        'name', p.name,
        'productType', p.product_type,
        'drinkTemperature', p.drink_temperature,
        'categoryId', p.category_id,
        'groupId', p.group_id,
        'groupName', p.group_name,
        'description', p.description,
        'image', p.image,
        'active', p.active,
        'available', p.available,
        'kitchenPrepared', p.kitchen_prepared,
        'price', p.price,
        'sku', p.sku,
        'recipeRef', p.recipe_ref,
        'sizes', coalesce((
          select jsonb_agg(jsonb_build_object(
            'sizeId', s.size_id,
            'name', s.name,
            'volumeMl', s.volume_ml,
            'displayVolume', s.display_volume,
            'price', s.price
          ) order by s.sort_order, s.name)
          from public.catalog_product_sizes s
          where s.store_id = v_store_id and s.product_id = p.product_id and s.active = true
        ), '[]'::jsonb),
        'variants', coalesce((
          select jsonb_agg(jsonb_build_object(
            'variantId', v.variant_id,
            'name', v.name,
            'price', v.price,
            'active', v.active
          ) order by v.sort_order, v.name)
          from public.catalog_product_variants v
          where v.store_id = v_store_id and v.product_id = p.product_id
        ), '[]'::jsonb),
        'options', coalesce((
          select jsonb_agg(jsonb_build_object(
            'optionId', po.option_id,
            'name', po.name,
            'price', po.price,
            'active', po.active,
            'kitchenPrepared', po.kitchen_prepared
          ) order by po.sort_order, po.name)
          from public.catalog_product_options po
          where po.store_id = v_store_id and po.product_id = p.product_id
        ), '[]'::jsonb)
      ) order by p.sort_order, p.name)
      from public.catalog_products p where p.store_id = v_store_id
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.get_store_management_catalog() from public;
grant execute on function public.get_store_management_catalog() to authenticated;

create or replace function public.publish_store_catalog_from_management(
  p_expected_version text,
  p_catalog jsonb
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_current_version text;
  v_new_version text;
  v_category jsonb;
  v_product jsonb;
  v_size jsonb;
  v_variant jsonb;
  v_option jsonb;
  v_option_definition jsonb;
  v_schema_version integer;
begin
  v_store_id := public.require_management_store_id();

  if jsonb_typeof(p_catalog) <> 'object' then
    raise exception 'Catalog payload must be a JSON object.';
  end if;

  v_schema_version := coalesce((p_catalog ->> 'schemaVersion')::integer, 1);
  if v_schema_version <> 1 then
    raise exception 'Unsupported catalog schema version: %', v_schema_version;
  end if;

  select catalog_version into v_current_version
  from public.store_catalog_versions
  where store_id = v_store_id
  for update;

  if v_current_version is null then
    raise exception 'No master catalog exists for store %. Initialize it first.', v_store_id;
  end if;

  if coalesce(trim(p_expected_version), '') <> v_current_version then
    raise exception 'Catalog changed on the server. Refresh the catalog before saving again. Current version: %', v_current_version;
  end if;

  v_new_version := 'mgmt-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSUS');

  delete from public.catalog_product_options where store_id = v_store_id;
  delete from public.catalog_product_sizes where store_id = v_store_id;
  delete from public.catalog_product_variants where store_id = v_store_id;
  delete from public.catalog_products where store_id = v_store_id;
  delete from public.catalog_option_definitions where store_id = v_store_id;
  delete from public.catalog_categories where store_id = v_store_id;

  for v_category in select value from jsonb_array_elements(coalesce(p_catalog -> 'categories', '[]'::jsonb)) loop
    insert into public.catalog_categories (store_id, category_id, name, subtitle, icon, active, sort_order)
    values (v_store_id, v_category ->> 'categoryId', coalesce(v_category ->> 'name', ''), coalesce(v_category ->> 'subtitle', ''), nullif(v_category ->> 'icon', ''), coalesce((v_category ->> 'active')::boolean, true), 0);
  end loop;

  for v_option_definition in select value from jsonb_array_elements(coalesce(p_catalog -> 'optionDefinitions', '[]'::jsonb)) loop
    insert into public.catalog_option_definitions (store_id, option_id, name, product_types, price, active, kitchen_prepared)
    values (v_store_id, v_option_definition ->> 'optionId', coalesce(v_option_definition ->> 'name', ''), coalesce(v_option_definition -> 'productTypes', '[]'::jsonb), nullif(v_option_definition ->> 'price', '')::numeric, coalesce((v_option_definition ->> 'active')::boolean, true), coalesce((v_option_definition ->> 'kitchenPrepared')::boolean, false));
  end loop;

  for v_product in select value from jsonb_array_elements(coalesce(p_catalog -> 'products', '[]'::jsonb)) loop
    insert into public.catalog_products (store_id, product_id, category_id, name, product_type, group_id, group_name, description, image, active, available, kitchen_prepared, drink_temperature, price, sku, recipe_ref, sort_order)
    values (v_store_id, v_product ->> 'productId', v_product ->> 'categoryId', coalesce(v_product ->> 'name', ''), coalesce(v_product ->> 'productType', ''), nullif(v_product ->> 'groupId', ''), nullif(v_product ->> 'groupName', ''), nullif(v_product ->> 'description', ''), nullif(v_product ->> 'image', ''), coalesce((v_product ->> 'active')::boolean, true), coalesce((v_product ->> 'available')::boolean, true), coalesce((v_product ->> 'kitchenPrepared')::boolean, false), nullif(v_product ->> 'drinkTemperature', ''), nullif(v_product ->> 'price', '')::numeric, nullif(v_product ->> 'sku', ''), nullif(v_product ->> 'recipeRef', ''), 0);

    for v_size in select value from jsonb_array_elements(coalesce(v_product -> 'sizes', '[]'::jsonb)) loop
      insert into public.catalog_product_sizes (store_id, product_id, size_id, name, volume_ml, display_volume, price, active, sort_order)
      values (v_store_id, v_product ->> 'productId', v_size ->> 'sizeId', coalesce(v_size ->> 'name', ''), nullif(v_size ->> 'volumeMl', '')::integer, nullif(v_size ->> 'displayVolume', ''), nullif(v_size ->> 'price', '')::numeric, true, 0);
    end loop;

    for v_variant in select value from jsonb_array_elements(coalesce(v_product -> 'variants', '[]'::jsonb)) loop
      insert into public.catalog_product_variants (store_id, product_id, variant_id, name, price, active, sort_order)
      values (v_store_id, v_product ->> 'productId', v_variant ->> 'variantId', coalesce(v_variant ->> 'name', ''), nullif(v_variant ->> 'price', '')::numeric, coalesce((v_variant ->> 'active')::boolean, true), 0);
    end loop;

    for v_option in select value from jsonb_array_elements(coalesce(v_product -> 'options', '[]'::jsonb)) loop
      insert into public.catalog_product_options (store_id, product_id, option_id, name, price, active, kitchen_prepared, sort_order)
      values (v_store_id, v_product ->> 'productId', v_option ->> 'optionId', coalesce(v_option ->> 'name', ''), nullif(v_option ->> 'price', '')::numeric, coalesce((v_option ->> 'active')::boolean, true), coalesce((v_option ->> 'kitchenPrepared')::boolean, false), 0);
    end loop;
  end loop;

  update public.store_catalog_versions
  set catalog_version = v_new_version,
      updated_at = now(),
      updated_by_device_id = null
  where store_id = v_store_id;

  return v_new_version;
end;
$$;

revoke all on function public.publish_store_catalog_from_management(text, jsonb) from public;
grant execute on function public.publish_store_catalog_from_management(text, jsonb) to authenticated;

notify pgrst, 'reload schema';
