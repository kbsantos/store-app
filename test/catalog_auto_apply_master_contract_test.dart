import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('master catalog read migration exposes autoApply', () {
    final sql = File(
      'supabase/20260920_product_option_auto_apply_master_read.sql',
    ).readAsStringSync();

    expect(sql, contains("'autoApply', x.auto_apply"));
    expect(sql, contains('add column if not exists auto_apply'));
  });
}
