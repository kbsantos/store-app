# Reporting UI Overflow Fix

## Product Sales / Category Sales / Sales Reporting

Fixed the reporting filter row overflow caused by long kiosk/device UUID values.

### Changes
- Kiosk/device dropdowns are now `isExpanded` so the selected value stays within the field.
- Long kiosk/device IDs are displayed with a single-line ellipsis instead of overflowing.
- Product Sales Kiosk filter width increased to 260px for better readability.
- Category Sales Kiosk filter width increased to 260px.
- Sales Reporting dashboard category and kiosk filters are constrained and ellipsized.
- Existing PDF buttons and reporting calculations are unchanged.

This prevents the Flutter `RIGHT OVERFLOWED BY ... PIXELS` error visible on narrow/landscape reporting screens.
