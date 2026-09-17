import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/home/store_management_home_page.dart';
import 'login_page.dart';
import 'store_management_auth.dart';

class StoreManagementAuthGate extends StatelessWidget {
  const StoreManagementAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;
        if (session == null) return const StoreManagementLoginPage();
        final auth = const StoreManagementAuth();
        if (auth.storeId == null || auth.storeId!.isEmpty) {
          return const _MissingStoreAccessPage();
        }
        return const StoreManagementHomePage();
      },
    );
  }
}

class _MissingStoreAccessPage extends StatelessWidget {
  const _MissingStoreAccessPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(title: const Text('STORE MANAGEMENT')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.store_mall_directory_outlined, size: 64),
              const SizedBox(height: 14),
              const Text('STORE ACCESS NOT CONFIGURED', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Your Supabase user must have app_metadata.store_id assigned before this application can access store data.', textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(onPressed: () => const StoreManagementAuth().signOut(), child: const Text('SIGN OUT')),
            ]),
          ),
        ),
      ),
    );
  }
}
