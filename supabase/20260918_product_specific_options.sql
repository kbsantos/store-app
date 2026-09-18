-- Product-specific catalog options are valid even when they are not backed by
-- a shared catalog_option_definitions row.
--
-- The Store Management UI supports two option concepts:
--   1. Shared options: catalog_option_definitions + catalog_product_options
--   2. Product-specific options: catalog_product_options only
--
-- The previous foreign key on (store_id, option_id) forced every product
-- option to have a shared definition, which caused assignments such as a
-- newly-created product-specific option to fail with SQLSTATE 23503.

alter table public.catalog_product_options
  drop constraint if exists catalog_product_options_store_id_option_id_fkey;

notify pgrst, 'reload schema';
