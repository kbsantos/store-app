import 'package:flutter_test/flutter_test.dart';

import '../lib/core/currency/store_currency.dart';

void main() {
  test('formats monetary values with thousands separators', () {
    expect(StoreCurrency.format(0), '₱0.00');
    expect(StoreCurrency.format(999), '₱999.00');
    expect(StoreCurrency.format(1000), '₱1,000.00');
    expect(StoreCurrency.format(12500.5), '₱12,500.50');
    expect(StoreCurrency.format(1234567.89), '₱1,234,567.89');
    expect(StoreCurrency.format(-1234567.89), '₱-1,234,567.89');
  });
}
