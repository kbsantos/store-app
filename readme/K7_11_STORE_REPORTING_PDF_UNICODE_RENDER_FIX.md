# K7.11 Store Reporting PDF Unicode Render Fix

## Problem

The PDF reports were still rendering the Philippine peso sign (`₱`) as a missing-glyph box even though a Unicode font theme had been added.

## Fix

All Store Management PDF generators now use locally bundled DejaVu Sans regular/bold fonts through `StoreReportingPdfFont.theme()`.

The previous Noto Sans assets were removed from the PDF asset contract to avoid ambiguity between the font loaded by the application and the font expected by the PDF renderer.

DejaVu Sans contains the peso sign and the other punctuation used by the reports.

## Applies to

- Dashboard PDF
- Product Sales PDF
- Category Sales PDF
- Hourly Sales PDF
- Payment Summary PDF
- Sales Transactions PDF

The existing September 17, 2026 Hourly Sales timezone fix remains included in this codebase.
