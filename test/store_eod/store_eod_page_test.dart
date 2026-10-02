import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EOD business-date formatting uses YYYY-MM-DD', () {
    final date = DateTime(2026, 9, 8);
    final value = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    expect(value, '2026-09-08');
  });
}
