# Product Type Sales Report

## Overview

Adds Product Type Sales to Store Management Sales Reporting.

The report uses `catalog_products.product_type` as the current Product Type source and
`report_reconciled_transaction_items` as the transaction-authoritative sales source.

## UI

Sales Management now includes **Product Type Sales**.

The report supports:
- date range
- kiosk filter
- quantity sold
- total sales
- percentage of sales
- PDF report preview

## Supabase migration

Apply:

`supabase/20261007_product_type_sales.sql`

after the existing transaction-reconciliation reporting migrations.

No transaction data is modified by this migration.
