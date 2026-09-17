# MyCoffeeShop Store Management

MyCoffeeShop Store Management is a separate Flutter application for back-office catalog administration and sales reporting.

It shares the existing `MyCoffeeShop` Supabase project with the MyCoffeeShop Kiosk but has a separate application boundary.

## Architecture

```text
MyCoffeeShop Kiosk                 Store Management
      |                                  |
      | secure kiosk RPCs                | Supabase Auth
      |                                  |
      +------------- Supabase -----------+
                         |
                    PostgreSQL
```

The kiosk keeps its local operational catalog. Store Management writes the Supabase Store Master Catalog. The kiosk then receives published catalog changes through its synchronization flow.

## First setup

1. Apply the existing MyCoffeeShop Store Master Catalog and REST API migrations to Supabase.
2. Apply `supabase/20260917_store_management_catalog_auth_rpc.sql`.
3. Create/sign in a Supabase Auth user.
4. Assign `app_metadata.store_id` and a management role (`owner`, `manager`, or `admin`).
5. Copy `.env.example` to `.env` and configure Supabase.
6. Run `flutter pub get` and `flutter run`.

See `readme/STORE_MANAGEMENT_APP.md` for details.
