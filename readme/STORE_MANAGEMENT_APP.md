# MyCoffeeShop Store Management

Separate Flutter back-office application for MyCoffeeShop. It owns store administration workflows that should not live on the customer-facing kiosk.

## Responsibilities

- Store-scoped Supabase Auth login
- Product Catalog management
- Categories
- Products
- Sizes and variants
- Options / add-ons
- Product/category assignment
- Catalog validation
- Sales reporting through Supabase REST reporting views

## Kiosk boundary

The kiosk remains the customer-facing application. It keeps a local operational catalog cache and synchronizes from the Supabase Store Master Catalog. Store Management does not require the kiosk's Store ID/Kiosk Code settings and does not replace the kiosk's transaction-sync RPCs.

## Supabase setup

The database must already have the MyCoffeeShop Store Master Catalog Phase 1 and REST API Phase 1 migrations installed.

Run:

`supabase/20260917_store_management_catalog_auth_rpc.sql`

This adds secure authenticated management RPCs that derive the store from the logged-in user's `app_metadata.store_id`.

### Assign a store to a management user

For an initial user, an administrator can assign the store and role in Supabase SQL Editor using the user's auth UUID:

```sql
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
  || jsonb_build_object(
       'store_id', 'YOUR_STORE_UUID',
       'role', 'owner'
     )
where id = 'AUTH_USER_UUID';
```

Supported catalog-management roles in the app are `owner`, `manager`, and `admin`.

## Configuration

Copy `.env.example` to `.env` and set:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

Do not put a Supabase secret/service-role key in the Flutter application.

## Run

```bash
flutter pub get
flutter run
```

For web:

```bash
flutter run -d chrome
```

## Current status

This repository is the first separate Store Management application extraction. Flutter/Dart compilation should be run in the developer environment before release; the build environment used to prepare this package did not include the Flutter SDK.

## Store Admin — Store Profile

The Store Settings area now includes Store Profile. Authenticated users can view
store details; owner and admin accounts can update the store name, brand,
location, and active status through the `update_store_management_profile` RPC.
The feature is store-scoped using `app_metadata.store_id` and does not modify
catalog or operational transaction data.

Apply `supabase/20260918_store_profile.sql` to the MyCoffeeShop Supabase project
before using the Store Profile page.

## Store Admin — Operating Hours

Store Settings now includes a weekly Operating Hours page. The schedule is stored
per store in `store_operating_hours` and accessed through secure management RPCs.
Owner and admin accounts can edit the seven-day schedule; other authenticated
management users can view it. Apply `supabase/20260918_store_operating_hours.sql`
before using the feature.
