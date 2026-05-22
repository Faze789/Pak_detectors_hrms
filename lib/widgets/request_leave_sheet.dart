// lib/widgets/request_leave_sheet.dart
//
// Bottom-sheet UI for submitting a leave request. Drop-in replacement for
// the date-only `showDateRangePicker` flow on attendance_screen.dart's
// "Request Leave" tap. Adds:
//   • Leave-type dropdown (gender-aware; "Custom" always available)
//   • Date-range picker
//   • Optional reason field
//   • "Read leave policy" button → opens `LeavePolicyInstructionsDialog`
//
// On Save, returns a `RequestLeaveResult` to the caller — the caller is
// responsible for calling `AttendanceViewModel.submitLeaveRequest` with
// the type fields plumbed through. This keeps the sheet pure-UI.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/leave_policy.dart';

class RequestLeaveResult {
  final DateTimeRange dateRange;
  final int workingDays;
  final RequestLeaveType type;
  final String? reason;
  const RequestLeaveResult({
    required this.dateRange,
    required this.workingDays,
    required this.type,
    this.reason,
  });
}

Future<RequestLeaveResult?> showRequestLeaveSheet(
  BuildContext context, {
  required String? gender,
}) {
  return showModalBottomSheet<RequestLeaveResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RequestLeaveSheet(gender: gender),
  );
}

class _RequestLeaveSheet extends StatefulWidget {
  final String? gender;
  const _RequestLeaveSheet({required this.gender});

  @override
  State<_RequestLeaveSheet> createState() => _RequestLeaveSheetState();
}

class _RequestLeaveSheetState extends State<_RequestLeaveSheet> {
  late List<RequestLeaveType> _options;
  late RequestLeaveType _selectedType;
  DateTimeRange? _range;
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _options = availableLeaveTypesForGender(widget.gender);
    _selectedType = _options.first;
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  int _countWorkingDays(DateTime s, DateTime e) {
    int n = 0;
    var cur = DateTime(s.year, s.month, s.day);
    final end = DateTime(e.year, e.month, e.day);
    while (!cur.isAfter(end)) {
      if (cur.weekday != DateTime.saturday && cur.weekday != DateTime.sunday) {
        n++;
      }
      cur = cur.add(const Duration(days: 1));
    }
    return n;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: tomorrow,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _range,
      helpText: 'Select leave dates',
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

  bool get _canSubmit => _range != null;

  void _onSave() {
    if (!_canSubmit) return;
    final days = _countWorkingDays(_range!.start, _range!.end);
    if (days == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected range has no working days.')),
      );
      return;
    }
    Navigator.of(context).pop(
      RequestLeaveResult(
        dateRange: _range!,
        workingDays: days,
        type: _selectedType,
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final rangeLabel = _range == null
        ? 'Pick dates'
        : '${DateFormat('d MMM').format(_range!.start)} → '
            '${DateFormat('d MMM yyyy').format(_range!.end)}';
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
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Request Leave',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => showLeavePolicyInstructions(context),
                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                    label: const Text('Policy'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const _SectionLabel('Leave type'),
              const SizedBox(height: 6),
              DropdownButtonFormField<RequestLeaveType>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                items: _options.map((t) {
                  return DropdownMenuItem<RequestLeaveType>(
                    value: t,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) =>
                    setState(() => _selectedType = v ?? _selectedType),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _selectedType.quotaHint,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _SectionLabel('Dates'),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _pickDateRange,
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(rangeLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _SectionLabel('Reason (optional)'),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: _selectedType == RequestLeaveType.custom
                      ? 'Required for custom — describe your situation'
                      : 'Add any context for HR / your lead',
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
                  onPressed: _canSubmit ? _onSave : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Submit',
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFF64748B),
        letterSpacing: 0.6,
      ),
    );
  }
}

// ─── Policy instructions dialog ──────────────────────────────────────────────

Future<void> showLeavePolicyInstructions(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Leave Policy',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'For reference only. Final approval rests with HR.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                ...LeavePolicy.instructions.map(
                  (e) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.body,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF475569),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
