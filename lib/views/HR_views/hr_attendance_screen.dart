// lib/screens/attendance/hr_attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/attendance_model.dart';
import '../../viewmodels/attendance_viewmodel.dart';
import '../../viewmodels/employee_viewmodel.dart';

// ─── Responsive breakpoints ───────────────────────────────────────────────────
abstract class _BP {
  static const double mobile = 600;
}

// ─── Attendance status enum (HR view) ────────────────────────────────────────
enum _Status { present, absent, late, leave, unknown }

extension _StatusExt on _Status {
  String get label {
    switch (this) {
      case _Status.present:
        return 'Present';
      case _Status.absent:
        return 'Absent';
      case _Status.late:
        return 'Late';
      case _Status.leave:
        return 'Leave';
      case _Status.unknown:
        return 'Unknown';
    }
  }

  Color get fg {
    switch (this) {
      case _Status.present:
        return const Color(0xFF065F46);
      case _Status.absent:
        return const Color(0xFF991B1B);
      case _Status.late:
        return const Color(0xFF92400E);
      case _Status.leave:
        return const Color(0xFF1E40AF);
      case _Status.unknown:
        return const Color(0xFF475569);
    }
  }

  Color get bg {
    switch (this) {
      case _Status.present:
        return const Color(0xFFECFDF5);
      case _Status.absent:
        return const Color(0xFFFEF2F2);
      case _Status.late:
        return const Color(0xFFFFFBEB);
      case _Status.leave:
        return const Color(0xFFEFF6FF);
      case _Status.unknown:
        return const Color(0xFFF1F5F9);
    }
  }

  Color get border {
    switch (this) {
      case _Status.present:
        return const Color(0xFF6EE7B7);
      case _Status.absent:
        return const Color(0xFFFCA5A5);
      case _Status.late:
        return const Color(0xFFFCD34D);
      case _Status.leave:
        return const Color(0xFF93C5FD);
      case _Status.unknown:
        return const Color(0xFFCBD5E1);
    }
  }

  IconData get icon {
    switch (this) {
      case _Status.present:
        return Icons.check_circle_outline_rounded;
      case _Status.absent:
        return Icons.cancel_outlined;
      case _Status.late:
        return Icons.schedule_rounded;
      case _Status.leave:
        return Icons.calendar_today_rounded;
      case _Status.unknown:
        return Icons.help_outline_rounded;
    }
  }
}

// ─── Row data model ───────────────────────────────────────────────────────────
class _AttendanceRow {
  final String uid;
  final String name;
  final String role;
  final String department;
  final String? checkIn;
  final String? checkOut;
  final String? workHours;
  final _Status status;
  final String? statusDetail;

