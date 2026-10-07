import 'package:flutter/material.dart';

import '../../core/auth/store_management_auth.dart';
import 'inventory_adjustments_page.dart';
import 'inventory_consumption_page.dart';
import 'inventory_items_page.dart';
import 'inventory_low_stock_page.dart';
import 'inventory_movements_page.dart';
import 'inventory_receiving_page.dart';
import 'inventory_reset_page.dart';
import 'inventory_stock_levels_page.dart';
import 'inventory_wastage_page.dart';

/// Unified inventory workspace. Existing specialized workflows remain the
/// source of truth; this page brings stock visibility and shortcuts together.
class InventoryManagementPage extends StatefulWidget {
  const InventoryManagementPage({super.key});

  @override
  State<InventoryManagementPage> createState() => _InventoryManagementPageState();
}

class _InventoryManagementPageState extends State<InventoryManagementPage> {
  final _auth = const StoreManagementAuth();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _levels = [];
  bool _loading = true;
  String? _error;
  String _category = 'ALL';
  String _status = 'ALL';

  bool get _canEdit => _auth.canManageInventory;

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
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _auth.client.rpc('get_store_inventory_stock_levels');
      final rows = (result as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _levels = rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<String> get _categories {
    final values = _levels.map((e) => (e['category']?.toString().trim() ?? ''))
        .where((e) => e.isNotEmpty).toSet().toList()..sort();
    return ['ALL', ...values];
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _levels.where((item) {
      final matchesQuery = q.isEmpty || ['name', 'category', 'unit', 'stock_status']
          .any((k) => (item[k]?.toString().toLowerCase() ?? '').contains(q));
      final category = item['category']?.toString().trim() ?? '';
      final matchesCategory = _category == 'ALL' || category == _category;
      final low = item['is_low_stock'] == true;
      final quantity = _number(item['current_quantity']);
      final matchesStatus = _status == 'ALL' ||
          (_status == 'LOW STOCK' && low && quantity > 0) ||
          (_status == 'OUT OF STOCK' && quantity <= 0) ||
          (_status == 'IN STOCK' && !low && quantity > 0);
      return matchesQuery && matchesCategory && matchesStatus;
    }).toList();
  }

  int get _lowCount => _levels.where((e) => e['is_low_stock'] == true && _number(e['current_quantity']) > 0).length;
  int get _outCount => _levels.where((e) => _number(e['current_quantity']) <= 0).length;

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text('INVENTORY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .6)),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh inventory')],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 850;
        return ListView(
          padding: EdgeInsets.all(compact ? 12 : 24),
          children: [
            Row(children: [
              const Icon(Icons.inventory_2_outlined, size: 42, color: Color(0xFFC69214)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('INVENTORY', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                const Text('Manage stock, receiving, recipes, consumption and inventory activity.', style: TextStyle(color: Colors.black54)),
              ])),
              if (!compact && _canEdit) FilledButton.icon(onPressed: () => _open(const InventoryItemsPage()), icon: const Icon(Icons.add), label: const Text('Manage Items')),
            ]),
            const SizedBox(height: 20),
            Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(width: compact ? constraints.maxWidth - 24 : 360, child: TextField(
                controller: _search, onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search item, category or unit', border: OutlineInputBorder(), isDense: true, filled: true, fillColor: Color(0xFFFFFAF3)),
              )),
              SizedBox(width: compact ? 150 : 190, child: DropdownButtonFormField<String>(
                initialValue: _categories.contains(_category) ? _category : 'ALL',
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true, filled: true, fillColor: Color(0xFFFFFAF3)),
                items: _categories.map((e) => DropdownMenuItem(value: e, child: Text(e == 'ALL' ? 'All Categories' : e, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _category = v ?? 'ALL'),
              )),
              SizedBox(width: compact ? 160 : 190, child: DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Stock Status', border: OutlineInputBorder(), isDense: true, filled: true, fillColor: Color(0xFFFFFAF3)),
                items: const ['ALL', 'IN STOCK', 'LOW STOCK', 'OUT OF STOCK'].map((e) => DropdownMenuItem(value: e, child: Text(e == 'ALL' ? 'All Stock Status' : e))).toList(),
                onChanged: (v) => setState(() => _status = v ?? 'ALL'),
              )),
              if (compact && _canEdit) OutlinedButton.icon(onPressed: () => _open(const InventoryItemsPage()), icon: const Icon(Icons.add), label: const Text('Manage Items')),
            ]),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator()
            else if (_error != null) Card(child: ListTile(leading: const Icon(Icons.error_outline), title: const Text('Unable to load inventory'), subtitle: Text(_error!), trailing: IconButton(onPressed: _load, icon: const Icon(Icons.refresh))))
            else Wrap(spacing: 12, runSpacing: 12, children: [
              _metric('TOTAL ITEMS', '${_levels.length}', Icons.inventory_2_outlined, const Color(0xFF9B6B00), compact),
              _metric('LOW STOCK', '$_lowCount', Icons.warning_amber_outlined, const Color(0xFFB77900), compact),
              _metric('OUT OF STOCK', '$_outCount', Icons.cancel_outlined, const Color(0xFFC62828), compact),
            ]),
            const SizedBox(height: 16),
            Text('QUICK ACTIONS', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: .5)),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _action('Receive Stock', Icons.local_shipping_outlined, const InventoryReceivingPage()),
              _action('Stock Adjustment', Icons.tune_outlined, const InventoryAdjustmentsPage()),
              _action('Reset Selected Stock', Icons.restart_alt, const InventoryResetPage()),
              _action('Record Wastage', Icons.delete_outline, const InventoryWastagePage()),
              _action('Inventory Consumption', Icons.remove_circle_outline, const InventoryConsumptionPage()),
              _action('Inventory Movements', Icons.receipt_long_outlined, const InventoryMovementsPage()),
              _action('Low Stock', Icons.warning_amber_outlined, const InventoryLowStockPage()),
              _action('Stock Levels', Icons.bar_chart_outlined, const InventoryStockLevelsPage()),
            ]),
            const SizedBox(height: 18),
            Row(children: [Expanded(child: Text('STOCK OVERVIEW', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))), Text('${_filtered.length} items', style: const TextStyle(color: Colors.black54))]),
            const SizedBox(height: 8),
            if (!_loading && _error == null)
              Card(clipBehavior: Clip.antiAlias, margin: EdgeInsets.zero, child: _filtered.isEmpty
                ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No inventory items match these filters.')))
                : SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF0E7DA)),
                    columns: const [DataColumn(label: Text('ITEM')), DataColumn(label: Text('CATEGORY')), DataColumn(label: Text('ON HAND')), DataColumn(label: Text('REORDER')), DataColumn(label: Text('STATUS')), DataColumn(label: Text('ACTIONS'))],
                    rows: _filtered.map((item) {
                      final qty = _number(item['current_quantity']); final low = item['is_low_stock'] == true; final unit = item['unit']?.toString() ?? '';
                      final status = qty <= 0 ? 'OUT OF STOCK' : low ? 'LOW STOCK' : 'IN STOCK';
                      final color = qty <= 0 ? const Color(0xFFC62828) : low ? const Color(0xFF9B6500) : const Color(0xFF23713A);
                      return DataRow(cells: [
                        DataCell(SizedBox(width: 170, child: Text(item['name']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w700)))),
                        DataCell(Text(item['category']?.toString().trim().isNotEmpty == true ? item['category'].toString() : 'Uncategorized')),
                        DataCell(Text('${_fmt(qty)}${unit.isEmpty ? '' : ' $unit'}')),
                        DataCell(Text('${_fmt(_number(item['reorder_level']))}${unit.isEmpty ? '' : ' $unit'}')),
                        DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(20)), child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)))),
                        DataCell(Wrap(spacing: 0, children: [
                          IconButton(tooltip: 'Receive stock', onPressed: _canEdit ? () => _open(InventoryReceivingPage(initialInventoryItemId: item['id']?.toString())) : null, icon: const Icon(Icons.local_shipping_outlined, size: 19)),
                          IconButton(tooltip: 'Adjust stock', onPressed: _canEdit ? () => _open(InventoryAdjustmentsPage(initialInventoryItemId: item['id']?.toString())) : null, icon: const Icon(Icons.tune, size: 19)),
                          IconButton(tooltip: 'Record wastage', onPressed: _canEdit ? () => _open(InventoryWastagePage(initialInventoryItemId: item['id']?.toString())) : null, icon: const Icon(Icons.delete_outline, size: 19)),
                          IconButton(tooltip: 'View movements', onPressed: () => _open(InventoryMovementsPage(initialItemName: item['name']?.toString())), icon: const Icon(Icons.receipt_long_outlined, size: 19)),
                        ])),
                      ]);
                    }).toList(),
                  ))),
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: () => _open(const InventoryConsumptionPage()), icon: const Icon(Icons.playlist_add_check), label: const Text('Apply Recipes to Sales'))),
          ],
        );
      }),
    );
  }

  Widget _metric(String title, String value, IconData icon, Color color, bool compact) => SizedBox(
    width: compact ? double.infinity : 230,
    child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [CircleAvatar(backgroundColor: color.withValues(alpha: .12), foregroundColor: color, child: Icon(icon)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700)), Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color))]))]))),
  );

  Widget _action(String label, IconData icon, Widget page, {bool requiresEodPermission = false}) => OutlinedButton.icon(
    onPressed: requiresEodPermission
        ? (_auth.canCompleteEod ? () => _open(page) : null)
        : ((!_canEdit && label != 'Inventory Movements' && label != 'Low Stock' && label != 'Stock Levels') ? null : () => _open(page)),
    icon: Icon(icon, size: 19, color: const Color(0xFF9B6B00)), label: Text(label),
    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), foregroundColor: const Color(0xFF26211B), side: const BorderSide(color: Color(0xFFDCCDB9)), backgroundColor: const Color(0xFFFFFAF3)),
  );

  double _number(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
  String _fmt(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);
}
