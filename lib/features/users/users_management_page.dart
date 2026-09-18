import 'package:flutter/material.dart';
import '../../core/auth/store_management_auth.dart';
import '../../core/auth/store_management_permissions.dart';

class UsersManagementPage extends StatefulWidget {
  const UsersManagementPage({super.key});

  @override
  State<UsersManagementPage> createState() => _UsersManagementPageState();
}

class _UsersManagementPageState extends State<UsersManagementPage>
    with SingleTickerProviderStateMixin {
  final _auth = const StoreManagementAuth();
  late final StoreManagementPermissions _permissions = StoreManagementPermissions(_auth);
  late final TabController _tabs;
  bool _loading = true;
  List<Map<String, dynamic>> _employees = const [];
  Object? _error;

  bool get _canManage => _permissions.canManageUsers;

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
      final result = await _auth.client.rpc('get_store_employees');
      final rows = result is List
          ? result.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() { _employees = rows; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e; });
    }
  }

  Future<void> _addEmployee() async {
    if (!_canManage) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _EmployeeDialog(),
    );
    if (result == true) await _load();
  }

  Future<void> _editEmployee(Map<String, dynamic> employee) async {
    if (!_canManage) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _EmployeeDialog(employee: employee),
    );
    if (result == true) await _load();
  }

  Future<void> _toggle(Map<String, dynamic> employee) async {
    if (!_canManage) return;
    final userId = employee['user_id']?.toString();
    if (userId == null || userId.isEmpty) return;
    try {
      await _auth.client.rpc('set_store_employee_active', params: {
        'p_user_id': userId,
        'p_is_active': employee['is_active'] != true,
      });
      await _load();
    } catch (e) {
      if (mounted) _message('Unable to update employee: $e');
    }
  }

  Future<void> _sendPasswordEmail(Map<String, dynamic> employee) async {
    if (!_canManage) return;
    final email = employee['email']?.toString().trim() ?? '';
    if (email.isEmpty) return;
    final name = employee['full_name']?.toString().trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SEND PASSWORD EMAIL?'),
        content: Text(
          'Send a Supabase password setup/recovery email to ${name == null || name.isEmpty ? email : name} ($email)?\n\n'
          'The employee must use that email to set or reset their password. No password is created or stored by Store Management.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('SEND EMAIL')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _auth.sendPasswordSetupEmail(email);
      if (mounted) _message('Password setup email sent to $email.');
    } catch (e) {
      if (mounted) _message('Unable to send password email: $e');
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        title: const Text('USERS'),
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(text: 'EMPLOYEES'),
          Tab(text: 'ROLES & PERMISSIONS'),
        ]),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: _canManage && _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: _addEmployee,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('ADD EMPLOYEE'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(error: _error!, onRetry: _load)
              : TabBarView(controller: _tabs, children: [
                  _EmployeeList(
                    employees: _employees,
                    canEdit: _canManage,
                    onEdit: _editEmployee,
                    onToggle: _toggle,
                    onPasswordEmail: _sendPasswordEmail,
                  ),
                  const _PermissionsPage(),
                ]),
    );
  }
}

class _EmployeeList extends StatelessWidget {
  const _EmployeeList({
    required this.employees,
    required this.canEdit,
    required this.onEdit,
    required this.onToggle,
    required this.onPasswordEmail,
  });
  final List<Map<String, dynamic>> employees;
  final bool canEdit;
  final Future<void> Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(Map<String, dynamic>) onToggle;
  final Future<void> Function(Map<String, dynamic>) onPasswordEmail;

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('No employees are assigned to this store.'),
      ));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: employees.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final employee = employees[index];
        final active = employee['is_active'] == true;
        final pending = employee['status']?.toString() == 'PENDING AUTH';
        final role = employee['role']?.toString() ?? 'staff';
        final email = employee['email']?.toString() ?? '-';
        final name = employee['full_name']?.toString().trim();
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(pending ? Icons.person_add_outlined : (active ? Icons.person_outline : Icons.person_off_outlined))),
            title: Text(name == null || name.isEmpty ? email : name, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('$email\n${role.toUpperCase()} • ${pending ? 'PENDING AUTH' : (active ? 'ACTIVE' : 'INACTIVE')}'),
            isThreeLine: true,
            trailing: canEdit
                ? Wrap(spacing: 4, children: [
                    if (pending)
                      IconButton(
                        tooltip: 'LINK AUTH USER',
                        onPressed: () => onEdit(employee),
                        icon: const Icon(Icons.link_outlined),
                      )
                    else ...[
                      IconButton(
                        tooltip: 'SEND PASSWORD EMAIL',
                        onPressed: () => onPasswordEmail(employee),
                        icon: const Icon(Icons.mark_email_read_outlined),
                      ),
                      IconButton(onPressed: () => onEdit(employee), icon: const Icon(Icons.edit_outlined)),
                      Switch(value: active, onChanged: (_) => onToggle(employee)),
                    ],
                  ])
                : Chip(label: Text(pending ? 'PENDING AUTH' : (active ? 'ACTIVE' : 'INACTIVE'))),
          ),
        );
      },
    );
  }
}

