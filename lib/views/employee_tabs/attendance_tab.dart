import 'package:flutter/material.dart';
import '../../models/attendance_model.dart';
import '../../models/employee_model.dart';
import '../../viewmodels/attendance_viewmodel.dart';
import '../../widgets/stat_card.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

String _fmtTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

String _dur(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

// ════════════════════════════════════════════════════════════════════════════
// AttendanceTab — Monthly View
// ════════════════════════════════════════════════════════════════════════════

class AttendanceTab extends StatefulWidget {
  final Employee employee;
  final AttendanceViewModel attendanceVM;

  const AttendanceTab({
    super.key,
    required this.employee,
    required this.attendanceVM,
  });

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  late int _selectedYear;
  late int _selectedMonth;
  MonthlyArchive? _archive;
  bool _loading = false;

  static const _monthNames = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _shortMonths = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchArchive());
  }

  // ── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchArchive() async {
    setState(() => _loading = true);
    final archive = await widget.attendanceVM.getMonthlyArchiveSilent(
      widget.employee.uid,
      _selectedYear,
      _selectedMonth,
    );
    if (mounted)
      setState(() {
        _archive = archive;
        _loading = false;
      });
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth += delta;
      if (_selectedMonth > 12) {
        _selectedMonth = 1;
        _selectedYear++;
      }
      if (_selectedMonth < 1) {
        _selectedMonth = 12;
        _selectedYear--;
      }
      _archive = null;
    });
    _fetchArchive();
  }

  // ── Derived stats ─────────────────────────────────────────────────────────

  int get _presentDays => _archive?.presentDays ?? 0;
  int get _absentDays => _archive?.absentDays ?? 0;
  int get _totalDays => _archive?.totalDays ?? 0;
  double get _avgHours => _archive?.avgDailyWorkHours ?? 0;
  double get _avgProd => _archive?.avgProductivity ?? 0;

  List<AttendanceModel> get _records {
    if (_archive == null) return [];
    final sorted = _archive!.days.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)); // newest first
    return sorted.map((e) => e.value).toList();
  }

  // ── Status helpers ────────────────────────────────────────────────────────

  String _statusLabel(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.checkedIn:
        return 'Active';
      case AttendanceStatus.onBreak:
        return 'On Break';
      case AttendanceStatus.checkedOut:
        return 'Completed';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.halfDay:
        return 'Half Day';
      case AttendanceStatus.onLeave:
        return 'On Leave';
      case AttendanceStatus.firstHalfLeave:
        return '½ AM Leave';
      case AttendanceStatus.secondHalfLeave:
        return '½ PM Leave';
    }
  }

  Color _statusColor(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.checkedIn:
        return const Color(0xFF10B981);
      case AttendanceStatus.onBreak:
        return const Color(0xFFF59E0B);
      case AttendanceStatus.checkedOut:
        return const Color(0xFF6366F1);
      case AttendanceStatus.absent:
        return const Color(0xFFEF4444);
      case AttendanceStatus.present:
        return const Color(0xFF3B82F6);
      case AttendanceStatus.late:
        return const Color(0xFFEA580C);
      case AttendanceStatus.halfDay:
        return const Color(0xFF8B5CF6);
      case AttendanceStatus.onLeave:
        return const Color(0xFF0891B2);
      case AttendanceStatus.firstHalfLeave:
        return const Color(0xFF7C3AED);
      case AttendanceStatus.secondHalfLeave:
        return const Color(0xFF0E7490);
    }
  }

  Color _statusBg(AttendanceStatus s) => _statusColor(s).withOpacity(0.1);

  String _formatDate(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${_shortMonths[d.month]} ${d.day}';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMonthSelector(),
        const SizedBox(height: 16),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          _buildSummaryCards(),
          const SizedBox(height: 20),
          _buildTableHeader(),
          const SizedBox(height: 10),
          _records.isEmpty ? _buildEmptyState() : _buildTable(),
        ],
      ],
    );
  }

  // ── Month Selector ────────────────────────────────────────────────────────

  Widget _buildMonthSelector() {
    final isCurrentMonth =
        _selectedYear == DateTime.now().year &&
        _selectedMonth == DateTime.now().month;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left_rounded),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Column(
            children: [
              Text(
                _monthNames[_selectedMonth],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                '$_selectedYear',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          IconButton(
            onPressed: isCurrentMonth ? null : () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right_rounded),
            style: IconButton.styleFrom(
              backgroundColor: isCurrentMonth
                  ? const Color(0xFFF8FAFC)
                  : const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary Cards ─────────────────────────────────────────────────────────

  Widget _buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.check_circle_outline_rounded,
                label: 'Present',
                value: '$_presentDays / $_totalDays days',
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                icon: Icons.cancel_outlined,
                label: 'Absent',
                value: '$_absentDays days',
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.access_time_rounded,
                label: 'Avg. Daily Hours',
                value: '${_avgHours.toStringAsFixed(1)}h',
                color: const Color(0xFF6366F1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                icon: Icons.bolt_rounded,
                label: 'Avg. Productivity',
                value: '${_avgProd.toStringAsFixed(0)}%',
                color: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Table ─────────────────────────────────────────────────────────────────

  Widget _buildTableHeader() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        '${_monthNames[_selectedMonth]} $_selectedYear — ${_records.length} records',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
      if (_archive != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_archive!.presentDays} Present',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF10B981),
            ),
          ),
        ),
    ],
  );

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            horizontalMargin: 16,
            headingRowHeight: 44,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 52,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            dividerThickness: 1,
            columns: const [
              DataColumn(
                label: Text(
                  'Date',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              DataColumn(
                label: Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              DataColumn(
                label: Text(
                  'Check-In',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              DataColumn(
                label: Text(
                  'Check-Out',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              DataColumn(
                label: Text(
                  'Work Duration',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              DataColumn(
                label: Text(
                  'Productivity',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
            rows: _records.map((r) {
              final statusColor = _statusColor(r.status);
              final isAbsent = r.status == AttendanceStatus.absent;
              final isLeave = r.status.isAnyLeave;
              return DataRow(
                color: WidgetStateProperty.resolveWith((states) {
                  if (isAbsent) return const Color(0xFFFEF2F2);
                  if (isLeave) return const Color(0xFFF5F3FF);
                  return null;
                }),
                cells: [
                  // Date
                  DataCell(
                    Text(
                      _formatDate(r.date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),

                  // Status badge
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusBg(r.status),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(r.status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),

                  // Check-in
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.login_rounded,
                          size: 13,
                          color: r.checkInTime != null
                              ? const Color(0xFF10B981)
                              : Colors.black26,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          r.checkInTime != null
                              ? _fmtTime(r.checkInTime!)
                              : '--:--',
                          style: TextStyle(
                            fontSize: 12,
                            color: r.checkInTime != null
                                ? const Color(0xFF374151)
                                : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Check-out
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 13,
                          color: r.checkOutTime != null
                              ? const Color(0xFF6366F1)
                              : Colors.black26,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          r.checkOutTime != null
                              ? _fmtTime(r.checkOutTime!)
                              : '--:--',
                          style: TextStyle(
                            fontSize: 12,
                            color: r.checkOutTime != null
                                ? const Color(0xFF374151)
                                : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Work duration
                  DataCell(
                    Text(
                      (isAbsent || (isLeave && r.checkInTime == null))
                          ? '—'
                          : _dur(r.totalWorkDuration),
                      style: TextStyle(
                        fontSize: 12,
                        color: isAbsent
                            ? Colors.black38
                            : const Color(0xFF374151),
                        fontWeight: isAbsent
                            ? FontWeight.normal
                            : FontWeight.w500,
                      ),
                    ),
                  ),

                  // Productivity
                  DataCell(
                    (isAbsent || (isLeave && r.checkInTime == null))
                        ? const Text(
                            '—',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black38,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 36,
                                height: 4,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: r.productivityPercent / 100,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    valueColor: AlwaysStoppedAnimation(
                                      r.productivityPercent >= 80
                                          ? const Color(0xFF10B981)
                                          : r.productivityPercent >= 50
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${r.productivityPercent}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  // FIX: updated subtitle — absent records are written by the cloud function
  // and will appear here even if the employee never checks in.

  Widget _buildEmptyState() => Container(
    padding: const EdgeInsets.symmetric(vertical: 48),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.calendar_month_outlined,
          size: 48,
          color: Colors.black26,
        ),
        const SizedBox(height: 12),
        Text(
          'No records for ${_monthNames[_selectedMonth]} $_selectedYear',
          style: const TextStyle(fontSize: 14, color: Colors.black45),
        ),
        const SizedBox(height: 4),
        const Text(
          'Records are created on check-in, check-out, and automatically at noon for absences',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.black26),
        ),
      ],
    ),
  );
}
