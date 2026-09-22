import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Product Sales report does not include average price column', () {
    final source = File('lib/features/reporting_api/product_sales_page.dart').readAsStringSync();
    final pdfSource = File('lib/features/reporting_api/reporting_pdf_service.dart').readAsStringSync();

    expect(source, isNot(contains("Text('AVG PRICE')")));
    expect(pdfSource, isNot(contains("'AVG PRICE'")));
    expect(pdfSource, isNot(contains('row.sales / row.quantity')));
  });
}
