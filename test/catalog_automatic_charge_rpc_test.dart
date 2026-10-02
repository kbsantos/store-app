import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('automatic charges migration persists and exposes charges', () {
    final sql = File('supabase/20260920_automatic_charges.sql').readAsStringSync();
    expect(sql, contains('create table if not exists public.catalog_automatic_charges'));
    expect(sql, contains("'automaticCharges'"));
    expect(sql, contains("public.catalog_automatic_charges ac"));
    expect(sql, contains("'chargeId', ac.charge_id"));
    expect(sql, contains("'categoryIds', ac.category_ids"));
    expect(sql, contains('auto_apply'));
  });
}
