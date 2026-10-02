import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reconciled category reporting views use catalog joins without security_invoker', () {
    final sql = File(
      'supabase/20260922_store_reporting_transaction_reconciliation_category_fix.sql',
    ).readAsStringSync();

    expect(sql, contains('create or replace view public.report_product_sales'));
    expect(sql, contains('create or replace view public.report_category_sales'));
    expect(sql, contains('public.catalog_products'));
    expect(sql, contains('public.catalog_categories'));
    expect(sql, contains('r.reconciled_item_total'));
    expect(sql, isNot(contains('with (security_invoker = true)')));
  });
}
