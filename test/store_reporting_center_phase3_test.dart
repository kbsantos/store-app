import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sales Reporting Center Phase 3 contracts', () {
    final root = Directory.current.path;

    test('Phase 3 migration defines discounts, charges and EOD range RPCs', () {
      final sql = File(
        '$root/supabase/20261007_sales_reporting_center_phase3.sql',
      ).readAsStringSync();

      expect(sql, contains('get_store_discounts_charges'));
      expect(sql, contains('get_store_eod_reporting'));
      expect(sql, contains('get_store_eod_summary'));
      expect(sql, contains("grant execute on function public.get_store_discounts_charges"));
      expect(sql, contains("grant execute on function public.get_store_eod_reporting"));
    });

    test('Reporting Center exposes Discounts & Charges but not End of Day', () {
      final page = File(
        '$root/lib/features/reporting_api/sales_reporting_center_page.dart',
      ).readAsStringSync();

      expect(page, contains("_ReportOption('discounts'"));
      expect(page, isNot(contains("_ReportOption('eod'")));
      expect(page, contains("case 'discounts'"));
      expect(page, isNot(contains("case 'eod'")));
    });
  });
}
