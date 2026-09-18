-- Bigger Brew Store Management: employees and roles
-- Employees must already exist in Supabase Auth. This migration does not create passwords.

create table if not exists public.store_employee_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  store_id uuid not null references public.stores(id) on delete cascade,
  full_name text not null default '',
  role text not null default 'staff' check (role in ('staff','editor','manager','admin','owner')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists store_employee_profiles_store_id_idx
  on public.store_employee_profiles(store_id);

create or replace function public.current_store_management_store_id()
returns uuid
language sql stable security invoker set search_path = public
as $$ select nullif(auth.jwt() -> 'app_metadata' ->> 'store_id', '')::uuid $$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'store_employee_profiles_store_user_unique') then
    alter table public.store_employee_profiles add constraint store_employee_profiles_store_user_unique unique (store_id, user_id);
  end if;
end $$;

alter table public.store_employee_profiles enable row level security;
drop policy if exists "store_employee_profiles_read" on public.store_employee_profiles;
drop policy if exists "store_employee_profiles_write" on public.store_employee_profiles;
create policy "store_employee_profiles_read" on public.store_employee_profiles for select to authenticated
using (store_id = public.current_store_management_store_id());
create policy "store_employee_profiles_write" on public.store_employee_profiles for all to authenticated
using (store_id = public.current_store_management_store_id() and lower(coalesce(auth.jwt()->'app_metadata'->>'role','')) in ('owner','admin'))
with check (store_id = public.current_store_management_store_id() and lower(coalesce(auth.jwt()->'app_metadata'->>'role','')) in ('owner','admin'));

grant select, insert, update on public.store_employee_profiles to authenticated;

create or replace function public.get_store_employees()
returns table(user_id uuid, email text, full_name text, role text, is_active boolean, created_at timestamptz, updated_at timestamptz)
language sql security definer set search_path = public, auth
as $$
  select p.user_id, u.email, p.full_name, p.role, p.is_active, p.created_at, p.updated_at
  from public.store_employee_profiles p
  join auth.users u on u.id = p.user_id
  where p.store_id = public.current_store_management_store_id()
  order by lower(coalesce(p.full_name, '')), lower(coalesce(u.email, ''));
$$;
revoke all on function public.get_store_employees() from public;
grant execute on function public.get_store_employees() to authenticated;

create or replace function public.add_store_employee(p_email text, p_full_name text default '', p_role text default 'staff')
returns uuid language plpgsql security definer set search_path = public, auth
as $$
declare v_user_id uuid; v_store_id uuid := public.current_store_management_store_id(); v_role text := lower(trim(p_role)); v_meta jsonb;
begin
  if lower(coalesce(auth.jwt()->'app_metadata'->>'role','')) not in ('owner','admin') then raise exception 'Employee management permission denied'; end if;
  if v_store_id is null then raise exception 'Store access is not configured'; end if;
  if v_role not in ('staff','editor','manager','admin','owner') then raise exception 'Invalid employee role'; end if;
  select id into v_user_id from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if v_user_id is null then raise exception 'No Supabase Auth user exists for this email'; end if;
  if exists (select 1 from public.store_employee_profiles where user_id = v_user_id and store_id = v_store_id) then raise exception 'User is already assigned to this store'; end if;
  insert into public.store_employee_profiles(user_id, store_id, full_name, role) values (v_user_id, v_store_id, coalesce(trim(p_full_name), ''), v_role);
  select coalesce(raw_app_meta_data, '{}'::jsonb) into v_meta from auth.users where id = v_user_id;
  update auth.users set raw_app_meta_data = v_meta || jsonb_build_object('store_id', v_store_id::text, 'role', v_role) where id = v_user_id;
  return v_user_id;
end $$;
revoke all on function public.add_store_employee(text,text,text) from public;
grant execute on function public.add_store_employee(text,text,text) to authenticated;

create or replace function public.update_store_employee(p_user_id uuid, p_full_name text, p_role text, p_is_active boolean)
returns void language plpgsql security definer set search_path = public, auth
as $$
declare v_store_id uuid := public.current_store_management_store_id(); v_role text := lower(trim(p_role)); v_meta jsonb;
begin
  if lower(coalesce(auth.jwt()->'app_metadata'->>'role','')) not in ('owner','admin') then raise exception 'Employee management permission denied'; end if;
  if v_role not in ('staff','editor','manager','admin','owner') then raise exception 'Invalid employee role'; end if;
  if not exists (select 1 from public.store_employee_profiles where user_id = p_user_id and store_id = v_store_id) then raise exception 'Employee not found for current store'; end if;
  update public.store_employee_profiles set full_name = coalesce(trim(p_full_name), ''), role = v_role, is_active = coalesce(p_is_active, true), updated_at = now() where user_id = p_user_id and store_id = v_store_id;
  select coalesce(raw_app_meta_data, '{}'::jsonb) into v_meta from auth.users where id = p_user_id;
  update auth.users set raw_app_meta_data = v_meta || jsonb_build_object('store_id', v_store_id::text, 'role', v_role) where id = p_user_id;
end $$;
revoke all on function public.update_store_employee(uuid,text,text,boolean) from public;
grant execute on function public.update_store_employee(uuid,text,text,boolean) to authenticated;

create or replace function public.set_store_employee_active(p_user_id uuid, p_is_active boolean)
returns void language plpgsql security definer set search_path = public, auth
as $$
begin
  if lower(coalesce(auth.jwt()->'app_metadata'->>'role','')) not in ('owner','admin') then raise exception 'Employee management permission denied'; end if;
  update public.store_employee_profiles set is_active = coalesce(p_is_active, true), updated_at = now() where user_id = p_user_id and store_id = public.current_store_management_store_id();
  if not found then raise exception 'Employee not found for current store'; end if;
end $$;
revoke all on function public.set_store_employee_active(uuid,boolean) from public;
grant execute on function public.set_store_employee_active(uuid,boolean) to authenticated;

notify pgrst, 'reload schema';
