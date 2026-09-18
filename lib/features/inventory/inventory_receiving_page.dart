import 'package:flutter/material.dart';

import '../../core/auth/store_management_auth.dart';

class InventoryReceivingPage extends StatefulWidget {
  const InventoryReceivingPage({super.key});

  @override
  State<InventoryReceivingPage> createState() => _InventoryReceivingPageState();
}

class _InventoryReceivingPageState extends State<InventoryReceivingPage> {
  final _auth = const StoreManagementAuth();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;
  Map<String, dynamic>? _selected;
  final _quantity = TextEditingController();
  final _note = TextEditingController();

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
          _selected = items.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['id'] == id,
            orElse: () => null,
          );
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

  Future<void> _receive() async {
    if (!_canEdit || _selected == null) return;
    final quantity = num.tryParse(_quantity.text.trim());
    if (quantity == null || quantity <= 0) {
      _message('Enter a receiving quantity greater than zero.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _auth.client.rpc(
        'receive_store_inventory_item',
        params: {
          'p_inventory_item_id': _selected!['id'],
          'p_quantity': quantity,
          'p_note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        },
      );
      if (!mounted) return;
      _quantity.clear();
      _note.clear();
      _message('Stock received successfully.');
    } catch (e) {
      if (mounted) _message('Unable to receive stock: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        title: const Text('RECEIVING'),
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
            'RECEIVING',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Store ${_auth.storeId}',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          if (!_canEdit)
            const Card(
              child: ListTile(
                leading: Icon(Icons.visibility_outlined),
                title: Text('Read-only access'),
                subtitle: Text(
                  'Owner, manager or admin access is required to receive stock.',
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
                subtitle: Text('$_error'),
                trailing: IconButton(
                  onPressed: _loadItems,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            )
          else if (_items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48),
                    SizedBox(height: 10),
                    Text(
                      'No active inventory items',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text('Add an active inventory item before receiving stock.'),
                  ],
                ),
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
                      'RECEIVE STOCK',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 16),
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
                        labelText: 'Quantity received',
                        suffixText: _unit(_selected),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _note,
                      enabled: _canEdit,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        hintText: 'Supplier, invoice or receiving note',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving || !_canEdit ? null : _receive,
                        icon: const Icon(Icons.add_box_outlined),
                        label: Text(_saving ? 'RECEIVING...' : 'RECEIVE STOCK'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Receiving creates a stock_in movement. Current stock on Stock Levels will update automatically.',
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
