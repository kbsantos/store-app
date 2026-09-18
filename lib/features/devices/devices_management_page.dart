import 'package:flutter/material.dart';
import '../../core/auth/store_management_auth.dart';

class DevicesManagementPage extends StatefulWidget {
  const DevicesManagementPage({super.key});

  @override
  State<DevicesManagementPage> createState() => _DevicesManagementPageState();
}

class _DevicesManagementPageState extends State<DevicesManagementPage>
    with SingleTickerProviderStateMixin {
  final _auth = const StoreManagementAuth();
  late final TabController _tabs;
  bool _loading = true;
  List<Map<String, dynamic>> _kiosks = const [];
  List<Map<String, dynamic>> _printers = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final kiosksResult = await _auth.client.rpc('get_store_devices');
      final printersResult = await _auth.client
          .from('store_printers')
          .select('id,name,model,interface,device_id,is_active,notes,created_at,updated_at')
          .order('name');
      if (!mounted) return;
      setState(() {
        _kiosks = _rows(kiosksResult);
        _printers = _rows(printersResult);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e; });
    }
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _toggleKiosk(Map<String, dynamic> kiosk) async {
    if (!_auth.canManageDevices) return;
    final id = kiosk['id']?.toString();
    if (id == null || id.isEmpty) return;
    final next = kiosk['is_active'] != true;
    try {
      await _auth.client.rpc('set_store_device_active', params: {
        'p_device_id': id,
        'p_is_active': next,
      });
      await _load();
    } catch (e) {
      if (mounted) _message('Unable to update kiosk: $e');
    }
  }

  Future<void> _addPrinter() async {
    if (!_auth.canManageDevices) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _PrinterDialog(kiosks: _kiosks),
    );
    if (result == true) await _load();
  }

  Future<void> _editPrinter(Map<String, dynamic> printer) async {
    if (!_auth.canManageDevices) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _PrinterDialog(kiosks: _kiosks, printer: printer),
    );
    if (result == true) await _load();
  }

  Future<void> _togglePrinter(Map<String, dynamic> printer) async {
    if (!_auth.canManageDevices) return;
    final id = printer['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      await _auth.client
          .from('store_printers')
          .update({'is_active': printer['is_active'] != true ? true : false})
          .eq('id', id);
      await _load();
    } catch (e) {
      if (mounted) _message('Unable to update printer: $e');
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DEVICES'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'KIOSKS'),
            Tab(text: 'PRINTERS'),
          ],
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: _auth.canManageDevices && _tabs.index == 1
          ? FloatingActionButton.extended(
              onPressed: _addPrinter,
              icon: const Icon(Icons.add),
              label: const Text('ADD PRINTER'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(error: _error!, onRetry: _load)
          : TabBarView(
              controller: _tabs,
              children: [
                _KioskList(kiosks: _kiosks, onToggle: _toggleKiosk, canEdit: _auth.canManageDevices),
                _PrinterList(
                  printers: _printers,
                  onEdit: _editPrinter,
                  onToggle: _togglePrinter,
                  canEdit: _auth.canManageDevices,
                ),
              ],
            ),
    );
  }
}

class _KioskList extends StatelessWidget {
  const _KioskList({required this.kiosks, required this.onToggle, required this.canEdit});
  final List<Map<String, dynamic>> kiosks;
  final Future<void> Function(Map<String, dynamic>) onToggle;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    if (kiosks.isEmpty) {
      return const _EmptyState(icon: Icons.point_of_sale_outlined, title: 'No kiosks registered', subtitle: 'Kiosks registered to this store will appear here.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: kiosks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final kiosk = kiosks[index];
        final active = kiosk['is_active'] == true;
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(active ? Icons.point_of_sale : Icons.portable_wifi_off)),
            title: Text(kiosk['device_code']?.toString() ?? 'Unnamed kiosk', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('Device ID: ${kiosk['id'] ?? '-'}\n${active ? 'Active' : 'Inactive'}'),
            isThreeLine: true,
            trailing: canEdit
                ? Switch(value: active, onChanged: (_) => onToggle(kiosk))
                : Chip(label: Text(active ? 'ACTIVE' : 'INACTIVE')),
          ),
        );
      },
    );
  }
}

