// lib/views/employee_views/leave_request_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/leave_model.dart';
import '../../viewmodels/leave_viewmodel.dart';

// ── Public entry point ────────────────────────────────────────────────────────

Future<void> showLeaveRequestDialog(
  BuildContext context, {
  required String userId,
  required String employeeName,
  required String employeeId,
  required String employeeRole,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LeaveRequestDialog(
      userId: userId,
      employeeName: employeeName,
      employeeRole: employeeRole,
      employeeId: employeeId,
    ),
  );
}

// ── Dialog widget ─────────────────────────────────────────────────────────────

class _LeaveRequestDialog extends StatefulWidget {
  final String userId;
  final String employeeName;
  final String employeeRole;
  final String employeeId;

  const _LeaveRequestDialog({
    required this.userId,
    required this.employeeName,
    required this.employeeRole,
    required this.employeeId,
  });

  @override
  State<_LeaveRequestDialog> createState() => _LeaveRequestDialogState();
}

class _LeaveRequestDialogState extends State<_LeaveRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();

  LeaveType _type = LeaveType.sick;
  LeaveDuration _duration = LeaveDuration.fullDay;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  bool _submitting = false;

  // For half day, toDate always equals fromDate
  bool get _isHalfDay => _duration != LeaveDuration.fullDay;

  int get _days => _isHalfDay ? 1 : _toDate.difference(_fromDate).inDays + 1;

  double get _deductedDays => _isHalfDay ? 0.5 : _days.toDouble();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _fromDate : _toDate;
    final first = isFrom ? DateTime.now() : _fromDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF2563EB)),
        ),
        child: child!,
      ),
    );

    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        // For half day, keep toDate in sync
        if (_isHalfDay) {
          _toDate = picked;
        } else if (_toDate.isBefore(_fromDate)) {
          _toDate = _fromDate;
        }
      } else {
        _toDate = picked;
      }
    });
  }

  // ── Duration changed ──────────────────────────────────────────────────────

  void _onDurationChanged(LeaveDuration d) {
    setState(() {
      _duration = d;
      // Lock toDate to fromDate for half days
      if (_isHalfDay) _toDate = _fromDate;
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final vm = context.read<LeaveViewModel>();
    final success = await vm.submitLeave(
      userId: widget.userId,
      employeeName: widget.employeeName,
      emp_id: widget.employeeId,
      employeeRole: widget.employeeRole,
      type: _type,
      duration: _duration,
      fromDate: _fromDate,
      toDate: _toDate,
      reason: _reasonCtrl.text,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Leave request submitted successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? 'Failed to submit.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Request Leave',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Fill in the details below',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: Colors.grey,
                    ),
                  ],
                ),
                const Divider(height: 24),

                // ── Leave Type ───────────────────────────────────────────
                const _FieldLabel(text: 'Leave Type'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: LeaveType.values.map((t) {
                    final selected = _type == t;
                    return GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: _Chip(label: t.label, selected: selected),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // ── Duration ─────────────────────────────────────────────
                const _FieldLabel(text: 'Duration'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: LeaveDuration.values.map((d) {
                    final selected = _duration == d;
                    return GestureDetector(
                      onTap: () => _onDurationChanged(d),
                      child: _Chip(
                        label: d.label,
                        selected: selected,
                        selectedColor: _durationColor(d),
                      ),
                    );
                  }).toList(),
                ),

                // Half day info banner
                if (_isHalfDay) ...[
                  const SizedBox(height: 10),
                  _HalfDayBanner(duration: _duration),
                ],
                const SizedBox(height: 16),

                // ── Date range ───────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel(text: 'From Date'),
                          const SizedBox(height: 6),
                          _DateTile(
                            date: fmt.format(_fromDate),
                            onTap: () => _pickDate(isFrom: true),
                          ),
                        ],
                      ),
                    ),
                    // Only show To Date for full day leaves
                    if (!_isHalfDay) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel(text: 'To Date'),
                            const SizedBox(height: 6),
                            _DateTile(
                              date: fmt.format(_toDate),
                              onTap: () => _pickDate(isFrom: false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Days summary pill
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _isHalfDay
                          ? '0.5 day deducted from balance'
                          : '$_days day${_days > 1 ? 's' : ''} selected'
                                ' · $_deductedDays deducted',
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Reason ───────────────────────────────────────────────
                const _FieldLabel(text: 'Reason'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _reasonCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Describe your reason...',
                    hintStyle: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF2563EB),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Reason is required'
                      : null,
                ),
                const SizedBox(height: 20),

                // ── Submit button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Submit Request',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _durationColor(LeaveDuration d) {
    switch (d) {
      case LeaveDuration.fullDay:
        return const Color(0xFF2563EB);
      case LeaveDuration.firstHalf:
        return const Color(0xFF7C3AED);
      case LeaveDuration.secondHalf:
        return const Color(0xFF0891B2);
    }
  }
}

// ── Half day info banner ──────────────────────────────────────────────────────

class _HalfDayBanner extends StatelessWidget {
  final LeaveDuration duration;
  const _HalfDayBanner({required this.duration});

  @override
  Widget build(BuildContext context) {
    final isFirst = duration == LeaveDuration.firstHalf;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isFirst ? const Color(0xFFF5F3FF) : const Color(0xFFECFEFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFirst
              ? const Color(0xFF7C3AED).withValues(alpha: 0.3)
              : const Color(0xFF0891B2).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isFirst ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
            size: 16,
            color: isFirst ? const Color(0xFF7C3AED) : const Color(0xFF0891B2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isFirst
                  ? 'Morning off · You may check in after 1:00 PM'
                  : 'Afternoon off · You may check out at 1:00 PM',
              style: TextStyle(
                fontSize: 12,
                color: isFirst
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF0891B2),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;

  const _Chip({
    required this.label,
    required this.selected,
    this.selectedColor = const Color(0xFF2563EB),
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: selected ? selectedColor : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: selected ? selectedColor : const Color(0xFFE2E8F0),
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: selected ? Colors.white : const Color(0xFF475569),
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF374151),
    ),
  );
}

class _DateTile extends StatelessWidget {
  final String date;
  final VoidCallback onTap;
  const _DateTile({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_outlined,
            color: Color(0xFF2563EB),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            date,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}
