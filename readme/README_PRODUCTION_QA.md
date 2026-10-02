# Store Management — Production Readiness QA

This checkpoint is the final Store Management QA hardening pass before production validation.

## Included

- Centralized role permission mapping with a pure, testable role matrix.
- StoreManagementAuth now delegates capability decisions to the centralized matrix.
- Unit coverage for Owner/Admin, Manager, Editor/Staff, unknown roles, and EOD capability.
- Existing Catalog Health, Reporting Integrity, Device Integrity, Inventory Consumption Integrity, EOD Integrity, and Database Reset hardening remain included.

## Required local validation

Run from the project root:

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

## Manual production-readiness pass

1. Sign in as Owner, Admin, Manager, Editor, and Staff.
2. Verify each role sees only the intended management controls.
3. Attempt restricted operations directly through the UI.
4. Verify Supabase RPC/RLS rejects unauthorized operations even if a client bypasses the UI.
5. Validate Catalog Health with both valid and intentionally inconsistent catalog data.
6. Validate Dashboard Reporting Integrity against Transactions, Product Sales, Category Sales, Hourly Sales, Device Sales, and Payment Summary.
7. Validate Device Integrity with valid and intentionally inconsistent kiosk/printer assignments.
8. Validate Inventory Consumption Integrity before and after processing.
9. Validate EOD Integrity before and after closing a business date.
10. On a disposable/test store, validate Database Reset and confirm master/configuration data survives while operational data is removed.
11. Perform the end-to-end workflow: Catalog → Sale → Payment → Inventory Consumption → EOD → Reporting.
12. Confirm Asia/Manila business-date boundaries around midnight.

## Security note

The Flutter permission matrix is a UI control layer. Supabase RLS and RPC authorization remain the authoritative security boundary and must be tested independently.

No GitHub commit or push was made for this checkpoint.
