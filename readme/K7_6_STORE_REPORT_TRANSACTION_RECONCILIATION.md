# K7.6 Store Report Transaction Reconciliation

## Purpose

The Store Dashboard's financial sales total is authoritative at the transaction
level (`transactions.total`). Product Sales and Category Sales previously summed
`transaction_items.total` directly, which could make a breakdown disagree with
the dashboard when an item row was stale, corrupted, or affected by a
transaction-level adjustment.

## Change

`20260922_store_reporting_transaction_reconciliation.sql` introduces:

- `report_reconciled_transaction_items`
- transaction-authoritative Product Sales
- transaction-authoritative Category Sales

Product/category identity and quantity still come from `transaction_items`.
The sales amount is reconciled per transaction:

- matching item totals remain unchanged;
- mismatched item totals are proportionally allocated to the recorded item
  amounts so the allocation equals `transactions.total`;
- zero item-total anomalies are allocated evenly across the transaction's
  item rows.

This means the Product Sales and Category Sales totals reconcile to the same
transaction-level sales used by the Store Dashboard.

## September 17, 2026 validation target

Use September 17, 2026 as the first validation date because the dashboard was
already verified against transaction-level sales.

Recommended checks after applying the migration:

```sql
select
  sum(total_sales) as product_sales
from public.report_product_sales
where sales_date = date '2026-09-17';

select
  sum(total_sales) as category_sales
from public.report_category_sales
where sales_date = date '2026-09-17';

select
  sum(total_sales) as transaction_sales
from public.report_daily_sales
where sales_date = date '2026-09-17';
```

The three totals should match within the report tolerance.

The existing reporting-integrity RPC can also be used:

```sql
select public.get_store_reporting_integrity(
  date '2026-09-17',
  date '2026-09-17'
);
```

No deployed migration should be edited or deleted; this is an additive
follow-up migration.
