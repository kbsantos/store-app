# Bigger Brew Store Management — Devices Update

This update adds Store Management device administration to the current Store EOD baseline.

## Added
- Devices page with Kiosks and Printers tabs.
- Store-scoped kiosk listing using `get_store_devices()`.
- Owner/Manager/Admin kiosk active/inactive control using `set_store_device_active()`.
- Store printer registry (`store_printers`) with name, model, interface, kiosk assignment, notes, and active status.
- Printer add/edit/activate/deactivate UI.
- DEVICES tile on the Store Management home page.

## Supabase
Run `supabase/20260918_store_devices.sql` against MyCoffeeShop before testing the Devices page.

No GitHub commit or push was made.
