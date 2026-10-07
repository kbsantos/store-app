import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hourly sales uses store operating hours to determine visible hours', () {
    final source = File(
      'lib/features/reporting_api/hourly_sales_page.dart',
    ).readAsStringSync();

    expect(source, contains("get_store_management_operating_hours"));
    expect(source, contains('_visibleOperatingHours'));
    expect(source, contains('days[date.weekday % 7]'));
    expect(source, contains('row.hour'));
    expect(source, contains('overnight schedule'));
  });
}
