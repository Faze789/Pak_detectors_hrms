import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

import '../../models/attendance_model.dart';
import '../../models/employee_model.dart';
import '../../viewmodels/attendance_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/employee_viewmodel.dart';

abstract class _Breakpoints {
  static const double mobile = 768;
  static const double tablet = 1024;
}

// ─────────────────────────────────────────────────────────────────────────────
// HR Dashboard Screen
// Real-time attendance is pulled from:
//   1. attendance_live  — employees currently checked in today (stream)
//   2. attendance_archive — absent / leave records written by cloud function
//      or app for today (polled once on load + on manual refresh)
// The two sets are merged per employee so every employee has exactly one
// status entry by the time the table and stat cards render.
// ─────────────────────────────────────────────────────────────────────────────
class HRDashboardScreen extends StatefulWidget {
  const HRDashboardScreen({super.key});

  @override
  State<HRDashboardScreen> createState() => _HRDashboardScreenState();
}

class _HRDashboardScreenState extends State<HRDashboardScreen> {
  late DashboardViewModel _dashVM;
  late AttendanceViewModel _attendanceVM;

  // Live attendance records keyed by userId — updated by the stream
  final Map<String, AttendanceModel> _liveRecords = {};

  // Today's archive records keyed by userId — polled once + on refresh
  final Map<String, AttendanceModel> _archiveRecords = {};

  bool _archiveLoading = false;

  @override
  void initState() {
    super.initState();
    final employeeVM = context.read<EmployeeViewModel>();
    _attendanceVM = context.read<AttendanceViewModel>();
    _dashVM = DashboardViewModel(employeeViewModel: employeeVM);

    Future.microtask(() async {
      await employeeVM.loadEmployees('');
      if (!mounted) return;
      _dashVM.startListening();
      await _loadTodayArchive();
    });
  }

  @override
  void dispose() {
    _dashVM.dispose();
    super.dispose();
  }

  // ── Load today's archive records for every employee ───────────────────────
  // This picks up absent / leave entries written by the cloud function or
  // by the app itself. Called once on init and again on manual refresh.
  Future<void> _loadTodayArchive() async {
    if (!mounted) return;
    setState(() => _archiveLoading = true);

    final employees = context.read<EmployeeViewModel>().employees;
    final today = DateTime.now();

    final results = await Future.wait(
      employees.map((emp) async {
        final rec = await _attendanceVM.getArchivedAttendanceForDay(
          emp.uid,
          today,
        );
        return MapEntry(emp.uid, rec);
      }),
    );

    if (!mounted) return;
    setState(() {
      _archiveRecords.clear();
      for (final entry in results) {
        if (entry.value != null) {
          _archiveRecords[entry.key] = entry.value!;
        }
      }
      _archiveLoading = false;
    });
  }

  // ── Merge live + archive into one record per employee ─────────────────────
  // Live doc wins if it exists (employee is currently checked in).
  // Archive is the fallback (absent / leave / checked-out record).
  AttendanceModel? _recordFor(String uid) =>
      _liveRecords[uid] ?? _archiveRecords[uid];

  // ── Derived counts (used by stat cards + chart) ───────────────────────────
  int get _presentCount {
    final employees = context.read<EmployeeViewModel>().employees;
    return employees.where((e) {
      final rec = _recordFor(e.uid);
      return rec != null && rec.wasPresent;
    }).length;
  }

  int get _onBreakCount {
    final employees = context.read<EmployeeViewModel>().employees;
    return employees.where((e) {
      final rec = _recordFor(e.uid);
      return rec?.status == AttendanceStatus.onBreak;
    }).length;
  }

  int get _absentCount {
    final employees = context.read<EmployeeViewModel>().employees;
    return employees.where((e) {
      final rec = _recordFor(e.uid);
      return rec == null || rec.status == AttendanceStatus.absent;
    }).length;
  }

  int get _lateCount {
    final employees = context.read<EmployeeViewModel>().employees;
    return employees.where((e) {
      final rec = _recordFor(e.uid);
      return rec?.status == AttendanceStatus.late;
    }).length;
  }

