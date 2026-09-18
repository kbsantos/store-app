import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CatalogSyncStatusPage extends StatefulWidget {
  const CatalogSyncStatusPage({super.key});

  @override
  State<CatalogSyncStatusPage> createState() => _CatalogSyncStatusPageState();
}

class _CatalogSyncStatusPageState extends State<CatalogSyncStatusPage> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  String? _masterVersion;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await _client.rpc('get_store_catalog_sync_status');
      final rows = result is List
          ? result
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : <Map<String, dynamic>>[];
      final master = rows
          .map((r) => r['master_catalog_version']?.toString().trim() ?? '')
          .firstWhere((v) => v.isNotEmpty, orElse: () => '');
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _masterVersion = master.isEmpty ? null : master;
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

  @override
  Widget build(BuildContext context) {
    final synced = _rows.where((r) => r['sync_status'] == 'SYNCED').length;
    final active = _rows.where((r) => r['is_active'] == true).length;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text(
          'CATALOG SYNC',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  _masterCard(),
                  const SizedBox(height: 16),
                  if (_error != null) _errorCard(_error!),
                  if (_error != null) const SizedBox(height: 12),
                  _summaryCard(active: active, synced: synced),
                  const SizedBox(height: 20),
                  const Text(
                    'KIOSK STATUS',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_rows.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No kiosks are registered for this store.'),
                      ),
                    )
                  else
                    ..._rows.map(_kioskCard),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.info_outline),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'A kiosk is marked SYNCED only after it reports the same master catalog version it has successfully cached. NEVER SYNCED means the kiosk has not yet reported a catalog refresh. OUTDATED means its last reported version differs from the current store master.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _masterCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 27,
                backgroundColor: Color(0xFF171717),
                foregroundColor: Colors.white,
                child: Icon(Icons.cloud_done_outlined, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STORE MASTER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _masterVersion ?? 'No master catalog',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text('Supabase is the catalog source of truth.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _summaryCard({required int active, required int synced}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _stat('Registered', '${_rows.length}'),
              _stat('Active', '$active'),
              _stat('Synced', '$synced'),
              _stat('Needs attention',
                  '${_rows.where((r) => const {'OUTDATED', 'NEVER SYNCED', 'NO MASTER'}.contains(r['sync_status'])).length}'),
            ],
          ),
        ),
      );

  Widget _stat(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label),
          ],
        ),
      );

  Widget _kioskCard(Map<String, dynamic> row) {
    final status = row['sync_status']?.toString() ?? 'UNKNOWN';
    final active = row['is_active'] == true;
    final syncedAt = _formatDate(row['synced_at']?.toString());
    final kioskVersion = row['kiosk_catalog_version']?.toString().trim();
    final statusIcon = switch (status) {
      'SYNCED' => Icons.check_circle_outline,
      'OUTDATED' => Icons.sync_problem_outlined,
      'NEVER SYNCED' => Icons.schedule_outlined,
      'INACTIVE' => Icons.portable_wifi_off,
      _ => Icons.help_outline,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(child: Icon(statusIcon)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                row['device_code']?.toString() ?? 'Unnamed kiosk',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            _statusChip(status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Text(
            'Device: ${row['device_id'] ?? '-'}\n'
            'Master: ${row['master_catalog_version'] ?? '-'}\n'
            'Kiosk: ${kioskVersion == null || kioskVersion.isEmpty ? '-' : kioskVersion}\n'
            'Last report: ${syncedAt ?? 'Never'}${active ? '' : '\nDevice is inactive'}',
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _statusChip(String status) => Chip(
        label: Text(
          status,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
        visualDensity: VisualDensity.compact,
      );

  Widget _errorCard(String message) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(message),
        ),
      );

  String? _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}
