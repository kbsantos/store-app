import 'package:supabase_flutter/supabase_flutter.dart';

class StoreManagementAuth {
  const StoreManagementAuth();

  SupabaseClient get client => Supabase.instance.client;
  Session? get session => client.auth.currentSession;
  User? get user => client.auth.currentUser;

  String? get storeId => user?.appMetadata['store_id']?.toString().trim();
  String get role => user?.appMetadata['role']?.toString().trim().toLowerCase() ?? 'staff';

  bool get isSignedIn => session != null;
  bool get canManageCatalog => role == 'owner' || role == 'manager' || role == 'admin';

  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<void> signOut() => client.auth.signOut();
}
