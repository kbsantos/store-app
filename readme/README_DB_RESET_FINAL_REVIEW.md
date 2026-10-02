# Database Reset Final Review

This checkpoint hardens the store-scoped operational reset after the newer Inventory Consumption and End-of-Day features were added.

## Reset deletes

- transactions
- transaction_items
- transaction_item_options
- payments
- inventory_consumption_records
- inventory_movements
- store_eod_closings
- physical store-scoped reporting/stock summary tables when present
- physical store-scoped sync_logs when present

Views/derived reporting objects are not deleted.

## Reset preserves

- store profile/configuration
- operating hours/settings
- users and employee invites
- devices and printers
- catalog categories/products/sizes/variants/options
- recipes
- Store Master catalog
- kiosk catalog sync state

Catalog sync state is intentionally preserved because resetting sales/operational data should not force a kiosk catalog refresh when the catalog itself has not changed.

## Security

The reset RPC remains `security definer`, requires an authenticated user assigned to a store, requires Owner/Admin role, and requires the literal confirmation `RESET`. The RPC is store-scoped and does not expose a cross-store reset parameter.

## Validation

Run locally:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Apply the existing reset migration after the prior Store Management migrations, then validate with a disposable/test store. Confirm that operational rows are removed while configuration/master data remains available. Re-run EOD after reset to verify that prior EOD closings no longer block processing.
