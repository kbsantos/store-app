import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Discounts & Charges falls back when the Phase 3 RPC is not installed', () {
    final service = File('lib/features/reporting_api/reporting_api_service.dart').readAsStringSync();
    expect(service, contains("'get_store_discounts_charges'"));
    expect(service, contains("error.code != 'PGRST202'"));
    expect(service, contains('final daily = await getDailySales('));
    expect(service, contains("'charges': 0"));
  });
}
