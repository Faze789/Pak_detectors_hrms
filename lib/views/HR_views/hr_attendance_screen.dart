import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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
// No hardcoded time thresholds. Late/absent/leave are driven by the value
// written to Firestore by the service at check-in time.
// ─────────────────────────────────────────────────────────────────────────────
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

      // Always try archive first
      rec = await vm.getArchivedAttendanceForDay(emp.uid, _selectedDate);

      // FIX: For today, use getEmployeeLiveRecord instead of getLiveAttendance.
      //
      // getLiveAttendance called loadToday() which is designed for the currently
      // logged-in user. Calling it in a loop for multiple employees corrupted
      // the ViewModel's shared state (todayAttendance, officeSettings etc.)
      // causing wrong statuses: checked-in-late shown as Present, absent shown
      // as Late, etc.
      //
      // getEmployeeLiveRecord reads directly from the Firestore live collection
      // without touching any ViewModel state — safe for any employee.
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

  const _TableCard({
    this.employees_data,

    required this.rows,
    required this.loading,
    required this.isMobile,
    required this.date,
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
          // Header
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
                      IconButton(
                        onPressed: () {
                          if (employees_data != null &&
                              employees_data!.isNotEmpty) {
                            debugPrint(
                              "First Employee: ${employees_data!.first.name}",
                            );
                          } else {
                            debugPrint("No employee data available");
                          }
                        },
                        icon: Icon(
                          Icons.person_search_rounded,
                          size: 18,
                          color: Colors.grey.shade500,
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

          // Body
          loading
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              : rows.isEmpty
              ? _EmptyTable()
              : isMobile
              ? _MobileList(rows: rows)
              : _DesktopTable(rows: rows),
        ],
      ),
    );
  }
}

// ── Desktop Table ─────────────────────────────────────────────────────────────
class _DesktopTable extends StatelessWidget {
  final List<_AttendanceRow> rows;
  const _DesktopTable({required this.rows});

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
                  // Employee
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
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
                  // Department
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
                  // Status badge + optional detail
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
  const _MobileList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows.asMap().entries.map((entry) {
        final i = entry.key;
        final r = entry.value;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: i.isEven ? Colors.white : const Color(0xFFFAFAFB),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _StatusBadge(status: r.status),
                            if (r.statusDetail != null)
                              Text(
                                r.statusDetail!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8),
                                ),
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
