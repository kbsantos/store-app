import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sales exposes End of Day and Inventory does not', () {
    final inventory =
        File('lib/features/inventory/inventory_management_page.dart').readAsStringSync();
    final sales =
        File('lib/features/sales/sales_management_page.dart').readAsStringSync();

    expect(
      sales.contains("'End of Day'") && sales.contains('const StoreEodPage()'),
      isTrue,
    );
    expect(sales.contains('Transactions'), isTrue);
    expect(inventory.contains("'End of Day'"), isFalse);
    expect(inventory.contains('StoreEodPage'), isFalse);
  });
}