class _EmployeeDialog extends StatefulWidget {
  const _EmployeeDialog({this.employee});
  final Map<String, dynamic>? employee;
  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  final _form = GlobalKey<FormState>();
  final _auth = const StoreManagementAuth();
  late final TextEditingController _email;
  late final TextEditingController _name;
  String _role = 'staff';
  bool _active = true;
  bool _saving = false;

  final _roles = const ['staff', 'editor', 'manager', 'admin', 'owner'];

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _email = TextEditingController(text: e?['email']?.toString() ?? '');
    _name = TextEditingController(text: e?['full_name']?.toString() ?? '');
    _role = e?['role']?.toString() ?? 'staff';
    if (!_roles.contains(_role)) _role = 'staff';
    _active = e?['is_active'] != false;
  }

  @override
  void dispose() { _email.dispose(); _name.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (widget.employee == null) {
        final result = await _auth.client.rpc('add_store_employee', params: {
          'p_email': _email.text.trim(),
          'p_full_name': _name.text.trim(),
          'p_role': _role,
        });
        if (mounted) {
          final pending = result == null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(pending ? 'Employee saved as PENDING AUTH. Link the employee after the Supabase Auth account exists.' : 'Employee added successfully.')),
          );
        }
      } else if (widget.employee!['status']?.toString() == 'PENDING AUTH') {
        await _auth.client.rpc('link_store_employee_invite', params: {
          'p_invite_id': widget.employee!['employee_id'].toString(),
          'p_email': _email.text.trim(),
        });
      } else {
        await _auth.client.rpc('update_store_employee', params: {
          'p_user_id': widget.employee!['user_id'].toString(),
          'p_full_name': _name.text.trim(),
          'p_role': _role,
          'p_is_active': _active,
        });
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save employee: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.employee == null ? 'ADD EMPLOYEE' : 'EDIT EMPLOYEE'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _email,
                enabled: widget.employee == null,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email address' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Employee name')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                onChanged: (v) => setState(() => _role = v ?? 'staff'),
              ),
              if (widget.employee != null) ...[
                const SizedBox(height: 12),
                SwitchListTile.adaptive(title: const Text('Active'), value: _active, onChanged: (v) => setState(() => _active = v)),
              ],
              const SizedBox(height: 8),
              const Text(
                'If the email is not yet registered in Supabase Auth, the employee will be saved as PENDING AUTH and can be linked later. After linking, an admin or owner can send a Supabase password setup email. This screen never creates or stores passwords.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('CANCEL')),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'SAVING…' : 'SAVE')),
        ],
      );
}

class _PermissionsPage extends StatelessWidget {
  const _PermissionsPage();

  @override
  Widget build(BuildContext context) {
    const roles = ['OWNER', 'ADMIN', 'MANAGER', 'EDITOR', 'STAFF'];
    const rows = <List<String>>[
      ['Dashboard / Sales', 'VIEW', 'VIEW', 'VIEW', 'VIEW', 'VIEW'],
      ['Product Catalog', 'EDIT', 'EDIT', 'EDIT', 'VIEW', 'VIEW'],
      ['Inventory', 'EDIT', 'EDIT', 'EDIT', 'VIEW', 'VIEW'],
      ['Recipes', 'EDIT', 'EDIT', 'EDIT', 'VIEW', 'VIEW'],
      ['End of Day', 'COMPLETE', 'COMPLETE', 'COMPLETE', 'VIEW', 'VIEW'],
      ['Kiosks / Printers', 'EDIT', 'EDIT', 'EDIT', 'VIEW', 'VIEW'],
      ['Store Profile', 'EDIT', 'EDIT', 'VIEW', 'VIEW', 'VIEW'],
      ['Operating Hours', 'EDIT', 'EDIT', 'VIEW', 'VIEW', 'VIEW'],
      ['Database Reset', 'RESET', 'RESET', '—', '—', '—'],
      ['Employees / Roles', 'MANAGE', 'MANAGE', 'VIEW', 'VIEW', 'VIEW'],
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'ROLES & PERMISSIONS',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Application access matrix. Supabase RPCs remain the authoritative security boundary.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 18),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('FUNCTION')),
                ...roles.map((r) => DataColumn(label: Text(r))),
              ],
              rows: rows
                  .map(
                    (row) => DataRow(
                      cells: row
                          .map(
                            (value) => DataCell(
                              Text(
                                value,
                                style: TextStyle(
                                  fontWeight: value == '—' ? FontWeight.normal : FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'EDITOR is catalog-specific and remains read-only in Store Management because catalog publishing is restricted to manager, admin and owner accounts. Staff and editor accounts can still access permitted read-only screens.',
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 52),
              const SizedBox(height: 12),
              const Text(
                'Unable to load employees',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('RETRY')),
            ],
          ),
        ),
      );
}
