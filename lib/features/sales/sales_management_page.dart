import 'package:flutter/material.dart';

import '../reporting_api/sales_transactions_page.dart';
import '../store_eod_page.dart';

class SalesManagementPage extends StatelessWidget {
  const SalesManagementPage({super.key});

  static const _ink = Color(0xFF171717);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        title: const Text(
          'SALES',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    child: Icon(Icons.point_of_sale_outlined, size: 25),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SALES MANAGEMENT',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .4,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Review sales, transactions and daily activity.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'SALES',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              _grid(constraints.maxWidth, [
                _tile(
                  context,
                  Icons.receipt_long_outlined,
                  'Transactions',
                  'Browse transactions, payments, items and kiosk activity.',
                  const SalesTransactionsPage(),
                ),
                _tile(
                  context,
                  Icons.event_available_outlined,
                  'End of Day',
                  'Complete and review the store end-of-day process.',
                  const StoreEodPage(),
                ),
              ]),
              if (!compact) const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  Widget _grid(double maxWidth, List<Widget> children) {
    final columns = maxWidth >= 1100 ? 3 : maxWidth >= 700 ? 2 : 1;
    final width = (maxWidth - 40 - (columns - 1) * 12) / columns;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: children.map((tile) => SizedBox(width: width, child: tile)).toList(),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Widget page,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => page),
        ),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _ink,
                foregroundColor: Colors.white,
                child: Icon(icon, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black54, height: 1.25),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
