import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sales Summary does not expose the drill-down Details column', () {
    final page = File('lib/features/reporting_api/sales_reporting_center_page.dart').readAsStringSync();
    expect(page, contains("case 'summary':"));
    expect(page, contains('_summaryPreview()'));
    expect(page, isNot(contains('onRowTap:')));
    expect(page, isNot(contains('DETAILS')));
  });
}
