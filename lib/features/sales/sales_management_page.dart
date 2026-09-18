import 'package:flutter/material.dart';

import '../reporting_api/reporting_dashboard_page.dart';
import '../reporting_api/sales_transactions_page.dart';
import '../reporting_api/hourly_sales_page.dart';
import '../reporting_api/payment_summary_page.dart';
import '../reporting_api/product_sales_page.dart';
import '../reporting_api/category_sales_page.dart';

class SalesManagementPage extends StatelessWidget {
  const SalesManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text(
          'SALES MANAGEMENT',
          style: TextStyle(fontWeight: FontWeight.w900),
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
              const SizedBox(height: 12),
              const Icon(
                Icons.point_of_sale_outlined,
                size: 68,
                color: Color(0xFFC69214),
              ),
              const SizedBox(height: 8),
              const Text(
                'SALES MANAGEMENT',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Review sales performance, transactions and sales activity.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
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
                      Icons.bar_chart_outlined,
                      'SALES DASHBOARD',
                      'Review sales by date, category, product and kiosk.',
                      const ReportingDashboardPage(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _tile(
                      context,
                      Icons.receipt_long_outlined,
                      'TRANSACTIONS',
                      'Browse transactions, payments, items and kiosk activity.',
                      const SalesTransactionsPage(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _tile(
                      context,
                      Icons.schedule_outlined,
                      'HOURLY SALES',
                      'Review transaction volume and sales by hour.',
                      const HourlySalesPage(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _tile(
                      context,
                      Icons.inventory_2_outlined,
                      'PRODUCT SALES',
                      'Review quantities and revenue by product.',
                      const ProductSalesPage(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _tile(
                      context,
                      Icons.category_outlined,
                      'CATEGORY SALES',
                      'Review quantities and revenue by category.',
                      const CategorySalesPage(),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _tile(
                      context,
                      Icons.payments_outlined,
                      'PAYMENT SUMMARY',
                      'Review payment count and total paid by payment method.',
                      const PaymentSummaryPage(),
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
    Widget page,
  ) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => page),
          );
        },
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
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
