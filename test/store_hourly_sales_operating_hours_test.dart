import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hourly sales removes operating-hours filtering and suppresses zero-sales hours', () {
    final page = File(
      'lib/features/reporting_api/hourly_sales_page.dart',
    ).readAsStringSync();
    final service = File(
      'lib/features/reporting_api/reporting_api_service.dart',
    ).readAsStringSync();

    expect(page, isNot(contains('get_store_management_operating_hours')));
    expect(page, isNot(contains('_visibleOperatingHours')));
    expect(page, contains('.where((row) => row.totalSales > 0)'));
    expect(service, contains('.where((row) => row.totalSales > 0)'));
  });
}
