import 'package:flutter/material.dart';

import '../../core/auth/store_management_auth.dart';
import 'inventory_receiving_page.dart';

class InventoryLowStockPage extends StatefulWidget {
  const InventoryLowStockPage({super.key});

  @override
  State<InventoryLowStockPage> createState() => _InventoryLowStockPageState();
}

class _InventoryLowStockPageState extends State<InventoryLowStockPage> {
  final _auth = const StoreManagementAuth();
  final _search = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _auth.client.rpc('get_store_inventory_stock_levels');
      final rows = (result as List?) ?? const [];

      final items = rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .where((item) => item['is_low_stock'] == true)
          .toList();

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _items;

    return _items.where((item) {
      return ['name', 'category', 'unit']
          .any((key) => (item[key]?.toString().toLowerCase() ?? '').contains(q));
    }).toList();
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _format(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  void _openReceiving() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InventoryReceivingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        title: const Text('LOW STOCK'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'LOW STOCK',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Items at or below their reorder level • Store ${_auth.storeId}',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const CircleAvatar(
                    child: Icon(Icons.warning_amber_outlined),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ITEMS NEEDING ATTENTION',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_items.length}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openReceiving,
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('RECEIVING'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search low-stock items',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Unable to load low-stock items'),
                subtitle: Text(_error!),
                trailing: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            )
          else if (filtered.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 48),
                    const SizedBox(height: 10),
                    const Text(
                      'No low-stock items',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _items.isEmpty
                          ? 'All active inventory items are above their reorder levels.'
                          : 'No low-stock item matches your search.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map(_card),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final quantity = _number(item['current_quantity']);
    final reorder = _number(item['reorder_level']);
    final shortage = reorder - quantity;
    final unit = item['unit']?.toString().trim() ?? '';
    final category = item['category']?.toString().trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(
              child: Icon(Icons.warning_amber_outlined),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text([
                    if (category.isNotEmpty) category,
                    if (unit.isNotEmpty) 'Unit: $unit',
                  ].join(' • ')),
                  const SizedBox(height: 8),
                  Text(
                    'Current: ${_format(quantity)}${unit.isEmpty ? '' : ' $unit'}'
                    '   •   Reorder: ${_format(reorder)}${unit.isEmpty ? '' : ' $unit'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (shortage > 0)
                    Text(
                      'Below reorder level by ${_format(shortage)}${unit.isEmpty ? '' : ' $unit'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.deepOrange,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _openReceiving,
              icon: const Icon(Icons.add),
              label: const Text('RECEIVE'),
            ),
          ],
        ),
      ),
    );
  }
}
