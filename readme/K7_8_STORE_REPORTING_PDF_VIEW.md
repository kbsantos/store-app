# K7.8 Store Reporting PDF View

Added dashboard-style PDF preview/download actions to all Store Management reporting pages:

- Product Sales
- Category Sales
- Hourly Sales
- Payment Summary
- Sales Transactions
- Store Dashboard already had PDF preview and remains unchanged

Each PDF uses the currently loaded report rows and the selected date/filter values. The preview supports printing, sharing, and browser download using the same `PdfPreview` interaction pattern as the Store Dashboard.

The reporting PDF service is shared at `lib/features/reporting_api/reporting_pdf_service.dart`, while `reporting_pdf_viewer.dart` centralizes the preview/download UI.
