import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sales Reporting Center Phase 5 drill-down actions are registered', () {
    final page = File('lib/features/reporting_api/sales_reporting_center_page.dart').readAsStringSync();
    expect(page.contains('onRowTap:'), isTrue);
    expect(page.contains('_drillIntoDaily'), isTrue);
    expect(page.contains('_drillIntoProduct'), isTrue);
    expect(page.contains('_drillIntoCategory'), isTrue);
    expect(page.contains('_drillIntoDevice'), isTrue);
    expect(page.contains("tooltip: 'View details'"), isTrue);
  });

  test('Sales Reporting Center Phase 5 keeps period-aware drill-down navigation', () {
    final page = File('lib/features/reporting_api/sales_reporting_center_page.dart').readAsStringSync();
    expect(page.contains("_reportKey = 'hourly'"), isTrue);
    expect(page.contains("_reportKey = 'product'"), isTrue);
    expect(page.contains("_category = category"), isTrue);
    expect(page.contains("_device = device"), isTrue);
  });
}
