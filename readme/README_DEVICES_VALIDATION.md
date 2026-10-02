# Store Management — Devices Final Validation

This checkpoint hardens the Devices Management page with a read-only **DEVICE INTEGRITY CHECK**.

It validates the currently loaded store-scoped device data for:
- missing kiosk IDs
- duplicate kiosk device codes
- printers missing name/model/interface
- printer assignments pointing to an unregistered kiosk
- active printers assigned to inactive kiosks
- multiple active printers assigned to one kiosk

The check is read-only and does not modify devices or printers.

## Database

The existing `supabase/20260918_store_devices.sql` remains the database security boundary:
- printer records are store-scoped with RLS
- printer writes require owner/manager/admin
- kiosk activation/deactivation is restricted to owner/manager/admin by RPC
- kiosk and printer records are store-scoped

No new migration is required for this UI validation checkpoint.

## Local validation

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Manual checks:
1. Open Devices.
2. Verify Kiosks list is store-scoped.
3. Verify inactive kiosk can be activated/deactivated only by permitted roles.
4. Open Printers and verify add/edit/activate/deactivate behavior.
5. Assign a printer to a kiosk and refresh.
6. Run DEVICE INTEGRITY CHECK.
7. Verify an intentionally inconsistent assignment is reported as ATTENTION, then correct it and verify PASS.
8. Confirm a read-only role cannot modify devices/printers.
