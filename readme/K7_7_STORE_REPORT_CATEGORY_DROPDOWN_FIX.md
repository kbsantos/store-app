# K7.7 Store Reporting — Category Dropdown Fix

## Problem

After transaction-authoritative reconciliation was applied, the Sales Reporting
page showed only `Uncategorized` in the category dropdown.

## Root cause

`report_product_sales` and `report_category_sales` were created with
`security_invoker = true`. Their joins to `catalog_products` and
`catalog_categories` were therefore evaluated under the authenticated reporting
user's RLS context. The catalog join returned no category rows and the report's
`coalesce(...)` converted them to `Uncategorized`.

## Fix

`20260922_store_reporting_transaction_reconciliation_category_fix.sql`
recreates both report views without `security_invoker`, while retaining explicit
store-scoped joins and the reconciled transaction-item sales amounts.

This does not modify `transactions` or `transaction_items`.

## Expected result

For September 17, 2026 the Sales Reporting category dropdown should contain the
actual categories represented by the current catalog (plus `ALL CATEGORIES`),
rather than only `Uncategorized`.

The total sales must remain:

- Dashboard / transactions: ₱14,226.00
- Product Sales: ₱14,226.00
- Category Sales: ₱14,226.00
