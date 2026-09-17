import 'package:flutter/material.dart';
import 'reporting_api_service.dart';

class ReportingDashboardPage extends StatefulWidget {
  const ReportingDashboardPage({super.key});
  @override
  State<ReportingDashboardPage> createState() => _ReportingDashboardPageState();
}

class _ReportingDashboardPageState extends State<ReportingDashboardPage> {
  final _api = ReportingApiService();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String _selectedCategory = 'ALL';
  String _deviceId = 'ALL';
  bool _loading = false;
  String? _error;
  List<ReportingProductSale> _rows = const [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await _api.getProductSales(startDate: _startDate, endDate: _endDate, category: _selectedCategory, deviceId: _deviceId == 'ALL' ? null : _deviceId);
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(context: context, initialDate: start ? _startDate : _endDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (picked == null || !mounted) return;
    setState(() {
      if (start) { _startDate = picked; if (_startDate.isAfter(_endDate)) _endDate = picked; }
      else { _endDate = picked; if (_endDate.isBefore(_startDate)) _startDate = picked; }
    });
    await _load();
  }

  String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _money(num v) => '₱${v.toStringAsFixed(2)}';
  List<String> get _categories => ['ALL', ...(_rows.map((e) => e.category).toSet().toList()..sort())];
  List<String> get _devices => ['ALL', ...(_rows.map((e) => e.deviceId).where((e) => e.isNotEmpty).toSet().toList()..sort())];
  Map<String, List<ReportingProductSale>> get _grouped { final result = <String, List<ReportingProductSale>>{}; for (final row in _rows) { result.putIfAbsent(row.category, () => []).add(row); } return result; }
  int get _qty => _rows.fold(0, (s, r) => s + r.quantitySold);
  num get _sales => _rows.fold<num>(0, (s, r) => s + r.totalSales);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F2ED),
    appBar: AppBar(backgroundColor: const Color(0xFF171717), foregroundColor: Colors.white, title: const Text('SALES REPORTING', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))]),
    body: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(20), children: [
      const Icon(Icons.bar_chart_outlined, size: 64, color: Color(0xFFC69214)),
      const SizedBox(height: 6),
      const Text('SALES REPORTING', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      const SizedBox(height: 18),
      _filters(),
      const SizedBox(height: 18),
      if (_error != null) _card('REPORTING ERROR', _error!),
      if (_loading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
      if (!_loading && _error == null) _body(),
    ])),
  );

  Widget _filters() => Card(child: Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
    OutlinedButton.icon(onPressed: () => _pickDate(true), icon: const Icon(Icons.calendar_today_outlined), label: Text('FROM ${_date(_startDate)}')),
    OutlinedButton.icon(onPressed: () => _pickDate(false), icon: const Icon(Icons.calendar_today_outlined), label: Text('TO ${_date(_endDate)}')),
    DropdownButton<String>(value: _categories.contains(_selectedCategory) ? _selectedCategory : 'ALL', items: _categories.map((v) => DropdownMenuItem(value: v, child: Text(v == 'ALL' ? 'ALL CATEGORIES' : v))).toList(), onChanged: (v) async { if (v == null) return; setState(() => _selectedCategory = v); await _load(); }),
    DropdownButton<String>(value: _devices.contains(_deviceId) ? _deviceId : 'ALL', items: _devices.map((v) => DropdownMenuItem(value: v, child: Text(v == 'ALL' ? 'ALL KIOSKS' : v))).toList(), onChanged: (v) async { if (v == null) return; setState(() => _deviceId = v); await _load(); }),
  ])));

  Widget _body() {
    if (_rows.isEmpty) return _card('NO SALES FOUND', 'No sales records match the selected filters.');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: _summary('ITEMS SOLD', '$_qty')), const SizedBox(width: 12), Expanded(child: _summary('TOTAL SALES', _money(_sales)))]),
      const SizedBox(height: 18),
      ..._grouped.entries.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 14), child: _category(entry.key, entry.value))),
    ]);
  }

  Widget _category(String name, List<ReportingProductSale> rows) {
    final qty = rows.fold(0, (s, r) => s + r.quantitySold);
    final sales = rows.fold<num>(0, (s, r) => s + r.totalSales);
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))), Text('Qty $qty  •  ${_money(sales)}', style: const TextStyle(fontWeight: FontWeight.w700))]),
      const Divider(),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(columns: const [DataColumn(label: Text('PRODUCT')), DataColumn(label: Text('QTY')), DataColumn(label: Text('TOTAL SALES')), DataColumn(label: Text('AVG. UNIT PRICE'))], rows: rows.map((r) => DataRow(cells: [DataCell(Text(r.productName)), DataCell(Text('${r.quantitySold}')), DataCell(Text(_money(r.totalSales))), DataCell(Text(_money(r.averageUnitPrice)))] )).toList())),
    ])));
  }

  Widget _summary(String label, String value) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))])));
  Widget _card(String title, String message) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(message, textAlign: TextAlign.center)])));
}
