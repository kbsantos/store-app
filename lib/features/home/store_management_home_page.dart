import 'package:flutter/material.dart';

import '../catalog/catalog_manager_dashboard.dart';
import 'store_dashboard_page.dart';
import '../sales/sales_management_page.dart';
import '../reporting_api/sales_reporting_center_page.dart';
import '../store/store_settings_page.dart';
import '../inventory/inventory_management_page.dart';
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
    final menu = _menuItems();
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
              storeName,
              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: .7),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        leading: MediaQuery.sizeOf(context).width < 900
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Open menu',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(_auth.role.toUpperCase()),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StoreSettingsPage()),
            ),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Store settings',
          ),
          IconButton(
            onPressed: () => _auth.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      drawer: MediaQuery.sizeOf(context).width < 900
          ? Drawer(child: _sideMenu(menu, closeAfterTap: true))
          : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (MediaQuery.sizeOf(context).width >= 900)
            SizedBox(width: 258, child: _sideMenu(menu)),
          Expanded(child: _welcomeContent()),
        ],
      ),
    );
  }

  List<_MenuItem> _menuItems() => [
        _MenuItem(Icons.dashboard_outlined, 'Dashboard', const StoreDashboardPage()),
        _MenuItem(Icons.inventory_2_outlined, 'Product', const CatalogManagerDashboardPage()),
        _MenuItem(Icons.point_of_sale_outlined, 'Sales', const SalesManagementPage()),
        _MenuItem(Icons.assessment_outlined, 'Reports', const SalesReportingCenterPage()),
        _MenuItem(Icons.inventory_2_outlined, 'Inventory', const InventoryManagementPage()),
      ];

  Widget _sideMenu(List<_MenuItem> items, {bool closeAfterTap = false}) {
    return Material(
      color: const Color(0xFF21170F),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 18, 20),
              child: FutureBuilder<String>(
                future: _storeNameFuture,
                builder: (context, snapshot) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.storefront_outlined, color: Color(0xFFC69214), size: 34),
                    const SizedBox(height: 10),
                    const Text('BIGGER BREW', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    Text(snapshot.data ?? 'STORE MANAGEMENT', style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .8), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (closeAfterTap) Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => item.page));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                      child: Row(
                        children: [
                          Icon(item.icon, color: Colors.white70, size: 21),
                          const SizedBox(width: 14),
                          Expanded(child: Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                          const Icon(Icons.chevron_right, color: Colors.white38, size: 19),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 18, 20),
              child: Text('Store ${_auth.storeId}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomeContent() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront_outlined, size: 78, color: Color(0xFFC69214)),
              const SizedBox(height: 18),
              const Text(
                'Store Management',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: .5),
              ),
              const SizedBox(height: 8),
              const Text('Use the menu on the left to manage your store, products, sales and operations.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 16, height: 1.4)),
              const SizedBox(height: 26),
              FutureBuilder<String>(
                future: _storeNameFuture,
                builder: (context, snapshot) => Text(snapshot.data ?? 'MyCoffeeShop', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final Widget page;

  const _MenuItem(this.icon, this.title, this.page);
}
