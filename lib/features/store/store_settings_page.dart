import 'package:flutter/material.dart';

import '../../core/auth/store_management_auth.dart';
import '../../core/auth/store_management_permissions.dart';
import 'store_database_reset_page.dart';
import 'store_profile_page.dart';
import 'store_operating_hours_page.dart';

class StoreSettingsPage extends StatelessWidget {
  const StoreSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = const StoreManagementAuth();
    final permissions = StoreManagementPermissions(auth);
    final canReset = permissions.canResetDatabase;
    final canEditHours = permissions.canManageOperatingHours;

    return Scaffold(
      appBar: AppBar(title: const Text('STORE SETTINGS')),
      backgroundColor: const Color(0xFFF5F2ED),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'STORE SETTINGS',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text('Store ${auth.storeId}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 28),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
              title: const Text(
                'Store Profile',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'View and manage the store name, brand, location and status.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StoreProfilePage(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.schedule_outlined)),
              title: const Text(
                'Operating Hours',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                canEditHours
                    ? 'Set the weekly opening and closing schedule for the store.'
                    : 'View the weekly opening and closing schedule.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const StoreOperatingHoursPage(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.storage_outlined)),
              title: const Text(
                'Data Management',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                canReset
                    ? 'Manage store operational data and database reset.'
                    : 'Database reset is restricted to owner and admin accounts.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: canReset
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StoreDatabaseResetPage(),
                        ),
                      )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
