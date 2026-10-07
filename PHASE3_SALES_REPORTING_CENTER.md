# Bigger Brew Sales Reporting Center — Phase 3

## Implemented

Phase 3 connects the remaining reconciliation-oriented reports to the central
Sales Reporting Center:

- **Discounts & Charges**
  - Date range
  - Transaction count
  - Subtotal
  - Recorded discounts
  - Recorded transaction charges/fees when present in the transaction record
  - Total sales
  - PDF / Excel / CSV / Print through the existing Phase 2 export framework
- **End of Day**
  - Business date
  - Transaction count
  - Sales total
  - Payment total
  - Payment difference
  - EOD closing status
  - PDF / Excel / CSV / Print through the existing Phase 2 export framework

## EOD data contract

The Reporting Center does **not** duplicate EOD calculation logic.

The new `get_store_eod_reporting(start, end)` RPC is only a date-range wrapper
around the existing `get_store_eod_summary(date)` function. The existing EOD
workflow remains authoritative for sales, payments, reconciliation and closing
state.

## Discounts & Charges data contract

The new `get_store_discounts_charges(start, end)` RPC reads the transaction
JSON projection to tolerate the historical transaction column naming already
used by Store Management.

Discounts use the populated transaction discount fields.

Charges use recorded transaction charge/fee fields, including a JSON `charges`
array/object when present. The catalog's `catalog_automatic_charges` table is
configuration and is therefore not treated as proof that a charge was applied.

If the live transaction record does not contain an applied charge amount, the
report shows zero rather than inventing a charge.

## Supabase migration

Apply after the existing Store Management reporting/EOD migrations:

`supabase/20261007_sales_reporting_center_phase3.sql`

No transaction data is modified by this migration.

## Validation

Added:

`test/store_reporting_center_phase3_test.dart`

The test verifies the Phase 3 RPC contracts and the central Reporting Center
report registrations.
