# Category Sales Review

The Store Dashboard Category Sales rows are now clickable.

Selecting a category opens a read-only drill-down showing:
- selected date range
- item count
- category sales
- dashboard sales total
- product-level quantity and sales

If the selected category total is greater than the dashboard sales total, the dialog displays a warning because that indicates a reporting-data mismatch rather than proof of actual sales.

For the September 17 screenshot, the displayed top five categories total more than the dashboard sales total, so the category report should be investigated. The drill-down is intended to identify which product rows are tagged with the category.


## Current implementation

The Store Dashboard Category Sales rows are clickable. Selecting a category opens a read-only drill-down with the selected date range, category item count, category sales, dashboard sales total, and product-level quantity and sales. A warning is shown when the selected category total exceeds the dashboard sales total.
