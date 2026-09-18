import 'package:flutter/material.dart';
import '../../core/auth/store_management_auth.dart';

class SalesTransactionsPage extends StatefulWidget {
  const SalesTransactionsPage({super.key});

  @override
  State<SalesTransactionsPage> createState() => _SalesTransactionsPageState();
}

class _SalesTransactionsPageState extends State<SalesTransactionsPage> {
  final _auth = const StoreManagementAuth();
  final _search = TextEditingController();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  String _status = 'ALL';
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _date(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  num _num(dynamic value) {
    if (value is num) return value;
    return num.tryParse('$value') ?? 0;
  }

  String _money(dynamic value) => '₱${_num(value).toStringAsFixed(2)}';

  String _first(Map<String, dynamic> map, List<String> keys, [String fallback = '']) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && '$value'.trim().isNotEmpty) return '$value';
    }
    return fallback;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _auth.client.rpc(
        'get_store_sales_transactions',
        params: {
          'p_start_date': _date(_start),
          'p_end_date': _date(_end),
          'p_search': _search.text.trim().isEmpty ? null : _search.text.trim(),
          'p_status': _status == 'ALL' ? null : _status,
        },
      );

      if (!mounted) return;
      final list = result is List ? result : <dynamic>[];
      setState(() {
        _rows = list
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
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

  Future<void> _openDetail(Map<String, dynamic> row) async {
    try {
      final result = await _auth.client.rpc(
        'get_store_sales_transaction_detail',
        params: {'p_transaction_id': row['id']},
      );
      if (!mounted) return;
      final data = Map<String, dynamic>.from(result as Map);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => _buildDetailDialog(dialogContext, data),
      );
    } catch (e) {
      if (mounted) _message('Unable to load transaction: $e');
    }
  }

  AlertDialog _buildDetailDialog(BuildContext dialogContext, Map<String, dynamic> data) {
    final tx = Map<String, dynamic>.from(data['transaction'] as Map? ?? {});
    final items = (data['items'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final payments = (data['payments'] as List? ?? [])
        .map((payment) => Map<String, dynamic>.from(payment as Map))
        .toList();

    final itemWidgets = <Widget>[];
    for (final item in items) {
      itemWidgets.add(
        ListTile(
          dense: true,
          title: Text(_first(item, ['product_name', 'name', 'product_id'], 'Item')),
          subtitle: Text('Qty: ${_first(item, ['quantity', 'qty'], '0')}'),
          trailing: Text(
            _money(_first(item, ['subtotal', 'total', 'amount', 'price'], '0')),
          ),
        ),
      );
    }

    final paymentWidgets = <Widget>[];
    for (final payment in payments) {
      paymentWidgets.add(
        ListTile(
          dense: true,
          title: Text(_first(payment, ['payment_method', 'payment_type', 'method'], 'Payment')),
          trailing: Text(
            _money(_first(payment, ['amount', 'total', 'paid'], '0')),
          ),
        ),
      );
    }

    final contentWidgets = <Widget>[
      Text('ID: ${_first(tx, ['id'])}'),
      Text('Status: ${_first(tx, ['status', 'transaction_status', 'payment_status'], '—')}'),
      Text('Payment: ${_first(tx, ['payment_method', 'payment_type'], '—')}'),
      const Divider(),
      const Text('ITEMS', style: TextStyle(fontWeight: FontWeight.w900)),
      ...itemWidgets,
    ];

    if (paymentWidgets.isNotEmpty) {
      contentWidgets.add(const Divider());
      contentWidgets.add(
        const Text('PAYMENTS', style: TextStyle(fontWeight: FontWeight.w900)),
      );
      contentWidgets.addAll(paymentWidgets);
    }

    return AlertDialog(
      title: Text(_first(
        tx,
        ['order_number', 'transaction_number', 'receipt_number', 'reference_number'],
        'TRANSACTION',
      )),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: contentWidgets,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('CLOSE'),
        ),
      ],
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        title: const Text('SALES TRANSACTIONS'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'SALES TRANSACTIONS',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text('Store ${_auth.storeId}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(true),
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(_date(_start)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(false),
                          icon: const Icon(Icons.event_outlined),
                          label: Text(_date(_end)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            labelText: 'Search transaction / order / kiosk',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onSubmitted: (_) => _load(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: const [
                            'ALL',
                            'completed',
                            'paid',
                            'cancelled',
                            'refunded',
                            'closed',
                          ]
                              .map(
                                (status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status.toUpperCase()),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _status = value);
                              _load();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _loading ? null : _load,
                        child: const Text('APPLY'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Unable to load transactions'),
                subtitle: Text(_error!),
              ),
            ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_rows.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('No transactions found for the selected filters.'),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: _rows.map((row) {
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.receipt_long_outlined),
                    ),
                    title: Text(
                      row['referenceNo']?.toString() ?? row['id'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${row['dateValue'] ?? ''}  •  ${row['deviceId'] ?? 'Kiosk'}  •  ${row['itemCount'] ?? 0} item(s)\n${row['status'] ?? ''}  •  ${row['paymentMethod'] ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      _money(row['total']),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () => _openDetail(row),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
