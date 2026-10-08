import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sales Reporting Center exposes no drill-down or Details actions', () {
    final page = File('lib/features/reporting_api/sales_reporting_center_page.dart').readAsStringSync();
    expect(page.contains('onRowTap:'), isFalse);
    expect(page.contains('_drillIntoDaily'), isFalse);
    expect(page.contains('_drillIntoProduct'), isFalse);
    expect(page.contains('_drillIntoCategory'), isFalse);
    expect(page.contains('_drillIntoDevice'), isFalse);
    expect(page.contains("tooltip: 'View details'"), isFalse);
    expect(page.contains("DataColumn(label: Text('DETAILS'))"), isFalse);
  });

  test('Sales Reporting Center keeps all report tables read-only', () {
    final page = File('lib/features/reporting_api/sales_reporting_center_page.dart').readAsStringSync();
    expect(page.contains('Widget _dataTable(List<String> headers, List<List<String>> rows)'), isTrue);
    expect(page.contains('DataCell(Text(value))'), isTrue);
  });
}
