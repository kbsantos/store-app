import 'package:flutter/material.dart';

import '../../core/auth/store_management_auth.dart';

class InventoryMovementsPage extends StatefulWidget {
  const InventoryMovementsPage({super.key});

  @override
  State<InventoryMovementsPage> createState() => _InventoryMovementsPageState();
}

class _InventoryMovementsPageState extends State<InventoryMovementsPage> {
  final _auth = const StoreManagementAuth();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _movements = [];
  bool _loading = true;
  String? _error;
  String _typeFilter = 'all';

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
      final result = await _auth.client.rpc('get_store_inventory_movements');
      final rows = (result as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _movements = rows
            .map((row) => Map<String, dynamic>.from(row as Map))
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
    return _movements.where((movement) {
      final type = movement['movement_type']?.toString().toLowerCase() ?? '';
      if (_typeFilter != 'all' && type != _typeFilter) return false;
      if (q.isEmpty) return true;
      return ['item_name', 'category', 'unit', 'movement_type', 'note']
          .any((key) => (movement[key]?.toString().toLowerCase() ?? '').contains(q));
    }).toList();
  }

  int _count(String type) =>
      _movements.where((m) => m['movement_type']?.toString().toLowerCase() == type).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        title: const Text('INVENTORY MOVEMENTS'),
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
            'INVENTORY MOVEMENTS',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text('Store ${_auth.storeId}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          if (!_loading && _error == null)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _summaryCard(Icons.receipt_long_outlined, 'TOTAL', '${_movements.length}'),
                _summaryCard(Icons.local_shipping_outlined, 'RECEIVED', '${_count('stock_in')}'),
                _summaryCard(Icons.tune_outlined, 'ADJUSTMENTS', '${_count('adjustment')}'),
                _summaryCard(Icons.delete_sweep_outlined, 'WASTAGE', '${_count('waste')}'),
                _summaryCard(Icons.restaurant_outlined, 'USAGE', '${_count('usage')}'),
              ],
            ),
          const SizedBox(height: 18),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search movements',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _typeFilter,
            decoration: const InputDecoration(
              labelText: 'Movement type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All movements')),
              DropdownMenuItem(value: 'stock_in', child: Text('Stock received')),
              DropdownMenuItem(value: 'adjustment', child: Text('Adjustments')),
              DropdownMenuItem(value: 'waste', child: Text('Wastage')),
              DropdownMenuItem(value: 'usage', child: Text('Usage')),
            ],
            onChanged: (value) => setState(() => _typeFilter = value ?? 'all'),
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
                title: const Text('Unable to load inventory movements'),
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
                    Icon(Icons.receipt_long_outlined, size: 48),
                    SizedBox(height: 10),
                    Text(
                      'No inventory movements found',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text('Receiving, adjustments and wastage will appear here.'),
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

  Widget _card(Map<String, dynamic> movement) {
    final type = movement['movement_type']?.toString().toLowerCase() ?? '';
    final quantity = _number(movement['quantity']);
    final unit = movement['unit']?.toString().trim() ?? '';
    final note = movement['note']?.toString().trim() ?? '';
    final recordedAt = movement['recorded_at']?.toString() ?? '';
    final itemName = movement['item_name']?.toString() ?? 'Unknown item';
    final category = movement['category']?.toString().trim() ?? '';
    final signed = type == 'stock_in' ? quantity : type == 'usage' || type == 'waste' ? -quantity : quantity;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(child: Icon(_icon(type))),
        title: Text(itemName, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text([
          _label(type),
          if (category.isNotEmpty) category,
          if (recordedAt.isNotEmpty) _formatDate(recordedAt),
          if (note.isNotEmpty) note,
        ].join(' • ')),
        trailing: Text(
          '${signed >= 0 ? '+' : ''}${_format(signed)}${unit.isEmpty ? '' : ' $unit'}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'stock_in':
        return Icons.add_box_outlined;
      case 'adjustment':
        return Icons.tune_outlined;
      case 'waste':
        return Icons.delete_sweep_outlined;
      case 'usage':
        return Icons.restaurant_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  String _label(String type) {
    switch (type) {
      case 'stock_in':
        return 'RECEIVED';
      case 'adjustment':
        return 'ADJUSTMENT';
      case 'waste':
        return 'WASTAGE';
      case 'usage':
        return 'USAGE';
      default:
        return type.isEmpty ? 'MOVEMENT' : type.toUpperCase();
    }
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)} ${two(parsed.hour)}:${two(parsed.minute)}';
  }
}