  const _AttendanceRow({
    required this.uid,
    required this.name,
    required this.role,
    required this.department,
    this.checkIn,
    this.checkOut,
    this.workHours,
    required this.status,
    this.statusDetail,
  });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
String _fmtTime(DateTime? dt) {
  if (dt == null) return '—';
  return DateFormat('HH:mm').format(dt);
}

String _calcHours(DateTime? inT, DateTime? outT) {
  if (inT == null || outT == null) return '—';
  final diff = outT.difference(inT);
  final h = diff.inHours;
  final m = diff.inMinutes % 60;
  return '${h}h ${m}m';
}

// ─── _deriveStatus reads stored AttendanceStatus directly ────────────────────
_Status _deriveStatus(AttendanceModel? rec) {
  if (rec == null) return _Status.absent;

  switch (rec.status) {
    case AttendanceStatus.checkedIn:
    case AttendanceStatus.onBreak:
    case AttendanceStatus.checkedOut:
    case AttendanceStatus.present:
      return _Status.present;

    case AttendanceStatus.late:
      return _Status.late;

    case AttendanceStatus.halfDay:
      return _Status.present;

    case AttendanceStatus.absent:
      return _Status.absent;

    case AttendanceStatus.onLeave:
    case AttendanceStatus.firstHalfLeave:
    case AttendanceStatus.secondHalfLeave:
      return _Status.leave;
  }
}

String? _statusDetail(AttendanceModel? rec) {
  if (rec == null) return null;
  switch (rec.status) {
    case AttendanceStatus.late:
      return rec.checkInTime != null
          ? 'Arrived ${_fmtTime(rec.checkInTime)}'
          : 'Late arrival';
    case AttendanceStatus.firstHalfLeave:
      return '½ AM Leave';
    case AttendanceStatus.secondHalfLeave:
      return '½ PM Leave';
    case AttendanceStatus.halfDay:
      return 'Half Day';
    default:
      return null;
  }
}

// ─── Convert raw Firestore status string → _Status ───────────────────────────
_Status _statusFromString(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'checkedin':
    case 'checked_in':
    case 'present':
    case 'onbreak':
    case 'on_break':
    case 'halfday':
    case 'half_day':
      return _Status.present;
    case 'late':
      return _Status.late;
    case 'absent':
      return _Status.absent;
    case 'onleave':
    case 'on_leave':
    case 'firsthalfleave':
    case 'first_half_leave':
    case 'secondhalfleave':
    case 'second_half_leave':
      return _Status.leave;
    default:
      return _Status.unknown;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HR Attendance Screen
// ══════════════════════════════════════════════════════════════════════════════
class HRAttendanceScreen extends StatefulWidget {
  const HRAttendanceScreen({super.key});

  @override
  State<HRAttendanceScreen> createState() => _HRAttendanceScreenState();
}

class _HRAttendanceScreenState extends State<HRAttendanceScreen> {
  String? _selectedEmployeeUid;
  DateTime _selectedDate = DateTime.now();
  String _statusFilter = 'all';

  final Map<String, AttendanceModel?> _records = {};
  bool _loading = false;
  List<_EmpInfo> _employees = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final empVM = context.read<EmployeeViewModel>();
    await empVM.loadEmployees('');
    if (!mounted) return;

    setState(() {
      _employees = empVM.employees
          .map(
            (e) => _EmpInfo(
              uid: e.uid,
              name: e.name,
              role: e.role ?? '',
              department: e.department ?? '',
            ),
          )
          .toList();
    });

    await _loadRecords();
  }

  Future<void> _loadRecords() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final vm = context.read<AttendanceViewModel>();
    final targets = _selectedEmployeeUid != null
        ? _employees.where((e) => e.uid == _selectedEmployeeUid).toList()
        : _employees;

    final today = DateTime.now();
    final isToday = _isSameDay(_selectedDate, today);

    _records.clear();

    for (final emp in targets) {
      AttendanceModel? rec;

      rec = await vm.getArchivedAttendanceForDay(emp.uid, _selectedDate);

      if (isToday) {
        final liveRec = await vm.getEmployeeLiveRecord(emp.uid);
        if (liveRec != null) rec = liveRec;
      }

      _records[emp.uid] = rec;
    }

    if (mounted) setState(() => _loading = false);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<_AttendanceRow> get _rows {
    final empList = _selectedEmployeeUid != null
        ? _employees.where((e) => e.uid == _selectedEmployeeUid).toList()
        : _employees;

    return empList.map((emp) {
      final rec = _records[emp.uid];
      final status = _deriveStatus(rec);
      return _AttendanceRow(
        uid: emp.uid,
        name: emp.name,
        role: emp.role,
        department: emp.department,
        checkIn: _fmtTime(rec?.checkInTime),
        checkOut: _fmtTime(rec?.checkOutTime),
        workHours: _calcHours(rec?.checkInTime, rec?.checkOutTime),
        status: status,
        statusDetail: _statusDetail(rec),
      );
    }).toList();
  }

  List<_AttendanceRow> get _filteredRows {
    return _rows.where((r) {
      if (_statusFilter == 'all') return true;
      return r.status.label.toLowerCase() == _statusFilter;
    }).toList();
  }

  int get _total => _rows.length;
  int get _present => _rows.where((r) => r.status == _Status.present).length;
  int get _absent => _rows.where((r) => r.status == _Status.absent).length;
  int get _late => _rows.where((r) => r.status == _Status.late).length;
  int get _leave => _rows.where((r) => r.status == _Status.leave).length;
  int get _attendance =>
      _total == 0 ? 0 : ((_present + _late) / _total * 100).round();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2563EB),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _records.clear();
      });
      await _loadRecords();
    }
  }

  void _showMonthlyStatus(
    BuildContext context,
    String uid,
    String name,
    DateTime initialDate,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _MonthlyStatusSheet(uid: uid, name: name, initialDate: initialDate),
    );
  }

  void _showLeaveRequests(BuildContext context, String uid, String name) async {
    final vm = context.read<AttendanceViewModel>();
    final requests = await vm.fetchLeaveRequestsForEmployee(uid);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _EmployeeLeaveRequestsSheet(employeeName: name, requests: requests),
    );
  }

  bool get _isToday => _isSameDay(_selectedDate, DateTime.now());

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < _BP.mobile;
    final hPad = isMobile ? 12.0 : 20.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _HRAttendanceAppBar(isMobile: isMobile),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 12),
                _StatsRow(
                  total: _total,
                  present: _present,
                  absent: _absent,
                  late: _late,
                  leave: _leave,
                  attendance: _attendance,
                  isMobile: isMobile,
                ),
                const SizedBox(height: 16),
                _FilterBar(
                  employees: _employees,
                  selectedEmployeeUid: _selectedEmployeeUid,
                  selectedDate: _selectedDate,
                  statusFilter: _statusFilter,
                  isMobile: isMobile,
                  onEmployeeChanged: (uid) {
                    setState(() {
                      _selectedEmployeeUid = uid;
                      _records.clear();
                    });
                    _loadRecords();
                  },
                  onDateTap: _pickDate,
                  onStatusChanged: (v) =>
                      setState(() => _statusFilter = v ?? 'all'),
                ),
                const SizedBox(height: 16),
                _TableCard(
                  employees_data: _employees,
                  rows: _filteredRows,
                  loading: _loading,
                  isMobile: isMobile,
                  date: _selectedDate,
                  onRowTap: (uid, name) =>
                      _showMonthlyStatus(context, uid, name, _selectedDate),
                  onLeaveHistoryTap: (uid, name) =>
                      _showLeaveRequests(context, uid, name),
                ),
                const SizedBox(height: 20),

                // ── Live Attendance Section (today only) ──────────────────
                if (_isToday)
                  _LiveAttendanceCard(
                    employees: _employees,
                    isMobile: isMobile,
                    filterUid: _selectedEmployeeUid,
                  ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Monthly Status Bottom Sheet (With Month Picker & Circular Graph UI)
// ══════════════════════════════════════════════════════════════════════════════
class _MonthlyStatusSheet extends StatefulWidget {
  final String uid;
  final String name;
  final DateTime initialDate;

  const _MonthlyStatusSheet({
    required this.uid,
    required this.name,
    required this.initialDate,
  });

  @override
  State<_MonthlyStatusSheet> createState() => _MonthlyStatusSheetState();
}

class _MonthlyStatusSheetState extends State<_MonthlyStatusSheet> {
  bool _loading = true;
  late DateTime _selectedMonth;

  int _presentCount = 0;
  int _absentCount = 0;
  int _leaveCount = 0;
  int _lateCount = 0;

  Map<int, _Status> _dayStatuses = {};

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
    );
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    final vm = context.read<AttendanceViewModel>();
    try {
      final archive = await vm.getMonthlyArchiveSilent(
        widget.uid,
        _selectedMonth.year,
        _selectedMonth.month,
      );

      int present = 0, absent = 0, leave = 0, late = 0;
      Map<int, _Status> mappedStatuses = {};

      if (archive != null && archive.days.isNotEmpty) {
        for (var record in archive.days.values) {
          final day = record.date.day;
          final status = _deriveStatus(record);
          mappedStatuses[day] = status;

          if (status == _Status.present) {
            present++;
          } else if (status == _Status.absent) {
            absent++;
          } else if (status == _Status.leave) {
            leave++;
          } else if (status == _Status.late) {
            late++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _dayStatuses = mappedStatuses;
          _presentCount = present;
          _absentCount = absent;
          _leaveCount = leave;
          _lateCount = late;
        });
      }
    } catch (e) {
      debugPrint('Error fetching monthly archive for sheet: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });
    _fetchData();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2563EB),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      _fetchData();
    }
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildCircularGraph() {
    final total = _presentCount + _absentCount + _leaveCount + _lateCount;
    final double rate = total == 0 ? 0 : ((_presentCount + _lateCount) / total);

    return Container(
      width: 120,
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: rate,
            strokeWidth: 8,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation(
              rate >= 0.8
                  ? const Color(0xFF10B981)
                  : rate >= 0.5
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFEF4444),
            ),
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(rate * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Text(
                  'Rate',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int daysInMonth = DateUtils.getDaysInMonth(
      _selectedMonth.year,
      _selectedMonth.month,
    );

    return Container(
      padding: const EdgeInsets.only(top: 16),
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFDBEAFE),
                  foregroundColor: const Color(0xFF2563EB),
                  child: Text(
                    widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Text(
                        'Monthly Attendance Report',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: Color(0xFF475569),
                  ),
                  onPressed: _loading ? null : () => _changeMonth(-1),
                ),
                InkWell(
                  onTap: _loading ? null : _pickMonth,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMMM yyyy').format(_selectedMonth),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF475569),
                  ),
                  onPressed:
                      (_loading ||
                          (_selectedMonth.year == DateTime.now().year &&
                              _selectedMonth.month == DateTime.now().month))
                      ? null
                      : () => _changeMonth(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _buildCircularGraph(),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryCount(
                                label: 'Present',
                                count: _presentCount,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SummaryCount(
                                label: 'Absent',
                                count: _absentCount,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryCount(
                                label: 'Late',
                                count: _lateCount,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SummaryCount(
                                label: 'Leave',
                                count: _leaveCount,
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: Colors.white,
              child: Wrap(
                spacing: 20,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildLegendItem(const Color(0xFF10B981), 'Present'),
                  _buildLegendItem(const Color(0xFFEF4444), 'Absent'),
                  _buildLegendItem(const Color(0xFFF59E0B), 'Leave'),
                  _buildLegendItem(const Color(0xFF475569), 'Late'),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Expanded(
              child: Container(
                color: Colors.white,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: List.generate(daysInMonth, (index) {
                      final day = index + 1;
                      final status = _dayStatuses[day];

                      Color bgColor = const Color(0xFFF8FAFC);
                      Color textColor = const Color(0xFF94A3B8);
                      Color borderColor = const Color(0xFFE2E8F0);

                      if (status == _Status.present) {
                        bgColor = const Color(0xFF10B981);
                        textColor = Colors.white;
                        borderColor = Colors.transparent;
                      } else if (status == _Status.absent) {
                        bgColor = const Color(0xFFEF4444);
                        textColor = Colors.white;
                        borderColor = Colors.transparent;
                      } else if (status == _Status.leave) {
                        bgColor = const Color(0xFFF59E0B);
                        textColor = Colors.white;
                        borderColor = Colors.transparent;
                      } else if (status == _Status.late) {
                        bgColor = const Color(0xFF475569);
                        textColor = Colors.white;
                        borderColor = Colors.transparent;
                      }

                      return Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: bgColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor),
                          boxShadow: status != null
                              ? [
                                  BoxShadow(
                                    color: bgColor.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCount extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryCount({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Employee info helper ─────────────────────────────────────────────────────
class _EmpInfo {
  final String uid, name, role, department;
  const _EmpInfo({
    required this.uid,
    required this.name,
    required this.role,
    required this.department,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// Leave Requests Bottom Sheet
// ══════════════════════════════════════════════════════════════════════════════
class _EmployeeLeaveRequestsSheet extends StatelessWidget {
  final String employeeName;
  final List<Map<String, dynamic>> requests;

  const _EmployeeLeaveRequestsSheet({
    required this.employeeName,
    required this.requests,
  });

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '—';
    return DateFormat('MMM d, yyyy').format(ts.toDate());
  }

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return '—';
    return DateFormat('MMM d, yyyy · hh:mm a').format(ts.toDate());
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF10B981);
      case 'declined':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFFD1FAE5);
      case 'declined':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'declined':
        return Icons.cancel_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFDBEAFE),
                  foregroundColor: const Color(0xFF2563EB),
                  child: Text(
                    employeeName.isNotEmpty
                        ? employeeName[0].toUpperCase()
                        : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employeeName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Text(
                        'Leave Requests',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: requests.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 64,
                          color: Color(0xFFCBD5E1),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No leave requests found',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final req = requests[i];
                      final status = req['status'] ?? 'pending';
                      final startTs = req['startDate'] as Timestamp?;
                      final endTs = req['endDate'] as Timestamp?;
                      final days = req['totalDays'] ?? 1;
                      final note = (req['note'] ?? '').toString();
                      final reason = (req['rejectionReason'] ?? '').toString();
                      final reviewedAt = req['reviewedAt'] as Timestamp?;
                      final createdAt = req['createdAt'] as Timestamp?;

                      final dateStr = startTs != null && endTs != null
                          ? days == 1
                                ? _formatDate(startTs)
                                : '${DateFormat('MMM d').format(startTs.toDate())} – ${_formatDate(endTs)}'
                          : '—';

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.date_range_rounded,
                                  size: 15,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    dateStr,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusBg(status),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _statusIcon(status),
                                        size: 12,
                                        color: _statusColor(status),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _statusColor(status),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$days day${days > 1 ? 's' : ''} requested',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Requested: ${_formatDateTime(createdAt)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            if (status != 'pending' && reviewedAt != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Reviewed: ${_formatDateTime(reviewedAt)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                            if (note.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Note: $note',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF475569),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            if (status == 'declined' && reason.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Text(
                                  'Reason: $reason',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _LiveRecord
// ══════════════════════════════════════════════════════════════════════════════
class _LiveRecord {
  final String userId;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String? checkInAddress;
  final String? checkOutAddress;
  final String status;
  final int totalWorkSeconds;
  final int totalBreakSeconds;

  const _LiveRecord({
    required this.userId,
    this.checkInTime,
    this.checkOutTime,
    this.checkInAddress,
    this.checkOutAddress,
    required this.status,
    required this.totalWorkSeconds,
    required this.totalBreakSeconds,
  });

  factory _LiveRecord.fromDoc(Map<String, dynamic> data) {
    DateTime? ts(String key) {
      final v = data[key];
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      return null;
    }

    return _LiveRecord(
      userId: (data['userId'] as String?) ?? '',
      checkInTime: ts('checkInTime'),
      checkOutTime: ts('checkOutTime'),
      checkInAddress: data['checkInAddress'] as String?,
      checkOutAddress: data['checkOutAddress'] as String?,
      status: (data['status'] as String?) ?? '',
      totalWorkSeconds: (data['totalWorkSeconds'] as int?) ?? 0,
      totalBreakSeconds: (data['totalBreakSeconds'] as int?) ?? 0,
    );
  }

  String get workLabel {
    if (totalWorkSeconds <= 0) return '—';
    final h = totalWorkSeconds ~/ 3600;
    final m = (totalWorkSeconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }
}

Stream<List<_LiveRecord>> _streamLiveRecords() {
  return FirebaseFirestore.instance
      .collection('attendance_live')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((doc) => _LiveRecord.fromDoc(doc.data()))
            .where((r) => r.userId.isNotEmpty)
            .toList(),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// LIVE ATTENDANCE CARD
// ══════════════════════════════════════════════════════════════════════════════
class _LiveAttendanceCard extends StatelessWidget {
  final List<_EmpInfo> employees;
  final bool isMobile;
  final String? filterUid;

  const _LiveAttendanceCard({
    required this.employees,
    required this.isMobile,
    this.filterUid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Color(0xFFD1FAE5))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.sensors_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Attendance',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Real-time check-ins · attendance_live',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                _PulsingDot(),
              ],
            ),
          ),
          StreamBuilder<List<_LiveRecord>>(
            stream: _streamLiveRecords(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Error loading live data: ${snapshot.error}',
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }
              final liveMap = <String, _LiveRecord>{
                for (final r in snapshot.data ?? [])
                  if (r.userId.isNotEmpty) r.userId: r,
              };
              final displayEmps = filterUid != null
                  ? employees.where((e) => e.uid == filterUid).toList()
                  : employees;
              final activeEmps = displayEmps
                  .where((e) => liveMap.containsKey(e.uid))
                  .toList();
              if (activeEmps.isEmpty) return _LiveEmptyState();
              return isMobile
                  ? _LiveMobileList(emps: activeEmps, liveMap: liveMap)
                  : _LiveDesktopTable(emps: activeEmps, liveMap: liveMap);
            },
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF059669),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF059669),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDesktopTable extends StatelessWidget {
  final List<_EmpInfo> emps;
  final Map<String, _LiveRecord> liveMap;

  const _LiveDesktopTable({required this.emps, required this.liveMap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 40,
        ),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2.5),
            1: FlexColumnWidth(1.8),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(1.2),
            4: FlexColumnWidth(2.0),
            5: FlexColumnWidth(1.5),
            6: FlexColumnWidth(1.0),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF0FDF4)),
              children: [
                _TH('Employee'),
                _TH('Department'),
                _TH('Check In', center: true),
                _TH('Check Out', center: true),
                _TH('Location'),
                _TH('Status', center: true),
                _TH('Work Time', center: true),
              ],
            ),
            ...emps.asMap().entries.map((entry) {
              final i = entry.key;
              final emp = entry.value;
              final rec = liveMap[emp.uid]!;
              final status = _statusFromString(rec.status);
              return TableRow(
                decoration: BoxDecoration(
                  color: i.isEven ? Colors.white : const Color(0xFFF9FAFB),
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              emp.name.isNotEmpty
                                  ? emp.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                emp.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                emp.role,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Text(
                      emp.department,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  _TD(_fmtTime(rec.checkInTime)),
                  _TD(_fmtTime(rec.checkOutTime)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 13,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            rec.checkInAddress ?? '—',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Center(child: _StatusBadge(status: status)),
                  ),
                  _TD(rec.workLabel),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _LiveMobileList extends StatelessWidget {
  final List<_EmpInfo> emps;
  final Map<String, _LiveRecord> liveMap;

  const _LiveMobileList({required this.emps, required this.liveMap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: emps.asMap().entries.map((entry) {
        final i = entry.key;
        final emp = entry.value;
        final rec = liveMap[emp.uid]!;
        final status = _statusFromString(rec.status);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: i.isEven ? Colors.white : const Color(0xFFF9FAFB),
            border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    emp.name.isNotEmpty ? emp.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            emp.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        _StatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      emp.role,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (rec.checkInAddress != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              rec.checkInAddress!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _TimeChip(
                          icon: Icons.login_rounded,
                          label: 'In',
                          value: _fmtTime(rec.checkInTime),
                          color: const Color(0xFF059669),
                        ),
                        const SizedBox(width: 8),
                        _TimeChip(
                          icon: Icons.logout_rounded,
                          label: 'Out',
                          value: _fmtTime(rec.checkOutTime),
                          color: const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 8),
                        _TimeChip(
                          icon: Icons.timer_outlined,
                          label: 'Worked',
                          value: rec.workLabel,
                          color: const Color(0xFF7C3AED),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _LiveEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.sensors_off_rounded,
                size: 28,
                color: Color(0xFF6EE7B7),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No live check-ins yet today',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Records will appear as employees check in',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Sticky AppBar
// ══════════════════════════════════════════════════════════════════════════════
class _HRAttendanceAppBar extends StatelessWidget {
  final bool isMobile;

  const _HRAttendanceAppBar({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      elevation: 1,
      toolbarHeight: isMobile ? 60 : 70,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 20,
            vertical: isMobile ? 8 : 12,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMobile)
                    const Text(
                      'HR MANAGEMENT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.2,
                      ),
                    ),
                  const Text(
                    'Attendance Tracking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (!isMobile)
                Text(
                  'Monitor employee presence & working hours',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Stats Row
// ══════════════════════════════════════════════════════════════════════════════
class _StatsRow extends StatelessWidget {
  final int total, present, absent, late, leave, attendance;
  final bool isMobile;

  const _StatsRow({
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
    required this.leave,
    required this.attendance,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCardData(
        'Total',
        '$total',
        const Color(0xFF2563EB),
        Icons.groups_rounded,
      ),
      _StatCardData(
        'Present',
        '$present',
        const Color(0xFF059669),
        Icons.check_circle_rounded,
      ),
      _StatCardData(
        'Absent',
        '$absent',
        const Color(0xFFDC2626),
        Icons.cancel_rounded,
      ),
      _StatCardData(
        'Late',
        '$late',
        const Color(0xFFD97706),
        Icons.schedule_rounded,
      ),
      _StatCardData(
        'Leave',
        '$leave',
        const Color(0xFF7C3AED),
        Icons.beach_access_rounded,
      ),
      _StatCardData(
        'Rate',
        '$attendance%',
        const Color(0xFF0891B2),
        Icons.trending_up_rounded,
      ),
    ];

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                SizedBox(width: 130, child: _StatCard(data: cards[i])),
              ],
            ],
          ),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _StatCard(data: cards[i])),
          ],
        ],
      ),
    );
  }
}

class _StatCardData {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatCardData(this.label, this.value, this.color, this.icon);
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: data.color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Filter Bar
// ══════════════════════════════════════════════════════════════════════════════
class _FilterBar extends StatelessWidget {
  final List<_EmpInfo> employees;
  final String? selectedEmployeeUid;
  final DateTime selectedDate;
  final String statusFilter;
  final bool isMobile;
  final ValueChanged<String?> onEmployeeChanged;
  final VoidCallback onDateTap;
  final ValueChanged<String?> onStatusChanged;

  const _FilterBar({
    required this.employees,
    required this.selectedEmployeeUid,
    required this.selectedDate,
    required this.statusFilter,
    required this.isMobile,
    required this.onEmployeeChanged,
    required this.onDateTap,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat(
      isMobile ? 'MMM d, yyyy' : 'EEEE, MMMM d, yyyy',
    ).format(selectedDate);

    final filters = [
      Expanded(
        flex: 3,
        child: _DropdownField<String>(
          icon: Icons.person_search_rounded,
          hint: 'All Employees',
          value: selectedEmployeeUid,
          items: [
            const DropdownMenuItem(value: null, child: Text('All Employees')),
            ...employees.map(
              (e) => DropdownMenuItem(
                value: e.uid,
                child: Text(e.name, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onEmployeeChanged,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 3,
        child: _DateButton(label: dateLabel, onTap: onDateTap),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 2,
        child: _DropdownField<String>(
          icon: Icons.filter_list_rounded,
          hint: 'All Status',
          value: statusFilter == 'all' ? null : statusFilter,
          items: const [
            DropdownMenuItem(value: null, child: Text('All Status')),
            DropdownMenuItem(value: 'present', child: Text('Present')),
            DropdownMenuItem(value: 'absent', child: Text('Absent')),
            DropdownMenuItem(value: 'late', child: Text('Late')),
            DropdownMenuItem(value: 'leave', child: Text('Leave')),
          ],
          onChanged: onStatusChanged,
        ),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: isMobile
          ? Column(
              children: [
                Row(children: [filters[0], filters[1], filters[2]]),
                const SizedBox(height: 10),
                Row(children: [filters[3]]),
              ],
            )
          : Row(children: filters),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final IconData icon;
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.icon,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFFF8FAFC),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                hint: Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                isExpanded: true,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w500,
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF64748B),
                  size: 18,
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DateButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.4)),
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFFEFF6FF),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              size: 16,
              color: Color(0xFF2563EB),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF2563EB),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Table Card
// ══════════════════════════════════════════════════════════════════════════════
class _TableCard extends StatelessWidget {
  final List<_EmpInfo>? employees_data;
  final List<_AttendanceRow> rows;
  final bool loading;
  final bool isMobile;
  final DateTime date;
  final Function(String, String) onRowTap;
  final Function(String, String) onLeaveHistoryTap;

  const _TableCard({
    this.employees_data,
    required this.rows,
    required this.loading,
    required this.isMobile,
    required this.date,
    required this.onRowTap,
    required this.onLeaveHistoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('MMM d, yyyy').format(date);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.table_chart_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Attendance Records',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF93C5FD)),
                  ),
                  child: Text(
                    '${rows.length} records',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          ),
          loading
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              : rows.isEmpty
              ? _EmptyTable()
              : isMobile
              ? _MobileList(
                  rows: rows,
                  onRowTap: onRowTap,
                  onLeaveHistoryTap: onLeaveHistoryTap,
                )
              : _DesktopTable(
                  rows: rows,
                  onRowTap: onRowTap,
                  onLeaveHistoryTap: onLeaveHistoryTap,
                ),
        ],
      ),
    );
  }
}

// ── Desktop Table ─────────────────────────────────────────────────────────────
class _DesktopTable extends StatelessWidget {
  final List<_AttendanceRow> rows;
  final Function(String, String) onRowTap;
  final Function(String, String) onLeaveHistoryTap;

  const _DesktopTable({
    required this.rows,
    required this.onRowTap,
    required this.onLeaveHistoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 40,
        ),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2.8),
            1: FlexColumnWidth(2.0),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(1.2),
            4: FlexColumnWidth(1.2),
            5: FlexColumnWidth(1.6),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
              children: [
                _TH('Employee'),
                _TH('Department'),
                _TH('Check In', center: true),
                _TH('Check Out', center: true),
                _TH('Working Hours', center: true),
                _TH('Status', center: true),
              ],
            ),
            ...rows.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              return TableRow(
                decoration: BoxDecoration(
                  color: i.isEven ? Colors.white : const Color(0xFFFAFAFB),
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                r.role,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.calendar_month_rounded,
                            color: Color(0xFF2563EB),
                            size: 20,
                          ),
                          tooltip: 'Monthly Status',
                          onPressed: () => onRowTap(r.uid, r.name),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.list_alt_rounded,
                            color: Color(0xFF7C3AED),
                            size: 20,
                          ),
                          tooltip: 'Leave Requests',
                          onPressed: () => onLeaveHistoryTap(r.uid, r.name),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.business_rounded,
                          size: 13,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            r.department,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _TD(r.checkIn ?? '—'),
                  _TD(r.checkOut ?? '—'),
                  _TD(r.workHours ?? '—'),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatusBadge(status: r.status),
                          if (r.statusDetail != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              r.statusDetail!,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

Widget _TH(String label, {bool center = false}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  child: Text(
    label,
    textAlign: center ? TextAlign.center : TextAlign.left,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Color(0xFF475569),
      letterSpacing: 0.3,
    ),
  ),
);

Widget _TD(String value) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  child: Text(
    value,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: Color(0xFF334155),
    ),
  ),
);

// ── Mobile Card List ──────────────────────────────────────────────────────────
class _MobileList extends StatelessWidget {
  final List<_AttendanceRow> rows;
  final Function(String, String) onRowTap;
  final Function(String, String) onLeaveHistoryTap;

  const _MobileList({
    required this.rows,
    required this.onRowTap,
    required this.onLeaveHistoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows.asMap().entries.map((entry) {
        final i = entry.key;
        final r = entry.value;
        return InkWell(
          onTap: () => onRowTap(r.uid, r.name),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: i.isEven ? Colors.white : const Color(0xFFFAFAFB),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              r.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.calendar_month,
                                  size: 18,
                                  color: Color(0xFF2563EB),
                                ),
                                onPressed: () => onRowTap(r.uid, r.name),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.list_alt,
                                  size: 18,
                                  color: Color(0xFF7C3AED),
                                ),
                                onPressed: () =>
                                    onLeaveHistoryTap(r.uid, r.name),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.role,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _TimeChip(
                            icon: Icons.login_rounded,
                            label: 'In',
                            value: r.checkIn ?? '—',
                            color: const Color(0xFF059669),
                          ),
                          const SizedBox(width: 8),
                          _TimeChip(
                            icon: Icons.logout_rounded,
                            label: 'Out',
                            value: r.checkOut ?? '—',
                            color: const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 8),
                          _TimeChip(
                            icon: Icons.timer_outlined,
                            label: 'Hrs',
                            value: r.workHours ?? '—',
                            color: const Color(0xFF7C3AED),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _TimeChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final _Status status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 11, color: status.fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: status.fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(36),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 36,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No attendance records found',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try adjusting your filters or select a different date',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
