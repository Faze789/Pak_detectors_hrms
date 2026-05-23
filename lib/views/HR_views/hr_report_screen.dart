// lib/screens/reports/hr_report_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/attendance_model.dart';
import '../../models/employee_model.dart';
import '../../models/payroll_model.dart';
import '../../models/leave_model.dart';
import '../../services/payroll_service.dart';
import '../../viewmodels/attendance_viewmodel.dart';
import '../../viewmodels/employee_viewmodel.dart';

const double _kTablet = 768;

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class HRReportScreen extends StatefulWidget {
  const HRReportScreen({super.key});

  @override
  State<HRReportScreen> createState() => _HRReportScreenState();
}

class _HRReportScreenState extends State<HRReportScreen> {
  Employee? _selectedEmployee;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _filterDept = 'All';
  String _searchQuery = '';

  bool _loading = false;
  bool _reportReady = false;
  MonthlyArchive? _archive;
  PayslipModel? _payslip;
  List<LeaveModel> _leaves = [];
  Map<String, dynamic>? _perf;

  final _payrollService = PayrollService();

  // ── Derived attendance stats ───────────────────────────────────────────────
  int get _presentDays => _archive?.presentDays ?? 0;
  int get _absentDays => _archive?.absentDays ?? 0;
  int get _lateDays =>
      _archive?.days.values
          .where((d) => d.status == AttendanceStatus.late)
          .length ??
      0;
  int get _halfDays =>
      _archive?.days.values
          .where(
            (d) =>
                d.status == AttendanceStatus.halfDay ||
                d.status == AttendanceStatus.firstHalfLeave ||
                d.status == AttendanceStatus.secondHalfLeave,
          )
          .length ??
      0;
  int get _totalDays => _archive?.totalDays ?? 0;
  double get _attendanceRate =>
      _totalDays > 0 ? (_presentDays / _totalDays * 100) : 0;

  // ── Filtered list ──────────────────────────────────────────────────────────
  List<Employee> _filtered(List<Employee> all) => all.where((e) {
    final matchDept = _filterDept == 'All' || e.department == _filterDept;
    final q = _searchQuery.toLowerCase();
    final matchSearch =
        q.isEmpty ||
        e.name.toLowerCase().contains(q) ||
        e.email.toLowerCase().contains(q) ||
        e.role.toLowerCase().contains(q);
    return matchDept && matchSearch;
  }).toList();

