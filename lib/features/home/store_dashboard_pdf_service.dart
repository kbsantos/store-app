import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../reporting_api/reporting_api_service.dart';

class StoreDashboardPdfService {
  static Future<Uint8List> build({
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
    required List<ReportingDailySale> daily,
    required List<ReportingProductSale> products,
    required List<ReportingCategorySale> categories,
    required List<ReportingDeviceSale> devices,
    required num payments,
  }) async {
    final pdf = pw.Document(title: 'Bigger Brew Store Dashboard');
    final topProducts = [...products]
      ..sort((a, b) => b.totalSales.compareTo(a.totalSales));
    final groupedCategories = <String, ReportingCategorySale>{};
    for (final row in categories) {
      final existing = groupedCategories[row.category];
      groupedCategories[row.category] = existing == null
          ? row
          : ReportingCategorySale(
              storeId: row.storeId,
              deviceId: row.deviceId,
              salesDate: row.salesDate,
              category: row.category,
              quantitySold: existing.quantitySold + row.quantitySold,
              totalSales: existing.totalSales + row.totalSales,
            );
    }
    final topCategories = groupedCategories.values.toList()
      ..sort((a, b) => b.totalSales.compareTo(a.totalSales));

    final sales = daily.fold<num>(0, (sum, row) => sum + row.totalSales);
    final orders = daily.fold<int>(0, (sum, row) => sum + row.transactionCount);
    final items = products.fold<int>(0, (sum, row) => sum + row.quantitySold);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'BIGGER BREW STORE DASHBOARD',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Store: $storeId'),
          pw.Text('Period: ${_date(startDate)}${_sameDay(startDate, endDate) ? '' : ' to ${_date(endDate)}'}'),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              _summaryRow('Sales', _money(sales)),
              _summaryRow('Orders', '$orders'),
              _summaryRow('Items Sold', '$items'),
              _summaryRow('Payments', _money(payments)),
            ],
          ),
          pw.SizedBox(height: 18),
          _section('TOP PRODUCTS', topProducts.take(10).map((row) => _dataRow(
                _displayName(row.productName),
                '${row.quantitySold} sold',
                _money(row.totalSales),
              )).toList()),
          pw.SizedBox(height: 14),
          _section('CATEGORY SALES', topCategories.take(10).map((row) => _dataRow(
                _displayName(row.category),
                '${row.quantitySold} items',
                _money(row.totalSales),
              )).toList()),
          pw.SizedBox(height: 14),
          _section('KIOSK SALES', _groupDevices(devices).map((row) => _dataRow(
                row.name,
                '${row.orders} orders',
                _money(row.sales),
              )).toList()),
          pw.SizedBox(height: 14),
          _section('DAILY SALES', daily.map((row) => _dataRow(
                _date(row.salesDate),
                '${row.transactionCount} orders',
                _money(row.totalSales),
              )).toList()),
          pw.SizedBox(height: 18),
          pw.Text(
            'Generated from Store Management reporting data.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  static pw.TableRow _summaryRow(String label, String value) => pw.TableRow(
        children: [
          pw.Padding(padding: const pw.EdgeInsets.all(7), child: pw.Text(label)),
          pw.Padding(
            padding: const pw.EdgeInsets.all(7),
            child: pw.Text(value, textAlign: pw.TextAlign.right),
          ),
        ],
      );

  static pw.Widget _section(String title, List<pw.TableRow> rows) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          if (rows.isEmpty)
            pw.Text('No data.', style: const pw.TextStyle(color: PdfColors.grey600))
          else
            pw.Table(
              border: pw.TableBorder(bottom: pw.BorderSide(color: PdfColors.grey300)),
              columnWidths: const {0: pw.FlexColumnWidth(4), 1: pw.FlexColumnWidth(1.5), 2: pw.FlexColumnWidth(1.5)},
              children: rows,
            ),
        ],
      );

  static pw.TableRow _dataRow(String title, String detail, String amount) => pw.TableRow(
        children: [
          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5), child: pw.Text(title)),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5), child: pw.Text(detail, textAlign: pw.TextAlign.right)),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5), child: pw.Text(amount, textAlign: pw.TextAlign.right)),
        ],
      );

  static List<_DeviceSummary> _groupDevices(List<ReportingDeviceSale> devices) {
    final grouped = <String, _DeviceSummary>{};
    for (final row in devices) {
      final key = row.deviceId.isEmpty ? 'Unassigned' : row.deviceId;
      final existing = grouped[key];
      grouped[key] = existing == null
          ? _DeviceSummary(key, row.transactionCount, row.totalSales)
          : _DeviceSummary(key, existing.orders + row.transactionCount, existing.sales + row.totalSales);
    }
    final rows = grouped.values.toList()
      ..sort((a, b) => b.sales.compareTo(a.sales));
    return rows;
  }

  static String _displayName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[_-]+'), ' ');
    if (normalized.isEmpty) return 'Uncategorized';
    return normalized.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }

  static String _money(num value) => 'PHP ${value.toStringAsFixed(2)}';

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DeviceSummary {
  const _DeviceSummary(this.name, this.orders, this.sales);
  final String name;
  final int orders;
  final num sales;
}
