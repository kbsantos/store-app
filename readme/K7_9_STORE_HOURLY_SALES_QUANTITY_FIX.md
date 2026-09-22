# K7.9 — Store Hourly Sales Quantity Fix

## Issue

The Store Management Hourly Sales report for September 17, 2026 showed:

- Transactions: 106
- Items Sold: 179
- Sales: ₱14,226.00

The Store Dashboard and transaction-level reconciliation show that the correct
item quantity is 200.

The RPC was counting `transaction_items` rows. That is incorrect when one
transaction item row has `quantity > 1`.

## Final contract

Hourly Sales now uses:

- Transactions: `count(*)` of qualifying transactions
- Items Sold: `sum(transaction_items.quantity)` per transaction
- Sales: `sum(transactions.total)`
- Hour: transaction event time converted to `Asia/Manila`

For September 17, 2026 the expected daily totals are:

- 106 transactions
- 200 items sold
- ₱14,226.00 sales

## Migration

Apply:

`supabase/20260922_store_hourly_sales_quantity_fix.sql`

This migration intentionally redefines `get_store_hourly_sales(date,date)`
after the earlier September 18 reporting migrations so the final deployed RPC
uses the corrected quantity calculation.


### V2 correction
The hourly aggregation pre-aggregates item quantities per transaction before grouping by hour. This avoids PostgreSQL grouping errors from referencing a transaction id inside the grouped hourly aggregate.
