// lib/views/HR_views/hr_work_hour_overrides_screen.dart
//
// HR-only screen for managing per-employee work-hour overrides.
// Pick an employee → see existing overrides → add a new one (date range
// + start/end time + reason) → or delete an existing one.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/work_hour_override_model.dart';
import '../../services/work_hour_override_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/employee_viewmodel.dart';

class HRWorkHourOverridesScreen extends StatefulWidget {
  const HRWorkHourOverridesScreen({super.key});

  @override
  State<HRWorkHourOverridesScreen> createState() =>
      _HRWorkHourOverridesScreenState();
}

class _HRWorkHourOverridesScreenState extends State<HRWorkHourOverridesScreen> {
  final _service = WorkHourOverrideService();
  String? _selectedUid;
  bool _loading = false;
  List<WorkHourOverride> _overrides = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthViewModel>();
      final empVM = context.read<EmployeeViewModel>();
      if (empVM.employees.isEmpty && auth.currentUser != null) {
        await empVM.loadEmployees(auth.currentUser!.uid);
      }
      if (!mounted) return;
      if (empVM.employees.isNotEmpty) {
        setState(() => _selectedUid = empVM.employees.first.uid);
        await _refresh();
      }
    });
  }

  Future<void> _refresh() async {
    if (_selectedUid == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.listForUser(_selectedUid!);
      if (!mounted) return;
      setState(() => _overrides = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onAddTap() async {
    if (_selectedUid == null) return;
    final result = await showModalBottomSheet<_NewOverrideResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddOverrideSheet(),
    );
    if (result == null || !mounted) return;
    final auth = context.read<AuthViewModel>();
    final createdBy = auth.currentUser?.uid ?? '';
    try {
      final override = WorkHourOverride.forCreate(
        userId: _selectedUid!,
        startDate: result.startDate,
        endDate: result.endDate,
        workStartHour: result.startTime.hour,
        workStartMinute: result.startTime.minute,
        workEndHour: result.endTime.hour,
        workEndMinute: result.endTime.minute,
        reason: result.reason,
        createdBy: createdBy,
      );
      await _service.create(override);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Override saved.'),
          backgroundColor: Color(0xFF059669),
        ),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _onDeleteTap(WorkHourOverride o) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete override?'),
        content: Text(
          '${DateFormat('d MMM yyyy').format(o.startDate)} – '
          '${DateFormat('d MMM yyyy').format(o.endDate)}\n'
          '${_fmtTime(o.workStartHour, o.workStartMinute)} – '
          '${_fmtTime(o.workEndHour, o.workEndMinute)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.delete(o.id);
      if (!mounted) return;
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final empVM = context.watch<EmployeeViewModel>();
    final employees = empVM.employees;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Custom Work Hours',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Employee picker card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EMPLOYEE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedUid,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      items: employees.map<DropdownMenuItem<String>>((e) {
                        final uid = e.uid;
                        final name =
                            e.name.isNotEmpty ? e.name : e.email;
                        return DropdownMenuItem<String>(
                          value: uid,
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() => _selectedUid = v);
                        _refresh();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedUid == null ? null : _onAddTap,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add custom hours'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Failed to load: $_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB91C1C)),
          ),
        ),
      );
    }
    if (_overrides.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.schedule_rounded,
                  size: 48, color: Color(0xFF94A3B8)),
              SizedBox(height: 10),
              Text(
                'No custom hours set.\nThis employee follows the default 9 AM – 6 PM schedule.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _overrides.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final o = _overrides[i];
        return _OverrideTile(
          entry: o,
          onDelete: () => _onDeleteTap(o),
        );
      },
    );
  }
}

// ─── Override row tile ───────────────────────────────────────────────────────
//
// NOTE: the field is named `entry` (not `override`) to avoid shadowing the
// Dart `@override` annotation inside the class body. Renaming saves a
// confusing `invalid_annotation` analyzer error.
class _OverrideTile extends StatelessWidget {
  final WorkHourOverride entry;
  final VoidCallback onDelete;
  const _OverrideTile({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final sameDay = entry.startDateKey == entry.endDateKey;
    final dateLabel = sameDay
        ? DateFormat('EEE d MMM yyyy').format(entry.startDate)
        : '${DateFormat('d MMM').format(entry.startDate)}'
            ' → '
            '${DateFormat('d MMM yyyy').format(entry.endDate)}';
    final timeLabel =
        '${_fmtTime(entry.workStartHour, entry.workStartMinute)}'
        '  →  '
        '${_fmtTime(entry.workEndHour, entry.workEndMinute)}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.access_time_filled_rounded,
              color: Color(0xFF2563EB),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
                if (entry.reason != null && entry.reason!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.reason!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFDC2626),
            ),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}

// ─── Add-override bottom sheet ───────────────────────────────────────────────
class _AddOverrideSheet extends StatefulWidget {
  const _AddOverrideSheet();

  @override
  State<_AddOverrideSheet> createState() => _AddOverrideSheetState();
}

class _AddOverrideSheetState extends State<_AddOverrideSheet> {
  DateTimeRange? _range;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _range ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(now.year, now.month, now.day),
          ),
      helpText: 'Select dates the custom hours apply to',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2563EB),
            onPrimary: Colors.white,
            onSurface: Color(0xFF0F172A),
          ),
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _range = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2563EB),
            onPrimary: Colors.white,
            onSurface: Color(0xFF0F172A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  bool _isValid() {
    if (_range == null) return false;
    final startMins = _startTime.hour * 60 + _startTime.minute;
    final endMins = _endTime.hour * 60 + _endTime.minute;
    if (endMins <= startMins) return false;
    return true;
  }

  void _onSave() {
    if (!_isValid()) return;
    Navigator.of(context).pop(
      _NewOverrideResult(
        startDate: _range!.start,
        endDate: _range!.end,
        startTime: _startTime,
        endTime: _endTime,
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final rangeLabel = _range == null
        ? 'Pick dates'
        : (_range!.start == _range!.end
            ? DateFormat('EEE d MMM yyyy').format(_range!.start)
            : '${DateFormat('d MMM').format(_range!.start)} → ${DateFormat('d MMM yyyy').format(_range!.end)}');
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Add custom hours',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'The employee can check in and out within this window on the dates you pick. Weekends inside the range are not covered.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _SectionLabel(label: 'Date range'),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _pickDateRange,
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(rangeLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SectionLabel(label: 'Working hours'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _TimeButton(
                      label: 'Start',
                      time: _startTime,
                      onTap: () => _pickTime(true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TimeButton(
                      label: 'End',
                      time: _endTime,
                      onTap: () => _pickTime(false),
                    ),
                  ),
                ],
              ),
              if (!_isValid() && _range != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'End time must be after start time.',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _SectionLabel(label: 'Reason (optional)'),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Training week, on-call rotation',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isValid() ? _onSave : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _fmtTimeOfDay(time),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFF64748B),
        letterSpacing: 0.6,
      ),
    );
  }
}

class _NewOverrideResult {
  final DateTime startDate;
  final DateTime endDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? reason;
  _NewOverrideResult({
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    this.reason,
  });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
String _fmtTime(int h, int m) {
  final period = h >= 12 ? 'PM' : 'AM';
  final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$hour:${m.toString().padLeft(2, '0')} $period';
}

String _fmtTimeOfDay(TimeOfDay t) => _fmtTime(t.hour, t.minute);
