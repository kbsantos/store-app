-- Bigger Brew Store Management: publish Auto Apply to kiosk master reads
-- The Store Management catalog already persists auto_apply. This migration
-- completes the shared master contract consumed by kiosk get_store_catalog().

alter table public.catalog_product_options
  add column if not exists auto_apply boolean not null default false;

create or replace function public.get_store_catalog(p_store_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_version text;
  v_result jsonb;
begin
  select catalog_version into v_version
  from public.store_catalog_versions
  where store_id = p_store_id;

  if v_version is null then
    raise exception 'No master catalog exists for store %', p_store_id;
  end if;

  select jsonb_build_object(
    'schemaVersion', 1,
    'catalogVersion', v_version,
    'categories', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'categoryId', c.category_id,
          'name', c.name,
          'subtitle', c.subtitle,
          'active', c.active,
          'icon', c.icon
        ) order by c.sort_order, c.name
      ) from public.catalog_categories c
      where c.store_id = p_store_id
    ), '[]'::jsonb),
    'optionDefinitions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'optionId', o.option_id,
          'name', o.name,
          'productTypes', o.product_types,
          'price', o.price,
          'active', o.active,
          'kitchenPrepared', o.kitchen_prepared
        ) order by o.name
      ) from public.catalog_option_definitions o
      where o.store_id = p_store_id
    ), '[]'::jsonb),
    -- Charges & Fees are part of the shared kiosk master contract.
    -- Keep this field here because this migration is the final definition
    -- of get_store_catalog() for the 20260920 migration set.
    'automaticCharges', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'chargeId', ac.charge_id,
          'name', ac.name,
          'amount', ac.amount,
          'active', ac.active,
          'scope', ac.scope,
          'categoryIds', ac.category_ids,
          'productIds', ac.product_ids,
          'productTypes', ac.product_types
        ) order by ac.sort_order, ac.name
      )
      from public.catalog_automatic_charges ac
      where ac.store_id = p_store_id
    ), '[]'::jsonb),
    'products', coalesce((
      select jsonb_agg(
        jsonb_build_object(
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
            select jsonb_agg(
              jsonb_build_object(
                'sizeId', s.size_id,
                'name', s.name,
                'volumeMl', s.volume_ml,
                'displayVolume', s.display_volume,
                'price', s.price
              ) order by s.sort_order, s.name
            ) from public.catalog_product_sizes s
            where s.store_id = p.store_id and s.product_id = p.product_id
          ), '[]'::jsonb),
          'variants', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'variantId', v.variant_id,
                'name', v.name,
                'price', v.price,
                'active', v.active
              ) order by v.sort_order, v.name
            ) from public.catalog_product_variants v
            where v.store_id = p.store_id and v.product_id = p.product_id
          ), '[]'::jsonb),
          'options', coalesce((
            select jsonb_agg(
              jsonb_build_object(
                'optionId', x.option_id,
                'name', x.name,
                'price', x.price,
                'active', x.active,
                'kitchenPrepared', x.kitchen_prepared,
                'autoApply', x.auto_apply
              ) order by x.sort_order, x.name
            ) from public.catalog_product_options x
            where x.store_id = p.store_id and x.product_id = p.product_id
          ), '[]'::jsonb)
        ) order by p.sort_order, p.name
      ) from public.catalog_products p
      where p.store_id = p_store_id
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;


revoke all on function public.get_store_catalog(uuid) from public;
grant execute on function public.get_store_catalog(uuid) to anon, authenticated;

notify pgrst, 'reload schema';
