import 'package:flutter/material.dart';

import '../../core/auth/store_management_auth.dart';

class InventoryAdjustmentsPage extends StatefulWidget {
  const InventoryAdjustmentsPage({super.key});

  @override
  State<InventoryAdjustmentsPage> createState() => _InventoryAdjustmentsPageState();
}

class _InventoryAdjustmentsPageState extends State<InventoryAdjustmentsPage> {
  final _auth = const StoreManagementAuth();
  final _countController = TextEditingController();
  final _reasonController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  double? _currentQuantity;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _canEdit => _auth.canManageInventory;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _countController.dispose();
    _reasonController.dispose();
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
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        if (_selected != null) {
          final id = _selected!['id'];
          _selected = items.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['id'] == id,
            orElse: () => null,
          );
          _currentQuantity = _selected == null
              ? null
              : _number(_selected!['current_quantity']);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _adjust() async {
    if (!_canEdit || _selected == null) return;
    final count = num.tryParse(_countController.text.trim());
    if (count == null || count < 0) {
      _message('Enter a physical count of zero or greater.');
      return;
    }

    final current = _currentQuantity ?? 0;
    final delta = count.toDouble() - current;
    if (delta == 0) {
      _message('No adjustment is required; physical count matches current stock.');
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await _auth.client.rpc(
        'adjust_store_inventory_stock',
        params: {
          'p_inventory_item_id': _selected!['id'],
          'p_counted_quantity': count,
          'p_reason': _reasonController.text.trim().isEmpty
              ? null
              : _reasonController.text.trim(),
        },
      );
      if (!mounted) return;
      _countController.clear();
      _reasonController.clear();
      await _load();
      final data = Map<String, dynamic>.from(result as Map);
      _message(
        'Stock adjusted by ${_format(_number(data['adjustment_quantity']))} ${_unit(_selected)}.',
      );
    } catch (e) {
      if (mounted) _message('Unable to adjust stock: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _select(Map<String, dynamic>? value) {
    setState(() {
      _selected = value;
      _currentQuantity = value == null ? null : _number(value['current_quantity']);
      _countController.clear();
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _unit(Map<String, dynamic>? item) => item?['unit']?.toString().trim() ?? '';

  String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final unit = _unit(_selected);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        title: const Text('STOCK ADJUSTMENTS'),
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
            'STOCK ADJUSTMENTS',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text('Store ${_auth.storeId}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          if (!_canEdit)
            const Card(
              child: ListTile(
                leading: Icon(Icons.visibility_outlined),
                title: Text('Read-only access'),
                subtitle: Text(
                  'Owner, manager or admin access is required to adjust stock.',
                ),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Unable to load stock'),
                subtitle: Text(_error!),
                trailing: IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              ),
            )
          else if (_items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No active inventory items found.')),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PHYSICAL STOCK COUNT',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter the quantity physically counted. The system records only the difference as an adjustment.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      initialValue: _selected,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Inventory item',
                        border: OutlineInputBorder(),
                      ),
                      items: _items
                          .map(
                            (item) => DropdownMenuItem<Map<String, dynamic>>(
                              value: item,
                              child: Text(
                                '${item['name']} (${item['unit'] ?? ''})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _canEdit ? _select : null,
                    ),
                    if (_selected != null) ...[
                      const SizedBox(height: 16),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Current system quantity',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          '${_format(_currentQuantity ?? 0)}${unit.isEmpty ? '' : ' $unit'}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _countController,
                        enabled: _canEdit,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Physical count',
                          suffixText: unit,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _reasonController,
                        enabled: _canEdit,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Reason / note (optional)',
                          hintText: 'e.g. Monthly stock count, damaged stock, variance',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving || !_canEdit ? null : _adjust,
                          icon: const Icon(Icons.tune_outlined),
                          label: Text(_saving ? 'ADJUSTING...' : 'APPLY STOCK ADJUSTMENT'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
