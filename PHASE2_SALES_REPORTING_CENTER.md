# Bigger Brew Sales Reporting Center — Phase 2

## Implemented

- Connected Hourly Sales, Payment Summary, and Transaction Report to the central Reporting Center preview.
- Added one normalized table model used by the screen and exports.
- Added real CSV export.
- Added Excel-compatible `.xls` export using an HTML workbook so no new Excel dependency is required.
- Added PDF export for every report with a preview table.
- Added system print support for every report with a preview table.
- Added consistent generated filenames: `BiggerBrew_<Report>_<Start>_<End>.<ext>`.
- Existing specialized PDF/report pages and Supabase reporting views remain unchanged.
- End of Day remains staged because its existing workflow is operational/reconciliation-specific and should not be duplicated until its data contract is defined for the central reporting engine.

## Data source

The Reporting Center continues to use the existing Supabase reporting views/RPCs. No new database migration is required for Phase 2.

## Export formats

- PDF: generated from the same report table data used by the preview.
- CSV: UTF-8 CSV generated from the same table data.
- Excel: Excel-compatible HTML workbook saved with `.xls` extension; Excel can open it directly.
- Print: system print dialog generated from the same table data.

## Live database

No live database changes were made.
