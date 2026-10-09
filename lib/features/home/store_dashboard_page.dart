import 'package:flutter/material.dart';

import '../../core/currency/store_currency.dart';
import 'package:printing/printing.dart';

import 'pdf_download_stub.dart' if (dart.library.html) 'pdf_download_web.dart'
    as pdf_download;

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
  late DateTime _selectedMonth;
  bool _loading = false;
  String? _error;
  List<ReportingDailySale> _daily = const [];
  List<ReportingProductSale> _products = const [];
  List<Map<String, dynamic>> _payments = const [];
  num _yesterdaySales = 0;
  List<ReportingCategorySale> _categories = const [];
  List<ReportingDeviceSale> _devices = const [];
  Map<String, dynamic>? _integrity;
  bool _integrityLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _load();
  }

  DateTime get _start => DateTime(_selectedMonth.year, _selectedMonth.month, 1);
  DateTime get _end =>
      DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _money(num value) => StoreCurrency.format(value);

  num _num(dynamic value) => value is num ? value : num.tryParse('$value') ?? 0;

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
                      leading: Icon(passed
                          ? Icons.check_circle
                          : Icons.warning_amber_rounded),
                      title: Text('${check['name']}'),
                      subtitle: Text(
                          'Expected ${_money(_num(check['expected']))} • Actual ${_money(_num(check['actual']))}'),
                      trailing: Text(_money(_num(check['difference']))),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE'))
        ],
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
        _api.getDailySales(
          startDate: DateTime.now().subtract(const Duration(days: 1)),
          endDate: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _daily = results[0] as List<ReportingDailySale>;
        _products = results[1] as List<ReportingProductSale>;
        _categories = results[2] as List<ReportingCategorySale>;
        _devices = results[3] as List<ReportingDeviceSale>;
        _payments = results[4] as List<Map<String, dynamic>>;
        final yesterdayRows = results[5] as List<ReportingDailySale>;
        _yesterdaySales =
            yesterdayRows.fold<num>(0, (sum, row) => sum + row.totalSales);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeMonth(int delta) async {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() => _selectedMonth = next);
    await _load();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'SELECT MONTH',
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedMonth = DateTime(picked.year, picked.month));
    await _load();
  }

  String _monthLabel(DateTime d) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${names[d.month - 1]} ${d.year}';
  }

  int get _orders => _daily.fold(0, (s, r) => s + r.transactionCount);
  num get _sales => _daily.fold<num>(0, (s, r) => s + r.totalSales);
  int get _items => _products.fold(0, (s, r) => s + r.quantitySold);
  num get _paid => _payments.fold<num>(0, (s, r) => s + _num(r['totalAmount']));

  List<_ProductTotal> get _topProducts {
    final grouped = <String, _ProductTotal>{};
    for (final row in _products) {
      final key = row.productId.isEmpty ? row.productName : row.productId;
      final existing = grouped[key];
      grouped[key] = _ProductTotal(
        productId: key,
        productName: row.productName,
        category: row.category,
        quantity: (existing?.quantity ?? 0) + row.quantitySold,
        sales: (existing?.sales ?? 0) + row.totalSales,
      );
    }
    final rows = grouped.values.toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));
    return rows.take(5).toList(growable: false);
  }

  List<_DailyPoint> get _dailyPoints {
    final byDay = <int, num>{};
    for (final row in _daily) {
      byDay[row.salesDate.day] =
          (byDay[row.salesDate.day] ?? 0) + row.totalSales;
    }
    final days = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    return List.generate(
        days, (i) => _DailyPoint(day: i + 1, sales: byDay[i + 1] ?? 0));
  }

  String get _topProductName =>
      _topProducts.isEmpty ? '—' : _topProducts.first.productName;

  List<_DailyDetail> get _dailyDetails {
    final byDate = <DateTime, _DailyDetail>{};
    for (final row in _daily) {
      final date =
          DateTime(row.salesDate.year, row.salesDate.month, row.salesDate.day);
      final existing = byDate[date];
      byDate[date] = _DailyDetail(
        date: date,
        orders: (existing?.orders ?? 0) + row.transactionCount,
        sales: (existing?.sales ?? 0) + row.totalSales,
      );
    }
    final days = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    return List.generate(days, (index) {
      final date =
          DateTime(_selectedMonth.year, _selectedMonth.month, index + 1);
      return byDate[date] ?? _DailyDetail(date: date, orders: 0, sales: 0);
    }, growable: false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF5F2ED),
        appBar: AppBar(
          backgroundColor: const Color(0xFF24180F),
          foregroundColor: Colors.white,
          title: const Text(' STORE',
              style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh'),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'integrity') _checkIntegrity();
                if (v == 'pdf') _viewPdf();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'integrity',
                    child: Text('Check reporting integrity')),
                PopupMenuItem(value: 'pdf', child: Text('View PDF report')),
              ],
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            LayoutBuilder(builder: (context, c) {
              final compact = c.maxWidth < 700;
              final header = Row(children: [
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Dashboard',
                          style: TextStyle(
                              fontSize: 32, fontWeight: FontWeight.w900)),
                      SizedBox(height: 3),
                      Text('Sales overview and top products',
                          style:
                              TextStyle(color: Colors.black54, fontSize: 15)),
                    ])),
                if (!compact) _monthSelector(),
              ]);
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    if (compact) ...[
                      const SizedBox(height: 14),
                      _monthSelector()
                    ],
                    const SizedBox(height: 20)
                  ]);
            }),
            if (_error != null) _messageCard('DASHBOARD ERROR', _error!),
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()))
            else
              _dashboardContent(),
          ]),
        ),
      );

  Widget _monthSelector() {
    final now = DateTime.now();
    final current =
        _selectedMonth.year == now.year && _selectedMonth.month == now.month;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton.filledTonal(
          onPressed: _loading ? null : () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left)),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: _loading ? null : _pickMonth,
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text(_monthLabel(_selectedMonth),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
      ),
      const SizedBox(width: 8),
      IconButton.filledTonal(
          onPressed: (_loading || current) ? null : () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right)),
    ]);
  }

  Widget _dashboardContent() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (context, c) {
          final columns = c.maxWidth >= 1050
              ? 4
              : c.maxWidth >= 650
                  ? 2
                  : 1;
          final width = (c.maxWidth - (columns - 1) * 14) / columns;
          return Wrap(spacing: 14, runSpacing: 14, children: [
            SizedBox(
                width: width,
                child: _metricCard('TOTAL SALES', _money(_sales),
                    Icons.bar_chart_rounded, 'Selected month')),
            SizedBox(
                width: width,
                child: _metricCard('TOTAL ORDERS', '$_orders',
                    Icons.shopping_cart_outlined, 'Completed transactions')),
            SizedBox(
                width: width,
                child: _metricCard(
                    'TOP PRODUCT',
                    _topProductName,
                    Icons.emoji_events_outlined,
                    _topProducts.isEmpty
                        ? 'No product sales'
                        : '${_topProducts.first.quantity} sold')),
            SizedBox(
                width: width,
                child: _metricCard(
                    "YESTERDAY'S SALES",
                    _money(_yesterdaySales),
                    Icons.today_outlined,
                    _date(DateTime.now().subtract(const Duration(days: 1))))),
          ]);
        }),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 1000)
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _dailySalesCard()),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: _topProductsCard())
            ]);
          return Column(children: [
            _dailySalesCard(),
            const SizedBox(height: 18),
            _topProductsCard()
          ]);
        }),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 1000) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _dailySalesDetailsCard()),
                const SizedBox(width: 18),
                Expanded(child: _productDetailsCard()),
              ],
            );
          }
          return Column(
            children: [
              _dailySalesDetailsCard(),
              const SizedBox(height: 18),
              _productDetailsCard(),
            ],
          );
        }),
      ]);

  Widget _metricCard(
          String label, String value, IconData icon, String detail) =>
      Card(
          elevation: 0,
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: const Color(0xFFF3E8D8),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, color: const Color(0xFF7B4B2A))),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(label,
                          style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 23, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(detail,
                          style: const TextStyle(
                              color: Colors.black45, fontSize: 12)),
                    ])),
              ])));

  Widget _dailySalesCard() => Card(
      elevation: 0,
      child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.bar_chart_rounded, color: Color(0xFF7B4B2A)),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('Daily Sales',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900))),
              Text(_monthLabel(_selectedMonth),
                  style: const TextStyle(color: Colors.black54))
            ]),
            const SizedBox(height: 18),
            SizedBox(
                height: 330,
                child: _dailyPoints.every((p) => p.sales == 0)
                    ? const Center(
                        child: Text('No sales for the selected month.',
                            style: TextStyle(color: Colors.black54)))
                    : _DailySalesChart(
                        points: _dailyPoints,
                        currencySymbol: StoreCurrency.symbol,
                        selectedMonth: _selectedMonth)),
          ])));

  Widget _topProductsCard() {
    final rows = _topProducts;
    final maxQty = rows.isEmpty
        ? 1
        : rows.map((r) => r.quantity).reduce((a, b) => a > b ? a : b);
    return Card(
        elevation: 0,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.emoji_events_outlined,
                        color: Color(0xFF7B4B2A)),
                    const SizedBox(width: 8),
                    const Expanded(
                        child: Text('Top Products',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900))),
                    Text(_monthLabel(_selectedMonth),
                        style: const TextStyle(color: Colors.black54))
                  ]),
                  const SizedBox(height: 14),
                  if (rows.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 50),
                        child: Center(
                            child: Text(
                                'No product sales for the selected month.',
                                style: TextStyle(color: Colors.black54))))
                  else
                    ...rows.asMap().entries.map((e) {
                      final row = e.value;
                      final share = _items == 0 ? 0.0 : row.quantity / _items;
                      return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(children: [
                            SizedBox(
                                width: 24,
                                child: Text('${e.key + 1}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black54))),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(row.productName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800))),
                                    Text('${row.quantity} sold',
                                        style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12)),
                                    const SizedBox(width: 10),
                                    Text('${(share * 100).round()}%',
                                        style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12))
                                  ]),
                                  const SizedBox(height: 7),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                        value: row.quantity / maxQty,
                                        minHeight: 8,
                                        backgroundColor:
                                            const Color(0xFFE9E5DF),
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                                Color(0xFF8A5A38))),
                                  ),
                                ])),
                          ]));
                    }),
                ])));
  }

  Widget _dailySalesDetailsCard() {
    final rows = _dailyDetails;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        leading: const Icon(Icons.calendar_view_day_outlined,
            color: Color(0xFF7B4B2A)),
        title: const Text('Daily Sales Details',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        subtitle: Text(_monthLabel(_selectedMonth),
            style: const TextStyle(color: Colors.black54)),
        children: [
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('No daily sales for the selected month.',
                    style: TextStyle(color: Colors.black54)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 28,
                headingRowColor:
                    const WidgetStatePropertyAll(Color(0xFFF0EEEA)),
                columns: const [
                  DataColumn(label: Text('DATE')),
                  DataColumn(label: Text('DAY')),
                  DataColumn(label: Text('ORDERS')),
                  DataColumn(label: Text('TOTAL SALES')),
                ],
                rows: rows.map((row) {
                  final date = row.date;
                  return DataRow(cells: [
                    DataCell(Text(
                        '${_monthName(date.month)} ${date.day}, ${date.year}',
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(_weekdayName(date.weekday))),
                    DataCell(Text('${row.orders}')),
                    DataCell(Text(_money(row.sales),
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return names[month - 1];
  }

  String _weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return names[weekday - 1];
  }

  Widget _productDetailsCard() {
    final rows = _topProducts;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        leading:
            const Icon(Icons.format_list_bulleted, color: Color(0xFF7B4B2A)),
        title: const Text('Product Sales Details',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        subtitle: Text(_monthLabel(_selectedMonth),
            style: const TextStyle(color: Colors.black54)),
        children: [
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('No product sales for the selected month.',
                    style: TextStyle(color: Colors.black54)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                headingRowColor:
                    const WidgetStatePropertyAll(Color(0xFFF0EEEA)),
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('PRODUCT')),
                  DataColumn(label: Text('CATEGORY')),
                  DataColumn(label: Text('QUANTITY SOLD')),
                  DataColumn(label: Text('SALES AMOUNT')),
                  DataColumn(label: Text('% OF TOTAL')),
                ],
                rows: rows.asMap().entries.map((e) {
                  final row = e.value;
                  final pct = _sales == 0 ? 0 : row.sales / _sales * 100;
                  return DataRow(cells: [
                    DataCell(Text('${e.key + 1}')),
                    DataCell(Text(row.productName,
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(_displayCategoryName(row.category))),
                    DataCell(Text('${row.quantity}')),
                    DataCell(Text(_money(row.sales))),
                    DataCell(Text('${pct.toStringAsFixed(0)}%')),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

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
                        SnackBar(
                            content: Text('Unable to download PDF: $error')),
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
    return normalized
        .split(RegExp(r'\s+'))
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  Widget _messageCard(String title, String message) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _DailyDetail {
  const _DailyDetail(
      {required this.date, required this.orders, required this.sales});
  final DateTime date;
  final int orders;
  final num sales;
}

class _ProductTotal {
  const _ProductTotal(
      {required this.productId,
      required this.productName,
      required this.category,
      required this.quantity,
      required this.sales});
  final String productId, productName, category;
  final int quantity;
  final num sales;
}

class _DailyPoint {
  const _DailyPoint({required this.day, required this.sales});
  final int day;
  final num sales;
}

class _DailySalesChart extends StatefulWidget {
  const _DailySalesChart(
      {required this.points,
      required this.currencySymbol,
      required this.selectedMonth});

  final List<_DailyPoint> points;
  final String currencySymbol;
  final DateTime selectedMonth;

  @override
  State<_DailySalesChart> createState() => _DailySalesChartState();
}

class _DailySalesChartState extends State<_DailySalesChart> {
  int? _hoveredIndex;

  void _setIndexFromPosition(Offset localPosition, Size size) {
    const left = 58.0;
    const right = 8.0;
    final width = size.width - left - right;
    if (width <= 0 || widget.points.isEmpty) return;

    final x = (localPosition.dx - left).clamp(0.0, width);
    final index = widget.points.length == 1
        ? 0
        : ((x / width) * (widget.points.length - 1))
            .round()
            .clamp(0, widget.points.length - 1);
    if (_hoveredIndex != index) setState(() => _hoveredIndex = index);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, 330);
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onExit: (_) => setState(() => _hoveredIndex = null),
            onHover: (event) =>
                _setIndexFromPosition(event.localPosition, size),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _setIndexFromPosition(details.localPosition, size),
              child: CustomPaint(
                size: size,
                painter: _DailySalesChartPainter(
                  points: widget.points,
                  currencySymbol: widget.currencySymbol,
                  selectedMonth: widget.selectedMonth,
                  hoveredIndex: _hoveredIndex,
                ),
              ),
            ),
          );
        },
      );
}

class _DailySalesChartPainter extends CustomPainter {
  const _DailySalesChartPainter({
    required this.points,
    required this.currencySymbol,
    required this.selectedMonth,
    required this.hoveredIndex,
  });

  final List<_DailyPoint> points;
  final String currencySymbol;
  final DateTime selectedMonth;
  final int? hoveredIndex;

  static const _left = 58.0;
  static const _right = 8.0;
  static const _top = 12.0;
  static const _bottom = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width - _left - _right;
    final height = size.height - _top - _bottom;
    final maxValue =
        points.fold<num>(0, (m, p) => p.sales > m ? p.sales : m).toDouble();
    final maxY = maxValue <= 0 ? 1.0 : maxValue;
    final grid = Paint()
      ..color = const Color(0xFFE6E2DC)
      ..strokeWidth = 1;
    final line = Paint()
      ..color = const Color(0xFF8A5A38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = const Color(0x338A5A38);
    const labelStyle = TextStyle(color: Colors.black54, fontSize: 10);

    for (var i = 0; i <= 4; i++) {
      final f = i / 4;
      final y = _top + height * (1 - f);
      canvas.drawLine(Offset(_left, y), Offset(_left + width, y), grid);
      final value = maxY * f;
      final label = value >= 1000
          ? '$currencySymbol${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k'
          : '$currencySymbol${value.toStringAsFixed(0)}';
      _text(canvas, label, Offset(0, y - 7), labelStyle, _left - 8);
    }

    final path = Path();
    final area = Path();
    for (var i = 0; i < points.length; i++) {
      final x = _xFor(i, width);
      final y = _yFor(points[i], height, maxY);
      if (i == 0) {
        path.moveTo(x, y);
        area.moveTo(x, _top + height);
        area.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        area.lineTo(x, y);
      }
    }
    if (points.isNotEmpty) {
      final x = _xFor(points.length - 1, width);
      area.lineTo(x, _top + height);
      area.close();
    }
    canvas.drawPath(area, fill);
    canvas.drawPath(path, line);

    final dot = Paint()..color = const Color(0xFF8A5A38);
    for (var i = 0; i < points.length; i++) {
      if (points[i].sales == 0) continue;
      final point = Offset(_xFor(i, width), _yFor(points[i], height, maxY));
      canvas.drawCircle(point, i == hoveredIndex ? 5.5 : 3.2, dot);
    }

    final every = points.length <= 15 ? 2 : 3;
    for (var i = 0; i < points.length; i++) {
      if (i != 0 && i != points.length - 1 && i % every != 0) continue;
      final x = _xFor(i, width);
      _text(canvas, '${points[i].day}', Offset(x - 7, _top + height + 10),
          labelStyle, 18);
    }
    _text(canvas, 'Day of Month',
        Offset(_left + width / 2 - 35, size.height - 18), labelStyle, 80);

    if (hoveredIndex != null &&
        hoveredIndex! >= 0 &&
        hoveredIndex! < points.length) {
      _drawTooltip(canvas, size, width, height, maxY, hoveredIndex!);
    }
  }

  double _xFor(int index, double width) =>
      _left +
      (points.length == 1 ? width / 2 : width * index / (points.length - 1));

  double _yFor(_DailyPoint point, double height, double maxY) =>
      _top + height * (1 - point.sales.toDouble() / maxY);

  void _drawTooltip(Canvas canvas, Size size, double width, double height,
      double maxY, int index) {
    final point = points[index];
    final x = _xFor(index, width);
    final y = _yFor(point, height, maxY);
    final date = DateTime(selectedMonth.year, selectedMonth.month, point.day);
    final dateLabel = '${_monthName(date.month)} ${date.day}, ${date.year}';
    final salesLabel = 'Total Sales: ${StoreCurrency.format(point.sales)}';

    const titleStyle = TextStyle(
        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700);
    const valueStyle = TextStyle(
        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900);
    final titlePainter = TextPainter(
        text: TextSpan(text: dateLabel, style: titleStyle),
        textDirection: TextDirection.ltr)
      ..layout();
    final valuePainter = TextPainter(
        text: TextSpan(text: salesLabel, style: valueStyle),
        textDirection: TextDirection.ltr)
      ..layout();
    final boxWidth = [titlePainter.width, valuePainter.width]
            .reduce((a, b) => a > b ? a : b) +
        24;
    const boxHeight = 58.0;
    final boxX = (x - boxWidth / 2).clamp(4.0, size.width - boxWidth - 4.0);
    final boxY = (y - boxHeight - 14).clamp(4.0, size.height - boxHeight - 4.0);

    final box = RRect.fromRectAndRadius(
        Rect.fromLTWH(boxX, boxY, boxWidth, boxHeight),
        const Radius.circular(8));
    canvas.drawRRect(box, Paint()..color = const Color(0xFF2D2119));
    titlePainter.paint(canvas, Offset(boxX + 12, boxY + 8));
    valuePainter.paint(canvas, Offset(boxX + 12, boxY + 30));

    final guide = Paint()
      ..color = const Color(0x668A5A38)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(x, _top), Offset(x, _top + height), guide);
  }

  String _monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return names[month - 1];
  }

  void _text(Canvas canvas, String value, Offset offset, TextStyle style,
      double maxWidth) {
    final p = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1)
      ..layout(maxWidth: maxWidth);
    p.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _DailySalesChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.currencySymbol != currencySymbol ||
      oldDelegate.selectedMonth != selectedMonth ||
      oldDelegate.hoveredIndex != hoveredIndex;
}
