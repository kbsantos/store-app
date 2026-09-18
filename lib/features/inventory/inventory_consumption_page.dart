import 'package:flutter/material.dart';

import '../../core/auth/store_management_auth.dart';

class InventoryConsumptionPage extends StatefulWidget {
  const InventoryConsumptionPage({super.key});

  @override
  State<InventoryConsumptionPage> createState() => _InventoryConsumptionPageState();
}

class _InventoryConsumptionPageState extends State<InventoryConsumptionPage> {
  final _auth = const StoreManagementAuth();
  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _loadingSummary = false;
  String? _error;
  Map<String, dynamic>? _lastResult;
  List<Map<String, dynamic>> _summary = [];

  bool get _canRun => _auth.canManageInventory;

  String _dateText(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
    await _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loadingSummary = true;
      _error = null;
    });
    try {
      final result = await _auth.client.rpc(
        'get_store_inventory_consumption_summary',
        params: {'p_business_date': _dateText(_date)},
      );
      final rows = (result as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _summary = rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
        _loadingSummary = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSummary = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _runConsumption() async {
    if (!_canRun) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _auth.client.rpc(
        'process_store_inventory_consumption',
        params: {'p_business_date': _dateText(_date)},
      );
      if (!mounted) return;
      setState(() => _lastResult = Map<String, dynamic>.from(result as Map));
      await _loadSummary();
      if (!mounted) return;
      _message('Inventory consumption processed for ${_dateText(_date)}.');
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        _message('Unable to process inventory consumption: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  String _format(dynamic value) {
    final n = _number(value);
    return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        title: const Text('INVENTORY CONSUMPTION'),
        actions: [
          IconButton(onPressed: _loadSummary, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('INVENTORY CONSUMPTION', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Store ${_auth.storeId}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          if (!_canRun)
            const Card(
              child: ListTile(
                leading: Icon(Icons.visibility_outlined),
                title: Text('Read-only access'),
                subtitle: Text('Owner, manager or admin access is required to process consumption.'),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PROCESS SALES CONSUMPTION', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('Apply product recipes to completed or paid sales for the selected business date. Processing is idempotent and will not consume the same recipe line twice.'),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(_dateText(_date)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _loading || !_canRun ? null : _runConsumption,
                          icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
                          label: Text(_loading ? 'PROCESSING...' : 'PROCESS CONSUMPTION'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 28,
                  runSpacing: 12,
                  children: [
                    _stat('Recipe lines', _lastResult!['processedRecipeLines']),
                    _stat('Usage movements', _lastResult!['usageMovements']),
                    _stat('No recipe', _lastResult!['skippedItemsWithoutRecipe']),
                    _stat('Already processed', _lastResult!['alreadyProcessedRecipeLines']),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          const Text('CONSUMPTION SUMMARY', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (_error != null)
            Card(child: ListTile(leading: const Icon(Icons.error_outline), title: const Text('Unable to load consumption'), subtitle: Text(_error!))),
          if (_loadingSummary)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (_summary.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(28), child: Center(child: Text('No inventory consumption recorded for this date.'))))
          else
            Card(
              child: Column(
                children: _summary.map((row) {
                  return ListTile(
                    leading: const Icon(Icons.remove_circle_outline),
                    title: Text(row['item_name']?.toString() ?? ''),
                    subtitle: Text('${row['usage_lines'] ?? 0} usage line(s)'),
                    trailing: Text('${_format(row['consumed_quantity'])} ${row['unit'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, dynamic value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(_format(value), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      Text(label, style: const TextStyle(color: Colors.black54)),
    ],
  );
}
