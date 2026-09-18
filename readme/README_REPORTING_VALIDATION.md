# Store Management Reporting Validation

This checkpoint adds a read-only cross-report integrity check to the Store Dashboard.

Apply `supabase/20260918_store_reporting_integrity.sql` after the existing sales consistency migration.

The check compares Daily Sales against Product Sales, Category Sales, Device Sales, and recorded Payments, plus item and order counts across independent report surfaces.

Run locally:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Open Store Dashboard, select a date range, and use **CHECK REPORTING INTEGRITY**. `PASS` means the report surfaces reconcile within the defined tolerance; `ATTENTION` identifies a discrepancy for investigation. The check is read-only.
