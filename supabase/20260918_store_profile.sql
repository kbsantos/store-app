-- MyCoffeeShop Store Management App
-- Store Profile management for the authenticated management store.
-- Requires the existing public.stores table and
-- public.current_management_store_id() helper.

create or replace function public.get_store_management_profile()
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

  select jsonb_build_object(
    'id', s.id,
    'name', s.name,
    'brand', s.brand,
    'location', s.location,
    'is_active', s.is_active,
    'created_at', s.created_at
  )
  into v_result
  from public.stores s
  where s.id = v_store_id;

  if v_result is null then
    raise exception 'Store % was not found.', v_store_id;
  end if;

  return v_result;
end;
$$;

revoke all on function public.get_store_management_profile() from public;
grant execute on function public.get_store_management_profile() to authenticated;

create or replace function public.update_store_management_profile(
  p_name text,
  p_brand text,
  p_location text,
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
  if v_role not in ('owner', 'admin') then
    raise exception 'Owner or admin access is required.';
  end if;

  if nullif(trim(coalesce(p_name, '')), '') is null then
    raise exception 'Store name is required.';
  end if;

  update public.stores
  set name = trim(p_name),
      brand = nullif(trim(coalesce(p_brand, '')), ''),
      location = nullif(trim(coalesce(p_location, '')), ''),
      is_active = coalesce(p_is_active, true)
  where id = v_store_id;

  if not found then
    raise exception 'Store % was not found.', v_store_id;
  end if;

  select jsonb_build_object(
    'id', s.id,
    'name', s.name,
    'brand', s.brand,
    'location', s.location,
    'is_active', s.is_active,
    'created_at', s.created_at
  )
  into v_result
  from public.stores s
  where s.id = v_store_id;

  return v_result;
end;
$$;

revoke all on function public.update_store_management_profile(text, text, text, boolean) from public;
grant execute on function public.update_store_management_profile(text, text, text, boolean) to authenticated;

notify pgrst, 'reload schema';
