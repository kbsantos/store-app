--  Store Management: owner-only user deletion
-- Admins retain the ability to disable users, but cannot permanently delete them.
-- Deletion removes the employee's Supabase Auth account as well as its store
-- membership. Only an Owner can invoke these functions.

create or replace function public.delete_store_employee(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_store_id uuid := public.current_store_management_store_id();
  v_actor_role text := lower(coalesce(auth.jwt()->'app_metadata'->>'role',''));
  v_target_role text;
  v_active_owner_count integer;
begin
  if v_actor_role <> 'owner' then
    raise exception 'Only the store owner can delete users';
  end if;
  if v_store_id is null then
    raise exception 'Store access is not configured';
  end if;
  if p_user_id is null then
    raise exception 'Employee user id is required';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'You cannot delete your own account';
  end if;

  select role into v_target_role
  from public.store_employee_profiles
  where user_id = p_user_id and store_id = v_store_id;

  if v_target_role is null then
    raise exception 'Employee not found for current store';
  end if;

  if v_target_role = 'owner' then
    select count(*) into v_active_owner_count
    from public.store_employee_profiles
    where store_id = v_store_id
      and role = 'owner'
      and is_active = true
      and user_id <> p_user_id;

    if v_active_owner_count = 0 then
      raise exception 'The store must retain at least one active owner';
    end if;
  end if;

  -- store_employee_profiles references auth.users with ON DELETE CASCADE.
  -- Remove the Auth account only after all owner/safety checks pass.
  delete from auth.users where id = p_user_id;
  if not found then
    raise exception 'Supabase Auth user not found';
  end if;
end;
$$;
revoke all on function public.delete_store_employee(uuid) from public;
grant execute on function public.delete_store_employee(uuid) to authenticated;

create or replace function public.delete_store_employee_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_store_id uuid := public.current_store_management_store_id();
  v_actor_role text := lower(coalesce(auth.jwt()->'app_metadata'->>'role',''));
begin
  if v_actor_role <> 'owner' then
    raise exception 'Only the store owner can delete pending employees';
  end if;
  if v_store_id is null then
    raise exception 'Store access is not configured';
  end if;
  if p_invite_id is null then
    raise exception 'Pending employee id is required';
  end if;

  delete from public.store_employee_invites
  where id = p_invite_id and store_id = v_store_id;

  if not found then
    raise exception 'Pending employee was not found for current store';
  end if;
end;
$$;
revoke all on function public.delete_store_employee_invite(uuid) from public;
grant execute on function public.delete_store_employee_invite(uuid) to authenticated;

notify pgrst, 'reload schema';
