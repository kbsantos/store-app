# K7.10 Store Reporting PDF Unicode Fix

All Store Management PDF generators now use the same bundled Noto Sans Unicode font theme.

## Covered PDFs

- Store Dashboard PDF
- Product Sales PDF
- Category Sales PDF
- Hourly Sales PDF
- Payment Summary PDF
- Sales Transactions PDF

This prevents missing-glyph boxes for the Philippine peso sign (`₱`), bullet separators (`•`), and other Unicode characters. The fonts are bundled locally, so PDF generation does not depend on network font loading.
