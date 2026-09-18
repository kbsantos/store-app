import 'package:flutter/material.dart';

import '../../core/auth/store_management_auth.dart';

class InventoryWastagePage extends StatefulWidget {
  const InventoryWastagePage({super.key});

  @override
  State<InventoryWastagePage> createState() => _InventoryWastagePageState();
}

class _InventoryWastagePageState extends State<InventoryWastagePage> {
  final _auth = const StoreManagementAuth();
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  String _reason = 'Damaged';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _reasons = ['Damaged', 'Expired', 'Spillage', 'Spoilage', 'Other'];

  bool get _canEdit => _auth.canManageInventory;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _auth.client.rpc('get_store_inventory_items');
      final rows = (result as List?) ?? const [];
      final items = rows
          .map((r) => Map<String, dynamic>.from(r as Map))
          .where((item) => item['is_active'] == true)
          .toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        if (_selected != null) {
          final id = _selected!['id'];
          Map<String, dynamic>? found;
          for (final item in items) {
            if (item['id'] == id) {
              found = item;
              break;
            }
          }
          _selected = found;
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

  Future<void> _recordWastage() async {
    if (!_canEdit || _selected == null) return;
    final quantity = num.tryParse(_quantity.text.trim());
    if (quantity == null || quantity <= 0) {
      _message('Enter a wastage quantity greater than zero.');
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await _auth.client.rpc(
        'waste_store_inventory_item',
        params: {
          'p_inventory_item_id': _selected!['id'],
          'p_quantity': quantity,
          'p_reason': _reason,
          'p_note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        },
      );
      if (!mounted) return;
      final data = Map<String, dynamic>.from(result as Map);
      _quantity.clear();
      _note.clear();
      _message(
        'Wastage recorded: ${_format(_number(data['quantity']))} ${_unit(_selected)}.',
      );
    } catch (e) {
      if (mounted) _message('Unable to record wastage: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _unit(Map<String, dynamic>? item) => item?['unit']?.toString().trim() ?? '';

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final unit = _unit(_selected);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        title: const Text('WASTAGE'),
        actions: [
          IconButton(
            onPressed: _loadItems,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'WASTAGE',
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
                  'Owner, manager or admin access is required to record wastage.',
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
                title: const Text('Unable to load inventory items'),
                subtitle: Text(_error!),
                trailing: IconButton(onPressed: _loadItems, icon: const Icon(Icons.refresh)),
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
                      'RECORD WASTAGE',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Record stock that was damaged, expired, spilled, spoiled or otherwise unusable.',
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
                      items: _items.map((item) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: item,
                          child: Text(
                            '${item['name']} (${item['unit'] ?? ''})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _canEdit
                          ? (value) => setState(() => _selected = value)
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _quantity,
                      enabled: _canEdit,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Wastage quantity',
                        suffixText: unit,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _reason,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        border: OutlineInputBorder(),
                      ),
                      items: _reasons
                          .map((reason) => DropdownMenuItem(value: reason, child: Text(reason)))
                          .toList(),
                      onChanged: _canEdit ? (value) => setState(() => _reason = value ?? 'Other') : null,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _note,
                      enabled: _canEdit,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        hintText: 'Add details about the wastage',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving || !_canEdit ? null : _recordWastage,
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: Text(_saving ? 'RECORDING...' : 'RECORD WASTAGE'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Wastage is recorded as a waste movement and reduces the current stock shown in Stock Levels.',
                      style: TextStyle(color: Colors.black54),
                    ),
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
