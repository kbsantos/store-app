import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_store_management/core/auth/store_management_permissions.dart';

void main() {
  test('owner has full management permissions and can assign every role', () {
    final p = StoreManagementPermissions.forRole('owner');
    expect(p.catalog, isTrue);
    expect(p.inventory, isTrue);
    expect(p.devices, isTrue);
    expect(p.storeProfile, isTrue);
    expect(p.operatingHours, isTrue);
    expect(p.databaseReset, isTrue);
    expect(p.users, isTrue);
    expect(p.completeEod, isTrue);
    expect(p.assignableRoles, ['staff', 'editor', 'manager', 'admin', 'owner']);
  });

  test('admin has operational administration but cannot reset database or assign admin/owner', () {
    final p = StoreManagementPermissions.forRole('admin');
    expect(p.catalog, isTrue);
    expect(p.inventory, isTrue);
    expect(p.devices, isTrue);
    expect(p.storeProfile, isTrue);
    expect(p.operatingHours, isTrue);
    expect(p.databaseReset, isFalse);
    expect(p.users, isTrue);
    expect(p.completeEod, isTrue);
    expect(p.assignableRoles, ['staff', 'editor', 'manager']);
  });

  test('manager can operate the store but cannot manage users or reset database', () {
    final p = StoreManagementPermissions.forRole('manager');
    expect(p.catalog, isTrue);
    expect(p.inventory, isTrue);
    expect(p.devices, isTrue);
    expect(p.completeEod, isTrue);
    expect(p.storeProfile, isFalse);
    expect(p.operatingHours, isFalse);
    expect(p.databaseReset, isFalse);
    expect(p.users, isFalse);
    expect(p.assignableRoles, ['staff', 'editor']);
  });

  test('editor can edit catalog but has no user or operational administration access', () {
    final p = StoreManagementPermissions.forRole('editor');
    expect(p.catalog, isTrue);
    expect(p.inventory, isFalse);
    expect(p.devices, isFalse);
    expect(p.storeProfile, isFalse);
    expect(p.operatingHours, isFalse);
    expect(p.databaseReset, isFalse);
    expect(p.users, isFalse);
    expect(p.completeEod, isFalse);
    expect(p.assignableRoles, isEmpty);
  });

  test('staff remains restricted to read access in management functions', () {
    final p = StoreManagementPermissions.forRole('staff');
    expect(p.catalog, isFalse);
    expect(p.inventory, isFalse);
    expect(p.devices, isFalse);
    expect(p.storeProfile, isFalse);
    expect(p.operatingHours, isFalse);
    expect(p.databaseReset, isFalse);
    expect(p.users, isFalse);
    expect(p.completeEod, isFalse);
    expect(p.assignableRoles, isEmpty);
  });
}
