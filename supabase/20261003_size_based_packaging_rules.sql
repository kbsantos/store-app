-- Additive schema for reusable packaging rules by catalog size.
-- This does not modify or drop existing recipe RPCs or consumption functions.
create table if not exists public.store_size_packaging_rules (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null,
  size_id text not null,
  inventory_item_id uuid not null,
  quantity numeric(14,4) not null default 1 check (quantity > 0),
  is_required boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, size_id, inventory_item_id)
);
create index if not exists idx_store_size_packaging_rules_store_size
  on public.store_size_packaging_rules(store_id, size_id, is_active);
alter table public.store_size_packaging_rules enable row level security;
drop policy if exists store_size_packaging_rules_select on public.store_size_packaging_rules;
create policy store_size_packaging_rules_select on public.store_size_packaging_rules
  for select to authenticated using (store_id = public.current_management_store_id());
drop policy if exists store_size_packaging_rules_write on public.store_size_packaging_rules;
create policy store_size_packaging_rules_write on public.store_size_packaging_rules
  for all to authenticated
  using (store_id = public.current_management_store_id() and lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role','staff')) in ('owner','manager','admin'))
  with check (store_id = public.current_management_store_id() and lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role','staff')) in ('owner','manager','admin'));
revoke all on public.store_size_packaging_rules from public, anon;
grant select, insert, update, delete on public.store_size_packaging_rules to authenticated;
create or replace function public.validate_store_size_packaging_rule()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.inventory_items i where i.id=new.inventory_item_id and i.store_id=new.store_id and i.is_active=true and coalesce(i.tracking_type,'tracked')='tracked') then
    raise exception 'Packaging rules must reference an active tracked inventory item in the same store.';
  end if;
  new.updated_at := now();
  return new;
end; $$;
drop trigger if exists trg_validate_store_size_packaging_rule on public.store_size_packaging_rules;
create trigger trg_validate_store_size_packaging_rule before insert or update on public.store_size_packaging_rules for each row execute function public.validate_store_size_packaging_rule();
comment on table public.store_size_packaging_rules is 'Reusable default packaging consumption rules by catalog size; automatic deduction requires a compatible size-aware recipe consumption RPC.';
