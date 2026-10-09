--  Store Management: user/role hardening
--
-- Role model:
--   owner  : full control, including assigning admin/owner and database reset
--   admin  : operational administration; may assign staff/editor/manager only
--   manager: store operations; no user administration
--   editor : catalog editing only
--   staff  : basic read access through the application
--
-- Supabase RPCs are the authoritative security boundary. The Flutter role
-- matrix is only a UX aid and must never be treated as authorization.

create or replace function public.can_manage_store_employee_role(p_target_role text)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select case lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', ''))
    when 'owner' then lower(trim(p_target_role)) in ('staff','editor','manager','admin','owner')
    when 'admin' then lower(trim(p_target_role)) in ('staff','editor','manager')
    else false
  end;
$$;
revoke all on function public.can_manage_store_employee_role(text) from public;
grant execute on function public.can_manage_store_employee_role(text) to authenticated;

-- Direct table writes are not part of the Store Users workflow. Employee
-- changes must go through the security-definer RPCs below.
revoke insert, update, delete on public.store_employee_profiles from authenticated;
revoke insert, update, delete on public.store_employee_invites from authenticated;

-- Keep employee reads available to authenticated store members through the
-- existing get_store_employees() security-definer function.
revoke select on public.store_employee_profiles from authenticated;
revoke select on public.store_employee_invites from authenticated;