  // ── Generate ───────────────────────────────────────────────────────────────
  Future<void> _generate() async {
    if (_selectedEmployee == null) return;
    setState(() {
      _loading = true;
      _reportReady = false;
    });
    try {
      final vm = context.read<AttendanceViewModel>();
      final uid = _selectedEmployee!.uid;
      final year = _selectedMonth.year;
      final mon = _selectedMonth.month;

      final archive = await vm.getMonthlyArchiveSilent(uid, year, mon);
      final payslips = await _payrollService.getPayslipsForEmployee(uid);
      final payslip = payslips
          .where((p) => p.monthNum == mon && p.year == year)
          .firstOrNull;
      final leaves = await _payrollService.getLeavesForEmployee(uid);

      setState(() {
        _archive = archive;
        _payslip = payslip;
        _leaves = leaves;
        _perf = {
          'score': 0.0,
          'totalTasks': 0,
          'completedTasks': 0,
          'missedTasks': 0,
          'rating': 'N/A',
        };
        _reportReady = true;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load report: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  String get _monthLabel => DateFormat('MMMM yyyy').format(_selectedMonth);

  List<DateTime> get _months => List.generate(
    12,
    (i) => DateTime(DateTime.now().year, DateTime.now().month - i),
  );

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final empVM = context.watch<EmployeeViewModel>();
    final all = empVM.employees;
    final filtered = _filtered(all);
    final departments = [
      'All',
      ...all
          .map((e) => e.department)
          .where((d) => d.isNotEmpty)
          .toSet()
          .toList()
        ..sort(),
    ];
    final isWide = MediaQuery.of(context).size.width >= _kTablet;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          // ── App bar ─────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            elevation: 1,
            toolbarHeight: 72,
            flexibleSpace: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.description_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'HR Reports & Analytics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Comprehensive employee records and insights',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Filter card ──────────────────────────────────────────────
                _FilterCard(
                  employees: filtered,
                  selected: _selectedEmployee,
                  month: _selectedMonth,
                  months: _months,
                  filterDept: _filterDept,
                  departments: departments,
                  isWide: isWide,
                  loading: _loading,
                  onEmployee: (e) => setState(() {
                    _selectedEmployee = e;
                    _reportReady = false;
                  }),
                  onMonth: (m) => setState(() {
                    _selectedMonth = m;
                    _reportReady = false;
                  }),
                  onDept: (d) => setState(() => _filterDept = d),
                  onSearch: (s) => setState(() => _searchQuery = s),
                  onGenerate: _loading ? null : _generate,
                ),
                const SizedBox(height: 20),

                // ── Report body ──────────────────────────────────────────────
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(60),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_reportReady && _selectedEmployee != null) ...[
                  _ProfileCard(
                    employee: _selectedEmployee!,
                    monthLabel: _monthLabel,
                  ),
                  const SizedBox(height: 20),
                  _OverviewRow(
                    perf: _perf,
                    attendanceRate: _attendanceRate,
                    presentDays: _presentDays,
                    totalDays: _totalDays,
                    payslip: _payslip,
                    isWide: isWide,
                  ),
                  const SizedBox(height: 20),
                  isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _AttendanceCard(
                                    archive: _archive,
                                    monthLabel: _monthLabel,
                                    present: _presentDays,
                                    absent: _absentDays,
                                    late: _lateDays,
                                    halfDay: _halfDays,
                                  ),
                                  const SizedBox(height: 20),
                                  _PayrollCard(
                                    payslip: _payslip,
                                    monthLabel: _monthLabel,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                children: [
                                  _PerformanceCard(perf: _perf),
                                  const SizedBox(height: 20),
                                  _LeaveCard(leaves: _leaves),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _AttendanceCard(
                              archive: _archive,
                              monthLabel: _monthLabel,
                              present: _presentDays,
                              absent: _absentDays,
                              late: _lateDays,
                              halfDay: _halfDays,
                            ),
                            const SizedBox(height: 16),
                            _PerformanceCard(perf: _perf),
                            const SizedBox(height: 16),
                            _PayrollCard(
                              payslip: _payslip,
                              monthLabel: _monthLabel,
                            ),
                            const SizedBox(height: 16),
                            _LeaveCard(leaves: _leaves),
                          ],
                        ),
                  const SizedBox(height: 32),
                ] else
                  _EmptyState(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Card
// ─────────────────────────────────────────────────────────────────────────────
class _FilterCard extends StatelessWidget {
  final List<Employee> employees;
  final Employee? selected;
  final DateTime month;
  final List<DateTime> months;
  final String filterDept;
  final List<String> departments;
  final bool isWide;
  final bool loading;
  final ValueChanged<Employee?> onEmployee;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<String> onDept;
  final ValueChanged<String> onSearch;
  final VoidCallback? onGenerate;

  const _FilterCard({
    required this.employees,
    required this.selected,
    required this.month,
    required this.months,
    required this.filterDept,
    required this.departments,
    required this.isWide,
    required this.loading,
    required this.onEmployee,
    required this.onMonth,
    required this.onDept,
    required this.onSearch,
    required this.onGenerate,
  });

  InputDecoration get _dec => InputDecoration(
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
    ),
    filled: true,
    fillColor: Colors.white,
  );

  Widget _lbl(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF475569),
      ),
    ),
  );

  Widget _empField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _lbl('Employee *'),
      DropdownButtonFormField<Employee>(
        initialValue: selected,
        decoration: _dec,
        isExpanded: true,
        hint: const Text(
          'Select Employee',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        ),
        items: employees
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 15,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${e.name}  ·  ${e.department}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: onEmployee,
        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
      ),
    ],
  );

  Widget _monthField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _lbl('Month'),
      DropdownButtonFormField<DateTime>(
        initialValue: month,
        decoration: _dec,
        isExpanded: true,
        items: months
            .map(
              (m) => DropdownMenuItem(
                value: m,
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMM yyyy').format(m),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: (m) {
          if (m != null) onMonth(m);
        },
        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
      ),
    ],
  );

  Widget _deptField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _lbl('Department'),
      DropdownButtonFormField<String>(
        initialValue: filterDept,
        decoration: _dec,
        isExpanded: true,
        items: departments
            .map(
              (d) => DropdownMenuItem(
                value: d,
                child: Row(
                  children: [
                    const Icon(
                      Icons.business_rounded,
                      size: 13,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(d, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: (d) {
          if (d != null) onDept(d);
        },
        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
      ),
    ],
  );

  Widget _genBtn() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _lbl(' '),
      SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: onGenerate,
          icon: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.search_rounded, size: 16),
          label: Text(
            loading ? 'Loading…' : 'Generate Report',
            style: const TextStyle(fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: const [
                Icon(Icons.tune_rounded, size: 17, color: Color(0xFF3B82F6)),
                SizedBox(width: 8),
                Text(
                  'Report Filters',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(flex: 3, child: _empField()),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _monthField()),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _deptField()),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _genBtn()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _empField(),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _monthField()),
                              const SizedBox(width: 12),
                              Expanded(child: _deptField()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _genBtn(),
                        ],
                      ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: onSearch,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email or role…',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Employee Profile Card
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final Employee employee;
  final String monthLabel;
  const _ProfileCard({required this.employee, required this.monthLabel});

  String _initials(String name) {
    final p = name.trim().split(' ');
    return p.length == 1
        ? p[0][0].toUpperCase()
        : '${p[0][0]}${p[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = employee.status == EmployeeStatus.active
        ? 'Active'
        : employee.status == EmployeeStatus.leave
        ? 'On Leave'
        : 'Inactive';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(employee.name),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${employee.role} · ${employee.department}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      _Chip(Icons.email_outlined, employee.email),
                      _Chip(Icons.calendar_today_rounded, monthLabel),
                    ],
                  ),
                ],
              ),
            ),
            _StatusBadge(label: statusLabel, light: true),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Chip(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: Colors.white70),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 12, color: Colors.white70)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Overview row — 4 stat cards
