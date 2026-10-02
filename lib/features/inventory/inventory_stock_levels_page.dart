import 'package:flutter/material.dart';

import '../../core/auth/store_management_auth.dart';

class InventoryStockLevelsPage extends StatefulWidget {
  const InventoryStockLevelsPage({super.key});

  @override
  State<InventoryStockLevelsPage> createState() => _InventoryStockLevelsPageState();
}

class _InventoryStockLevelsPageState extends State<InventoryStockLevelsPage> {
  final _auth = const StoreManagementAuth();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _levels = [];
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
      if (!mounted) return;
      setState(() {
        _levels = rows
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
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
    if (q.isEmpty) return _levels;
    return _levels.where((i) {
      return ['name', 'category', 'unit', 'stock_status'].any(
        (key) => (i[key]?.toString().toLowerCase() ?? '').contains(q),
      );
    }).toList();
  }

  int get _lowStockCount => _levels.where((i) => i['is_low_stock'] == true).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        title: const Text('STOCK LEVELS'),
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
            'STOCK LEVELS',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Store ${_auth.storeId}',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          if (!_loading && _error == null)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _summaryCard(
                  Icons.inventory_2_outlined,
                  'ITEMS',
                  '${_levels.length}',
                ),
                _summaryCard(
                  Icons.warning_amber_outlined,
                  'LOW STOCK',
                  '$_lowStockCount',
                ),
              ],
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search stock levels',
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
                title: const Text('Unable to load stock levels'),
                subtitle: Text('$_error'),
                trailing: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            )
          else if (_filtered.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48),
                    SizedBox(height: 10),
                    Text(
                      'No stock items found',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text('Add active inventory items to start tracking stock.'),
                  ],
                ),
              ),
            )
          else
            ..._filtered.map(_card),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _summaryCard(IconData icon, String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final quantity = _number(item['current_quantity']);
    final reorder = _number(item['reorder_level']);
    final low = item['is_low_stock'] == true;
    final category = item['category']?.toString().trim() ?? '';
    final unit = item['unit']?.toString().trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          child: Icon(low ? Icons.warning_amber_outlined : Icons.inventory_2_outlined),
        ),
        title: Text(
          item['name']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text([
          if (category.isNotEmpty) category,
          'Reorder: ${_format(reorder)}${unit.isEmpty ? '' : ' $unit'}',
        ].join(' • ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${_format(quantity)}${unit.isEmpty ? '' : ' $unit'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            Text(
              low ? 'LOW STOCK' : 'IN STOCK',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: low ? Colors.deepOrange : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
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
}
