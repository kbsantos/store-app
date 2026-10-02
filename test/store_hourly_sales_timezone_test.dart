import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hourly sales groups transaction timestamps in Asia/Manila time', () {
    final sql = File(
      'supabase/20260922_store_hourly_sales_timezone_fix.sql',
    ).readAsStringSync();

    // The report must use the transaction event timestamp first and convert it
    // to the store-local timezone before both date filtering and hour grouping.
    expect(sql, contains("(to_jsonb(t)->>'transaction_date')::timestamptz"));
    expect(sql, contains("(to_jsonb(t)->>'created_at')::timestamptz"));
    expect(sql, contains("at time zone 'Asia/Manila'"));
    expect(sql, contains('n.local_event_time::date between p_start_date and p_end_date'));
    expect(sql, contains('extract(hour from f.local_event_time)::int'));

    // Keep the established financial and quantity authorities.
    expect(sql, contains('coalesce(sum(f.total), 0) as total_sales'));
    expect(sql, contains('coalesce(sum(ti.quantity), 0)::int as item_count'));
    expect(sql, contains("'transactionCount', coalesce(a.transaction_count, 0)"));
    expect(sql, contains("'itemCount', coalesce(a.item_count, 0)"));
    expect(sql, contains("'totalSales', coalesce(a.total_sales, 0)"));

    // Regression guard: do not filter/group the report using the raw UTC date
    // or raw timestamptz hour.
    expect(sql, isNot(contains("(to_jsonb(t)->>'transaction_date')::date")));
    expect(sql, isNot(contains("extract(hour from (f.event_time at time zone 'Asia/Manila'))")));
  });
}
