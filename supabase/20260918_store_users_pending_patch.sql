-- Bigger Brew Store Management: fix get_store_employees return type conflict
-- Run this after 20260918_store_users.sql and before/with 20260918_store_users_pending.sql.

drop function if exists public.get_store_employees();

notify pgrst, 'reload schema';
