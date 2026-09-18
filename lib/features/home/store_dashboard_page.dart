import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'pdf_download_stub.dart'
    if (dart.library.html) 'pdf_download_web.dart' as pdf_download;

import 'store_dashboard_pdf_service.dart';

import '../../core/auth/store_management_auth.dart';
import '../reporting_api/reporting_api_service.dart';

class StoreDashboardPage extends StatefulWidget {
  const StoreDashboardPage({super.key});

  @override
  State<StoreDashboardPage> createState() => _StoreDashboardPageState();
}

class _StoreDashboardPageState extends State<StoreDashboardPage> {
  final _auth = const StoreManagementAuth();
  final _api = ReportingApiService();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  bool _loading = false;
  String? _error;
  List<ReportingDailySale> _daily = const [];
  List<ReportingProductSale> _products = const [];
  List<ReportingCategorySale> _categories = const [];
  List<ReportingDeviceSale> _devices = const [];
  List<Map<String, dynamic>> _payments = const [];
  Map<String, dynamic>? _integrity;
  bool _integrityLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _money(num value) => '₱${value.toStringAsFixed(2)}';

  num _num(dynamic value) =>
      value is num ? value : num.tryParse('$value') ?? 0;

  Future<List<Map<String, dynamic>>> _getPayments() async {
    final result = await _auth.client.rpc(
      'get_store_payment_summary',
      params: {
        'p_start_date': _date(_start),
        'p_end_date': _date(_end),
      },
    );
    final list = result is List ? result : const <dynamic>[];
    return list
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<void> _checkIntegrity() async {
    if (_integrityLoading) return;
    setState(() => _integrityLoading = true);
    try {
      final result = await _auth.client.rpc(
        'get_store_reporting_integrity',
        params: {
          'p_start_date': _date(_start),
          'p_end_date': _date(_end),
        },
      );
      if (!mounted) return;
      setState(() => _integrity = Map<String, dynamic>.from(result as Map));
      await _showIntegrityDialog();
    } catch (e) {
      if (mounted) {
        setState(() => _integrity = {'status': 'ERROR', 'error': e.toString()});
        await _showIntegrityDialog();
      }
    } finally {
      if (mounted) setState(() => _integrityLoading = false);
    }
  }

  Future<void> _showIntegrityDialog() async {
    final data = _integrity;
    if (data == null || !mounted) return;
    final checks = (data['checks'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('REPORTING INTEGRITY: ${data['status'] ?? 'UNKNOWN'}'),
        content: SizedBox(
          width: 560,
          child: data['error'] != null
              ? Text('${data['error']}')
              : ListView(
                  shrinkWrap: true,
                  children: checks.map((check) {
                    final passed = check['passed'] == true;
                    return ListTile(
                      dense: true,
                      leading: Icon(passed ? Icons.check_circle : Icons.warning_amber_rounded),
                      title: Text('${check['name']}'),
                      subtitle: Text('Expected ${_money(_num(check['expected']))} • Actual ${_money(_num(check['actual']))}'),
                      trailing: Text(_money(_num(check['difference']))),
                    );
                  }).toList(),
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE'))],
      ),
    );
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _api.getDailySales(startDate: _start, endDate: _end),
        _api.getProductSales(startDate: _start, endDate: _end),
        _api.getCategorySales(startDate: _start, endDate: _end),
        _api.getDeviceSales(startDate: _start, endDate: _end),
        _getPayments(),
      ]);
      if (!mounted) return;
      setState(() {
        _daily = results[0] as List<ReportingDailySale>;
        _products = results[1] as List<ReportingProductSale>;
        _categories = results[2] as List<ReportingCategorySale>;
        _devices = results[3] as List<ReportingDeviceSale>;
        _payments = results[4] as List<Map<String, dynamic>>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_start.isAfter(_end)) _end = picked;
      } else {
        _end = picked;
        if (_end.isBefore(_start)) _start = picked;
      }
    });
    await _load();
  }

  int get _orders => _daily.fold(0, (s, r) => s + r.transactionCount);
  num get _sales => _daily.fold<num>(0, (s, r) => s + r.totalSales);
  int get _items => _products.fold(0, (s, r) => s + r.quantitySold);
  num get _paid => _payments.fold<num>(0, (s, r) => s + _num(r['totalAmount']));

  List<ReportingProductSale> get _topProducts {
    final rows = [..._products]
      ..sort((a, b) => b.totalSales.compareTo(a.totalSales));
    return rows.take(5).toList(growable: false);
  }

  List<ReportingCategorySale> get _topCategories {
    final grouped = <String, ReportingCategorySale>{};
    for (final row in _categories) {
      final existing = grouped[row.category];
      if (existing == null) {
        grouped[row.category] = row;
      } else {
        grouped[row.category] = ReportingCategorySale(
          storeId: row.storeId,
          deviceId: row.deviceId,
          salesDate: row.salesDate,
          category: row.category,
          quantitySold: existing.quantitySold + row.quantitySold,
          totalSales: existing.totalSales + row.totalSales,
        );
      }
    }
    final rows = grouped.values.toList()
      ..sort((a, b) => b.totalSales.compareTo(a.totalSales));
    return rows.take(5).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF5F2ED),
        appBar: AppBar(
          backgroundColor: const Color(0xFF171717),
          foregroundColor: Colors.white,
          title: const Text(
            'STORE DASHBOARD',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.dashboard_outlined, size: 64, color: Color(0xFFC69214)),
              const SizedBox(height: 6),
              const Text(
                'STORE DASHBOARD',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '${_auth.storeId ?? 'Store'}  •  ${_date(_start)}${_start == _end ? '' : ' to ${_date(_end)}'}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 18),
              _filters(),
              const SizedBox(height: 10),
              if (_error != null) _messageCard('DASHBOARD ERROR', _error!),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error == null)
                _content(),
            ],
          ),
        ),
      );

  Future<void> _viewPdf() async {
    if (_loading) return;
    final filename = 'store_dashboard_${_date(_start)}_${_date(_end)}.pdf';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 1000,
          height: MediaQuery.sizeOf(dialogContext).height * 0.9,
          child: PdfPreview(
            // Generate a fresh Uint8List for every preview request. Reusing a
            // previously returned buffer can cause Flutter Web's worker to
            // detach the ArrayBuffer and trigger DataCloneError on refresh.
            build: (_) => StoreDashboardPdfService.build(
              storeId: _auth.storeId ?? 'Store',
              startDate: _start,
              endDate: _end,
              daily: _daily,
              products: _products,
              categories: _categories,
              devices: _devices,
              payments: _paid,
            ),
            canChangePageFormat: false,
            canChangeOrientation: false,
            allowPrinting: true,
            allowSharing: true,
            pdfFileName: filename,
            actions: [
              PdfPreviewAction(
                icon: const Icon(Icons.download_outlined),
                onPressed: (context, build, pageFormat) async {
                  try {
                    final bytes = await build(pageFormat);
                    await pdf_download.downloadPdf(bytes, filename);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unable to download PDF: $error')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayCategoryName(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[_-]+'), ' ');
    if (normalized.isEmpty) return 'Uncategorized';
    return normalized.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }

  Widget _filters() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dateControls = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pick(true),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('FROM ${_date(_start)}'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _pick(false),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('TO ${_date(_end)}'),
                  ),
                ],
              );

              final actionControls = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: _integrityLoading
                        ? 'Checking reporting integrity'
                        : 'Check reporting integrity',
                    child: IconButton(
                      onPressed: _integrityLoading ? null : _checkIntegrity,
                      icon: _integrityLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fact_check_outlined),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'View PDF',
                    child: IconButton(
                      onPressed: _loading ? null : _viewPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                    ),
                  ),
                ],
              );

              if (constraints.maxWidth < 700) {
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [dateControls, actionControls],
                );
              }

              return Row(
                children: [
                  dateControls,
                  const Spacer(),
                  actionControls,
                ],
              );
            },
          ),
        ),
      );

  Widget _content() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 4 : 2;
              final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(width: width, child: _metric('SALES', _money(_sales), Icons.payments_outlined)),
                  SizedBox(width: width, child: _metric('ORDERS', '$_orders', Icons.receipt_long_outlined)),
                  SizedBox(width: width, child: _metric('ITEMS SOLD', '$_items', Icons.inventory_2_outlined)),
                  SizedBox(width: width, child: _metric('PAYMENTS', _money(_paid), Icons.account_balance_wallet_outlined)),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _section('TOP PRODUCTS', _topProducts.isEmpty
              ? _empty('No product sales for the selected dates.')
              : Column(children: _topProducts.map((r) => _row(r.productName, '${r.quantitySold} sold', _money(r.totalSales))).toList())),
          const SizedBox(height: 14),
          _section('CATEGORY SALES', _topCategories.isEmpty
              ? _empty('No category sales for the selected dates.')
              : Column(children: _topCategories.map((r) => _categoryRow(r)).toList())),
          const SizedBox(height: 14),
          _section('KIOSK SALES', _devices.isEmpty
              ? _empty('No kiosk sales for the selected dates.')
              : Column(children: _deviceRows())),
          const SizedBox(height: 14),
          _section('DAILY SALES', _daily.isEmpty
              ? _empty('No sales for the selected dates.')
              : Column(children: _daily.map((r) => _row(_date(r.salesDate), '${r.transactionCount} orders', _money(r.totalSales))).toList())),
        ],
      );

  Widget _categoryRow(ReportingCategorySale row) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: InkWell(
          onTap: _loading ? null : () => _showCategoryDrillDown(row.category),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _displayCategoryName(row.category),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text('${row.quantitySold} items', style: const TextStyle(color: Colors.black54)),
                const SizedBox(width: 18),
                Text(_money(row.totalSales), style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 20, color: Colors.black54),
              ],
            ),
          ),
        ),
      );

  Future<void> _showCategoryDrillDown(String category) async {
    final selectedCategory = category.trim().isEmpty ? 'Uncategorized' : category.trim();
    final categoryRows = _products.where((row) => row.category == category).toList(growable: false);
    final grouped = <String, _DashboardProductTotal>{};
    for (final row in categoryRows) {
      final key = row.productId.isEmpty ? row.productName : row.productId;
      final existing = grouped[key];
      grouped[key] = _DashboardProductTotal(
        productName: row.productName,
        quantity: (existing?.quantity ?? 0) + row.quantitySold,
        sales: (existing?.sales ?? 0) + row.totalSales,
      );
    }
    final products = grouped.values.toList()..sort((a, b) => b.sales.compareTo(a.sales));
    final categoryTotal = _categories
        .where((row) => row.category == category)
        .fold<num>(0, (sum, row) => sum + row.totalSales);
    final categoryQuantity = _categories
        .where((row) => row.category == category)
        .fold<int>(0, (sum, row) => sum + row.quantitySold);
    final mismatch = categoryTotal > _sales + 0.009;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_displayCategoryName(selectedCategory)} SALES'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('DATE RANGE: ${_date(_start)}${_start == _end ? '' : ' to ${_date(_end)}'}'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _drillMetric('ITEMS', '$categoryQuantity')),
                    const SizedBox(width: 10),
                    Expanded(child: _drillMetric('CATEGORY SALES', _money(categoryTotal))),
                    const SizedBox(width: 10),
                    Expanded(child: _drillMetric('DASHBOARD SALES', _money(_sales))),
                  ],
                ),
                if (mismatch) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black26),
                    ),
                    child: const Text(
                      'WARNING: This category total is greater than the dashboard sales total. This indicates a reporting-data mismatch and is not proof of additional actual sales.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('PRODUCT SALES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const Divider(),
                if (products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No product rows are currently tagged with this category.'),
                  )
                else
                  ...products.map(
                    (product) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Expanded(child: Text(product.productName, style: const TextStyle(fontWeight: FontWeight.w700))),
                          Text('${product.quantity} sold', style: const TextStyle(color: Colors.black54)),
                          const SizedBox(width: 18),
                          Text(_money(product.sales), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CLOSE')),
        ],
      ),
    );
  }

  Widget _drillMetric(String label, String value) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );

  List<Widget> _deviceRows() {
    final grouped = <String, ReportingDeviceSale>{};
    for (final row in _devices) {
      final key = row.deviceId.isEmpty ? 'Unassigned' : row.deviceId;
      final existing = grouped[key];
      if (existing == null) {
        grouped[key] = row;
      } else {
        grouped[key] = ReportingDeviceSale(
          storeId: row.storeId,
          deviceId: row.deviceId,
          salesDate: row.salesDate,
          transactionCount: existing.transactionCount + row.transactionCount,
          subtotal: existing.subtotal + row.subtotal,
          discount: existing.discount + row.discount,
          totalSales: existing.totalSales + row.totalSales,
        );
      }
    }
    final rows = grouped.values.toList()..sort((a, b) => b.totalSales.compareTo(a.totalSales));
    return rows.map((r) => _row(r.deviceId.isEmpty ? 'Unassigned' : r.deviceId, '${r.transactionCount} orders', _money(r.totalSales))).toList();
  }

  Widget _metric(String label, String value, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF171717),
                foregroundColor: Colors.white,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _section(String title, Widget child) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Divider(),
              child,
            ],
          ),
        ),
      );

  Widget _row(String title, String detail, String amount) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(detail, style: const TextStyle(color: Colors.black54)),
            const SizedBox(width: 18),
            Text(amount, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text, style: const TextStyle(color: Colors.black54)),
      );

  Widget _messageCard(String title, String message) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}


class _DashboardProductTotal {
  const _DashboardProductTotal({required this.productName, required this.quantity, required this.sales});
  final String productName;
  final int quantity;
  final num sales;
}
