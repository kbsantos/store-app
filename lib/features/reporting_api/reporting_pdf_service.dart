import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/currency/store_currency.dart';
import 'hourly_sale.dart';
import 'reporting_api_service.dart';
import 'reporting_pdf_font.dart';

class StoreReportingPdfService {
  static Future<Uint8List> buildProductSales({
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
    required List<ReportingProductSale> rows,
    String category = 'ALL',
    String device = 'ALL',
  }) async {
    final totals = <String, _ProductTotal>{};
    for (final row in rows) {
      final key = row.productId.isEmpty ? row.productName : row.productId;
      final current = totals[key];
      totals[key] = _ProductTotal(
        name: row.productName,
        category: row.category,
        quantity: (current?.quantity ?? 0) + row.quantitySold,
        sales: (current?.sales ?? 0) + row.totalSales,
      );
    }
    final sorted = totals.values.toList()..sort((a, b) => b.sales.compareTo(a.sales));
    final qty = sorted.fold<int>(0, (sum, row) => sum + row.quantity);
    final sales = sorted.fold<num>(0, (sum, row) => sum + row.sales);

    return _buildDocument(
      title: 'PRODUCT SALES REPORT',
      storeId: storeId,
      startDate: startDate,
      endDate: endDate,
      summary: [
        _summaryRow('Products', '${sorted.length}'),
        _summaryRow('Items Sold', '$qty'),
        _summaryRow('Total Sales', _money(sales)),
      ],
      filters: [
        'Category: $category',
        'Kiosk: $device',
      ],
      sections: [
        _tableSection(
          'PRODUCT SALES',
          const ['PRODUCT', 'CATEGORY', 'QTY SOLD', 'TOTAL SALES'],
          sorted.map((row) => [
            _displayName(row.name),
            _displayName(row.category),
            '${row.quantity}',
            _money(row.sales),
          ]).toList(),
        ),
      ],
    );
  }

  static Future<Uint8List> buildCategorySales({
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
    required List<ReportingCategorySale> rows,
    String device = 'ALL',
  }) async {
    final totals = <String, _CategoryTotal>{};
    for (final row in rows) {
      final current = totals[row.category];
      totals[row.category] = _CategoryTotal(
        quantity: (current?.quantity ?? 0) + row.quantitySold,
        sales: (current?.sales ?? 0) + row.totalSales,
      );
    }
    final sorted = totals.entries.toList()..sort((a, b) => b.value.sales.compareTo(a.value.sales));
    final qty = sorted.fold<int>(0, (sum, entry) => sum + entry.value.quantity);
    final sales = sorted.fold<num>(0, (sum, entry) => sum + entry.value.sales);

    return _buildDocument(
      title: 'CATEGORY SALES REPORT',
      storeId: storeId,
      startDate: startDate,
      endDate: endDate,
      summary: [
        _summaryRow('Categories', '${sorted.length}'),
        _summaryRow('Items Sold', '$qty'),
        _summaryRow('Total Sales', _money(sales)),
      ],
      filters: ['Kiosk: $device'],
      sections: [
        _tableSection(
          'CATEGORY SALES',
          const ['CATEGORY', 'QTY SOLD', 'TOTAL SALES', 'AVG ITEM PRICE'],
          sorted.map((entry) => [
            _displayName(entry.key),
            '${entry.value.quantity}',
            _money(entry.value.sales),
            _money(entry.value.quantity == 0 ? 0 : entry.value.sales / entry.value.quantity),
          ]).toList(),
        ),
      ],
    );
  }

  static Future<Uint8List> buildHourlySales({
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
    required List<HourlySale> rows,
  }) async {
    final transactions = rows.fold<int>(0, (sum, row) => sum + row.transactionCount);
    final items = rows.fold<int>(0, (sum, row) => sum + row.itemCount);
    final sales = rows.fold<num>(0, (sum, row) => sum + row.totalSales);

    return _buildDocument(
      title: 'HOURLY SALES REPORT',
      storeId: storeId,
      startDate: startDate,
      endDate: endDate,
      summary: [
        _summaryRow('Transactions', '$transactions'),
        _summaryRow('Items Sold', '$items'),
        _summaryRow('Total Sales', _money(sales)),
      ],
      sections: [
        _tableSection(
          'HOURLY SALES',
          const ['HOUR', 'TRANSACTIONS', 'ITEMS SOLD', 'TOTAL SALES'],
          rows.map((row) => [
            row.label,
            '${row.transactionCount}',
            '${row.itemCount}',
            _money(row.totalSales),
          ]).toList(),
        ),
      ],
    );
  }

