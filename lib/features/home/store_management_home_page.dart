import 'package:flutter/material.dart';
import '../catalog/catalog_manager_dashboard.dart';
import '../reporting_api/reporting_dashboard_page.dart';
import '../../core/auth/store_management_auth.dart';

class StoreManagementHomePage extends StatelessWidget {
  const StoreManagementHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = const StoreManagementAuth();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text('BIGGER BREW STORE MANAGEMENT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .7)),
        actions: [
          Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(auth.role.toUpperCase()))),
          IconButton(onPressed: () => auth.signOut(), icon: const Icon(Icons.logout), tooltip: 'Sign out'),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000 ? 3 : constraints.maxWidth >= 650 ? 2 : 1;
          final width = (constraints.maxWidth - (columns - 1) * 16 - 48) / columns;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 12),
              const Icon(Icons.storefront_outlined, size: 68, color: Color(0xFFC69214)),
              const SizedBox(height: 8),
              const Text('STORE MANAGEMENT', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('Store ${auth.storeId}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 28),
              Wrap(spacing: 16, runSpacing: 16, children: [
                SizedBox(width: width, child: _tile(context, Icons.inventory_2_outlined, 'PRODUCT CATALOG', 'Manage categories, products, sizes, variants and add-ons.', const CatalogManagerDashboardPage())),
                SizedBox(width: width, child: _tile(context, Icons.bar_chart_outlined, 'SALES REPORTING', 'Review sales by date, category, product and kiosk.', const ReportingDashboardPage())),
                SizedBox(width: width, child: _tile(context, Icons.store_outlined, 'STORE & KIOSKS', 'Reserved for store and device administration.', null)),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, Widget? page) {
    return Card(
      child: InkWell(
        onTap: page == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(padding: const EdgeInsets.all(22), child: Row(children: [
          CircleAvatar(backgroundColor: const Color(0xFF171717), foregroundColor: Colors.white, radius: 26, child: Icon(icon)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(color: Colors.black54, height: 1.25)),
          ])),
          if (page != null) const Icon(Icons.chevron_right),
        ])),
      ),
    );
  }
}
