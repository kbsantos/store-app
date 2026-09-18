-- Bigger Brew Store Management: device administration
-- Kiosks use the existing public.devices table created by the kiosk/reporting schema.
-- Printers are store-managed configuration records and may optionally be assigned to a kiosk.

create table if not exists public.store_printers (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  name text not null,
  model text not null default 'XP-58H',
  interface text not null default 'Bluetooth',
  device_id uuid null references public.devices(id) on delete set null,
  is_active boolean not null default true,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists store_printers_store_id_idx
  on public.store_printers(store_id);

create index if not exists store_printers_device_id_idx
  on public.store_printers(device_id);

create or replace function public.current_store_management_store_id()
returns uuid
language sql
stable
security invoker
set search_path = public
as $$
  select nullif(auth.jwt() -> 'app_metadata' ->> 'store_id', '')::uuid;
$$;

revoke all on function public.current_store_management_store_id() from public;
grant execute on function public.current_store_management_store_id() to authenticated;

alter table public.store_printers enable row level security;

drop policy if exists "store_management_printers_read" on public.store_printers;
drop policy if exists "store_management_printers_write" on public.store_printers;

create policy "store_management_printers_read"
on public.store_printers
for select to authenticated
using (store_id = public.current_store_management_store_id());

create policy "store_management_printers_write"
on public.store_printers
for all to authenticated
using (
  store_id = public.current_store_management_store_id()
  and lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')) in ('owner','manager','admin')
)
with check (
  store_id = public.current_store_management_store_id()
  and lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')) in ('owner','manager','admin')
);

grant select, insert, update, delete on public.store_printers to authenticated;

create or replace function public.get_store_devices()
returns table (
  id uuid,
  device_code text,
  is_active boolean,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select d.id, d.device_code, d.is_active, d.created_at
  from public.devices d
  where d.store_id = public.current_store_management_store_id()
  order by d.device_code;
$$;

revoke all on function public.get_store_devices() from public;
grant execute on function public.get_store_devices() to authenticated;

create or replace function public.set_store_device_active(
  p_device_id uuid,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', ''));
begin
  if v_role not in ('owner','manager','admin') then
    raise exception 'Device management permission denied';
  end if;

  update public.devices
  set is_active = coalesce(p_is_active, true)
  where id = p_device_id
    and store_id = public.current_store_management_store_id();

  if not found then
    raise exception 'Device not found for current store';
  end if;
end;
$$;

revoke all on function public.set_store_device_active(uuid, boolean) from public;
grant execute on function public.set_store_device_active(uuid, boolean) to authenticated;

notify pgrst, 'reload schema';
