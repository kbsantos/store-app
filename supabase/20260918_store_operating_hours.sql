-- MyCoffeeShop Store Management App
-- Store Operating Hours management.
-- Adds one weekly schedule row per store/day.

create table if not exists public.store_operating_hours (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  is_closed boolean not null default false,
  open_time time,
  close_time time,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint store_operating_hours_store_day_unique unique (store_id, day_of_week),
  constraint store_operating_hours_time_check check (
    (is_closed = true and open_time is null and close_time is null)
    or
    (is_closed = false and open_time is not null and close_time is not null and open_time <> close_time)
  )
);

create index if not exists store_operating_hours_store_id_idx
  on public.store_operating_hours(store_id);

insert into public.store_operating_hours (store_id, day_of_week, is_closed, open_time, close_time)
select s.id, d.day_of_week, true, null::time, null::time
from public.stores s
cross join generate_series(0, 6) as d(day_of_week)
on conflict (store_id, day_of_week) do nothing;

alter table public.store_operating_hours enable row level security;
revoke all on public.store_operating_hours from anon, authenticated;

drop policy if exists store_operating_hours_select on public.store_operating_hours;
create policy store_operating_hours_select
on public.store_operating_hours
for select
to authenticated
using (store_id = public.current_management_store_id());

create or replace function public.get_store_management_operating_hours()
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
        'day_of_week', h.day_of_week,
        'is_closed', h.is_closed,
        'open_time', case when h.open_time is null then null else to_char(h.open_time, 'HH24:MI') end,
        'close_time', case when h.close_time is null then null else to_char(h.close_time, 'HH24:MI') end
      ) order by h.day_of_week
    ),
    '[]'::jsonb
  )
  into v_result
  from public.store_operating_hours h
  where h.store_id = v_store_id;

  return v_result;
end;
$$;

revoke all on function public.get_store_management_operating_hours() from public;
grant execute on function public.get_store_management_operating_hours() to authenticated;

create or replace function public.update_store_management_operating_hours(
  p_hours jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_role text;
  v_entry jsonb;
  v_day smallint;
  v_closed boolean;
  v_open time;
  v_close time;
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

  if jsonb_typeof(p_hours) <> 'array' or jsonb_array_length(p_hours) <> 7 then
    raise exception 'Operating hours must contain exactly 7 days.';
  end if;

  for v_entry in select value from jsonb_array_elements(p_hours)
  loop
    v_day := (v_entry ->> 'day_of_week')::smallint;
    v_closed := coalesce((v_entry ->> 'is_closed')::boolean, false);

    if v_day < 0 or v_day > 6 then
      raise exception 'Invalid day_of_week: %.', v_day;
    end if;

    if v_closed then
      v_open := null;
      v_close := null;
    else
      begin
        v_open := (v_entry ->> 'open_time')::time;
        v_close := (v_entry ->> 'close_time')::time;
      exception when others then
        raise exception 'Invalid operating time for day %.', v_day;
      end;

      if v_open is null or v_close is null then
        raise exception 'Open and close times are required for day %.', v_day;
      end if;

      if v_open = v_close then
        raise exception 'Open and close times cannot be the same for day %.', v_day;
      end if;
    end if;

    insert into public.store_operating_hours (
      store_id, day_of_week, is_closed, open_time, close_time, updated_at
    ) values (
      v_store_id, v_day, v_closed, v_open, v_close, now()
    )
    on conflict (store_id, day_of_week)
    do update set
      is_closed = excluded.is_closed,
      open_time = excluded.open_time,
      close_time = excluded.close_time,
      updated_at = now();
  end loop;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'day_of_week', h.day_of_week,
        'is_closed', h.is_closed,
        'open_time', case when h.open_time is null then null else to_char(h.open_time, 'HH24:MI') end,
        'close_time', case when h.close_time is null then null else to_char(h.close_time, 'HH24:MI') end
      ) order by h.day_of_week
    ),
    '[]'::jsonb
  )
  into v_result
  from public.store_operating_hours h
  where h.store_id = v_store_id;

  return v_result;
end;
$$;

revoke all on function public.update_store_management_operating_hours(jsonb) from public;
grant execute on function public.update_store_management_operating_hours(jsonb) to authenticated;

notify pgrst, 'reload schema';
