import 'package:flutter/material.dart';

import '../../core/currency/store_currency.dart';
import 'reporting_api_service.dart';
import 'reporting_export_service.dart';
import 'hourly_sale.dart';

class SalesReportingCenterPage extends StatefulWidget {
  const SalesReportingCenterPage({super.key});

  @override
  State<SalesReportingCenterPage> createState() => _SalesReportingCenterPageState();
}

class _SalesReportingCenterPageState extends State<SalesReportingCenterPage> {
  final _api = ReportingApiService();
  final _reports = const [
    _ReportOption('summary', 'Sales Summary', 'Overall sales performance', Icons.summarize_outlined),
    _ReportOption('daily', 'Daily Sales', 'Sales grouped by date', Icons.calendar_month_outlined),
    _ReportOption('hourly', 'Hourly Sales', 'Sales grouped by hour', Icons.schedule_outlined),
    _ReportOption('product', 'Product Sales', 'Sales by individual product', Icons.inventory_2_outlined),
    _ReportOption('product_type', 'Product Type Sales', 'Sales grouped by product type', Icons.account_tree_outlined),
    _ReportOption('category', 'Category Sales', 'Sales grouped by category', Icons.category_outlined),
    _ReportOption('payment', 'Payment Summary', 'Payment-method totals', Icons.payments_outlined),
    _ReportOption('device', 'Sales by Device', 'Sales grouped by kiosk/device', Icons.devices_outlined),
    _ReportOption('discounts', 'Discounts & Charges', 'Discount and charge reporting', Icons.receipt_long_outlined),
    _ReportOption('transactions', 'Transaction Report', 'Transaction-level detail', Icons.receipt_long_outlined),
  ];

  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  String _reportKey = 'summary';
  String _device = 'ALL';
  String _category = 'ALL';
  String _transactionStatus = 'ALL';
  String _transactionSearch = '';
  bool _loading = false;
  String? _error;

  List<ReportingDailySale> _dailyRows = const [];
  List<ReportingProductSale> _productRows = const [];
  List<ReportingProductTypeSale> _productTypeRows = const [];
  List<ReportingCategorySale> _categoryRows = const [];
  List<ReportingDeviceSale> _deviceRows = const [];
  List<HourlySale> _hourlyRows = const [];
  List<Map<String, dynamic>> _paymentRows = const [];
  List<Map<String, dynamic>> _transactionRows = const [];
  List<Map<String, dynamic>> _discountChargeRows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _money(num value) => StoreCurrency.format(value);

  _ReportOption get _selectedReport =>
      _reports.firstWhere((report) => report.key == _reportKey);

  bool get _supportsPreview =>
      const {'summary', 'daily', 'hourly', 'product', 'product_type', 'category', 'payment', 'device', 'discounts', 'transactions'}.contains(_reportKey);

  bool get _supportsKioskFilter =>
      const {'summary', 'daily', 'product', 'product_type', 'category', 'device'}.contains(_reportKey);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _dailyRows = const [];
      _productRows = const [];
      _productTypeRows = const [];
      _categoryRows = const [];
      _deviceRows = const [];
      _hourlyRows = const [];
      _paymentRows = const [];
      _transactionRows = const [];
      _discountChargeRows = const [];