// ─────────────────────────────────────────────────────────────────────────────
class _OverviewRow extends StatelessWidget {
  final Map<String, dynamic>? perf;
  final double attendanceRate;
  final int presentDays, totalDays;
  final PayslipModel? payslip;
  final bool isWide;

  const _OverviewRow({
    required this.perf,
    required this.attendanceRate,
    required this.presentDays,
    required this.totalDays,
    required this.payslip,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    final score = (perf?['score'] as num?)?.toDouble() ?? 0;
    final completed = (perf?['completedTasks'] as int?) ?? 0;
    final total = (perf?['totalTasks'] as int?) ?? 0;
    final rating = perf?['rating'] as String? ?? '—';

    final cards = [
      _MiniStat(
        icon: Icons.trending_up_rounded,
        label: 'Performance Score',
        value: score > 0 ? '${score.toStringAsFixed(0)}%' : '—',
        sub: rating,
        iconBg: const Color(0xFFD1FAE5),
        iconColor: const Color(0xFF059669),
      ),
      _MiniStat(
        icon: Icons.my_location_rounded,
        label: 'Goals Achieved',
        value: total > 0 ? '$completed/$total' : '—',
        sub: total > 0
            ? '${(completed / total * 100).round()}% completion'
            : 'No data',
        iconBg: const Color(0xFFDBEAFE),
        iconColor: const Color(0xFF2563EB),
      ),
      _MiniStat(
        icon: Icons.how_to_reg_rounded,
        label: 'Attendance Rate',
        value: totalDays > 0 ? '${attendanceRate.toStringAsFixed(0)}%' : '—',
        sub: '$presentDays/$totalDays days present',
        iconBg: const Color(0xFFEDE9FE),
        iconColor: const Color(0xFF7C3AED),
      ),
      _MiniStat(
        icon: Icons.payments_rounded,
        label: 'Net Salary',
        value: (payslip?.netPay ?? 0) > 0
            ? 'PKR ${NumberFormat('#,##0').format(payslip!.netPay)}'
            : '—',
        sub: payslip?.status.name ?? '—',
        iconBg: const Color(0xFFFEF3C7),
        iconColor: const Color(0xFFD97706),
      ),
    ];

    if (isWide) {
      return Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 12),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label, value, sub;
  final Color iconBg, iconColor;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) => _Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance Card
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceCard extends StatelessWidget {
  final MonthlyArchive? archive;
  final String monthLabel;
  final int present, absent, late, halfDay;

  const _AttendanceCard({
    required this.archive,
    required this.monthLabel,
    required this.present,
    required this.absent,
    required this.late,
    required this.halfDay,
  });

  String _dur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final records = archive?.days.values.toList()
      ?..sort((a, b) => b.date.compareTo(a.date));

    return _DetailCard(
      icon: Icons.access_time_rounded,
      iconColor: const Color(0xFF2563EB),
      title: 'Attendance Report',
      trailing: monthLabel,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _AttStat('Present', present, const Color(0xFF059669)),
                _AttStat('Absent', absent, const Color(0xFFDC2626)),
                _AttStat('Late', late, const Color(0xFFD97706)),
                _AttStat('Half Day', halfDay, const Color(0xFF2563EB)),
              ],
            ),
          ),
          const Divider(height: 1),
          if (records == null || records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No records for this month',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            )
          else
            SizedBox(
              height: 280,
              child: SingleChildScrollView(
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1.5),
                    2: FlexColumnWidth(1.2),
                    3: FlexColumnWidth(1.8),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                      children: ['Date', 'Check In', 'Hours', 'Status']
                          .map(
                            (h) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Text(
                                h,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    ...records
                        .take(15)
                        .map(
                          (r) => TableRow(
                            decoration: BoxDecoration(
                              color: r.status == AttendanceStatus.absent
                                  ? const Color(
                                      0xFFFEF2F2,
                                    ).withValues(alpha: 0.5)
                                  : null,
                            ),
                            children: [
                              _TCell(DateFormat('MMM d').format(r.date)),
                              _TCell(
                                r.checkInTime != null
                                    ? DateFormat('HH:mm').format(r.checkInTime!)
                                    : '—',
                              ),
                              _TCell(
                                r.checkInTime != null
                                    ? _dur(r.totalWorkDuration)
                                    : '0h',
                              ),
                              TableCell(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: _StatusBadge(
                                    label: r.status.shortLabel,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AttStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _AttStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Performance Card
// ─────────────────────────────────────────────────────────────────────────────
class _PerformanceCard extends StatelessWidget {
  final Map<String, dynamic>? perf;
  const _PerformanceCard({required this.perf});

  @override
  Widget build(BuildContext context) {
    final score = (perf?['score'] as num?)?.toDouble() ?? 0;
    final completed = (perf?['completedTasks'] as int?) ?? 0;
    final total = (perf?['totalTasks'] as int?) ?? 0;
    final missed = (perf?['missedTasks'] as int?) ?? 0;
    final rating = perf?['rating'] as String? ?? 'N/A';
    final barColor = score >= 85
        ? const Color(0xFF059669)
        : score >= 70
        ? const Color(0xFF2563EB)
        : const Color(0xFFD97706);

    return _DetailCard(
      icon: Icons.emoji_events_rounded,
      iconColor: const Color(0xFF059669),
      title: 'Performance Report',
      trailing: 'This month',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: score == 0
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No performance data for this month',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ),
              )
            : Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: score / 100,
                              strokeWidth: 7,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation(barColor),
                            ),
                            Text(
                              '${score.toInt()}%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: barColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PRow('Rating', rating, null),
                            _PRow('Total tasks', '$total', null),
                            _PRow(
                              'Completed',
                              '$completed',
                              const Color(0xFF059669),
                            ),
                            _PRow(
                              'Missed',
                              '$missed',
                              missed > 0
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation(barColor),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _PRow(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Payroll Card
// ─────────────────────────────────────────────────────────────────────────────
class _PayrollCard extends StatelessWidget {
  final PayslipModel? payslip;
  final String monthLabel;
  const _PayrollCard({required this.payslip, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    return _DetailCard(
      icon: Icons.payments_rounded,
      iconColor: const Color(0xFFD97706),
      title: 'Payroll Report',
      trailing: monthLabel,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: payslip == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No payslip for this month',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Net Salary',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            _StatusBadge(
                              label: payslip!.status.name.toUpperCase(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'PKR ${fmt.format(payslip!.netPay)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _PayItem(
                                'Basic',
                                payslip!.basicSalary,
                                fmt,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PayItem(
                                'Allowances',
                                payslip!.totalAllowances,
                                fmt,
                                add: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _PayItem(
                                'Bonus',
                                payslip!.performanceBonus,
                                fmt,
                                add: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PayItem(
                                'Deductions',
                                payslip!.totalDeductions,
                                fmt,
                                deduct: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (payslip!.attendanceDeduction > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Color(0xFFEA580C),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Attendance deduction',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                          ),
                          Text(
                            '-PKR ${fmt.format(payslip!.attendanceDeduction)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _PayItem extends StatelessWidget {
  final String label;
  final double amount;
  final NumberFormat fmt;
  final bool add, deduct;
  const _PayItem(
    this.label,
    this.amount,
    this.fmt, {
    this.add = false,
    this.deduct = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = deduct
        ? const Color(0xFFDC2626)
        : add
        ? const Color(0xFF059669)
        : const Color(0xFF0F172A);
    final prefix = deduct
        ? '−'
        : add
        ? '+'
        : '';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: deduct
                  ? const Color(0xFFDC2626)
                  : add
                  ? const Color(0xFF059669)
                  : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${prefix}PKR ${fmt.format(amount)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leave Card
// ─────────────────────────────────────────────────────────────────────────────
class _LeaveCard extends StatelessWidget {
  final List<LeaveModel> leaves;
  const _LeaveCard({required this.leaves});

  @override
  Widget build(BuildContext context) {
    final approved = leaves
        .where((l) => l.status == LeaveStatus.approved)
        .length;
    final pending = leaves.where((l) => l.status == LeaveStatus.pending).length;
    final totalDays = leaves
        .where((l) => l.status == LeaveStatus.approved)
        .fold<int>(0, (s, l) => s + l.toDate.difference(l.fromDate).inDays + 1);

    return _DetailCard(
      icon: Icons.event_note_rounded,
      iconColor: const Color(0xFF7C3AED),
      title: 'Leave Report',
      trailing: 'All time',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _LStat(
                  'Total',
                  '20',
                  const Color(0xFF475569),
                  const Color(0xFFF1F5F9),
                ),
                _LStat(
                  'Used',
                  '$totalDays',
                  const Color(0xFF059669),
                  const Color(0xFFD1FAE5),
                ),
                _LStat(
                  'Approved',
                  '$approved',
                  const Color(0xFF2563EB),
                  const Color(0xFFDBEAFE),
                ),
                _LStat(
                  'Pending',
                  '$pending',
                  const Color(0xFFD97706),
                  const Color(0xFFFEF3C7),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (leaves.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No leave records found',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            )
          else ...[
            ...leaves.take(5).map((l) => _LeaveRow(leave: l)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _LStat extends StatelessWidget {
  final String label, value;
  final Color fg, bg;
  const _LStat(this.label, this.value, this.fg, this.bg);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
        ],
      ),
    ),
  );
}

class _LeaveRow extends StatelessWidget {
  final LeaveModel leave;
  const _LeaveRow({required this.leave});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d');
    final days = leave.toDate.difference(leave.fromDate).inDays + 1;
    final typeColors = <String, List<Color>>{
      'sick': [const Color(0xFFFEE2E2), const Color(0xFFDC2626)],
      'casual': [const Color(0xFFDBEAFE), const Color(0xFF2563EB)],
      'annual': [const Color(0xFFD1FAE5), const Color(0xFF059669)],
      'unpaid': [const Color(0xFFF1F5F9), const Color(0xFF475569)],
    };
    final key = leave.type.name.toLowerCase();
    final colors = typeColors[key] ?? typeColors['unpaid']!;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors[0],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  leave.type.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors[1],
                  ),
                ),
              ),
              _StatusBadge(label: leave.status.label),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${fmt.format(leave.fromDate)} → ${fmt.format(leave.toDate)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$days day${days > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              if (leave.reason.isNotEmpty)
                Flexible(
                  child: Text(
                    leave.reason,
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF94A3B8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => _Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFDBEAFE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_rounded,
              size: 40,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Report Generated',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select an employee, month and department above,\nthen tap "Generate Report" to view records.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared primitives
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, trailing;
  final Widget child;

  const _DetailCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                trailing,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        child,
      ],
    ),
  );
}

class _TCell extends TableCell {
  _TCell(String text)
    : super(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
          ),
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool light;
  const _StatusBadge({required this.label, this.light = false});

  @override
  Widget build(BuildContext context) {
    Color bg, fg, border;
    switch (label.toLowerCase()) {
      case 'approved':
      case 'paid':
      case 'active':
      case 'present':
      case 'excellent':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        border = const Color(0xFF6EE7B7);
        break;
      case 'pending':
      case 'late':
      case 'on leave':
      case 'average':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        border = const Color(0xFFFCD34D);
        break;
      case 'rejected':
      case 'absent':
      case 'below average':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        border = const Color(0xFFFCA5A5);
        break;
      default:
        bg = light
            ? Colors.white.withValues(alpha: 0.2)
            : const Color(0xFFF1F5F9);
        fg = light ? Colors.white : const Color(0xFF475569);
        border = light
            ? Colors.white.withValues(alpha: 0.3)
            : const Color(0xFFCBD5E1);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
