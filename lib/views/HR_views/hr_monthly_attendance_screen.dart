// lib/views/HR_views/hr_monthly_attendance_screen.dart
//
// HR-side monthly attendance report. Pick an employee + month, read the
// `attendance_archive/{userId}_{year}_{MM}` doc, apply the policy in
// AttendancePolicy.compute() to each weekday entry, and show a summary +
// per-day breakdown with the deduction reason and amount.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/attendance_model.dart';
import '../../models/attendance_policy.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/employee_viewmodel.dart';

class HRMonthlyAttendanceScreen extends StatefulWidget {
  const HRMonthlyAttendanceScreen({super.key});

  @override
  State<HRMonthlyAttendanceScreen> createState() =>
      _HRMonthlyAttendanceScreenState();
}

class _HRMonthlyAttendanceScreenState extends State<HRMonthlyAttendanceScreen> {
  String? _selectedEmployeeUid;
  late int _year;
  late int _month;
  bool _loading = false;
  String? _error;
  MonthlyArchive? _archive;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthViewModel>();
      final empVM = context.read<EmployeeViewModel>();
      if (empVM.employees.isEmpty && auth.currentUser != null) {
        await empVM.loadEmployees(auth.currentUser!.uid);
      }
      if (!mounted) return;
      if (empVM.employees.isNotEmpty) {
        setState(() => _selectedEmployeeUid = empVM.employees.first.uid);
        await _loadArchive();
      }
    });
  }

  Future<void> _loadArchive() async {
    if (_selectedEmployeeUid == null || _selectedEmployeeUid!.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _archive = null;
    });
    try {
      final docId =
          MonthlyArchive.docId(_selectedEmployeeUid!, _year, _month);
      final snap = await FirebaseFirestore.instance
          .collection('attendance_archive')
          .doc(docId)
          .get();
      if (!mounted) return;
      _archive = (snap.exists && snap.data() != null)
          ? MonthlyArchive.fromMap(snap.data()!)
          : null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shiftMonth(int delta) {
    var m = _month + delta;
    var y = _year;
    while (m < 1) {
      m += 12;
      y -= 1;
    }
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    setState(() {
      _month = m;
      _year = y;
    });
    _loadArchive();
  }

  @override
  Widget build(BuildContext context) {
    final empVM = context.watch<EmployeeViewModel>();
    final employees = empVM.employees;

    final daysSorted = _archive == null
        ? const <MapEntry<String, AttendanceModel>>[]
        : (_archive!.days.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)));

    final deductions =
        daysSorted.map((e) => AttendancePolicy.compute(e.value)).toList();
    final totalDeduction =
        deductions.fold<double>(0, (s, d) => s + d.totalDeduction);
    final netPay = AttendancePolicy.monthlySalary - totalDeduction;
    final daysRecorded = daysSorted.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Monthly Attendance Report',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilterCard(
                employees: employees,
                selectedUid: _selectedEmployeeUid,
                onEmployeeChanged: (uid) {
                  setState(() => _selectedEmployeeUid = uid);
                  _loadArchive();
                },
                monthLabel:
                    DateFormat('MMMM yyyy').format(DateTime(_year, _month)),
                onPrev: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Gross',
                      value: 'Rs ${_fmtMoney(AttendancePolicy.monthlySalary)}',
                      color: const Color(0xFF2563EB),
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Deductions',
                      value: 'Rs ${_fmtMoney(totalDeduction)}',
                      color: const Color(0xFFDC2626),
                      icon: Icons.trending_down_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Net pay',
                      value: 'Rs ${_fmtMoney(netPay)}',
                      color: const Color(0xFF059669),
                      icon: Icons.payments_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Days recorded',
                      value:
                          '$daysRecorded / ${AttendancePolicy.standardWorkingDays}',
                      color: const Color(0xFF7C3AED),
                      icon: Icons.event_available_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _PolicyBanner(),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorBlock(message: _error!)
              else if (_selectedEmployeeUid == null || employees.isEmpty)
                const _EmptyBlock(text: 'No employees available.')
              else if (daysSorted.isEmpty)
                _EmptyBlock(
                  text:
                      'No attendance recorded for this employee in ${DateFormat('MMMM yyyy').format(DateTime(_year, _month))}.',
                )
              else
                ...daysSorted.asMap().entries.map((e) {
                  final dayKey = e.value.key;
                  final att = e.value.value;
                  final ded = deductions[e.key];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DayRow(dayKey: dayKey, att: att, ded: ded),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Filter card ──────────────────────────────────────────────────────────────
class _FilterCard extends StatelessWidget {
  final List<dynamic> employees; // Employee — kept dynamic to avoid import churn
  final String? selectedUid;
  final ValueChanged<String?> onEmployeeChanged;
  final String monthLabel;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _FilterCard({
    required this.employees,
    required this.selectedUid,
    required this.onEmployeeChanged,
    required this.monthLabel,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedUid,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Employee',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: employees.map<DropdownMenuItem<String>>((e) {
              final uid = e.uid as String;
              final name = (e.name as String).isNotEmpty
                  ? e.name as String
                  : e.email as String;
              return DropdownMenuItem<String>(
                value: uid,
                child: Text(name, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: onEmployeeChanged,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: onPrev,
                  tooltip: 'Previous month',
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      monthLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: onNext,
                  tooltip: 'Next month',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary card ────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Policy banner ───────────────────────────────────────────────────────────
class _PolicyBanner extends StatelessWidget {
  const _PolicyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.rule_rounded,
              size: 16, color: Color(0xFF1D4ED8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Late: 15% up to 10:00 AM • 50% after 10:00 AM     '
              'Early-out: 25% (5–6 PM) • 50% before 5:00 PM     '
              'Absent: 100%     Approved leave: 0%     '
              'Per-day deduction capped at 100% of '
              'Rs ${AttendancePolicy.perDayWage.toStringAsFixed(0)}.',
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF1D4ED8),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Day row ─────────────────────────────────────────────────────────────────
class _DayRow extends StatelessWidget {
  final String dayKey;
  final AttendanceModel att;
  final DayDeduction ded;
  const _DayRow({
    required this.dayKey,
    required this.att,
    required this.ded,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(dayKey);
    final ci = att.checkInTime;
    final co = att.checkOutTime;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('EEE  d MMM').format(date),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(status: att.status),
              const Spacer(),
              if (ded.totalDeduction > 0)
                Text(
                  '- Rs ${ded.totalDeduction.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFDC2626),
                  ),
                )
              else
                Text(
                  '+ Rs ${ded.wage.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF059669),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TimeCell(
                  label: 'Check-in',
                  value: ci != null
                      ? DateFormat('HH:mm').format(ci)
                      : '—',
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TimeCell(
                  label: 'Check-out',
                  value: co != null
                      ? DateFormat('HH:mm').format(co)
                      : '—',
                  color: const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TimeCell(
                  label: 'Worked',
                  value: _hms(att.totalWorkSeconds),
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
          if (ded.infractions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: ded.infractions
                    .map((i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.remove_circle_outline_rounded,
                                  size: 14, color: Color(0xFFB91C1C)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  i.label,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF7F1D1D),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '${(i.pct * 100).toStringAsFixed(0)}%  ·  -Rs ${i.amount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFB91C1C),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Net for day: Rs ${ded.netForDay.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TimeCell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AttendanceStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      AttendanceStatus.absent => (
        const Color(0xFFFEE2E2),
        const Color(0xFFB91C1C),
      ),
      AttendanceStatus.late => (
        const Color(0xFFFEF3C7),
        const Color(0xFFB45309),
      ),
      AttendanceStatus.onLeave ||
      AttendanceStatus.firstHalfLeave ||
      AttendanceStatus.secondHalfLeave =>
        (const Color(0xFFEDE9FE), const Color(0xFF6D28D9)),
      AttendanceStatus.halfDay => (
        const Color(0xFFFFE4E6),
        const Color(0xFFBE123C),
      ),
      _ => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.shortLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

// ─── Empty / error blocks ────────────────────────────────────────────────────
class _EmptyBlock extends StatelessWidget {
  final String text;
  const _EmptyBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_busy_rounded,
              size: 44, color: Color(0xFF94A3B8)),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  const _ErrorBlock({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: Color(0xFFB91C1C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Failed to load: $message',
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
String _fmtMoney(double v) {
  final s = v.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    buf.write(s[i]);
    final rem = s.length - i - 1;
    if (rem > 0 && rem % 3 == 0) buf.write(',');
  }
  return buf.toString();
}

String _hms(int secs) {
  if (secs <= 0) return '—';
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}
