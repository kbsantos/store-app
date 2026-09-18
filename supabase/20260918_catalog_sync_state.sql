-- Bigger Brew / MyCoffeeShop
-- Catalog synchronization state for multi-kiosk stores.
--
-- The store master remains authoritative. Each kiosk reports the master
-- version it has successfully cached so Store Management can see whether
-- registered kiosks are current.

create table if not exists public.device_catalog_sync_state (
  store_id uuid not null references public.stores(id) on delete cascade,
  device_id uuid not null references public.devices(id) on delete cascade,
  catalog_version text not null,
  synced_at timestamptz not null default now(),
  primary key (store_id, device_id)
);

create index if not exists device_catalog_sync_state_store_idx
  on public.device_catalog_sync_state(store_id, synced_at desc);

alter table public.device_catalog_sync_state enable row level security;

revoke all on table public.device_catalog_sync_state from anon, authenticated;

-- Kiosk reports a version only after it has validated and cached the complete
-- master catalog. The device code must resolve to an active kiosk belonging
-- to the supplied store.
create or replace function public.report_kiosk_catalog_sync(
  p_store_id uuid,
  p_device_code text,
  p_catalog_version text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_device_id uuid;
  v_master_version text;
begin
  if nullif(trim(p_catalog_version), '') is null then
    raise exception 'Catalog version is required.';
  end if;

  select d.id into v_device_id
  from public.devices d
  where d.store_id = p_store_id
    and d.device_code = trim(p_device_code)
    and d.is_active = true
  limit 1;

  if v_device_id is null then
    raise exception 'No active kiosk found for store % and device %',
      p_store_id, p_device_code;
  end if;

  select catalog_version into v_master_version
  from public.store_catalog_versions
  where store_id = p_store_id;

  if v_master_version is null then
    raise exception 'No master catalog exists for store %', p_store_id;
  end if;

  insert into public.device_catalog_sync_state (
    store_id, device_id, catalog_version, synced_at
  ) values (
    p_store_id, v_device_id, trim(p_catalog_version), now()
  )
  on conflict (store_id, device_id) do update
    set catalog_version = excluded.catalog_version,
        synced_at = excluded.synced_at;
end;
$$;

-- Store Management reads all registered kiosks, including kiosks that have
-- never reported a sync. This makes a missing report visible rather than
-- silently treating it as healthy.
create or replace function public.get_store_catalog_sync_status()
returns table (
  device_id uuid,
  device_code text,
  is_active boolean,
  master_catalog_version text,
  kiosk_catalog_version text,
  synced_at timestamptz,
  sync_status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_master_version text;
begin
  v_store_id := public.current_management_store_id();
  if v_store_id is null then
    raise exception 'Authentication required and app_metadata.store_id is missing.';
  end if;

  if lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', 'staff'))
      not in ('owner', 'manager', 'admin') then
    raise exception 'Manager or owner access is required.';
  end if;

  select catalog_version into v_master_version
  from public.store_catalog_versions
  where store_id = v_store_id;

  return query
  select
    d.id,
    d.device_code,
    d.is_active,
    v_master_version,
    s.catalog_version,
    s.synced_at,
    case
      when not d.is_active then 'INACTIVE'
      when v_master_version is null then 'NO MASTER'
      when s.catalog_version is null then 'NEVER SYNCED'
      when s.catalog_version = v_master_version then 'SYNCED'
      else 'OUTDATED'
    end
  from public.devices d
  left join public.device_catalog_sync_state s
    on s.store_id = d.store_id
   and s.device_id = d.id
  where d.store_id = v_store_id
  order by d.device_code;
end;
$$;

revoke all on function public.report_kiosk_catalog_sync(uuid, text, text) from public;
revoke all on function public.get_store_catalog_sync_status() from public;

grant execute on function public.report_kiosk_catalog_sync(uuid, text, text)
  to anon, authenticated;
grant execute on function public.get_store_catalog_sync_status()
  to authenticated;

notify pgrst, 'reload schema';
