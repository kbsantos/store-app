import 'package:flutter/material.dart';

import '../core/auth/store_management_auth.dart';

class StoreEodPage extends StatefulWidget {
  const StoreEodPage({super.key});

  @override
  State<StoreEodPage> createState() => _StoreEodPageState();
}

class _StoreEodPageState extends State<StoreEodPage> {
  final _auth = const StoreManagementAuth();
  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _completing = false;
  bool _checking = false;
  String? _error;
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _integrity;

  bool get _canComplete => _auth.canManageInventory;

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _money(dynamic value) {
    final n = value is num ? value : num.tryParse('$value') ?? 0;
    return '₱${n.toStringAsFixed(2)}';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _auth.client.rpc(
        'get_store_eod_summary',
        params: {'p_business_date': _dateOnly(_date)},
      );
      if (!mounted) return;
      setState(() => _summary = Map<String, dynamic>.from(result as Map));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      _integrity = null;
    });
    await _load();
  }

  Future<void> _checkIntegrity() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final result = await _auth.client.rpc(
        'get_store_eod_integrity',
        params: {'p_business_date': _dateOnly(_date)},
      );
      if (!mounted) return;
      setState(() => _integrity = Map<String, dynamic>.from(result as Map));
      final status = _integrity?['status']?.toString() ?? 'ATTENTION';
      _message('EOD integrity: $status');
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        _message('Unable to check EOD integrity: $e');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _complete() async {
    if (!_canComplete || _completing) return;
    final closing = _summary?['closing'];
    if (closing is Map && closing['status']?.toString() == 'completed') {
      _message('EOD is already completed for ${_dateOnly(_date)}.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('COMPLETE END OF DAY?'),
        content: Text(
          'This will process recipe-based inventory consumption and mark ${_dateOnly(_date)} as completed for this store. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('COMPLETE EOD')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _completing = true;
      _error = null;
    });
    try {
      final result = await _auth.client.rpc(
        'complete_store_eod',
        params: {'p_business_date': _dateOnly(_date)},
      );
      await _load();
      await _checkIntegrity();
      if (!mounted) return;
      _message('End of Day completed for ${_dateOnly(_date)}.');
      setState(() => _summary = {
            ...?_summary,
            'completionResult': Map<String, dynamic>.from(result as Map),
          });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        _message('Unable to complete EOD: $e');
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final closing = _summary?['closing'];
    final completed = closing is Map && closing['status']?.toString() == 'completed';
    final consumption = (_summary?['inventoryConsumption'] as List?) ?? const [];
    final payments = (_summary?['payments'] as List?) ?? const [];
    final paymentDifference = _summary?['paymentDifference'];
    final paymentDifferenceNumber = paymentDifference is num
        ? paymentDifference
        : num.tryParse('$paymentDifference') ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text('END OF DAY', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.event_available_outlined, size: 64, color: Color(0xFFC69214)),
          const SizedBox(height: 6),
          const Text('END OF DAY', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Store ${_auth.storeId}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today_outlined), label: Text(_dateOnly(_date))),
                  Chip(
                    avatar: Icon(completed ? Icons.check_circle_outline : Icons.pending_outlined, size: 18),
                    label: Text(completed ? 'EOD COMPLETED' : 'OPEN'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _checking ? null : _checkIntegrity,
                    icon: _checking
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.fact_check_outlined),
                    label: Text(_checking ? 'CHECKING...' : 'CHECK INTEGRITY'),
                  ),
                  FilledButton.icon(
                    onPressed: _completing || completed || !_canComplete ? null : _complete,
                    icon: _completing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.lock_outline),
                    label: Text(_completing ? 'COMPLETING...' : 'COMPLETE EOD'),
                  ),
                ],
              ),
            ),
          ),
          if (!_canComplete)
            const Card(child: ListTile(leading: Icon(Icons.visibility_outlined), title: Text('Read-only access'), subtitle: Text('Owner, manager or admin access is required to complete EOD.'))),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(child: ListTile(leading: const Icon(Icons.error_outline), title: const Text('EOD ERROR'), subtitle: Text(_error!))),
          ],
          const SizedBox(height: 18),
          if (_loading)
            const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator()))
          else if (_summary != null) ...[
            Row(children: [
              Expanded(child: _stat('TRANSACTIONS', '${_summary!['transactionCount'] ?? 0}')),
              const SizedBox(width: 12),
              Expanded(child: _stat('SALES', _money(_summary!['salesTotal']))),
              const SizedBox(width: 12),
              Expanded(child: _stat('PAYMENTS', _money(_summary!['paymentTotal']))),
            ]),
            const SizedBox(height: 18),
            if (paymentDifferenceNumber.abs() >= 0.01)
              Card(
                color: const Color(0xFFFFF3CD),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_outlined),
                  title: const Text('PAYMENT RECONCILIATION WARNING'),
                  subtitle: Text('Sales and recorded payments differ by ${_money(paymentDifferenceNumber.abs())}.'),
                ),
              ),
            if (paymentDifferenceNumber.abs() >= 0.01) const SizedBox(height: 14),
            if (_integrity != null) ...[
              _integrityCard(_integrity!),
              const SizedBox(height: 14),
            ],
            _section('PAYMENT SUMMARY', payments, (row) => ListTile(
              title: Text('${row['paymentMethod'] ?? 'Unknown'}'),
              trailing: Text(_money(row['totalAmount']), style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('${row['paymentCount'] ?? 0} payment(s)'),
            )),
            const SizedBox(height: 14),
            _section('INVENTORY CONSUMPTION', consumption, (row) => ListTile(
              title: Text('${row['item_name'] ?? ''}'),
              subtitle: Text('${row['usage_lines'] ?? 0} usage line(s)'),
              trailing: Text('${row['consumed_quantity'] ?? 0} ${row['unit'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900)),
            )),
            const SizedBox(height: 14),
            Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(
              completed
                  ? 'This business date has been closed. Inventory consumption and the EOD snapshot have been recorded.'
                  : 'Review sales, payments and inventory consumption before completing EOD. Completing EOD is store-scoped and can be safely retried without duplicating recipe consumption.',
              style: const TextStyle(height: 1.35),
            ))),
          ],
        ],
      ),
    );
  }

  Widget _integrityCard(Map<String, dynamic> integrity) {
    final status = integrity['status']?.toString() ?? 'ATTENTION';
    final paymentBalanced = integrity['paymentBalanced'] == true;
    final inventoryBalanced = integrity['inventoryBalanced'] == true;
    final completed = integrity['isCompleted'] == true;
    final difference = integrity['paymentDifference'];
    final differenceNumber = difference is num ? difference : num.tryParse('$difference') ?? 0;
    final ready = status == 'READY' || status == 'COMPLETED';

    Widget check(String label, bool ok, String detail) => ListTile(
      dense: true,
      leading: Icon(ok ? Icons.check_circle_outline : Icons.warning_amber_outlined),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(detail),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(child: Text('EOD INTEGRITY CHECK', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
              Chip(label: Text(status)),
            ]),
            const Divider(),
            check('Payment reconciliation', paymentBalanced,
                paymentBalanced ? 'Sales and recorded payments reconcile.' : 'Difference: ${_money(differenceNumber.abs())}.'),
            check('Inventory consumption', inventoryBalanced,
                inventoryBalanced ? 'Consumption records and usage movements reconcile.' : 'Review Inventory Consumption integrity before relying on the result.'),
            check('EOD close state', completed || ready,
                completed ? 'This business date is already closed.' : ready ? 'The business date is ready for completion.' : 'Resolve the attention items or review the warnings before closing.'),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))])));

  Widget _section(String title, List rows, Widget Function(Map<String, dynamic>) builder) {
    return Card(child: Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const Divider(), if (rows.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No records for this business date.')) else ...rows.map((r) => builder(Map<String, dynamic>.from(r as Map)))])));
  }
}
