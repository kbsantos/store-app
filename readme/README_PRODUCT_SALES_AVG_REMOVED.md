# Product Sales — Average Price Removed

The Product Sales report no longer displays the calculated average price/amount.

Changed:
- Product Sales screen: removed the `AVG PRICE` column.
- Product Sales PDF: removed the `AVG PRICE` column.
- Product count, items sold, and total sales remain unchanged.
- Reporting API data still exposes its existing `average_unit_price` field for compatibility; it is simply not displayed by this report.
- Category Sales and other reports were not changed by this update.
