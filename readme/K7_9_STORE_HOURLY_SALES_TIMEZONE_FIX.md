# K7.9 — Store Hourly Sales Timezone Fix

## Problem

Hourly Sales was displaying September 17, 2026 activity around 03:00–04:00
instead of the store's actual Manila-local activity around 08:00–20:00.

The transaction timestamps are stored as `timestamptz`/UTC. The report must
convert the event timestamp to `Asia/Manila` before filtering by business date
and before extracting the hour.

## Fix

`20260922_store_hourly_sales_timezone_fix.sql` redefines
`public.get_store_hourly_sales(date, date)` so that:

- `transaction_date` is the primary event timestamp.
- `created_at` is the fallback event timestamp.
- Both are converted to `Asia/Manila`.
- The Manila-local date is used for the requested report date range.
- The Manila-local hour is used for hourly grouping.
- `transaction_items.quantity` remains the authority for Items Sold.
- `transactions.total` remains the financial authority for Total Sales.
- All 24 hourly rows remain visible, including zero-activity hours.

## September 17 validation target

The previously verified Manila-local distribution is:

| Hour | Transactions | Items | Sales |
|---:|---:|---:|---:|
| 08:00 | 6 | 9 | 1,144 |
| 09:00 | 7 | 13 | 1,919 |
| 10:00 | 9 | 19 | 4,889 |
| 11:00 | 16 | 27 | 3,640 |
| 12:00 | 15 | 24 | 3,940 |
| 13:00 | 12 | 20 | 2,721 |
| 14:00 | 6 | 14 | 2,394 |
| 15:00 | 6 | 11 | 1,615 |
| 16:00 | 6 | 17 | 4,814 |
| 17:00 | 10 | 23 | 3,011 |
| 18:00 | 5 | 11 | 2,073 |
| 19:00 | 7 | 11 | 1,281 |
| 20:00 | 1 | 1 | 39 |

Totals: 106 transactions, 179 items, ₱14,226.00.

## Deployment

Apply the migration in Supabase SQL Editor while authenticated as an account
with the required Store Management access.

Then reload the Store Management app and select:

`FROM 2026-09-17` → `TO 2026-09-17`

The on-screen Hourly Sales report and its PDF use the same RPC output, so the
timezone correction applies to both.
