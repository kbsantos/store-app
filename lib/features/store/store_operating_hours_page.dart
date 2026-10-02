import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/store_management_auth.dart';

class StoreOperatingHoursPage extends StatefulWidget {
  const StoreOperatingHoursPage({super.key});

  @override
  State<StoreOperatingHoursPage> createState() => _StoreOperatingHoursPageState();
}

class _DayHours {
  _DayHours({
    required this.dayOfWeek,
    required this.name,
    required this.isClosed,
    this.openTime,
    this.closeTime,
  });

  final int dayOfWeek;
  final String name;
  bool isClosed;
  TimeOfDay? openTime;
  TimeOfDay? closeTime;

  static _DayHours fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTime(dynamic value) {
      final text = value?.toString();
      if (text == null || text.isEmpty) return null;
      final parts = text.split(':');
      if (parts.length < 2) return null;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return null;
      return TimeOfDay(hour: hour, minute: minute);
    }

    const names = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    final day = (json['day_of_week'] as num?)?.toInt() ?? 0;
    return _DayHours(
      dayOfWeek: day,
      name: names[day.clamp(0, 6)],
      isClosed: json['is_closed'] == true,
      openTime: parseTime(json['open_time']),
      closeTime: parseTime(json['close_time']),
    );
  }

  Map<String, dynamic> toJson() => {
        'day_of_week': dayOfWeek,
        'is_closed': isClosed,
        'open_time': isClosed ? null : _formatTime(openTime),
        'close_time': isClosed ? null : _formatTime(closeTime),
      };

  static String? _formatTime(TimeOfDay? value) {
    if (value == null) return null;
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _StoreOperatingHoursPageState extends State<StoreOperatingHoursPage> {
  final _auth = const StoreManagementAuth();
  late List<_DayHours> _days;
  bool _loading = true;
  bool _saving = false;

  bool get _canEdit => _auth.role == 'owner' || _auth.role == 'admin';

  @override
  void initState() {
    super.initState();
    _loadHours();
  }

  Future<void> _loadHours() async {
    setState(() => _loading = true);
    try {
      final result = await _auth.client.rpc('get_store_management_operating_hours');
      final rows = (result as List)
          .map((row) => _DayHours.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
      rows.sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
      if (rows.length != 7) {
        throw StateError('The store operating-hours schedule is incomplete.');
      }
      _days = rows;
    } on PostgrestException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Unable to load operating hours: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_canEdit) return;

    for (final day in _days) {
      if (!day.isClosed && (day.openTime == null || day.closeTime == null)) {
        _showError('${day.name}: open and close times are required.');
        return;
      }
      if (!day.isClosed && _sameTime(day.openTime!, day.closeTime!)) {
        _showError('${day.name}: open and close times cannot be the same.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await _auth.client.rpc(
        'update_store_management_operating_hours',
        params: {'p_hours': _days.map((day) => day.toJson()).toList()},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operating hours saved successfully.')),
      );
    } on PostgrestException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Unable to save operating hours: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _sameTime(TimeOfDay a, TimeOfDay b) =>
      a.hour == b.hour && a.minute == b.minute;

  Future<void> _pickTime(_DayHours day, bool opening) async {
    if (!_canEdit || _saving || day.isClosed) return;
    final current = opening ? day.openTime : day.closeTime;
    final selected = await showTimePicker(
      context: context,
      initialTime: current ?? (opening ? const TimeOfDay(hour: 8, minute: 0) : const TimeOfDay(hour: 21, minute: 0)),
      helpText: opening ? 'SELECT OPENING TIME' : 'SELECT CLOSING TIME',
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (opening) {
        day.openTime = selected;
      } else {
        day.closeTime = selected;
      }
    });
  }

  String _formatTime(TimeOfDay? value) {
    if (value == null) return 'Set time';
    return MaterialLocalizations.of(context).formatTimeOfDay(value);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OPERATING HOURS')),
      backgroundColor: const Color(0xFFF5F2ED),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      'OPERATING HOURS',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Set the weekly opening schedule for Store ${_auth.storeId}.',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    ..._days.map(_dayCard),
                    if (!_canEdit) ...[
                      const SizedBox(height: 12),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'This schedule is read-only for your account. Owner or admin access is required to edit operating hours.',
                          ),
                        ),
                      ),
                    ],
                    if (_canEdit) ...[
                      const SizedBox(height: 12),
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
                          label: Text(_saving ? 'SAVING...' : 'SAVE OPERATING HOURS'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _dayCard(_DayHours day) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final controls = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _timeButton(day, true),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('to'),
                ),
                _timeButton(day, false),
              ],
            );

            final switchTile = SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: day.isClosed,
              onChanged: _canEdit && !_saving
                  ? (value) => setState(() => day.isClosed = value)
                  : null,
              title: const Text('Closed'),
            );

            return compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              day.name,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                          ),
                          SizedBox(width: 125, child: switchTile),
                        ],
                      ),
                      if (!day.isClosed) controls,
                    ],
                  )
                : Row(
                    children: [
                      SizedBox(
                        width: 125,
                        child: Text(
                          day.name,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Expanded(child: day.isClosed ? const Text('Closed') : controls),
                      SizedBox(width: 125, child: switchTile),
                    ],
                  );
          },
        ),
      ),
    );
  }

  Widget _timeButton(_DayHours day, bool opening) {
    return OutlinedButton.icon(
      onPressed: _canEdit && !_saving && !day.isClosed
          ? () => _pickTime(day, opening)
          : null,
      icon: const Icon(Icons.schedule_outlined, size: 18),
      label: Text(_formatTime(opening ? day.openTime : day.closeTime)),
    );
  }
}
