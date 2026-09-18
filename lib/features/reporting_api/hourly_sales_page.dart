import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HourlySalesPage extends StatefulWidget {
  const HourlySalesPage({super.key});

  @override
  State<HourlySalesPage> createState() => _HourlySalesPageState();
}

class _HourlySalesPageState extends State<HourlySalesPage> {
  final _client = Supabase.instance.client;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _loading = false;
  String? _error;
  List<HourlySale> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _client.rpc(
        'get_store_hourly_sales',
        params: {
          'p_start_date': _dateOnly(_startDate),
          'p_end_date': _dateOnly(_endDate),
        },
      );
      final list = (result as List<dynamic>)
          .map((e) => HourlySale.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (!mounted) return;
      setState(() => _rows = list);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = picked;
        if (_startDate.isAfter(_endDate)) _endDate = picked;
      } else {
        _endDate = picked;
        if (_endDate.isBefore(_startDate)) _startDate = picked;
      }
    });
    await _load();
  }

  String _dateOnly(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _money(num value) => '₱${value.toStringAsFixed(2)}';

  num get _sales => _rows.fold<num>(0, (sum, row) => sum + row.totalSales);
  int get _transactions => _rows.fold(0, (sum, row) => sum + row.transactionCount);
  int get _items => _rows.fold(0, (sum, row) => sum + row.itemCount);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF5F2ED),
        appBar: AppBar(
          backgroundColor: const Color(0xFF171717),
          foregroundColor: Colors.white,
          title: const Text(
            'HOURLY SALES',
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
              const Icon(Icons.schedule_outlined, size: 64, color: Color(0xFFC69214)),
              const SizedBox(height: 6),
              const Text(
                'HOURLY SALES',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
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

  Widget _filters() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickDate(true),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('FROM ${_dateOnly(_startDate)}'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(false),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('TO ${_dateOnly(_endDate)}'),
              ),
            ],
          ),
        ),
      );

  Widget _body() {
    if (_rows.isEmpty) {
      return _card('NO SALES FOUND', 'No sales records match the selected filters.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _summary('TRANSACTIONS', '$_transactions')),
            const SizedBox(width: 12),
            Expanded(child: _summary('ITEMS SOLD', '$_items')),
            const SizedBox(width: 12),
            Expanded(child: _summary('TOTAL SALES', _money(_sales))),
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
                  DataColumn(label: Text('HOUR')),
                  DataColumn(label: Text('TRANSACTIONS')),
                  DataColumn(label: Text('ITEMS SOLD')),
                  DataColumn(label: Text('TOTAL SALES')),
                ],
                rows: _rows
                    .map(
                      (row) => DataRow(
                        cells: [
                          DataCell(Text(row.label)),
                          DataCell(Text('${row.transactionCount}')),
                          DataCell(Text('${row.itemCount}')),
                          DataCell(Text(_money(row.totalSales))),
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
              Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );

  Widget _card(String title, String message) => Card(
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

class HourlySale {
  const HourlySale({
    required this.hour,
    required this.label,
    required this.transactionCount,
    required this.itemCount,
    required this.totalSales,
  });

  final int hour;
  final String label;
  final int transactionCount;
  final int itemCount;
  final num totalSales;

  factory HourlySale.fromMap(Map<String, dynamic> map) => HourlySale(
        hour: _toInt(map['hour']),
        label: '${map['label'] ?? ''}',
        transactionCount: _toInt(map['transactionCount']),
        itemCount: _toInt(map['itemCount']),
        totalSales: _toNum(map['totalSales']),
      );
}

int _toInt(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
num _toNum(dynamic value) => value is num ? value : num.tryParse('$value') ?? 0;
