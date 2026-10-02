import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/store_management_auth.dart';

class StoreProfilePage extends StatefulWidget {
  const StoreProfilePage({super.key});

  @override
  State<StoreProfilePage> createState() => _StoreProfilePageState();
}

class _StoreProfilePageState extends State<StoreProfilePage> {
  final _auth = const StoreManagementAuth();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _locationController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _isActive = true;
  DateTime? _createdAt;

  bool get _canEdit => _auth.role == 'owner' || _auth.role == 'admin';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final result = await _auth.client.rpc('get_store_management_profile');
      final profile = Map<String, dynamic>.from(result as Map);

      _nameController.text = profile['name']?.toString() ?? '';
      _brandController.text = profile['brand']?.toString() ?? '';
      _locationController.text = profile['location']?.toString() ?? '';
      _isActive = profile['is_active'] == true;
      final created = profile['created_at']?.toString();
      _createdAt = created == null ? null : DateTime.tryParse(created);
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load store profile: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_canEdit || !_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await _auth.client.rpc(
        'update_store_management_profile',
        params: {
          'p_name': _nameController.text.trim(),
          'p_brand': _brandController.text.trim(),
          'p_location': _locationController.text.trim(),
          'p_is_active': _isActive,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store profile saved successfully.')),
      );
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save store profile: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatCreatedAt() {
    final value = _createdAt;
    if (value == null) return '—';
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('STORE PROFILE')),
      backgroundColor: const Color(0xFFF5F2ED),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text(
                        'STORE PROFILE',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Store ${_auth.storeId}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _nameController,
                                enabled: _canEdit && !_saving,
                                decoration: const InputDecoration(
                                  labelText: 'Store Name',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Store name is required.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _brandController,
                                enabled: _canEdit && !_saving,
                                decoration: const InputDecoration(
                                  labelText: 'Brand',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _locationController,
                                enabled: _canEdit && !_saving,
                                decoration: const InputDecoration(
                                  labelText: 'Location',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: _isActive,
                                onChanged: _canEdit && !_saving
                                    ? (value) => setState(() => _isActive = value)
                                    : null,
                                title: const Text(
                                  'Store Active',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                  _isActive
                                      ? 'Store is active.'
                                      : 'Store is inactive.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.calendar_today_outlined),
                          ),
                          title: const Text(
                            'Created',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(_formatCreatedAt()),
                        ),
                      ),
                      if (!_canEdit) ...[
                        const SizedBox(height: 16),
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'This profile is read-only for your account. '
                              'Owner or admin access is required to edit store settings.',
                            ),
                          ),
                        ),
                      ],
                      if (_canEdit) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(_saving ? 'SAVING...' : 'SAVE STORE PROFILE'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
