# Bigger Brew Sales Reporting Center — Phase 4

## Implemented

Phase 4 adds advanced report filtering to the central Sales Reporting Center without duplicating reporting calculations:

- **Product Sales**
  - Category filter populated from the loaded product report data.
  - Existing kiosk/device filter remains available.
- **Transaction Report**
  - Transaction search field.
  - Status filter for common transaction states.
  - Search and status are passed to the existing `get_store_sales_transactions` RPC.
- **Filter behavior**
  - Filters reload the report using the same existing Reporting API service.
  - Report switching resets filters that do not apply to the selected report.
  - No live transaction data is changed.

## Data contract

Phase 4 does not introduce a new reporting calculation or database table. It uses the existing report views/RPCs and exposes filtering parameters that the transaction RPC already accepts.

## Supabase migration

No new Supabase migration is required for Phase 4.

## Validation

Added:

`test/store_reporting_center_phase4_test.dart`

The test verifies the Phase 4 filter registrations and transaction API parameter contract.
