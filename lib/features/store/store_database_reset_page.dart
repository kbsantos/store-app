import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/store_management_auth.dart';

class StoreDatabaseResetPage extends StatefulWidget {
  const StoreDatabaseResetPage({super.key});

  @override
  State<StoreDatabaseResetPage> createState() => _StoreDatabaseResetPageState();
}

class _StoreDatabaseResetPageState extends State<StoreDatabaseResetPage> {
  final _confirmationController = TextEditingController();
  final _auth = const StoreManagementAuth();
  bool _busy = false;

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  bool get _canReset => _auth.role == 'owner' || _auth.role == 'admin';

  Future<void> _reset() async {
    if (!_canReset) return;

    if (_confirmationController.text.trim().toUpperCase() != 'RESET') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type RESET to continue.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RESET STORE DATABASE?'),
        content: const Text(
          'This permanently deletes this store\'s operational transactions, '
          'payments, inventory consumption records, inventory movements, EOD closings, '
          'reporting summaries and store-scoped sync logs. '
          'Master catalog and store configuration data will be preserved. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESET DATA'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await _auth.client.rpc(
        'reset_store_operational_data',
        params: {'p_confirmation': 'RESET'},
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('RESET COMPLETE'),
          content: Text(
            'Store operational data has been reset successfully.\n\n'
            'The database returned:\n$result',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reset failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canReset) {
      return Scaffold(
        appBar: AppBar(title: const Text('DATABASE RESET')),
        backgroundColor: const Color(0xFFF5F2ED),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Owner or admin access is required to reset store data.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('DATABASE RESET')),
      backgroundColor: const Color(0xFFF5F2ED),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.warning_amber_rounded, size: 72),
              const SizedBox(height: 12),
              const Text(
                'DANGER ZONE',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Reset store operational data only.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Deleted: transactions, payments, transaction items/options, inventory consumption, '
                        'inventory movements, EOD closings, stock/sales summaries, and '
                        'store-scoped sync logs.',
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Preserved: store configuration, users, employee invites, devices, catalog master '
                        'data, recipes, and catalog sync state.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _confirmationController,
                enabled: !_busy,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Type RESET to confirm',
                  helperText: 'This action cannot be undone.',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _reset,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_forever),
                  label: Text(_busy ? 'RESETTING...' : 'RESET STORE DATA'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
