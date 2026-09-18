import 'package:flutter/material.dart';

import '../../core/currency/store_currency.dart';
import 'reporting_api_service.dart';

class CategorySalesPage extends StatefulWidget {
  const CategorySalesPage({super.key});
  @override
  State<CategorySalesPage> createState() => _CategorySalesPageState();
}

class _CategorySalesPageState extends State<CategorySalesPage> {
  final _api = ReportingApiService();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  String _device = 'ALL';
  bool _loading = false;
  String? _error;
  List<ReportingCategorySale> _rows = const [];

  @override
  void initState() { super.initState(); _load(); }
  String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await _api.getCategorySales(startDate: _start, endDate: _end, deviceId: _device == 'ALL' ? null : _device);
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _pick(bool start) async {
    final picked = await showDatePicker(context: context, initialDate: start ? _start : _end, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked == null || !mounted) return;
    setState(() { if (start) { _start = picked; if (_start.isAfter(_end)) _end = picked; } else { _end = picked; if (_end.isBefore(_start)) _start = picked; } });
    await _load();
  }

  List<String> get _devices => ['ALL', ...(_rows.map((e) => e.deviceId).where((e) => e.isNotEmpty).toSet().toList()..sort())];
  Map<String, _CategoryTotal> get _totals {
    final result = <String, _CategoryTotal>{};
    for (final row in _rows) {
      final current = result[row.category];
      result[row.category] = _CategoryTotal(
        quantity: (current?.quantity ?? 0) + row.quantitySold,
        sales: (current?.sales ?? 0) + row.totalSales,
      );
    }
    return result;
  }
  int get _qty => _totals.values.fold(0, (s, r) => s + r.quantity);
  num get _sales => _totals.values.fold<num>(0, (s, r) => s + r.sales);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F2ED),
    appBar: AppBar(backgroundColor: const Color(0xFF171717), foregroundColor: Colors.white, title: const Text('CATEGORY SALES', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))]),
    body: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(20), children: [
      const Icon(Icons.category_outlined, size: 64, color: Color(0xFFC69214)), const SizedBox(height: 6),
      const Text('CATEGORY SALES', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 18),
      _filters(), const SizedBox(height: 18),
      if (_error != null) _card('REPORTING ERROR', _error!),
      if (_loading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
      if (!_loading && _error == null) _body(),
    ])),
  );

  Widget _filters() => Card(child: Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
    OutlinedButton.icon(onPressed: () => _pick(true), icon: const Icon(Icons.calendar_today_outlined), label: Text('FROM ${_date(_start)}')),
    OutlinedButton.icon(onPressed: () => _pick(false), icon: const Icon(Icons.calendar_today_outlined), label: Text('TO ${_date(_end)}')),
    SizedBox(width: 180, child: DropdownButtonFormField<String>(initialValue: _devices.contains(_device) ? _device : 'ALL', decoration: const InputDecoration(labelText: 'Kiosk'), items: _devices.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) async { if (v == null) return; setState(() => _device = v); await _load(); })),
  ])));

  Widget _body() {
    if (_totals.isEmpty) return _card('NO CATEGORY SALES', 'No category sales match the selected filters.');
    final rows = _totals.entries.toList()..sort((a, b) => b.value.sales.compareTo(a.value.sales));
    return Column(children: [
      Row(children: [Expanded(child: _summary('CATEGORIES', '${rows.length}')), const SizedBox(width: 12), Expanded(child: _summary('ITEMS SOLD', '$_qty')), const SizedBox(width: 12), Expanded(child: _summary('TOTAL SALES', StoreCurrency.format(_sales)))]),
      const SizedBox(height: 18),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
        columns: const [DataColumn(label: Text('CATEGORY')), DataColumn(label: Text('QTY SOLD')), DataColumn(label: Text('TOTAL SALES')), DataColumn(label: Text('% OF SALES'))],
        rows: rows.map((e) => DataRow(cells: [DataCell(Text(e.key)), DataCell(Text('${e.value.quantity}')), DataCell(Text(StoreCurrency.format(e.value.sales))), DataCell(Text(_sales == 0 ? '0.0%' : '${(e.value.sales / _sales * 100).toStringAsFixed(1)}%'))])).toList(),
      )))),
    ]);
  }
  Widget _summary(String label, String value) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))])));
  Widget _card(String title, String message) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(message, textAlign: TextAlign.center)])));
}

class _CategoryTotal { const _CategoryTotal({required this.quantity, required this.sales}); final int quantity; final num sales; }