create or replace function public.add_store_employee(
  p_email text,
  p_full_name text default '',
  p_role text default 'staff'
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid;
  v_store_id uuid := public.current_store_management_store_id();
  v_role text := lower(trim(p_role));
  v_meta jsonb;
begin
  if not public.can_manage_store_employee_role(v_role) then
    raise exception 'You are not allowed to assign the % role', v_role;
  end if;
  if v_store_id is null then
    raise exception 'Store access is not configured';
  end if;
  if trim(coalesce(p_email,'')) = '' or position('@' in p_email) = 0 then
    raise exception 'A valid employee email is required';
  end if;

  select id into v_user_id
  from auth.users
  where lower(email) = lower(trim(p_email))
  limit 1;

  if v_user_id is not null then
    if exists (
      select 1 from public.store_employee_profiles
      where user_id = v_user_id and store_id = v_store_id
    ) then
      raise exception 'User is already assigned to this store';
    end if;

    delete from public.store_employee_invites
    where store_id = v_store_id and lower(email) = lower(trim(p_email));

    insert into public.store_employee_profiles(user_id, store_id, full_name, role)
    values (v_user_id, v_store_id, coalesce(trim(p_full_name), ''), v_role);

    select coalesce(raw_app_meta_data, '{}'::jsonb) into v_meta
    from auth.users where id = v_user_id;

    update auth.users
    set raw_app_meta_data = v_meta || jsonb_build_object(
      'store_id', v_store_id::text,
      'role', v_role
    )
    where id = v_user_id;
    return v_user_id;
  end if;

  insert into public.store_employee_invites(store_id, email, full_name, role)
  values (v_store_id, lower(trim(p_email)), coalesce(trim(p_full_name), ''), v_role)
  on conflict (store_id, lower(email)) do update
    set full_name = excluded.full_name,
        role = excluded.role,
        is_active = true,
        updated_at = now();

  return null;
end;
$$;
revoke all on function public.add_store_employee(text,text,text) from public;
grant execute on function public.add_store_employee(text,text,text) to authenticated;

create or replace function public.update_store_employee(
  p_user_id uuid,
  p_full_name text,
  p_role text,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_store_id uuid := public.current_store_management_store_id();
  v_role text := lower(trim(p_role));
  v_current_role text;
  v_meta jsonb;
  v_active_owner_count integer;
begin
  if v_store_id is null then
    raise exception 'Store access is not configured';
  end if;

  select role into v_current_role
  from public.store_employee_profiles
  where user_id = p_user_id and store_id = v_store_id;

  if v_current_role is null then
    raise exception 'Employee not found for current store';
  end if;

  if not public.can_manage_store_employee_role(v_role) then
    raise exception 'You are not allowed to assign the % role', v_role;
  end if;

  -- Admins cannot edit an existing admin/owner account at all. Owners can.
  if lower(coalesce(auth.jwt()->'app_metadata'->>'role','')) = 'admin'
     and v_current_role in ('admin','owner') then
    raise exception 'Admins cannot modify admin or owner accounts';
  end if;

  -- Never leave the store without an active owner.
  if v_current_role = 'owner' and (v_role <> 'owner' or coalesce(p_is_active, true) = false) then
    select count(*) into v_active_owner_count
    from public.store_employee_profiles
    where store_id = v_store_id and role = 'owner' and is_active = true and user_id <> p_user_id;
    if v_active_owner_count = 0 then
      raise exception 'The store must retain at least one active owner';
    end if;
  end if;

  update public.store_employee_profiles
  set full_name = coalesce(trim(p_full_name), ''),
      role = v_role,
      is_active = coalesce(p_is_active, true),
      updated_at = now()
  where user_id = p_user_id and store_id = v_store_id;

  select coalesce(raw_app_meta_data, '{}'::jsonb) into v_meta
  from auth.users where id = p_user_id;

  update auth.users
  set raw_app_meta_data = v_meta || jsonb_build_object(
    'store_id', v_store_id::text,
    'role', v_role
  )
  where id = p_user_id;
end;
$$;
revoke all on function public.update_store_employee(uuid,text,text,boolean) from public;
grant execute on function public.update_store_employee(uuid,text,text,boolean) to authenticated;

create or replace function public.set_store_employee_active(
  p_user_id uuid,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_store_id uuid := public.current_store_management_store_id();
  v_target_role text;
  v_active_owner_count integer;
begin
  if v_store_id is null then
    raise exception 'Store access is not configured';
  end if;

  select role into v_target_role
  from public.store_employee_profiles
  where user_id = p_user_id and store_id = v_store_id;

  if v_target_role is null then
    raise exception 'Employee not found for current store';
  end if;

  if lower(coalesce(auth.jwt()->'app_metadata'->>'role','')) = 'admin'
     and v_target_role in ('admin','owner') then
    raise exception 'Admins cannot modify admin or owner accounts';
  end if;

  if v_target_role = 'owner' and coalesce(p_is_active, true) = false then
    select count(*) into v_active_owner_count
    from public.store_employee_profiles
    where store_id = v_store_id and role = 'owner' and is_active = true and user_id <> p_user_id;
    if v_active_owner_count = 0 then
      raise exception 'The store must retain at least one active owner';
    end if;
  end if;

  update public.store_employee_profiles
  set is_active = coalesce(p_is_active, true), updated_at = now()
  where user_id = p_user_id and store_id = v_store_id;
end;
$$;
revoke all on function public.set_store_employee_active(uuid,boolean) from public;
grant execute on function public.set_store_employee_active(uuid,boolean) to authenticated;

-- Pending invitations follow the same role rules and should not be visible
-- directly through table reads to ordinary store users.
drop policy if exists "store_employee_invites_read" on public.store_employee_invites;
drop policy if exists "store_employee_invites_write" on public.store_employee_invites;

create policy "store_employee_invites_read" on public.store_employee_invites
for select to authenticated
using (
  store_id = public.current_store_management_store_id()
  and lower(coalesce(auth.jwt()->'app_metadata'->>'role','')) in ('owner','admin')
);

create policy "store_employee_invites_write" on public.store_employee_invites
for all to authenticated
using (
  store_id = public.current_store_management_store_id()
  and lower(coalesce(auth.jwt()->'app_metadata'->>'role','')) in ('owner','admin')
)
with check (
  store_id = public.current_store_management_store_id()
  and lower(coalesce(auth.jwt()->'app_metadata'->>'role','')) in ('owner','admin')
);

notify pgrst, 'reload schema';

create or replace function public.link_store_employee_invite(p_invite_id uuid, p_email text)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid;
  v_store_id uuid := public.current_store_management_store_id();
  v_role text;
  v_meta jsonb;
  v_invite_exists boolean;
begin
  if v_store_id is null then
    raise exception 'Store access is not configured';
  end if;

  select exists (
    select 1 from public.store_employee_invites
    where id = p_invite_id and store_id = v_store_id and lower(email) = lower(trim(p_email))
  ) into v_invite_exists;
  if not v_invite_exists then
    raise exception 'Pending employee invitation was not found';
  end if;

  select role into v_role
  from public.store_employee_invites
  where id = p_invite_id and store_id = v_store_id;

  if not public.can_manage_store_employee_role(v_role) then
    raise exception 'You are not allowed to assign the % role', v_role;
  end if;

  select id into v_user_id
  from auth.users
  where lower(email) = lower(trim(p_email))
  limit 1;
  if v_user_id is null then
    raise exception 'No Supabase Auth user exists for this email yet';
  end if;

  if exists (
    select 1 from public.store_employee_profiles
    where user_id = v_user_id and store_id = v_store_id
  ) then
    raise exception 'User is already assigned to this store';
  end if;

  insert into public.store_employee_profiles(user_id, store_id, full_name, role)
  select v_user_id, store_id, full_name, role
  from public.store_employee_invites
  where id = p_invite_id and store_id = v_store_id;

  delete from public.store_employee_invites
  where id = p_invite_id and store_id = v_store_id;

  select coalesce(raw_app_meta_data, '{}'::jsonb) into v_meta
  from auth.users where id = v_user_id;

  update auth.users
  set raw_app_meta_data = v_meta || jsonb_build_object(
    'store_id', v_store_id::text,
    'role', v_role
  )
  where id = v_user_id;

  return v_user_id;
end;
$$;
revoke all on function public.link_store_employee_invite(uuid,text) from public;
grant execute on function public.link_store_employee_invite(uuid,text) to authenticated;

notify pgrst, 'reload schema';
