import 'package:flutter/material.dart';

import '../../core/currency/store_currency.dart';
import 'reporting_api_service.dart';
import 'reporting_pdf_service.dart';
import 'reporting_pdf_viewer.dart';

class ProductTypeSalesPage extends StatefulWidget {
  const ProductTypeSalesPage({super.key});

  @override
  State<ProductTypeSalesPage> createState() => _ProductTypeSalesPageState();
}

class _ProductTypeSalesPageState extends State<ProductTypeSalesPage> {
  final _api = ReportingApiService();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  String _device = 'ALL';
  bool _loading = false;
  String? _error;
  List<ReportingProductTypeSale> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.getProductTypeSales(
        startDate: _start,
        endDate: _end,
        deviceId: _device == 'ALL' ? null : _device,
      );
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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

  List<String> get _devices => [
        'ALL',
        ...(_rows
              .map((row) => row.deviceId)
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort()),
      ];

  Map<String, _ProductTypeTotal> get _totals {
    final result = <String, _ProductTypeTotal>{};
    for (final row in _rows) {
      final key = row.productType.trim().isEmpty
          ? 'Uncategorized'
          : row.productType.trim();
      final current = result[key];
      result[key] = _ProductTypeTotal(
        quantity: (current?.quantity ?? 0) + row.quantitySold,
        sales: (current?.sales ?? 0) + row.totalSales,
      );
    }
    return result;
  }

  int get _qty => _totals.values.fold(0, (sum, row) => sum + row.quantity);

  num get _sales =>
      _totals.values.fold<num>(0, (sum, row) => sum + row.sales);

  String _productTypeTitle(String value) {
    switch (value.trim()) {
      case 'drink':
        return 'Drink';
      case 'food':
        return 'Food';
      case 'accessory':
        return 'Accessory';
      case 'addOn':
      case 'addon':
      case 'add-on':
        return 'Add-on';
      case 'Uncategorized':
        return 'Uncategorized';
      default:
        if (value.trim().isEmpty) return 'Uncategorized';
        final normalized = value.trim();
        return normalized[0].toUpperCase() + normalized.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF5F2ED),
        appBar: AppBar(
          backgroundColor: const Color(0xFF171717),
          foregroundColor: Colors.white,
          title: const Text(
            'PRODUCT TYPE SALES',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(
                Icons.account_tree_outlined,
                size: 64,
                color: Color(0xFFC69214),
              ),
              const SizedBox(height: 6),
              const Text(
                'PRODUCT TYPE SALES',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sales performance grouped by product type',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 18),
              _filters(),
              const SizedBox(height: 18),
              if (_error != null) _card('REPORTING ERROR', _error!),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_loading && _error == null) _body(),
            ],
          ),
        ),
      );

  Future<void> _viewPdf() async {
    if (_loading) return;
    final filename =
        'product_type_sales_${_date(_start)}_${_date(_end)}.pdf';
    await ReportingPdfViewer.show(
      context: context,
      filename: filename,
      build: (_) => StoreReportingPdfService.buildProductTypeSales(
        storeId: _rows.isNotEmpty ? _rows.first.storeId : 'Store',
        startDate: _start,
        endDate: _end,
        rows: _rows,
        device: _device,
      ),
    );
  }

  Widget _filters() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pick(true),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('FROM ${_date(_start)}'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pick(false),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('TO ${_date(_end)}'),
              ),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue:
                      _devices.contains(_device) ? _device : 'ALL',
                  decoration: const InputDecoration(labelText: 'Kiosk'),
                  items: _devices
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) return;
                    setState(() => _device = value);
                    await _load();
                  },
                ),
              ),
              IconButton(
                tooltip: 'View PDF',
                onPressed: _loading ? null : _viewPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
              ),
            ],
          ),
        ),
      );

  Widget _body() {
    if (_totals.isEmpty) {
      return _card(
        'NO PRODUCT TYPE SALES',
        'No product type sales match the selected filters.',
      );
    }

    final rows = _totals.entries.toList()
      ..sort((a, b) => b.value.sales.compareTo(a.value.sales));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _summary('PRODUCT TYPES', '${rows.length}')),
            const SizedBox(width: 12),
            Expanded(child: _summary('ITEMS SOLD', '$_qty')),
            const SizedBox(width: 12),
            Expanded(
              child: _summary('TOTAL SALES', StoreCurrency.format(_sales)),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('PRODUCT TYPE')),
                  DataColumn(label: Text('QTY SOLD')),
                  DataColumn(label: Text('TOTAL SALES')),
                  DataColumn(label: Text('% OF SALES')),
                ],
                rows: rows
                    .map(
                      (entry) => DataRow(
                        cells: [
                          DataCell(Text(_productTypeTitle(entry.key))),
                          DataCell(Text('${entry.value.quantity}')),
                          DataCell(
                            Text(StoreCurrency.format(entry.value.sales)),
                          ),
                          DataCell(
                            Text(
                              _sales == 0
                                  ? '0.0%'
                                  : '${(entry.value.sales / _sales * 100).toStringAsFixed(1)}%',
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summary(String label, String value) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      );

  Widget _card(String title, String message) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _ProductTypeTotal {
  const _ProductTypeTotal({required this.quantity, required this.sales});

  final int quantity;
  final num sales;
}
