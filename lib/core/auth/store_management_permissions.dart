import 'store_management_auth.dart';

/// Centralized Store Management role permissions.
///
/// These helpers define the UI capability matrix. Supabase RLS/RPC
/// authorization remains the authoritative security boundary.
class StoreManagementPermissions {
  const StoreManagementPermissions(this.auth);

  final StoreManagementAuth auth;

  bool get canViewStoreManagement => auth.isSignedIn;
  bool get canManageCatalog => forRole(auth.role).catalog;
  bool get canManageInventory => forRole(auth.role).inventory;
  bool get canManageDevices => forRole(auth.role).devices;
  bool get canManageStoreProfile => forRole(auth.role).storeProfile;
  bool get canManageOperatingHours => forRole(auth.role).operatingHours;
  bool get canResetDatabase => forRole(auth.role).databaseReset;
  bool get canManageUsers => forRole(auth.role).users;
  bool get canCompleteEod => forRole(auth.role).completeEod;

  bool canManageFunction(String function) {
    switch (function) {
      case 'catalog':
        return canManageCatalog;
      case 'inventory':
      case 'recipes':
        return canManageInventory;
      case 'eod':
        return canCompleteEod;
      case 'devices':
        return canManageDevices;
      case 'store_profile':
        return canManageStoreProfile;
      case 'operating_hours':
        return canManageOperatingHours;
      case 'database_reset':
        return canResetDatabase;
      case 'users':
        return canManageUsers;
      default:
        return false;
    }
  }

  /// Pure role mapping used by UI code and unit tests without requiring a
  /// live Supabase session.
  static StoreManagementRolePermissions forRole(String role) {
    switch (role.trim().toLowerCase()) {
      case 'owner':
        return const StoreManagementRolePermissions.all();
      case 'admin':
        return const StoreManagementRolePermissions.all();
      case 'manager':
        return const StoreManagementRolePermissions.manager();
      case 'editor':
        return const StoreManagementRolePermissions.editor();
      case 'staff':
      default:
        return const StoreManagementRolePermissions.staff();
    }
  }
}

class StoreManagementRolePermissions {
  const StoreManagementRolePermissions({
    required this.catalog,
    required this.inventory,
    required this.devices,
    required this.storeProfile,
    required this.operatingHours,
    required this.databaseReset,
    required this.users,
    required this.completeEod,
  });

  const StoreManagementRolePermissions.all()
      : catalog = true,
        inventory = true,
        devices = true,
        storeProfile = true,
        operatingHours = true,
        databaseReset = true,
        users = true,
        completeEod = true;

  const StoreManagementRolePermissions.manager()
      : catalog = true,
        inventory = true,
        devices = true,
        storeProfile = false,
        operatingHours = false,
        databaseReset = false,
        users = false,
        completeEod = true;

  const StoreManagementRolePermissions.editor()
      : catalog = false,
        inventory = false,
        devices = false,
        storeProfile = false,
        operatingHours = false,
        databaseReset = false,
        users = false,
        completeEod = false;

  const StoreManagementRolePermissions.staff()
      : catalog = false,
        inventory = false,
        devices = false,
        storeProfile = false,
        operatingHours = false,
        databaseReset = false,
        users = false,
        completeEod = false;

  final bool catalog;
  final bool inventory;
  final bool devices;
  final bool storeProfile;
  final bool operatingHours;
  final bool databaseReset;
  final bool users;
  final bool completeEod;
}
