import 'package:flutter/material.dart';
import '../../core/auth/store_management_auth.dart';

class PaymentSummaryPage extends StatefulWidget {
  const PaymentSummaryPage({super.key});

  @override
  State<PaymentSummaryPage> createState() => _PaymentSummaryPageState();
}

class _PaymentSummaryPageState extends State<PaymentSummaryPage> {
  final _auth = const StoreManagementAuth();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  num _num(dynamic value) =>
      value is num ? value : num.tryParse('$value') ?? 0;

  String _money(num value) => '₱${value.toStringAsFixed(2)}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _auth.client.rpc(
        'get_store_payment_summary',
        params: {
          'p_start_date': _date(_start),
          'p_end_date': _date(_end),
        },
      );
      final list = result is List ? result : const <dynamic>[];
      if (!mounted) return;
      setState(() {
        _rows = list
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);
      });
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

  int get _count => _rows.fold(0, (sum, row) => sum + (_num(row['paymentCount']).toInt()));
  num get _total => _rows.fold<num>(0, (sum, row) => sum + _num(row['totalAmount']));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF5F2ED),
        appBar: AppBar(
          backgroundColor: const Color(0xFF171717),
          foregroundColor: Colors.white,
          title: const Text(
            'PAYMENT SUMMARY',
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
              const Icon(Icons.payments_outlined, size: 64, color: Color(0xFFC69214)),
              const SizedBox(height: 6),
              const Text(
                'PAYMENT SUMMARY',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Store ${_auth.storeId}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
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
            ],
          ),
        ),
      );

  Widget _body() {
    if (_rows.isEmpty) {
      return _card('NO PAYMENTS FOUND', 'No payments match the selected date range.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _summary('PAYMENTS', '$_count')),
            const SizedBox(width: 12),
            Expanded(child: _summary('TOTAL PAID', _money(_total))),
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
                  DataColumn(label: Text('PAYMENT METHOD')),
                  DataColumn(label: Text('PAYMENTS')),
                  DataColumn(label: Text('TOTAL PAID')),
                ],
                rows: _rows
                    .map(
                      (row) => DataRow(
                        cells: [
                          DataCell(Text('${row['paymentMethod'] ?? 'Unknown'}')),
                          DataCell(Text('${_num(row['paymentCount']).toInt()}')),
                          DataCell(Text(_money(_num(row['totalAmount'])))),
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
