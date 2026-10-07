# Bigger Brew Sales Reporting Center — Phase 1

## Scope

Phase 1 establishes the centralized Sales Reporting Center without removing or breaking the existing Sales Management report pages.

### Included
- Central **Reporting Center** entry in Sales Management.
- Period presets: Today, Yesterday, This Week, This Month.
- Custom From/To date selection.
- Central report selector for:
  - Sales Summary
  - Daily Sales
  - Hourly Sales
  - Product Sales
  - Product Type Sales
  - Category Sales
  - Payment Summary
  - Sales by Device
  - Discounts & Charges
  - Transaction Report
  - End of Day
- Dynamic kiosk filter where supported by the existing reporting API.
- Unified preview area for Sales Summary, Daily Sales, Product Sales, Product Type Sales, Category Sales, and Sales by Device.
- PDF export wired for Product Sales, Product Type Sales, and Category Sales using existing PDF services.
- Excel, CSV, and Print controls established as Phase 2 actions; no new dependency was added in Phase 1.
- Existing individual report pages remain available to avoid regressions.

## Data behavior

The center reuses existing reporting API methods and reporting views. It does not introduce a new reporting SQL migration and does not modify the live database.

## Next phase

Phase 2 can move the remaining report types into the shared preview/export pipeline and implement Excel, CSV, and print output from the same normalized report dataset.
