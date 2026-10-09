import 'package:flutter/material.dart';

import '../../core/auth/store_management_auth.dart';

/// Resets selected active inventory items to zero by creating signed adjustment
/// movements. Existing movement history, item records, links, and reorder levels
/// are preserved.
class InventoryResetPage extends StatefulWidget {
  const InventoryResetPage({super.key});

  @override
  State<InventoryResetPage> createState() => _InventoryResetPageState();
}

class _InventoryResetPageState extends State<InventoryResetPage> {
  final _auth = const StoreManagementAuth();
  final _reason = TextEditingController(text: 'Inventory reset');
  final Set<String> _selectedIds = {};
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _resetting = false;
  String? _error;
  int _completed = 0;
  int _recipeOnlyCount = 0;

  bool get _canEdit => _auth.canManageInventory;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait<dynamic>([
        _auth.client.rpc('get_store_inventory_stock_levels'),
        _auth.client.rpc('get_store_inventory_items'),
      ]);
      final trackingById = <String, String>{};
      for (final raw in (results[1] as List? ?? const [])) {
        final item = Map<String, dynamic>.from(raw as Map);
        final id = item['id']?.toString();
        if (id != null) {
          trackingById[id] = item['tracking_type']?.toString() ?? 'tracked';
        }
      }
      final allRows = (results[0] as List? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .where((row) => row['is_active'] != false)
          .map((row) => {
                ...row,
                'tracking_type': trackingById[row['id']?.toString()] ??
                    row['tracking_type']?.toString() ?? 'tracked',
              })
          .toList();
      final recipeOnlyCount = allRows
          .where((row) => row['tracking_type'] == 'recipe_only')
          .length;
      final rows = allRows
          .where((row) => row['tracking_type'] != 'recipe_only')
          .toList();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _recipeOnlyCount = recipeOnlyCount;
        final validIds = rows.map((e) => e['id'].toString()).toSet();
        _selectedIds.removeWhere((id) => !validIds.contains(id));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  double _number(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  String _fmt(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  Future<void> _reset() async {
    if (!_canEdit || _selectedIds.isEmpty || _resetting) return;
    final selected = _items.where((item) => _selectedIds.contains(item['id'].toString())).toList();
    final nonzero = selected.where((item) => _number(item['current_quantity']) != 0).toList();
    if (nonzero.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All selected items are already at zero.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset selected stock to zero?'),
        content: Text(
          'This will create a stock adjustment for ${nonzero.length} item(s) and set their on-hand quantity to zero. '
          'Existing movement history, inventory links, item records, and reorder levels will be preserved. '
          'This action cannot be undone automatically.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('CANCEL')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('RESET STOCK'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() { _resetting = true; _completed = 0; });
    final failures = <String>[];
    for (final item in nonzero) {
      try {
        await _auth.client.rpc('adjust_store_inventory_stock', params: {
          'p_inventory_item_id': item['id'],
          'p_counted_quantity': 0,
          'p_reason': _reason.text.trim().isEmpty ? 'Inventory reset to zero' : _reason.text.trim(),
        });
      } catch (e) {
        failures.add('${item['name']}: $e');
      }
      if (!mounted) return;
      setState(() => _completed++);
    }
    await _load();
    if (!mounted) return;
    setState(() { _resetting = false; _selectedIds.clear(); });
    final successCount = nonzero.length - failures.length;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(failures.isEmpty
          ? 'Reset $successCount item(s) to zero. Adjustment history was recorded.'
          : 'Reset $successCount item(s); ${failures.length} failed. Review details below.'),
      duration: const Duration(seconds: 6),
    ));
    if (failures.isNotEmpty) {
      setState(() => _error = failures.join('\n'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        title: const Text('RESET INVENTORY STOCK'),
        actions: [IconButton(onPressed: _resetting ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh')],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Reset selected items', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Choose inventory items to set their on-hand stock to zero. The reset is recorded as an adjustment movement; it does not delete history or change reorder levels or product links.'),
          const SizedBox(height: 16),
          if (_recipeOnlyCount > 0)
            Card(
              color: Colors.blueGrey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '$_recipeOnlyCount recipe-only item(s) are hidden because they do not have physical stock movements.',
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ),
          if (!_canEdit) const Card(child: ListTile(leading: Icon(Icons.lock_outline), title: Text('Read-only access'), subtitle: Text('Owner, manager or admin access is required to reset stock.'))),
          TextField(controller: _reason, enabled: !_resetting, decoration: const InputDecoration(labelText: 'Adjustment reason', border: OutlineInputBorder(), hintText: 'e.g. Opening stock reset')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text('${_selectedIds.length} selected', style: const TextStyle(fontWeight: FontWeight.w800))),
            TextButton(onPressed: _resetting || _items.isEmpty ? null : () => setState(() {
              if (_selectedIds.length == _items.length) { _selectedIds.clear(); } else { _selectedIds.addAll(_items.map((e) => e['id'].toString())); }
            }), child: Text(_selectedIds.length == _items.length ? 'SELECT NONE' : 'SELECT ALL')),
          ]),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_items.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No active inventory items found.')))
          else ..._items.map((item) {
            final id = item['id'].toString();
            final quantity = _number(item['current_quantity']);
            final unit = item['unit']?.toString() ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: CheckboxListTile(
                value: _selectedIds.contains(id),
                onChanged: !_canEdit || _resetting ? null : (checked) => setState(() {
                  if (checked == true) { _selectedIds.add(id); } else { _selectedIds.remove(id); }
                }),
                title: Text(item['name']?.toString() ?? 'Unnamed item', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('On hand: ${_fmt(quantity)} $unit • Reorder: ${_fmt(_number(item['reorder_level']))} $unit'),
                secondary: Icon(quantity == 0 ? Icons.check_circle_outline : Icons.inventory_2_outlined, color: quantity == 0 ? Colors.green : Colors.brown),
              ),
            );
          }),
          if (_error != null) Card(color: Colors.red.shade50, child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: TextStyle(color: Colors.red.shade900)))),
          if (_resetting) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Column(children: [const LinearProgressIndicator(), const SizedBox(height: 8), Text('Processing $_completed of ${_items.where((e) => _selectedIds.contains(e['id'].toString()) && _number(e['current_quantity']) != 0).length} item(s)…')])) ,
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: !_canEdit || _resetting || _selectedIds.isEmpty || _loading ? null : _reset,
            icon: const Icon(Icons.restart_alt),
            label: Text(_resetting ? 'RESETTING…' : 'RESET SELECTED TO ZERO'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700, padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ],
      ),
    );
  }
}
