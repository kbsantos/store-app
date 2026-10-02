import 'package:supabase_flutter/supabase_flutter.dart';

import 'store_management_permissions.dart';

class StoreManagementAuth {
  const StoreManagementAuth();

  SupabaseClient get client => Supabase.instance.client;
  Session? get session => client.auth.currentSession;
  User? get user => client.auth.currentUser;

  String? get storeId => user?.appMetadata['store_id']?.toString().trim();
  String get role => user?.appMetadata['role']?.toString().trim().toLowerCase() ?? 'staff';

  bool get isSignedIn => session != null;
  bool get canManageCatalog => StoreManagementPermissions.forRole(role).catalog;
  bool get canManageInventory => StoreManagementPermissions.forRole(role).inventory;
  bool get canManageDevices => StoreManagementPermissions.forRole(role).devices;
  bool get canManageStoreProfile => StoreManagementPermissions.forRole(role).storeProfile;
  bool get canManageOperatingHours => StoreManagementPermissions.forRole(role).operatingHours;
  bool get canResetDatabase => StoreManagementPermissions.forRole(role).databaseReset;
  bool get canManageUsers => StoreManagementPermissions.forRole(role).users;
  bool get canCompleteEod => StoreManagementPermissions.forRole(role).completeEod;

  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Sends Supabase's password recovery email to an already-linked employee.
  /// The Store Management app never creates or stores employee passwords.
  Future<void> sendPasswordSetupEmail(String email) async {
    await client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> signOut() => client.auth.signOut();
}
