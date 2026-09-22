import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migration =
      'supabase/20260922_store_reporting_transaction_reconciliation.sql';

  test('reporting uses transaction-authoritative reconciliation', () {
    final sql = File(migration).readAsStringSync();

    expect(sql, contains('report_reconciled_transaction_items'));
    expect(sql, contains('transaction_total'));
    expect(sql, contains('recorded_transaction_item_total'));
    expect(sql, contains('reconciled_item_total'));
    expect(sql, contains('abs(recorded_transaction_item_total - transaction_total) <= 0.01'));
    expect(sql, contains('recorded_item_total * transaction_total'));
    expect(sql, contains('transaction_total / transaction_item_count'));
    expect(sql, contains('create or replace view public.report_product_sales'));
    expect(sql, contains('create or replace view public.report_category_sales'));
  });

  test('product and category reports consume reconciled item sales', () {
    final sql = File(migration).readAsStringSync();

    final productStart = sql.indexOf(
      'create or replace view public.report_product_sales',
    );
    final categoryStart = sql.indexOf(
      'create or replace view public.report_category_sales',
    );

    expect(productStart, greaterThanOrEqualTo(0));
    expect(categoryStart, greaterThan(productStart));

    final productSql = sql.substring(productStart, categoryStart);
    final categorySql = sql.substring(categoryStart);

    expect(productSql, contains('sum(r.reconciled_item_total) as total_sales'));
    expect(categorySql, contains('sum(r.reconciled_item_total) as total_sales'));
    expect(productSql, isNot(contains('sum(r.recorded_item_total) as total_sales')));
    expect(categorySql, isNot(contains('sum(r.recorded_item_total) as total_sales')));
  });
}
