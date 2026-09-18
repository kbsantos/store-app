-- Bigger Brew Store Management: pending employee records
-- Allows a store manager to create an employee record before the employee has
-- a Supabase Auth account. No password is created or stored by the Store app.

create table if not exists public.store_employee_invites (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  email text not null,
  full_name text not null default '',
  role text not null default 'staff' check (role in ('staff','editor','manager','admin','owner')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists store_employee_invites_store_email_idx
  on public.store_employee_invites(store_id, lower(email));

alter table public.store_employee_invites enable row level security;
drop policy if exists "store_employee_invites_read" on public.store_employee_invites;
drop policy if exists "store_employee_invites_write" on public.store_employee_invites;
create policy "store_employee_invites_read" on public.store_employee_invites
for select to authenticated
using (store_id = public.current_store_management_store_id());
create policy "store_employee_invites_write" on public.store_employee_invites
for all to authenticated
using (store_id = public.current_store_management_store_id() and lower(coalesce(auth.jwt()->'app_metadata'->>'role','')) in ('owner','admin'))
with check (store_id = public.current_store_management_store_id() and lower(coalesce(auth.jwt()->'app_metadata'->>'role','')) in ('owner','admin'));

grant select, insert, update, delete on public.store_employee_invites to authenticated;

-- The existing Store users migration created get_store_employees() with a different
-- OUT parameter row type. PostgreSQL cannot change a function's return row type
-- with CREATE OR REPLACE, so remove the old zero-argument overload first.
drop function if exists public.get_store_employees();

create or replace function public.get_store_employees()
returns table(employee_id uuid, user_id uuid, email text, full_name text, role text, is_active boolean, status text, created_at timestamptz, updated_at timestamptz)
language sql security definer set search_path = public, auth
as $$
  select employee_id, user_id, email, full_name, role, is_active, status, created_at, updated_at
  from (
    select p.user_id as employee_id, p.user_id as user_id, u.email, p.full_name, p.role, p.is_active, 'ACTIVE'::text as status, p.created_at, p.updated_at
    from public.store_employee_profiles p
    join auth.users u on u.id = p.user_id
    where p.store_id = public.current_store_management_store_id()
    union all
    select i.id as employee_id, null::uuid as user_id, i.email, i.full_name, i.role, i.is_active, 'PENDING AUTH'::text as status, i.created_at, i.updated_at
    from public.store_employee_invites i
    where i.store_id = public.current_store_management_store_id()
  ) employees
  order by full_name, email;
$$;
revoke all on function public.get_store_employees() from public;
grant execute on function public.get_store_employees() to authenticated;

create or replace function public.add_store_employee(p_email text, p_full_name text default '', p_role text default 'staff')
returns uuid language plpgsql security definer set search_path = public, auth
as $$
declare
  v_user_id uuid;
  v_store_id uuid := public.current_store_management_store_id();
  v_role text := lower(trim(p_role));
  v_meta jsonb;
  v_invite_id uuid;
begin
  if lower(coalesce(auth.jwt()->'app_metadata'->>'role','')) not in ('owner','admin') then raise exception 'Employee management permission denied'; end if;
  if v_store_id is null then raise exception 'Store access is not configured'; end if;
  if v_role not in ('staff','editor','manager','admin','owner') then raise exception 'Invalid employee role'; end if;
  if trim(coalesce(p_email,'')) = '' or position('@' in p_email) = 0 then raise exception 'A valid employee email is required'; end if;

  select id into v_user_id from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if v_user_id is not null then
    if exists (select 1 from public.store_employee_profiles where user_id = v_user_id and store_id = v_store_id) then raise exception 'User is already assigned to this store'; end if;
    delete from public.store_employee_invites where store_id = v_store_id and lower(email) = lower(trim(p_email));
    insert into public.store_employee_profiles(user_id, store_id, full_name, role) values (v_user_id, v_store_id, coalesce(trim(p_full_name), ''), v_role);
    select coalesce(raw_app_meta_data, '{}'::jsonb) into v_meta from auth.users where id = v_user_id;
    update auth.users set raw_app_meta_data = v_meta || jsonb_build_object('store_id', v_store_id::text, 'role', v_role) where id = v_user_id;
    return v_user_id;
  end if;

  insert into public.store_employee_invites(store_id, email, full_name, role)
  values (v_store_id, lower(trim(p_email)), coalesce(trim(p_full_name), ''), v_role)
  on conflict (store_id, lower(email)) do update
    set full_name = excluded.full_name, role = excluded.role, is_active = true, updated_at = now()
  returning id into v_invite_id;
  return null;
end $$;
revoke all on function public.add_store_employee(text,text,text) from public;
grant execute on function public.add_store_employee(text,text,text) to authenticated;

create or replace function public.link_store_employee_invite(p_invite_id uuid, p_email text)
returns uuid language plpgsql security definer set search_path = public, auth
as $$
declare
  v_user_id uuid;
  v_store_id uuid := public.current_store_management_store_id();
  v_role text;
  v_meta jsonb;
  v_invite_exists boolean;
begin
  if lower(coalesce(auth.jwt()->'app_metadata'->>'role','')) not in ('owner','admin') then raise exception 'Employee management permission denied'; end if;
  select exists (
    select 1 from public.store_employee_invites
    where id = p_invite_id and store_id = v_store_id and lower(email) = lower(trim(p_email))
  ) into v_invite_exists;
  if not v_invite_exists then raise exception 'Pending employee invitation was not found'; end if;
  select id into v_user_id from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if v_user_id is null then raise exception 'No Supabase Auth user exists for this email yet'; end if;
  if exists (select 1 from public.store_employee_profiles where user_id = v_user_id and store_id = v_store_id) then raise exception 'User is already assigned to this store'; end if;
  select role into v_role from public.store_employee_invites where id = p_invite_id and store_id = v_store_id;
  insert into public.store_employee_profiles(user_id, store_id, full_name, role)
  select v_user_id, store_id, full_name, role from public.store_employee_invites where id = p_invite_id and store_id = v_store_id;
  delete from public.store_employee_invites where id = p_invite_id and store_id = v_store_id;
  select coalesce(raw_app_meta_data, '{}'::jsonb) into v_meta from auth.users where id = v_user_id;
  update auth.users set raw_app_meta_data = v_meta || jsonb_build_object('store_id', v_store_id::text, 'role', v_role) where id = v_user_id;
  return v_user_id;
end $$;
revoke all on function public.link_store_employee_invite(uuid,text) from public;
grant execute on function public.link_store_employee_invite(uuid,text) to authenticated;

notify pgrst, 'reload schema';
