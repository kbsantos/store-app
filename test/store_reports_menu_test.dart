import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Reports menu owns the Sales Reporting Center', () {
    final home = File('lib/features/home/store_management_home_page.dart').readAsStringSync();
    final sales = File('lib/features/sales/sales_management_page.dart').readAsStringSync();
    final inventory = File('lib/features/inventory/inventory_management_page.dart').readAsStringSync();

    expect(home.contains("'Reports', const SalesReportingCenterPage()"), isTrue);
    expect(sales.contains("'Reporting Center'"), isFalse);
    expect(sales.contains('SalesReportingCenterPage'), isFalse);
    expect(sales.contains("'Transactions'"), isTrue);
    expect(sales.contains("'End of Day'"), isTrue);
    expect(inventory.contains("_action('End of Day'"), isFalse);
  });
}
