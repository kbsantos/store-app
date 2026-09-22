import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hourly sales RPC uses item quantity and transaction total authority', () {
    final sql = File(
      'supabase/20260922_store_hourly_sales_quantity_fix.sql',
    ).readAsStringSync();

    expect(sql, contains('sum(ti.quantity)::int'));
    expect(sql, contains('coalesce(sum(f.total), 0) as total_sales'));
    expect(sql, contains("'totalSales', coalesce(a.total_sales, 0)"));
    expect(sql, contains("count(*)::int as transaction_count"));
    expect(sql, contains('item_totals as ('));
    expect(sql, contains('coalesce(sum(it.item_count), 0)::int as item_count'));
    expect(sql, contains('left join item_totals it on it.transaction_id = f.id'));

    // Regression guard: item count must not be derived from row count or a
    // correlated aggregate inside the grouped hourly query.
    expect(
      sql,
      isNot(contains(
        'sum((select count(*) from public.transaction_items ti where ti.transaction_id=f.id))',
      )),
    );
  });
}

