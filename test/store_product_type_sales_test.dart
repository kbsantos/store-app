import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('product type sales migration exposes reconciled product type reporting', () {
    final sql = File('supabase/20261007_product_type_sales.sql')
        .readAsStringSync();

    expect(sql, contains('create or replace view public.report_product_type_sales'));
    expect(sql, contains('public.report_reconciled_transaction_items'));
    expect(sql, contains('cp.product_type'));
    expect(sql, contains('sum(r.reconciled_item_total) as total_sales'));
    expect(sql, contains('grant select on public.report_product_type_sales to authenticated'));
  });

  test('product type report uses customer-facing labels', () {
    final source = File(
      'lib/features/reporting_api/sales_reporting_center_page.dart',
    ).readAsStringSync();

    expect(source, contains('_productTypeLabel'));
    expect(source, contains("'Drink'"));
    expect(source, contains("'Food'"));
    expect(source, contains("'Accessory'"));
    expect(source, contains("'Add-on'"));
  });
}
