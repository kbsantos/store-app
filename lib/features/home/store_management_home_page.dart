import 'package:flutter/material.dart';

import '../catalog/catalog_manager_dashboard.dart';
import '../sales/sales_management_page.dart';
import '../store/store_settings_page.dart';
import '../inventory/inventory_management_page.dart';
import '../recipes/recipes_management_page.dart';
import '../store_eod_page.dart';
import '../devices/devices_management_page.dart';
import '../users/users_management_page.dart';
import '../../core/auth/store_management_auth.dart';

class StoreManagementHomePage extends StatefulWidget {
  const StoreManagementHomePage({super.key});

  @override
  State<StoreManagementHomePage> createState() => _StoreManagementHomePageState();
}

class _StoreManagementHomePageState extends State<StoreManagementHomePage> {
  final _auth = const StoreManagementAuth();
  late Future<String> _storeNameFuture;

  @override
  void initState() {
    super.initState();
    _storeNameFuture = _loadStoreName();
  }

  Future<String> _loadStoreName() async {
    try {
      final result = await _auth.client.rpc('get_store_management_profile');
      final profile = Map<String, dynamic>.from(result as Map);
      final name = profile['name']?.toString().trim() ?? '';
      return name.isEmpty ? 'MyCoffeeShop' : name;
    } catch (_) {
      return 'MyCoffeeShop';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: FutureBuilder<String>(
          future: _storeNameFuture,
          builder: (context, snapshot) {
            final storeName = snapshot.data ?? 'MyCoffeeShop';
            return Text(
              '$storeName - Store Management',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(_auth.role.toUpperCase()),
            ),
          ),
          IconButton(
            onPressed: () => _auth.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000
              ? 3
              : constraints.maxWidth >= 650
              ? 2
              : 1;
          final width =
              (constraints.maxWidth - (columns - 1) * 16 - 48) / columns;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 12),
              const Icon(
                Icons.storefront_outlined,
                size: 68,
                color: Color(0xFFC69214),
              ),
              const SizedBox(height: 8),
              const Text(
                'STORE MANAGEMENT',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Store ${_auth.storeId}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: width,
                    child: _tile(
                      context,
                      Icons.inventory_2_outlined,
                      'PRODUCT CATALOG',
                      'Manage categories, products, sizes, variants and add-ons.',
                      const CatalogManagerDashboardPage(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _tile(
                      context,
                      Icons.point_of_sale_outlined,
                      'SALES',
                      'Manage sales reporting, transactions and hourly sales.',
                      const SalesManagementPage(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _tile(
                      context,
                      Icons.store_outlined,
                      'STORE & KIOSKS',
                      'Open store settings, data management and device administration.',
                      const StoreSettingsPage(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _tile(
                      context,
                      Icons.inventory_2_outlined,
                      'INVENTORY',
                      'Manage inventory items, stock, receiving, consumption and movements.',
                      const InventoryManagementPage(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _tile(
                      context,
                      Icons.menu_book_outlined,
                      'RECIPES',
                      'Manage product recipes and ingredient usage definitions.',
                      const RecipesManagementPage(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _tile(
                      context,
                      Icons.event_available_outlined,
                      'END OF DAY',
                      'Review sales, payments and inventory consumption, then close the business date.',
                      const StoreEodPage(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _tile(
                      context,
                      Icons.devices_other_outlined,
                      'DEVICES',
                      'Manage store kiosks and registered printers.',
                      const DevicesManagementPage(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _tile(
                      context,
                      Icons.people_outline,
                      'USERS',
                      'Manage employees, roles and store permissions.',
                      const UsersManagementPage(),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget? page,
  ) {
    return Card(
      child: InkWell(
        onTap: page == null
            ? null
            : () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => page)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF171717),
                foregroundColor: Colors.white,
                radius: 26,
                child: Icon(icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (page != null) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
