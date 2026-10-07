import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
test('Sales Reporting Center Phase 4 filters are registered', () {
  final page = File('lib/features/reporting_api/sales_reporting_center_page.dart').readAsStringSync();
  expect(page.contains("_reportKey == 'product'"), isTrue);
  expect(page.contains("label: 'Category'"), isTrue);
  expect(page.contains("_reportKey == 'transactions'"), isTrue);
  expect(page.contains("labelText: 'Search transaction'"), isTrue);
  expect(page.contains("label: 'Status'"), isTrue);
});

test('Reporting API forwards transaction search and status filters', () {
  final api = File('lib/features/reporting_api/reporting_api_service.dart').readAsStringSync();
  expect(api.contains('String? search'), isTrue);
  expect(api.contains('String? status'), isTrue);
  expect(api.contains("'p_search': search"), isTrue);
  expect(api.contains("'p_status': status"), isTrue);
});
}