  static Future<Uint8List> buildPaymentSummary({
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> rows,
  }) async {
    num number(dynamic value) => value is num ? value : num.tryParse('$value') ?? 0;
    final count = rows.fold<int>(0, (sum, row) => sum + number(row['paymentCount']).toInt());
    final total = rows.fold<num>(0, (sum, row) => sum + number(row['totalAmount']));

    return _buildDocument(
      title: 'PAYMENT SUMMARY REPORT',
      storeId: storeId,
      startDate: startDate,
      endDate: endDate,
      summary: [
        _summaryRow('Payments', '$count'),
        _summaryRow('Total Paid', _money(total)),
      ],
      sections: [
        _tableSection(
          'PAYMENT SUMMARY',
          const ['PAYMENT METHOD', 'PAYMENTS', 'TOTAL PAID'],
          rows.map((row) => [
            '${row['paymentMethod'] ?? 'Unknown'}',
            '${number(row['paymentCount']).toInt()}',
            _money(number(row['totalAmount'])),
          ]).toList(),
        ),
      ],
    );
  }

  static Future<Uint8List> buildTransactions({
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> rows,
    String search = '',
    String status = 'ALL',
  }) async {
    num number(dynamic value) => value is num ? value : num.tryParse('$value') ?? 0;
    final total = rows.fold<num>(0, (sum, row) => sum + number(row['total']));
    final items = rows.fold<int>(0, (sum, row) => sum + number(row['itemCount']).toInt());

    return _buildDocument(
      title: 'SALES TRANSACTIONS REPORT',
      storeId: storeId,
      startDate: startDate,
      endDate: endDate,
      summary: [
        _summaryRow('Transactions', '${rows.length}'),
        _summaryRow('Items', '$items'),
        _summaryRow('Total Sales', _money(total)),
      ],
      filters: [
        if (search.trim().isNotEmpty) 'Search: ${search.trim()}',
        'Status: $status',
      ],
      sections: [
        _tableSection(
          'TRANSACTIONS',
          const ['REFERENCE', 'DATE', 'KIOSK', 'ITEMS', 'STATUS', 'PAYMENT', 'TOTAL'],
          rows.map((row) => [
            '${row['referenceNo'] ?? row['id'] ?? ''}',
            '${row['dateValue'] ?? ''}',
            '${row['deviceId'] ?? 'Kiosk'}',
            '${row['itemCount'] ?? 0}',
            '${row['status'] ?? ''}',
            '${row['paymentMethod'] ?? ''}',
            _money(number(row['total'])),
          ]).toList(),
        ),
      ],
    );
  }

  static Future<Uint8List> _buildDocument({
    required String title,
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
    required List<pw.TableRow> summary,
    required List<_PdfSection> sections,
    List<String> filters = const [],
  }) async {
    final pdf = pw.Document(title: 'Bigger Brew $title');
    final theme = await StoreReportingPdfFont.theme();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: theme,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Store: $storeId'),
          pw.Text('Period: ${_date(startDate)}${_sameDay(startDate, endDate) ? '' : ' to ${_date(endDate)}'}'),
          if (filters.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(filters.join('  •  '), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
          pw.SizedBox(height: 14),
          pw.Table(border: pw.TableBorder.all(color: PdfColors.grey400), children: summary),
          pw.SizedBox(height: 18),
          ...sections.expand((section) => [
                pw.Text(section.title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                if (section.rows.isEmpty)
                  pw.Text('No data.', style: const pw.TextStyle(color: PdfColors.grey600))
                else
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    columnWidths: {
                      for (var i = 0; i < section.headers.length; i++)
                        i: pw.FlexColumnWidth(i == 0 ? 3 : 1.4),
                    },
                    children: [
                      _headerRow(section.headers),
                      ...section.rows.map(_dataTableRow),
                    ],
                  ),
                pw.SizedBox(height: 16),
              ]),
          pw.Text('Generated from Store Management reporting data.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
    return pdf.save();
  }

  static pw.TableRow _headerRow(List<String> headers) => pw.TableRow(
        children: headers.map((header) => pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(header, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
        )).toList(),
      );

  static pw.TableRow _dataTableRow(List<String> values) => pw.TableRow(
        children: values.map((value) => pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
        )).toList(),
      );

  static pw.TableRow _summaryRow(String label, String value) => pw.TableRow(children: [
        pw.Padding(padding: const pw.EdgeInsets.all(7), child: pw.Text(label)),
        pw.Padding(padding: const pw.EdgeInsets.all(7), child: pw.Text(value, textAlign: pw.TextAlign.right)),
      ]);

  static _PdfSection _tableSection(String title, List<String> headers, List<List<String>> rows) =>
      _PdfSection(title: title, headers: headers, rows: rows);

  static String _money(num value) => StoreCurrency.format(value);

  static String _displayName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[_-]+'), ' ');
    if (normalized.isEmpty) return 'Uncategorized';
    return normalized.split(RegExp(r'\s+')).map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}').join(' ');
  }

  static String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _PdfSection {
  const _PdfSection({required this.title, required this.headers, required this.rows});
  final String title;
  final List<String> headers;
  final List<List<String>> rows;
}

class _ProductTotal {
  const _ProductTotal({required this.name, required this.category, required this.quantity, required this.sales});
  final String name;
  final String category;
  final int quantity;
  final num sales;
}

class _CategoryTotal {
  const _CategoryTotal({required this.quantity, required this.sales});
  final int quantity;
  final num sales;
}
