import 'package:flutter/material.dart';

import 'inventory_adjustments_page.dart';
import 'inventory_consumption_page.dart';
import 'inventory_items_page.dart';
import 'inventory_low_stock_page.dart';
import 'inventory_movements_page.dart';
import 'inventory_receiving_page.dart';
import 'inventory_stock_levels_page.dart';
import 'inventory_wastage_page.dart';

class InventoryManagementPage extends StatelessWidget {
  const InventoryManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = <_InventorySection>[
      _InventorySection(
        Icons.inventory_2_outlined,
        'INVENTORY ITEMS',
        'Manage ingredients, packaging and reorder levels.',
        const InventoryItemsPage(),
      ),
      _InventorySection(
        Icons.stacked_bar_chart_outlined,
        'STOCK LEVELS',
        'View current stock quantities and stock status.',
        const InventoryStockLevelsPage(),
      ),
      _InventorySection(
        Icons.warning_amber_outlined,
        'LOW STOCK',
        'See items at or below their reorder levels.',
        const InventoryLowStockPage(),
      ),
      _InventorySection(
        Icons.local_shipping_outlined,
        'RECEIVING',
        'Receive stock and record stock-in movements.',
        const InventoryReceivingPage(),
      ),
      _InventorySection(
        Icons.tune_outlined,
        'STOCK ADJUSTMENTS',
        'Record physical counts and correct inventory variances.',
        const InventoryAdjustmentsPage(),
      ),
      _InventorySection(
        Icons.delete_sweep_outlined,
        'WASTAGE',
        'Record damaged, expired, spilled or unusable stock.',
        const InventoryWastagePage(),
      ),
      _InventorySection(
        Icons.remove_circle_outline,
        'INVENTORY CONSUMPTION',
        'Apply product recipes to completed sales and record usage.',
        const InventoryConsumptionPage(),
      ),
      _InventorySection(
        Icons.receipt_long_outlined,
        'INVENTORY MOVEMENTS',
        'Review the complete inventory movement audit trail.',
        const InventoryMovementsPage(),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text(
          'INVENTORY MANAGEMENT',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
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
              const SizedBox(height: 8),
              const Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: Color(0xFFC69214),
              ),
              const SizedBox(height: 8),
              const Text(
                'INVENTORY',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Manage stock, receiving, recipes, consumption and inventory activity.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final section in sections)
                    SizedBox(
                      width: width,
                      child: _tile(context, section),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, _InventorySection section) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => section.page),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF171717),
                foregroundColor: Colors.white,
                radius: 26,
                child: Icon(section.icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      section.subtitle,
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventorySection {
  const _InventorySection(
    this.icon,
    this.title,
    this.subtitle,
    this.page,
  );

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;
}