  int get _onLeaveCount {
    final employees = context.read<EmployeeViewModel>().employees;
    return employees.where((e) {
      final rec = _recordFor(e.uid);
      return rec != null && rec.status.isAnyLeave;
    }).length;
  }

  int get _checkedOutCount {
    final employees = context.read<EmployeeViewModel>().employees;
    return employees.where((e) {
      final rec = _recordFor(e.uid);
      return rec?.status == AttendanceStatus.checkedOut;
    }).length;
  }

  int get _attendanceRate {
    final total = context.read<EmployeeViewModel>().employees.length;
    if (total == 0) return 0;
    return ((_presentCount / total) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _dashVM,
      builder: (context, _) {
        final empVM = context.read<EmployeeViewModel>();

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: _dashVM.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 24),

                        if (_dashVM.errorMessage != null) ...[
                          _ErrorBanner(message: _dashVM.errorMessage!),
                          const SizedBox(height: 16),
                        ],

                        // ── Real-time stat cards ──────────────────────
                        _StatCardsGrid(
                          totalEmployees: empVM.employees.length,
                          presentCount: _presentCount,
                          onBreakCount: _onBreakCount,
                          absentCount: _absentCount,
                          lateCount: _lateCount,
                          onLeaveCount: _onLeaveCount,
                          attendanceRate: _attendanceRate,
                          employees: empVM.employees,
                        ),
                        const SizedBox(height: 24),

                        // ── Charts + department summary ───────────────
                        _ChartsAndDepartments(
                          present: _presentCount,
                          onBreak: _onBreakCount,
                          absent: _absentCount,
                          late: _lateCount,
                          onLeave: _onLeaveCount,
                          checkedOut: _checkedOutCount,
                          total: empVM.employees.length,
                          employees: empVM.employees,
                        ),
                        const SizedBox(height: 24),

                        // ── Real-time team attendance table ───────────
                        _LiveAttendanceTable(
                          attendanceVM: _attendanceVM,
                          employeeVM: empVM,
                          liveRecords: _liveRecords,
                          archiveRecords: _archiveRecords,
                          archiveLoading: _archiveLoading,
                          onLiveUpdate: (uid, rec) {
                            setState(() {
                              if (rec != null) {
                                _liveRecords[uid] = rec;
                              } else {
                                _liveRecords.remove(uid);
                              }
                            });
                          },
                          onRefresh: _loadTodayArchive,
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final dateLabel = DateFormat('EEEE, MMMM d').format(now);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dateLabel,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ],
        ),
        Row(
          children: [
            // Refresh button — re-polls archive for today
            IconButton(
              onPressed: _loadTodayArchive,
              icon: _archiveLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      size: 22,
                      color: Color(0xFF475569),
                    ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
              ),
              tooltip: 'Refresh attendance',
            ),
            const SizedBox(width: 8),
            Stack(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.notifications_outlined,
                    size: 24,
                    color: Color(0xFF475569),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Cards Grid
// ─────────────────────────────────────────────────────────────────────────────
class _StatCardsGrid extends StatelessWidget {
  final int totalEmployees;
  final int presentCount;
  final int onBreakCount;
  final int absentCount;
  final int lateCount;
  final int onLeaveCount;
  final int attendanceRate;
  final List<Employee> employees;

  const _StatCardsGrid({
    required this.totalEmployees,
    required this.presentCount,
    required this.onBreakCount,
    required this.absentCount,
    required this.lateCount,
    required this.onLeaveCount,
    required this.attendanceRate,
    required this.employees,
  });

  @override
  Widget build(BuildContext context) {
    final double totalPayroll = employees.fold(0.0, (sum, e) => sum + e.salary);
    final String payrollLabel = totalPayroll >= 1000000
        ? 'Rs ${(totalPayroll / 1000000).toStringAsFixed(1)}M'
        : totalPayroll >= 1000
        ? 'Rs ${(totalPayroll / 1000).toStringAsFixed(0)}K'
        : 'Rs ${totalPayroll.toStringAsFixed(0)}';

    final int activeCount = employees
        .where((e) => e.status == EmployeeStatus.active)
        .length;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < _Breakpoints.mobile;

    final cards = [
      StatCard(
        title: 'TOTAL EMPLOYEES',
        value: totalEmployees.toString(),
        subtitle: '$activeCount active · $onLeaveCount on leave',
        color: const Color(0xFF3B82F6),
        iconBg: const Color(0xFFDBEAFE),
        iconColor: const Color(0xFF3B82F6),
        icon: Icons.people_alt_outlined,
      ),
      StatCard(
        title: 'PRESENT TODAY',
        value: presentCount.toString(),
        subtitle: '$attendanceRate% attendance rate',
        color: const Color(0xFF22C55E),
        iconBg: const Color(0xFFDCFCE7),
        iconColor: const Color(0xFF22C55E),
        icon: Icons.how_to_reg_outlined,
      ),
      StatCard(
        title: 'ABSENT TODAY',
        value: absentCount.toString(),
        subtitle: '$lateCount late · $onBreakCount on break',
        color: const Color(0xFFEF4444),
        iconBg: const Color(0xFFFEE2E2),
        iconColor: const Color(0xFFEF4444),
        icon: Icons.person_off_outlined,
      ),
      StatCard(
        title: 'MONTHLY PAYROLL',
        value: payrollLabel,
        subtitle: 'Total salary cost',
        color: const Color(0xFF6366F1),
        iconBg: const Color(0xFFE0E7FF),
        iconColor: const Color(0xFF6366F1),
        icon: Icons.attach_money_outlined,
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards
            .map(
              (card) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: card,
              ),
            )
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > _Breakpoints.tablet
            ? 4
            : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.5,
          children: cards,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Charts + Department breakdown
// ─────────────────────────────────────────────────────────────────────────────
class _ChartsAndDepartments extends StatelessWidget {
  final int present;
  final int onBreak;
  final int absent;
  final int late;
  final int onLeave;
  final int checkedOut;
  final int total;
  final List<Employee> employees;

  const _ChartsAndDepartments({
    required this.present,
    required this.onBreak,
    required this.absent,
    required this.late,
    required this.onLeave,
    required this.checkedOut,
    required this.total,
    required this.employees,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _Breakpoints.mobile;

    final chartCard = _AttendanceChartCard(
      present: present,
      onBreak: onBreak,
      absent: absent,
      late: late,
      onLeave: onLeave,
      checkedOut: checkedOut,
      total: total,
    );
    final deptCard = _DepartmentBreakdownCard(employees: employees);

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: chartCard),
          const SizedBox(width: 24),
          Expanded(child: deptCard),
        ],
      );
    }

    return Column(children: [chartCard, const SizedBox(height: 16), deptCard]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance Chart Card — now includes late + on leave segments
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceChartCard extends StatelessWidget {
  final int present;
  final int onBreak;
  final int absent;
  final int late;
  final int onLeave;
  final int checkedOut;
  final int total;

  const _AttendanceChartCard({
    required this.present,
    required this.onBreak,
    required this.absent,
    required this.late,
    required this.onLeave,
    required this.checkedOut,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    // present = checkedIn + onBreak + late + checkedOut (all physically here)
    // We show separate legend items but group in donut as present vs absent vs leave
    final attendancePct = total > 0 ? ((present / total) * 100).round() : 0;

    final legendItems = [
      if (checkedOut > 0)
        _PieData('Checked out', checkedOut, const Color(0xFF6366F1)),
      _PieData(
        'Active',
        present - onBreak - late - checkedOut > 0
            ? present - onBreak - late - checkedOut
            : 0,
        const Color(0xFF22C55E),
      ),
      if (late > 0) _PieData('Late', late, const Color(0xFFF59E0B)),
      if (onBreak > 0) _PieData('On break', onBreak, const Color(0xFFFACC15)),
      if (onLeave > 0) _PieData('On leave', onLeave, const Color(0xFF0891B2)),
      _PieData('Absent', absent, const Color(0xFFEF4444)),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Attendance",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
              Row(
                children: [
                  // Live indicator dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Live',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF22C55E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: attendancePct >= 70
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$attendancePct% rate',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: attendancePct >= 70
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      painter: DonutChartPainter(
                        present: present,
                        onBreak: onBreak,
                        absent: absent,
                        late: late,
                        onLeave: onLeave,
                        checkedOut: checkedOut,
                      ),
                      size: const Size(160, 160),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          present.toString(),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Text(
                          'Present',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: legendItems
                      .where((d) => d.value > 0)
                      .map(
                        (d) => _LegendItem(d.name, d.value.toString(), d.color),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PieData {
  final String name;
  final int value;
  final Color color;
  _PieData(this.name, this.value, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
// Department Breakdown Card
// ─────────────────────────────────────────────────────────────────────────────
class _DepartmentBreakdownCard extends StatelessWidget {
  final List<Employee> employees;
  const _DepartmentBreakdownCard({required this.employees});

  @override
  Widget build(BuildContext context) {
    final Map<String, int> deptCount = {};
    for (final e in employees) {
      final dept = e.department.isNotEmpty ? e.department : 'Unassigned';
      deptCount[dept] = (deptCount[dept] ?? 0) + 1;
    }

    final sorted = deptCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF22C55E),
      const Color(0xFF6366F1),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF14B8A6),
      const Color(0xFFEC4899),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: const [
              Icon(Icons.business_outlined, size: 18, color: Color(0xFF0F172A)),
              SizedBox(width: 8),
              Text(
                'Department Breakdown',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (sorted.isEmpty)
            const Center(
              child: Text(
                'No department data',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            )
          else
            ...sorted.asMap().entries.map((entry) {
              final i = entry.key;
              final dept = entry.value;
              final color = colors[i % colors.length];
              final pct = employees.isNotEmpty
                  ? (dept.value / employees.length * 100).round()
                  : 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            dept.key,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${dept.value} · $pct%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: employees.isNotEmpty
                            ? dept.value / employees.length
                            : 0,
                        minHeight: 7,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Attendance Table
//
// Streams attendance_live in real time via
// AttendanceService.streamTodayLiveAttendance(). When the stream emits,
// the parent's _liveRecords map is updated via onLiveUpdate callback so the
// stat cards and chart also update. Archive records (absent / leave / checked
// out) come from the separate polled map.
// ─────────────────────────────────────────────────────────────────────────────
class _LiveAttendanceTable extends StatefulWidget {
  final AttendanceViewModel attendanceVM;
  final EmployeeViewModel employeeVM;
  final Map<String, AttendanceModel> liveRecords;
  final Map<String, AttendanceModel> archiveRecords;
  final bool archiveLoading;
  final void Function(String uid, AttendanceModel? rec) onLiveUpdate;
  final VoidCallback onRefresh;

  const _LiveAttendanceTable({
    required this.attendanceVM,
    required this.employeeVM,
    required this.liveRecords,
    required this.archiveRecords,
    required this.archiveLoading,
    required this.onLiveUpdate,
    required this.onRefresh,
  });

  @override
  State<_LiveAttendanceTable> createState() => _LiveAttendanceTableState();
}

class _LiveAttendanceTableState extends State<_LiveAttendanceTable> {
  String _searchQuery = '';
  String _filterDept = 'All';
  String _filterStatus = 'All';

  // ── Status helpers ─────────────────────────────────────────────────────────

  _DisplayStatus _statusFor(String uid) {
    final live = widget.liveRecords[uid];
    final archive = widget.archiveRecords[uid];
    final rec = live ?? archive;
    if (rec == null) return _DisplayStatus.noRecord;

    switch (rec.status) {
      case AttendanceStatus.checkedIn:
        return _DisplayStatus.checkedIn;
      case AttendanceStatus.onBreak:
        return _DisplayStatus.onBreak;
      case AttendanceStatus.late:
        return _DisplayStatus.late;
      case AttendanceStatus.checkedOut:
        return _DisplayStatus.checkedOut;
      case AttendanceStatus.absent:
        return _DisplayStatus.absent;
      case AttendanceStatus.onLeave:
      case AttendanceStatus.firstHalfLeave:
      case AttendanceStatus.secondHalfLeave:
        return _DisplayStatus.onLeave;
      case AttendanceStatus.halfDay:
        return _DisplayStatus.checkedOut;
      default:
        return _DisplayStatus.noRecord;
    }
  }

  AttendanceModel? _recordFor(String uid) =>
      widget.liveRecords[uid] ?? widget.archiveRecords[uid];

  String _checkInLabel(String uid) {
    final rec = _recordFor(uid);
    if (rec?.checkInTime == null) return '—';
    return DateFormat('HH:mm').format(rec!.checkInTime!);
  }

  String _checkOutLabel(String uid) {
    final rec = _recordFor(uid);
    if (rec?.checkOutTime == null) return '—';
    return DateFormat('HH:mm').format(rec!.checkOutTime!);
  }

  String _workDurationLabel(String uid) {
    final rec = _recordFor(uid);
    if (rec == null || rec.checkInTime == null) return '—';
    final dur = rec.totalWorkDuration;
    if (dur.inSeconds == 0) return '—';
    final h = dur.inHours;
    final m = dur.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  // ── Filter logic ───────────────────────────────────────────────────────────

  bool _matchesStatusFilter(String uid) {
    if (_filterStatus == 'All') return true;
    final s = _statusFor(uid);
    switch (_filterStatus) {
      case 'Present':
        return s == _DisplayStatus.checkedIn || s == _DisplayStatus.late;
      case 'On Break':
        return s == _DisplayStatus.onBreak;
      case 'Late':
        return s == _DisplayStatus.late;
      case 'Absent':
        return s == _DisplayStatus.absent || s == _DisplayStatus.noRecord;
      case 'On Leave':
        return s == _DisplayStatus.onLeave;
      case 'Checked Out':
        return s == _DisplayStatus.checkedOut;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.employeeVM,
      builder: (context, _) {
        final allEmployees = widget.employeeVM.employees;

        final departments =
            ['All'] +
                  allEmployees
                      .map((e) => e.department)
                      .where((d) => d.isNotEmpty)
                      .toSet()
                      .toList()
              ..sort();

        final filtered = allEmployees.where((emp) {
          final matchSearch =
              _searchQuery.isEmpty ||
              emp.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              emp.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              emp.department.toLowerCase().contains(_searchQuery.toLowerCase());
          final matchDept =
              _filterDept == 'All' || emp.department == _filterDept;
          final matchStatus = _matchesStatusFilter(emp.uid);
          return matchSearch && matchDept && matchStatus;
        }).toList();

        // Sort: active first (checkedIn / onBreak / late), then checkedOut,
        // then onLeave, then absent/no record
        filtered.sort((a, b) {
          return _statusSort(
            _statusFor(a.uid),
          ).compareTo(_statusSort(_statusFor(b.uid)));
        });

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Text(
                            'Live Attendance',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(width: 8),
                          _PulseDot(),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${filtered.length} of ${allEmployees.length} employees',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: widget.onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text(
                      'Refresh',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Filters ────────────────────────────────────────────
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 220,
                    height: 38,
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search employees…',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  _FilterDropdown(
                    value: _filterDept,
                    items: departments,
                    onChanged: (v) => setState(() => _filterDept = v ?? 'All'),
                    hint: 'Department',
                  ),
                  _FilterDropdown(
                    value: _filterStatus,
                    items: const [
                      'All',
                      'Present',
                      'On Break',
                      'Late',
                      'Checked Out',
                      'On Leave',
                      'Absent',
                    ],
                    onChanged: (v) =>
                        setState(() => _filterStatus = v ?? 'All'),
                    hint: 'Status',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Stream builder — live attendance ───────────────────
              StreamBuilder<List<AttendanceModel>>(
                stream: widget.attendanceVM is _StreamProvider
                    ? (widget.attendanceVM as _StreamProvider).liveStream
                    : _buildStream(),
                builder: (context, snapshot) {
                  // Update parent's liveRecords map when stream emits
                  if (snapshot.hasData) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      final incoming = {
                        for (final r in snapshot.data!) r.userId: r,
                      };
                      // Remove stale live records not in latest emission
                      final toRemove = widget.liveRecords.keys
                          .where((uid) => !incoming.containsKey(uid))
                          .toList();
                      for (final uid in toRemove) {
                        widget.onLiveUpdate(uid, null);
                      }
                      for (final entry in incoming.entries) {
                        widget.onLiveUpdate(entry.key, entry.value);
                      }
                    });
                  }

                  if (widget.archiveLoading && widget.archiveRecords.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 40,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No employees found',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF8FAFC),
                      ),
                      dataRowMinHeight: 56,
                      dataRowMaxHeight: 68,
                      horizontalMargin: 12,
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: _ColHeader('Employee')),
                        DataColumn(label: _ColHeader('Department')),
                        DataColumn(label: _ColHeader('Status')),
                        DataColumn(label: _ColHeader('Check In')),
                        DataColumn(label: _ColHeader('Check Out')),
                        DataColumn(label: _ColHeader('Work Time')),
                      ],
                      rows: filtered.map((emp) => _buildRow(emp)).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Fallback stream — works when AttendanceService is accessible via
  // the service locator. We reach into the VM's service directly.
  Stream<List<AttendanceModel>> _buildStream() {
    try {
      // AttendanceViewModel exposes the service publicly for stream access
      return widget.attendanceVM.service.streamTodayLiveAttendance();
    } catch (_) {
      return const Stream.empty();
    }
  }

  DataRow _buildRow(Employee emp) {
    final status = _statusFor(emp.uid);
    final cfg = _statusConfig(status);
    final rec = _recordFor(emp.uid);
    final initials = _initials(emp.name);

    return DataRow(
      color: WidgetStateProperty.resolveWith((states) {
        if (status == _DisplayStatus.absent ||
            status == _DisplayStatus.noRecord) {
          return const Color(0xFFFEF2F2).withOpacity(0.5);
        }
        if (status == _DisplayStatus.onLeave) {
          return const Color(0xFFEFF6FF).withOpacity(0.5);
        }
        return null;
      }),
      cells: [
        // Employee
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
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
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Department
        DataCell(
          Text(
            emp.department.isNotEmpty ? emp.department : '—',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
        ),

        // Status badge
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: cfg.bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing dot for active statuses
                if (status == _DisplayStatus.checkedIn ||
                    status == _DisplayStatus.onBreak ||
                    status == _DisplayStatus.late)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: cfg.fg,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Text(
                  cfg.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cfg.fg,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Check-in time
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.login_rounded,
                size: 13,
                color: rec?.checkInTime != null
                    ? const Color(0xFF22C55E)
                    : Colors.black26,
              ),
              const SizedBox(width: 4),
              Text(
                _checkInLabel(emp.uid),
                style: TextStyle(
                  fontSize: 12,
                  color: rec?.checkInTime != null
                      ? const Color(0xFF374151)
                      : Colors.black38,
                ),
              ),
            ],
          ),
        ),

        // Check-out time
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.logout_rounded,
                size: 13,
                color: rec?.checkOutTime != null
                    ? const Color(0xFF6366F1)
                    : Colors.black26,
              ),
              const SizedBox(width: 4),
              Text(
                _checkOutLabel(emp.uid),
                style: TextStyle(
                  fontSize: 12,
                  color: rec?.checkOutTime != null
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
            _workDurationLabel(emp.uid),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: rec?.checkInTime != null
                  ? const Color(0xFF374151)
                  : Colors.black38,
            ),
          ),
        ),
      ],
    );
  }

  int _statusSort(_DisplayStatus s) {
    switch (s) {
      case _DisplayStatus.checkedIn:
        return 0;
      case _DisplayStatus.onBreak:
        return 1;
      case _DisplayStatus.late:
        return 2;
      case _DisplayStatus.checkedOut:
        return 3;
      case _DisplayStatus.onLeave:
        return 4;
      case _DisplayStatus.absent:
        return 5;
      case _DisplayStatus.noRecord:
        return 6;
    }
  }

  _StatusBadgeCfg _statusConfig(_DisplayStatus s) {
    switch (s) {
      case _DisplayStatus.checkedIn:
        return _StatusBadgeCfg(
          'Active',
          const Color(0xFF065F46),
          const Color(0xFFECFDF5),
        );
      case _DisplayStatus.onBreak:
        return _StatusBadgeCfg(
          'On Break',
          const Color(0xFFB45309),
          const Color(0xFFFFFBEB),
        );
      case _DisplayStatus.late:
        return _StatusBadgeCfg(
          'Late',
          const Color(0xFF92400E),
          const Color(0xFFFEF3C7),
        );
      case _DisplayStatus.checkedOut:
        return _StatusBadgeCfg(
          'Checked Out',
          const Color(0xFF3730A3),
          const Color(0xFFEDE9FE),
        );
      case _DisplayStatus.onLeave:
        return _StatusBadgeCfg(
          'On Leave',
          const Color(0xFF0369A1),
          const Color(0xFFE0F2FE),
        );
      case _DisplayStatus.absent:
        return _StatusBadgeCfg(
          'Absent',
          const Color(0xFF991B1B),
          const Color(0xFFFEF2F2),
        );
      case _DisplayStatus.noRecord:
        return _StatusBadgeCfg(
          'No record',
          const Color(0xFF64748B),
          const Color(0xFFF1F5F9),
        );
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small types
// ─────────────────────────────────────────────────────────────────────────────

enum _DisplayStatus {
  checkedIn,
  onBreak,
  late,
  checkedOut,
  onLeave,
  absent,
  noRecord,
}

class _StatusBadgeCfg {
  final String label;
  final Color fg;
  final Color bg;
  const _StatusBadgeCfg(this.label, this.fg, this.bg);
}

// Marker interface — if AttendanceViewModel exposes a stream getter
abstract class _StreamProvider {
  Stream<List<AttendanceModel>> get liveStream;
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing live dot widget
// ─────────────────────────────────────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFF22C55E),
        shape: BoxShape.circle,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Donut Chart Painter — extended with late + onLeave + checkedOut segments
// ─────────────────────────────────────────────────────────────────────────────
class DonutChartPainter extends CustomPainter {
  final int present;
  final int onBreak;
  final int absent;
  final int late;
  final int onLeave;
  final int checkedOut;

  const DonutChartPainter({
    required this.present,
    required this.onBreak,
    required this.absent,
    required this.late,
    required this.onLeave,
    required this.checkedOut,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // active = present minus onBreak minus late minus checkedOut
    final active = math.max(0, present - onBreak - late - checkedOut);
    final total = active + onBreak + absent + late + onLeave + checkedOut;

    if (total == 0) {
      paint.color = const Color(0xFFE2E8F0);
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double start = -math.pi / 2;

    void drawArc(int count, Color color) {
      if (count == 0) return;
      final sweep = (count / total) * 2 * math.pi;
      paint.color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }

    drawArc(active, const Color(0xFF22C55E));
    drawArc(checkedOut, const Color(0xFF6366F1));
    drawArc(late, const Color(0xFFF59E0B));
    drawArc(onBreak, const Color(0xFFFACC15));
    drawArc(onLeave, const Color(0xFF0891B2));
    drawArc(absent, const Color(0xFFEF4444));
  }

  @override
  bool shouldRepaint(DonutChartPainter old) =>
      old.present != present ||
      old.onBreak != onBreak ||
      old.absent != absent ||
      old.late != late ||
      old.onLeave != onLeave ||
      old.checkedOut != checkedOut;
}

// ─────────────────────────────────────────────────────────────────────────────
// Reused small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String hint;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          isDense: true,
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
        ),
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String text;
  const _ColHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF64748B),
      fontWeight: FontWeight.w600,
      fontSize: 12,
    ),
  );
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final Color iconBg;
  final Color iconColor;
  final IconData icon;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.iconBg,
    required this.iconColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String name;
  final String value;
  final Color color;
  const _LegendItem(this.name, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
            child: Text(
              name,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