class _PrinterList extends StatelessWidget {
  const _PrinterList({required this.printers, required this.onEdit, required this.onToggle, required this.canEdit});
  final List<Map<String, dynamic>> printers;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(Map<String, dynamic>) onToggle;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    if (printers.isEmpty) {
      return const _EmptyState(icon: Icons.print_outlined, title: 'No printers registered', subtitle: 'Add the store printers and optionally assign them to a kiosk.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: printers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final printer = printers[index];
        final active = printer['is_active'] == true;
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.print_outlined)),
            title: Text(printer['name']?.toString() ?? 'Printer', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${printer['model'] ?? 'Unknown model'} • ${printer['interface'] ?? 'Unknown interface'}\n${active ? 'Active' : 'Inactive'}'),
            isThreeLine: true,
            trailing: canEdit
                ? Wrap(spacing: 4, children: [
                    IconButton(onPressed: () => onEdit(printer), icon: const Icon(Icons.edit_outlined)),
                    Switch(value: active, onChanged: (_) => onToggle(printer)),
                  ])
                : Chip(label: Text(active ? 'ACTIVE' : 'INACTIVE')),
          ),
        );
      },
    );
  }
}

class _PrinterDialog extends StatefulWidget {
  const _PrinterDialog({required this.kiosks, this.printer});
  final List<Map<String, dynamic>> kiosks;
  final Map<String, dynamic>? printer;

  @override
  State<_PrinterDialog> createState() => _PrinterDialogState();
}

class _PrinterDialogState extends State<_PrinterDialog> {
  final _form = GlobalKey<FormState>();
  final _auth = const StoreManagementAuth();
  late final TextEditingController _name;
  late final TextEditingController _model;
  late final TextEditingController _interface;
  late final TextEditingController _notes;
  String? _deviceId;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.printer;
    _name = TextEditingController(text: p?['name']?.toString() ?? '');
    _model = TextEditingController(text: p?['model']?.toString() ?? 'XP-58H');
    _interface = TextEditingController(text: p?['interface']?.toString() ?? 'Bluetooth');
    _notes = TextEditingController(text: p?['notes']?.toString() ?? '');
    _deviceId = p?['device_id']?.toString();
    _active = p?['is_active'] != false;
  }

  @override
  void dispose() {
    _name.dispose(); _model.dispose(); _interface.dispose(); _notes.dispose(); super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final values = {
        'name': _name.text.trim(),
        'model': _model.text.trim(),
        'interface': _interface.text.trim(),
        'device_id': _deviceId,
        'is_active': _active,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      };
      final id = widget.printer?['id']?.toString();
      if (id == null) {
        await _auth.client.from('store_printers').insert(values);
      } else {
        await _auth.client.from('store_printers').update(values).eq('id', id);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save printer: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.printer == null ? 'Add Printer' : 'Edit Printer'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              child: Column(children: [
                TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Printer name'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter a printer name' : null),
                TextFormField(controller: _model, decoration: const InputDecoration(labelText: 'Model')),
                TextFormField(controller: _interface, decoration: const InputDecoration(labelText: 'Interface')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _deviceId,
                  decoration: const InputDecoration(labelText: 'Assigned kiosk'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                    ...widget.kiosks.map((k) => DropdownMenuItem<String?>(value: k['id']?.toString(), child: Text(k['device_code']?.toString() ?? 'Kiosk'))),
                  ],
                  onChanged: (value) => setState(() => _deviceId = value),
                ),
                TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
                SwitchListTile(title: const Text('Active'), value: _active, onChanged: (v) => setState(() => _active = v)),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('CANCEL')),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'SAVING...' : 'SAVE')),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle});
  final IconData icon; final String title; final String subtitle;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 56, color: Colors.black45), const SizedBox(height: 12), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54))])));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error; final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 52), const SizedBox(height: 12), const Text('Unable to load devices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text('$error', textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton(onPressed: onRetry, child: const Text('RETRY'))])));
}
