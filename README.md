# Store Management

Store Management is a Flutter application for back-office store operations, catalog administration, inventory management, and sales reporting. It uses the existing Supabase project for authentication and store data.

## Main areas

- **Products** — manage categories, products, recipes, sizes and variants, options/add-ons, category assignments, catalog health, and catalog synchronization.
- **Inventory** — manage inventory items, stock levels, adjustments, movements, consumption, and stock reset operations.
- **Sales** — access Transactions and End of Day.
- **Reports** — open the Sales Reporting Center for Sales Summary, Daily Sales, Hourly Sales, Product Sales, Product Type Sales, Category Sales, Payment Summary, Sales by Device, Discounts & Charges, and Transaction Report.

## Reporting behavior

- Reports support date selection and applicable report filters.
- Report exports include PDF, Excel, CSV, and Print where supported by the selected report.
- Product Type Sales uses customer-facing labels for known internal values, including `drink` → **Drink**, `food` → **Food**, `accessory` → **Accessory**, and `addOn`/`addon`/`add-on` → **Add-on**.
- Hourly Sales excludes zero-sales rows. When no hourly sales exist for the selected period, the report shows an empty-state message.
- The Sales Reporting Center does not expose row Details/drill-down actions.

## Inventory reset safety

The **Reset Selected to Zero** operation applies only to inventory items that support physical stock movements. Recipe-only items (for example, ingredients configured as recipe-only) must not be given physical stock movements. The UI excludes recipe-only items from the reset selection; the database validation remains in place. Stock adjustments/history for eligible items should be preserved by the existing reset workflow.

## Architecture

```text
     Kiosk                          Store Management
      |                                  |
      | secure kiosk RPCs                | Supabase Auth
      |                                  |
      +------------- Supabase -----------+
                         |
                    PostgreSQL
```

The kiosk keeps its local operational catalog. Store Management writes the Supabase Store Master Catalog, and the kiosk receives published catalog changes through its synchronization flow.

## First setup

1. Apply the existing Store Master Catalog and REST API migrations to Supabase.
2. Apply `supabase/20260917_store_management_catalog_auth_rpc.sql` where required by your existing deployment setup.
3. Create/sign in a Supabase Auth user.
4. Assign `app_metadata.store_id` and a management role (`owner`, `manager`, or `admin`).
5. Copy `.env.example` to `.env` and configure Supabase.
6. Run `flutter pub get` and `flutter run`.

See `readme/STORE_MANAGEMENT_APP.md` for additional setup details. Do not apply migrations to the live database without reviewing them first.

## Development checks

```bash
flutter pub get
flutter analyze
flutter test
```

## Release builds

Android APK:

```bash
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`.