      switch (_reportKey) {
        case 'summary':
        case 'daily':
          _dailyRows = await _api.getDailySales(
            startDate: _start,
            endDate: _end,
            deviceId: _device == 'ALL' ? null : _device,
          );
          break;
        case 'hourly':
          _hourlyRows = await _api.getHourlySales(startDate: _start, endDate: _end);
          break;
        case 'product':
          _productRows = await _api.getProductSales(
            startDate: _start,
            endDate: _end,
            category: _category == 'ALL' ? null : _category,
            deviceId: _device == 'ALL' ? null : _device,
          );
          break;
        case 'product_type':
          _productTypeRows = await _api.getProductTypeSales(
            startDate: _start,
            endDate: _end,
            deviceId: _device == 'ALL' ? null : _device,
          );
          break;
        case 'category':
          _categoryRows = await _api.getCategorySales(
            startDate: _start,
            endDate: _end,
            deviceId: _device == 'ALL' ? null : _device,
          );
          break;
        case 'device':
          _deviceRows = await _api.getDeviceSales(startDate: _start, endDate: _end);
          break;
        case 'payment':
          _paymentRows = await _api.getPaymentSummary(startDate: _start, endDate: _end);
          break;
        case 'discounts':
          _discountChargeRows = await _api.getDiscountsAndCharges(
            startDate: _start,
            endDate: _end,
          );
          break;
        case 'transactions':
          _transactionRows = await _api.getTransactions(
            startDate: _start,
            endDate: _end,
            search: _transactionSearch.trim().isEmpty ? null : _transactionSearch.trim(),
            status: _transactionStatus == 'ALL' ? null : _transactionStatus,
          );
          break;
        default:
          break;
      }
      if (!mounted) return;
      setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setReport(String? value) async {
    if (value == null || value == _reportKey) return;
    setState(() {
      _reportKey = value;
      if (!_supportsKioskFilter) _device = 'ALL';
      if (value != 'product') _category = 'ALL';
      if (value != 'transactions') {
        _transactionStatus = 'ALL';
        _transactionSearch = '';
      }
    });
    await _load();
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
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

  void _setPreset(String preset) {
    final today = DateTime.now();
    final date = DateTime(today.year, today.month, today.day);
    setState(() {
      switch (preset) {
        case 'today':
          _start = date;
          _end = date;
          break;
        case 'yesterday':
          _start = date.subtract(const Duration(days: 1));
          _end = _start;
          break;
        case 'week':
          final mondayOffset = date.weekday - DateTime.monday;
          _start = date.subtract(Duration(days: mondayOffset));
          _end = date;
          break;
        case 'month':
          _start = DateTime(date.year, date.month, 1);
          _end = date;
          break;
      }
    });
    _load();
  }

  List<String> get _devices {
    final values = <String>{};
    for (final row in _dailyRows) values.add(row.deviceId);
    for (final row in _productRows) values.add(row.deviceId);
    for (final row in _productTypeRows) values.add(row.deviceId);
    for (final row in _categoryRows) values.add(row.deviceId);
    return [
      'ALL',
      ...values.where((value) => value.trim().isNotEmpty).toList()..sort(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text('SALES REPORTING CENTER', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: _loading ? null : _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _controls(),
            const SizedBox(height: 18),
            _reportHeader(),
            const SizedBox(height: 12),
            if (_error != null) _messageCard('REPORTING ERROR', _error!),
            if (_loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (_error == null)
              _preview(),
          ],
        ),
      ),
    );
  }

  Widget _controls() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('PERIOD', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _preset('Today', 'today'),
                  _preset('Yesterday', 'yesterday'),
                  _preset('This Week', 'week'),
                  _preset('This Month', 'month'),
                  OutlinedButton.icon(onPressed: () => _pickDate(true), icon: const Icon(Icons.calendar_today_outlined), label: Text('FROM ${_date(_start)}')),
                  OutlinedButton.icon(onPressed: () => _pickDate(false), icon: const Icon(Icons.calendar_today_outlined), label: Text('TO ${_date(_end)}')),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 900;
                  final reportControl = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('REPORT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _reportKey,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: _reports.map((report) => DropdownMenuItem(
                          value: report.key,
                          child: Row(
                            children: [
                              Icon(report.icon, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text(report.title, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        )).toList(),
                        onChanged: _loading ? null : _setReport,
                      ),
                    ],
                  );

                  final filterControls = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FILTERS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, filterConstraints) {
                          final fieldWidth = filterConstraints.maxWidth >= 600 ? 280.0 : filterConstraints.maxWidth;
                          final transactionFieldWidth = filterConstraints.maxWidth >= 600 ? 280.0 : filterConstraints.maxWidth;

                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              if (_supportsKioskFilter)
                                _filterDropdown(
                                  width: fieldWidth,
                                  label: 'Kiosk',
                                  value: _devices.contains(_device) ? _device : 'ALL',
                                  values: _devices,
                                  display: (value) => value == 'ALL' ? 'All Kiosks' : value,
                                  onChanged: (value) async {
                                    if (value == null) return;
                                    setState(() => _device = value);
                                    await _load();
                                  },
                                ),
                              if (_reportKey == 'product')
                                _filterDropdown(
                                  width: fieldWidth,
                                  label: 'Category',
                                  value: _categories.contains(_category) ? _category : 'ALL',
                                  values: _categories,
                                  display: (value) => value == 'ALL' ? 'All Categories' : value,
                                  onChanged: (value) async {
                                    if (value == null) return;
                                    setState(() => _category = value);
                                    await _load();
                                  },
                                ),
                              if (_reportKey == 'transactions') ...[
                                SizedBox(
                                  width: transactionFieldWidth,
                                  child: TextFormField(
                                    initialValue: _transactionSearch,
                                    decoration: InputDecoration(
                                      labelText: 'Search transaction',
                                      border: const OutlineInputBorder(),
                                      prefixIcon: const Icon(Icons.search),
                                      suffixIcon: _transactionSearch.isEmpty ? null : IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: _loading ? null : () async {
                                          setState(() => _transactionSearch = '');
                                          await _load();
                                        },
                                      ),
                                    ),
                                    onFieldSubmitted: _loading ? null : (value) async {
                                      setState(() => _transactionSearch = value);
                                      await _load();
                                    },
                                  ),
                                ),
                                _filterDropdown(
                                  width: transactionFieldWidth,
                                  label: 'Status',
                                  value: _transactionStatus,
                                  values: const ['ALL', 'completed', 'cancelled', 'voided', 'pending'],
                                  display: (value) => value == 'ALL' ? 'All Statuses' : value.toUpperCase(),
                                  onChanged: (value) async {
                                    if (value == null) return;
                                    setState(() => _transactionStatus = value);
                                    await _load();
                                  },
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        reportControl,
                        const SizedBox(height: 18),
                        filterControls,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: reportControl),
                      const SizedBox(width: 24),
                      Expanded(flex: 6, child: filterControls),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );

  List<String> get _categories {
    final values = <String>{'ALL'};
    for (final row in _productRows) {
      final value = row.category.trim();
      if (value.isNotEmpty) values.add(value);
    }
    final sorted = values.toList()..sort();
    sorted.remove('ALL');
    return ['ALL', ...sorted];
  }

  Widget _filterDropdown({
    double width = 280,
    required String label,
    required String value,
    required List<String> values,
    required String Function(String) display,
    required Future<void> Function(String?) onChanged,
  }) => SizedBox(
        width: width,
        child: DropdownButtonFormField<String>(
          initialValue: values.contains(value) ? value : 'ALL',
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          items: values.map((item) => DropdownMenuItem(
            value: item,
            child: Text(display(item), maxLines: 1, overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: _loading ? null : onChanged,
        ),
      );

  Widget _preset(String label, String value) => OutlinedButton(
        onPressed: _loading ? null : () => _setPreset(value),
        child: Text(label),
      );

  Widget _reportHeader() => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selectedReport.title.toUpperCase(), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(_selectedReport.subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          _exportButton('PDF', Icons.picture_as_pdf_outlined, () => _export('PDF')),
          const SizedBox(width: 6),
          _exportButton('Excel', Icons.table_view_outlined, () => _export('Excel')),
          const SizedBox(width: 6),
          _exportButton('CSV', Icons.file_present_outlined, () => _export('CSV')),
          const SizedBox(width: 6),
          _exportButton('Print', Icons.print_outlined, () => _export('Print')),
        ],
      );

  Widget _exportButton(String label, IconData icon, Future<void> Function()? onPressed) => OutlinedButton.icon(
        onPressed: _loading || !_supportsPreview ? null : onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
      );

  Future<void> _export(String format) async {
    final table = _currentTable();
    if (table.rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('There is no report data to export.')));
      return;
    }
    final base = 'BiggerBrew_${_selectedReport.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_${_date(_start)}_${_date(_end)}';
    try {
      if (format == 'PDF') {
        await ReportingExportService.savePdf(filename: '$base.pdf', title: _selectedReport.title.toUpperCase(), subtitle: '${_selectedReport.subtitle} • ${_date(_start)} to ${_date(_end)}', headers: table.headers, rows: table.rows);
      } else if (format == 'CSV') {
        await ReportingExportService.saveCsv(filename: '$base.csv', headers: table.headers, rows: table.rows);
      } else if (format == 'Excel') {
        await ReportingExportService.saveExcel(filename: '$base.xls', title: _selectedReport.title, headers: table.headers, rows: table.rows);
      } else {
        await ReportingExportService.printReport(
          title: _selectedReport.title.toUpperCase(),
          subtitle: '${_selectedReport.subtitle} • ${_date(_start)} to ${_date(_end)}',
          headers: table.headers,
          rows: table.rows,
        );
      }
      if (mounted && format != 'Print') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$format report ready.')));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$format export failed: $error')));
    }
  }

  _ReportTable _currentTable() {
    switch (_reportKey) {
      case 'summary':
      case 'daily':
        return _ReportTable(
          const ['DATE', 'TRANSACTIONS', 'SUBTOTAL', 'DISCOUNT', 'TOTAL SALES'],
          _dailyRows.map((row) => [_date(row.salesDate), '${row.transactionCount}', _money(row.subtotal), _money(row.discount), _money(row.totalSales)]).toList(),
        );
      case 'hourly':
        return _ReportTable(
          const ['HOUR', 'TRANSACTIONS', 'ITEMS SOLD', 'TOTAL SALES'],
          _hourlyRows.map((row) => [row.label, '${row.transactionCount}', '${row.itemCount}', _money(row.totalSales)]).toList(),
        );
      case 'product':
        final rows = [..._productRows]..sort((a, b) => b.totalSales.compareTo(a.totalSales));
        return _ReportTable(const ['PRODUCT', 'CATEGORY', 'QTY SOLD', 'TOTAL SALES'], rows.map((r) => [r.productName, r.category, '${r.quantitySold}', _money(r.totalSales)]).toList());
      case 'product_type':
        final totals = <String, List<num>>{};
        for (final row in _productTypeRows) {
          final key = row.productType.trim().isEmpty ? 'Uncategorized' : row.productType.trim();
          final current = totals[key] ?? [0, 0];
          totals[key] = [current[0] + row.quantitySold, current[1] + row.totalSales];
        }
        final rows = totals.entries.toList()..sort((a, b) => b.value[1].compareTo(a.value[1]));
        final sales = rows.fold<num>(0, (s, r) => s + r.value[1]);
        return _ReportTable(const ['PRODUCT TYPE', 'QTY SOLD', 'TOTAL SALES', '% OF SALES'], rows.map((r) => [r.key, '${r.value[0].toInt()}', _money(r.value[1]), sales == 0 ? '0.0%' : '${(r.value[1] / sales * 100).toStringAsFixed(1)}%']).toList());
      case 'category':
        final totals = <String, List<num>>{};
        for (final row in _categoryRows) {
          final current = totals[row.category] ?? [0, 0];
          totals[row.category] = [current[0] + row.quantitySold, current[1] + row.totalSales];
        }
        final rows = totals.entries.toList()..sort((a, b) => b.value[1].compareTo(a.value[1]));
        final sales = rows.fold<num>(0, (s, r) => s + r.value[1]);
        return _ReportTable(const ['CATEGORY', 'QTY SOLD', 'TOTAL SALES', '% OF SALES'], rows.map((r) => [r.key, '${r.value[0].toInt()}', _money(r.value[1]), sales == 0 ? '0.0%' : '${(r.value[1] / sales * 100).toStringAsFixed(1)}%']).toList());
      case 'payment':
        num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
        return _ReportTable(const ['PAYMENT METHOD', 'PAYMENTS', 'TOTAL PAID'], _paymentRows.map((r) => ['${r['paymentMethod'] ?? 'Unknown'}', '${n(r['paymentCount']).toInt()}', _money(n(r['totalAmount']))]).toList());
      case 'device':
        final rows = <String, List<num>>{};
        for (final row in _deviceRows) {
          final current = rows[row.deviceId] ?? [0, 0, 0];
          rows[row.deviceId] = [current[0] + row.transactionCount, current[1] + row.totalSales, current[2] + row.discount];
        }
        final entries = rows.entries.toList()..sort((a, b) => b.value[1].compareTo(a.value[1]));
        return _ReportTable(const ['DEVICE', 'TRANSACTIONS', 'TOTAL SALES', 'DISCOUNT'], entries.map((r) => [r.key, '${r.value[0].toInt()}', _money(r.value[1]), _money(r.value[2])]).toList());
      case 'discounts':
        num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
        return _ReportTable(
          const ['DATE', 'TRANSACTIONS', 'SUBTOTAL', 'DISCOUNT', 'CHARGES', 'TOTAL SALES'],
          _discountChargeRows.map((r) => [
            '${r['salesDate'] ?? ''}',
            '${n(r['transactionCount']).toInt()}',
            _money(n(r['subtotal'])),
            _money(n(r['discount'])),
            _money(n(r['charges'])),
            _money(n(r['totalSales'])),
          ]).toList(),
        );
      case 'transactions':
        num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
        return _ReportTable(
          const ['DATE/TIME', 'TRANSACTION', 'DEVICE', 'ITEMS', 'PAYMENT', 'TOTAL', 'STATUS'],
          _transactionRows.map((r) => [
            '${r['dateValue'] ?? r['created_at'] ?? r['transaction_date'] ?? ''}',
            '${r['transactionNumber'] ?? r['transaction_id'] ?? r['id'] ?? ''}',
            '${r['deviceId'] ?? r['device_id'] ?? 'Kiosk'}',
            '${r['itemCount'] ?? 0}',
            '${r['paymentMethod'] ?? r['payment_method'] ?? ''}',
            _money(n(r['total'] ?? r['total_amount'])),
            '${r['status'] ?? ''}',
          ]).toList(),
        );
      default:
        return const _ReportTable([], []);
    }
  }

  Widget _preview() {
    if (!_supportsPreview) {
      return _messageCard(
        'REPORT PREVIEW',
        'The $_reportKey report is available in Sales Management today. Its unified preview and export implementation will be connected in Phase 2 without changing the existing report page.',
      );
    }

    switch (_reportKey) {
      case 'summary':
        return _summaryPreview();
      case 'daily':
        return _dailyPreview();
      case 'hourly':
        return _hourlyPreview();
      case 'product':
        return _productPreview();
      case 'product_type':
        return _productTypePreview();
      case 'category':
        return _categoryPreview();
      case 'device':
        return _devicePreview();
      case 'payment':
        return _paymentPreview();
      case 'transactions':
        return _transactionsPreview();
      case 'discounts':
        return _discountsPreview();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _summaryPreview() {
    final sales = _dailyRows.fold<num>(0, (sum, row) => sum + row.totalSales);
    final transactions = _dailyRows.fold(0, (sum, row) => sum + row.transactionCount);
    final discounts = _dailyRows.fold<num>(0, (sum, row) => sum + row.discount);
    return _previewCard(
      children: [
        _kpiRow([
          _kpi('TOTAL SALES', _money(sales)),
          _kpi('TRANSACTIONS', '$transactions'),
          _kpi('AVG. ORDER', transactions == 0 ? _money(0) : _money(sales / transactions)),
          _kpi('DISCOUNTS', _money(discounts)),
        ]),
        const SizedBox(height: 16),
        _sectionTitle('SALES SUMMARY'),
        _dataTable(
          const ['DATE', 'TRANSACTIONS', 'SUBTOTAL', 'DISCOUNT', 'TOTAL SALES'],
          _dailyRows.map((row) => [
            _date(row.salesDate), '${row.transactionCount}', _money(row.subtotal), _money(row.discount), _money(row.totalSales),
          ]).toList(),
          onRowTap: (index) => _drillIntoDaily(_dailyRows[index]),
        ),
      ],
    );
  }

  Widget _dailyPreview() => _summaryPreview();

  Widget _hourlyPreview() => _previewCard(children: [
        _kpiRow([
          _kpi('HOURS', '${_hourlyRows.length}'),
          _kpi('TRANSACTIONS', '${_hourlyRows.fold(0, (s, r) => s + r.transactionCount)}'),
          _kpi('ITEMS SOLD', '${_hourlyRows.fold(0, (s, r) => s + r.itemCount)}'),
          _kpi('TOTAL SALES', _money(_hourlyRows.fold<num>(0, (s, r) => s + r.totalSales))),
        ]),
        const SizedBox(height: 16),
        _dataTable(
          const ['HOUR', 'TRANSACTIONS', 'ITEMS SOLD', 'TOTAL SALES'],
          _hourlyRows.map((r) => [r.label, '${r.transactionCount}', '${r.itemCount}', _money(r.totalSales)]).toList(),
          onRowTap: (index) => _showDrilldown(
            'Hourly Sales',
            _hourlyRows[index].label,
            [
              _detail('Transactions', '${_hourlyRows[index].transactionCount}'),
              _detail('Items Sold', '${_hourlyRows[index].itemCount}'),
              _detail('Total Sales', _money(_hourlyRows[index].totalSales)),
            ],
          ),
        ),
      ]);

  Widget _paymentPreview() {
    num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
    final count = _paymentRows.fold<int>(0, (s, r) => s + n(r['paymentCount']).toInt());
    final total = _paymentRows.fold<num>(0, (s, r) => s + n(r['totalAmount']));
    return _previewCard(children: [
      _kpiRow([_kpi('PAYMENTS', '$count'), _kpi('PAYMENT METHODS', '${_paymentRows.length}'), _kpi('TOTAL PAID', _money(total)), _kpi('PERIOD', '${_date(_start)} → ${_date(_end)}')]),
      const SizedBox(height: 16),
      _dataTable(const ['PAYMENT METHOD', 'PAYMENTS', 'TOTAL PAID'], _paymentRows.map((r) => ['${r['paymentMethod'] ?? 'Unknown'}', '${n(r['paymentCount']).toInt()}', _money(n(r['totalAmount']))]).toList()),
    ]);
  }

  Widget _discountsPreview() {
    num n(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
    final discount = _discountChargeRows.fold<num>(0, (s, r) => s + n(r['discount']));
    final charges = _discountChargeRows.fold<num>(0, (s, r) => s + n(r['charges']));
    final sales = _discountChargeRows.fold<num>(0, (s, r) => s + n(r['totalSales']));
    return _previewCard(children: [
      _kpiRow([
        _kpi('DISCOUNTS', _money(discount)),
        _kpi('CHARGES', _money(charges)),
        _kpi('NET SALES', _money(sales)),
        _kpi('PERIOD', '${_date(_start)} → ${_date(_end)}'),
      ]),
      const SizedBox(height: 16),
      _dataTable(_currentTable().headers, _currentTable().rows),
    ]);
  }

  Widget _transactionsPreview() {
    final table = _currentTable();
    return _previewCard(children: [
      _kpiRow([_kpi('TRANSACTIONS', '${_transactionRows.length}'), _kpi('PERIOD', '${_date(_start)} → ${_date(_end)}')]),
      const SizedBox(height: 16),
      _dataTable(table.headers, table.rows.take(200).toList()),
    ]);
  }

  Widget _productPreview() {
    final rows = [..._productRows]..sort((a, b) => b.totalSales.compareTo(a.totalSales));
    return _previewCard(children: [
      _kpiRow([_kpi('PRODUCTS', '${rows.map((r) => r.productId).toSet().length}'), _kpi('ITEMS SOLD', '${rows.fold(0, (s, r) => s + r.quantitySold)}'), _kpi('TOTAL SALES', _money(rows.fold<num>(0, (s, r) => s + r.totalSales))), _kpi('PERIOD', '${_date(_start)} → ${_date(_end)}')]),
      const SizedBox(height: 16),
      _dataTable(
        const ['PRODUCT', 'CATEGORY', 'QTY SOLD', 'TOTAL SALES'],
        rows.take(50).map((r) => [r.productName, r.category, '${r.quantitySold}', _money(r.totalSales)]).toList(),
        onRowTap: (index) => _drillIntoProduct(rows.take(50).toList()[index]),
      ),
    ]);
  }

  Widget _productTypePreview() {
    final totals = <String, List<num>>{};
    for (final row in _productTypeRows) {
      final key = row.productType.trim().isEmpty ? 'Uncategorized' : row.productType.trim();
      final current = totals[key] ?? [0, 0];
      totals[key] = [current[0] + row.quantitySold, current[1] + row.totalSales];
    }
    final rows = totals.entries.toList()..sort((a, b) => b.value[1].compareTo(a.value[1]));
    final sales = rows.fold<num>(0, (s, r) => s + r.value[1]);
    return _previewCard(children: [
      _kpiRow([_kpi('PRODUCT TYPES', '${rows.length}'), _kpi('ITEMS SOLD', '${rows.fold<num>(0, (s, r) => s + r.value[0]).toInt()}'), _kpi('TOTAL SALES', _money(sales)), _kpi('PERIOD', '${_date(_start)} → ${_date(_end)}')]),
      const SizedBox(height: 16),
      _dataTable(
        const ['PRODUCT TYPE', 'QTY SOLD', 'TOTAL SALES', '% OF SALES'],
        rows.map((r) => [r.key, '${r.value[0].toInt()}', _money(r.value[1]), sales == 0 ? '0.0%' : '${(r.value[1] / sales * 100).toStringAsFixed(1)}%']).toList(),
        onRowTap: (index) => _showDrilldown(
          'Product Type Sales',
          rows[index].key,
          [
            _detail('Items Sold', '${rows[index].value[0].toInt()}'),
            _detail('Total Sales', _money(rows[index].value[1])),
            _detail('Share of Sales', sales == 0 ? '0.0%' : '${(rows[index].value[1] / sales * 100).toStringAsFixed(1)}%'),
          ],
        ),
      ),
    ]);
  }

  Widget _categoryPreview() {
    final totals = <String, List<num>>{};
    for (final row in _categoryRows) {
      final current = totals[row.category] ?? [0, 0];
      totals[row.category] = [current[0] + row.quantitySold, current[1] + row.totalSales];
    }
    final rows = totals.entries.toList()..sort((a, b) => b.value[1].compareTo(a.value[1]));
    final sales = rows.fold<num>(0, (s, r) => s + r.value[1]);
    return _previewCard(children: [
      _kpiRow([_kpi('CATEGORIES', '${rows.length}'), _kpi('ITEMS SOLD', '${rows.fold<num>(0, (s, r) => s + r.value[0]).toInt()}'), _kpi('TOTAL SALES', _money(sales)), _kpi('PERIOD', '${_date(_start)} → ${_date(_end)}')]),
      const SizedBox(height: 16),
      _dataTable(
        const ['CATEGORY', 'QTY SOLD', 'TOTAL SALES', '% OF SALES'],
        rows.map((r) => [r.key, '${r.value[0].toInt()}', _money(r.value[1]), sales == 0 ? '0.0%' : '${(r.value[1] / sales * 100).toStringAsFixed(1)}%']).toList(),
        onRowTap: (index) => _drillIntoCategory(rows[index].key),
      ),
    ]);
  }

  Widget _devicePreview() {
    final rows = <String, List<num>>{};
    for (final row in _deviceRows) {
      final current = rows[row.deviceId] ?? [0, 0, 0];
      rows[row.deviceId] = [current[0] + row.transactionCount, current[1] + row.totalSales, current[2] + row.discount];
    }
    final entries = rows.entries.toList()..sort((a, b) => b.value[1].compareTo(a.value[1]));
    return _previewCard(children: [
      _kpiRow([_kpi('DEVICES', '${entries.length}'), _kpi('TRANSACTIONS', '${entries.fold<num>(0, (s, r) => s + r.value[0]).toInt()}'), _kpi('TOTAL SALES', _money(entries.fold<num>(0, (s, r) => s + r.value[1]))), _kpi('PERIOD', '${_date(_start)} → ${_date(_end)}')]),
      const SizedBox(height: 16),
      _dataTable(
        const ['DEVICE', 'TRANSACTIONS', 'TOTAL SALES', 'DISCOUNT'],
        entries.map((r) => [r.key, '${r.value[0].toInt()}', _money(r.value[1]), _money(r.value[2])]).toList(),
        onRowTap: (index) => _drillIntoDevice(entries[index].key),
      ),
    ]);
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700))),
            Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900))),
          ],
        ),
      );

  Future<void> _showDrilldown(String title, String subtitle, List<Widget> details, {List<Widget> actions = const []}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(subtitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const Divider(height: 24),
              ...details,
            ],
          ),
        ),
        actions: [
          ...actions,
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CLOSE')),
        ],
      ),
    );
  }

  Future<void> _drillIntoDaily(ReportingDailySale row) async {
    await _showDrilldown(
      'Daily Sales',
      _date(row.salesDate),
      [
        _detail('Transactions', '${row.transactionCount}'),
        _detail('Subtotal', _money(row.subtotal)),
        _detail('Discount', _money(row.discount)),
        _detail('Total Sales', _money(row.totalSales)),
      ],
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            setState(() {
              _reportKey = 'hourly';
              _start = DateTime(row.salesDate.year, row.salesDate.month, row.salesDate.day);
              _end = _start;
            });
            await _load();
          },
          child: const Text('VIEW HOURLY'),
        ),
      ],
    );
  }

  Future<void> _drillIntoProduct(ReportingProductSale row) async {
    await _showDrilldown(
      'Product Sales',
      row.productName,
      [
        _detail('Category', row.category),
        _detail('Product ID', row.productId),
        _detail('Quantity Sold', '${row.quantitySold}'),
        _detail('Total Sales', _money(row.totalSales)),
        _detail('Average Unit Price', _money(row.averageUnitPrice)),
      ],
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            setState(() {
              _reportKey = 'product';
              _category = row.category;
            });
            await _load();
          },
          child: const Text('VIEW CATEGORY'),
        ),
      ],
    );
  }

  Future<void> _drillIntoCategory(String category) async {
    await _showDrilldown(
      'Category Sales',
      category,
      [
        _detail('Period', '${_date(_start)} → ${_date(_end)}'),
        _detail('Category', category),
      ],
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            setState(() {
              _reportKey = 'product';
              _category = category;
            });
            await _load();
          },
          child: const Text('VIEW PRODUCTS'),
        ),
      ],
    );
  }

  Future<void> _drillIntoDevice(String device) async {
    await _showDrilldown(
      'Sales by Device',
      device,
      [_detail('Device', device), _detail('Period', '${_date(_start)} → ${_date(_end)}')],
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            setState(() {
              _reportKey = 'product';
              _device = device;
              _category = 'ALL';
            });
            await _load();
          },
          child: const Text('VIEW PRODUCTS'),
        ),
      ],
    );
  }

  Widget _previewCard({required List<Widget> children}) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)));

  Widget _sectionTitle(String text) => Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: .8));

  Widget _kpiRow(List<Widget> children) => LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth >= 1000 ? (constraints.maxWidth - 36) / 4 : constraints.maxWidth >= 700 ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
        return Wrap(spacing: 12, runSpacing: 12, children: children.map((child) => SizedBox(width: width, child: child)).toList());
      });

  Widget _kpi(String label, String value) => Card(margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))])));

  Widget _dataTable(List<String> headers, List<List<String>> rows, {ValueChanged<int>? onRowTap}) {
    if (rows.isEmpty) return const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No sales records match the selected filters.')));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          ...headers.map((header) => DataColumn(label: Text(header))),
          if (onRowTap != null) const DataColumn(label: Text('DETAILS')),
        ],
        rows: List<DataRow>.generate(rows.length, (index) {
          final row = rows[index];
          return DataRow(
            cells: [
              ...row.map((value) => DataCell(Text(value))),
              if (onRowTap != null)
                DataCell(
                  IconButton(
                    tooltip: 'View details',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => onRowTap(index),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _messageCard(String title, String message) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center)])));
}

class _ReportOption {
  const _ReportOption(this.key, this.title, this.subtitle, this.icon);
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _ReportTable {
  const _ReportTable(this.headers, this.rows);
  final List<String> headers;
  final List<List<String>> rows;
}
