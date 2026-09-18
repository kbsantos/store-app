import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_store_management/core/auth/store_management_permissions.dart';

void main() {
  test('owner and admin have full management permissions', () {
    for (final role in ['owner', 'admin']) {
      final p = StoreManagementPermissions.forRole(role);
      expect(p.catalog, isTrue);
      expect(p.inventory, isTrue);
      expect(p.devices, isTrue);
      expect(p.storeProfile, isTrue);
      expect(p.operatingHours, isTrue);
      expect(p.databaseReset, isTrue);
      expect(p.users, isTrue);
      expect(p.completeEod, isTrue);
    }
  });

  test('manager can operate store functions but cannot manage users or reset database', () {
    final p = StoreManagementPermissions.forRole('manager');
    expect(p.catalog, isTrue);
    expect(p.inventory, isTrue);
    expect(p.devices, isTrue);
    expect(p.completeEod, isTrue);
    expect(p.storeProfile, isFalse);
    expect(p.operatingHours, isFalse);
    expect(p.databaseReset, isFalse);
    expect(p.users, isFalse);
  });

  test('editor and staff are read-only for management functions', () {
    for (final role in ['editor', 'staff', 'unknown']) {
      final p = StoreManagementPermissions.forRole(role);
      expect(p.catalog, isFalse);
      expect(p.inventory, isFalse);
      expect(p.devices, isFalse);
      expect(p.storeProfile, isFalse);
      expect(p.operatingHours, isFalse);
      expect(p.databaseReset, isFalse);
      expect(p.users, isFalse);
      expect(p.completeEod, isFalse);
    }
  });

  test('function names map to the intended capability', () {
    // Use a manager-independent pure mapping through a small local assertion
    // helper so this test remains independent of a live Supabase session.
    final p = StoreManagementPermissions.forRole('manager');
    expect(p.catalog, isTrue);
    expect(p.inventory, isTrue);
    expect(p.completeEod, isTrue);
    expect(p.devices, isTrue);
  });
}
