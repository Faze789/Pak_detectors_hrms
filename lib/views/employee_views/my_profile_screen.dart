import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/attendance_model.dart';
import '../../models/employee_model.dart';
import '../../models/payroll_model.dart';
import '../../viewmodels/attendance_viewmodel.dart';
import '../../viewmodels/employee_viewmodel.dart';
import '../../viewmodels/leave_viewmodel.dart';
import '../employee_tabs/leaves_tab.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MyProfileScreen
// ══════════════════════════════════════════════════════════════════════════════

class MyProfileScreen extends StatefulWidget {
  /// Pass the currently-logged-in user's UID.
  final String userId;

  const MyProfileScreen({super.key, required this.userId});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Month filter state ────────────────────────────────────────────────────
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaveViewModel>().initForEmployee(widget.userId);
      context.read<EmployeeViewModel>().loadEmployees(widget.userId);
      _loadAttendance();
    });
  }

  void _loadAttendance() {
    context.read<AttendanceViewModel>().getMonthlyArchive(
      widget.userId,
      _selectedYear,
      _selectedMonth,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Month picker dialog ───────────────────────────────────────────────────
  Future<void> _pickMonth() async {
    int tempYear = _selectedYear;
    int tempMonth = _selectedMonth;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Select Month'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setSt(() => tempYear--),
                    ),
                    Text(
                      '$tempYear',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setSt(() {
                        if (tempYear < DateTime.now().year) tempYear++;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  itemCount: 12,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 1.4,
                  ),
                  itemBuilder: (_, i) {
                    final m = i + 1;
                    final isSelected =
                        m == tempMonth && tempYear == _selectedYear;
                    final isFuture = DateTime(
                      tempYear,
                      m,
                    ).isAfter(DateTime.now());
                    return GestureDetector(
                      onTap: isFuture ? null : () => setSt(() => tempMonth = m),
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : isFuture
                              ? Colors.grey.shade100
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          DateFormat.MMM().format(DateTime(0, m)),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isFuture
                                ? Colors.grey.shade400
                                : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
              ),
              onPressed: () {
                setState(() {
                  _selectedYear = tempYear;
                  _selectedMonth = tempMonth;
                });
                _loadAttendance();
                Navigator.pop(ctx);
              },
              child: const Text('Apply', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Consumer2<EmployeeViewModel, AttendanceViewModel>(
        builder: (context, empVm, attVm, _) {
          final Employee? employee = empVm.employees.isNotEmpty
              ? empVm.employees.firstWhere(
                  (e) => e.uid == widget.userId,
                  orElse: () => empVm.employees.first,
                )
              : null;

          return NestedScrollView(
            headerSliverBuilder: (ctx, _) => [
              // ── Gradient app bar + profile card ──────────────────────
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: const Color(0xFF2563EB),
                flexibleSpace: FlexibleSpaceBar(
                  background: _ProfileHeader(employee: employee),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(0),
                  child: Container(),
                ),
              ),

              // ── Tab bar ──────────────────────────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: const Color(0xFF2563EB),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFF2563EB),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.person_outline, size: 18),
                        text: 'Profile',
                      ),
                      Tab(
                        icon: Icon(Icons.event_available_outlined, size: 18),
                        text: 'Attendance',
                      ),
                      Tab(
                        icon: Icon(Icons.calendar_today_outlined, size: 18),
                        text: 'Leaves',
                      ),
                      Tab(
                        icon: Icon(Icons.trending_up_outlined, size: 18),
                        text: 'Performance',
                      ),
                      Tab(
                        icon: Icon(Icons.attach_money_outlined, size: 18),
                        text: 'Salary',
                      ),
                    ],
                  ),
                ),
              ),
            ],

            body: TabBarView(
              controller: _tabController,
              children: [
                _ProfileTab(
                  employee: employee,
                  empVm: empVm,
                  userId: widget.userId,
                ),
                _AttendanceTab(
                  attVm: attVm,
                  userId: widget.userId,
                  selectedYear: _selectedYear,
                  selectedMonth: _selectedMonth,
                  onPickMonth: _pickMonth,
                ),
                LeavesTab(
                  userId: widget.userId,
                  employeeName: employee?.name ?? '',
                  employeeRole: employee?.role ?? '',
                  emp_id: employee?.emp_id ?? '',
                  isHR: (employee?.role ?? '').toLowerCase() == 'hr',
                ),
                _PerformanceTab(),
                // ✅ Real payslip data
                _SalaryTab(userId: widget.userId),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PROFILE HEADER
// ══════════════════════════════════════════════════════════════════════════════

class _ProfileHeader extends StatelessWidget {
  final Employee? employee;
  const _ProfileHeader({this.employee});

  @override
  Widget build(BuildContext context) {
    final name = employee?.name ?? '—';
    final role = employee?.role ?? '—';
    final department = employee?.department ?? '—';
    final empId = employee?.uid ?? '—';
    final statusColor = employee?.status == EmployeeStatus.active
        ? Colors.greenAccent
        : Colors.orangeAccent;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                  ),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                employee?.status.name ?? 'active',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: [
                        _HeaderChip(icon: Icons.badge_outlined, text: empId),
                        _HeaderChip(
                          icon: Icons.business_outlined,
                          text: department,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeaderChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Colors.white70, size: 13),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB BAR DELEGATE
// ══════════════════════════════════════════════════════════════════════════════

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlaps) =>
      Container(color: Colors.white, child: tabBar);

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// PROFILE TAB
// ══════════════════════════════════════════════════════════════════════════════

class _ProfileTab extends StatelessWidget {
  final Employee? employee;
  final EmployeeViewModel empVm;
  final String userId;

  const _ProfileTab({
    required this.employee,
    required this.empVm,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    if (empVm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (employee == null) {
      return const Center(child: Text('Could not load profile.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Contact Information',
          icon: Icons.mail_outline,
          children: [
            _InfoRow(
              icon: Icons.mail_outline,
              label: 'Email',
              value: employee!.email,
            ),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: employee!.phone,
            ),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: employee!.location,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Employment Details',
          icon: Icons.work_outline,
          children: [
            _InfoRow(
              icon: Icons.badge_outlined,
              label: 'Employee ID',
              value: employee!.uid,
            ),
            _InfoRow(
              icon: Icons.business_outlined,
              label: 'Department',
              value: employee!.department,
            ),
            _InfoRow(
              icon: Icons.work_outline,
              label: 'Job Title',
              value: employee!.role,
            ),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Join Date',
              value: employee!.joinDate,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            border: Border.all(color: const Color(0xFFBFDBFE)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Employment details like department and role are managed by HR. '
                  'Contact your HR manager for changes.',
                  style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ATTENDANCE TAB
// ══════════════════════════════════════════════════════════════════════════════

class _AttendanceTab extends StatelessWidget {
  final AttendanceViewModel attVm;
  final String userId;
  final int selectedYear;
  final int selectedMonth;
  final VoidCallback onPickMonth;

  const _AttendanceTab({
    required this.attVm,
    required this.userId,
    required this.selectedYear,
    required this.selectedMonth,
    required this.onPickMonth,
  });

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat.yMMMM().format(
      DateTime(selectedYear, selectedMonth),
    );

    final archiveKey =
        '${selectedYear}_${selectedMonth.toString().padLeft(2, '0')}';
    final archive = attVm.monthlyArchiveCache[archiveKey];
    final isLoading = attVm.state == ViewState.loading;

    int present = 0, absent = 0, workingDays = 0;
    List<MapEntry<String, AttendanceModel>> dayEntries = [];

    if (archive != null) {
      dayEntries = archive.days.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key));

      for (final e in archive.days.entries) {
        workingDays++;
        if (e.value.status == AttendanceStatus.absent) {
          absent++;
        } else {
          present++;
        }
      }
    }

    final percentage = workingDays > 0
        ? ((present / workingDays) * 100).round()
        : 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              monthLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onPickMonth,
              icon: const Icon(Icons.calendar_month_outlined, size: 16),
              label: const Text('Change Month'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF2563EB)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else if (archive == null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy_outlined,
                    size: 56,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No records for $monthLabel',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          )
        else ...[
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.9,
            children: [
              _StatTile(
                label: 'Working Days',
                value: '$workingDays',
                icon: Icons.calendar_today_outlined,
                color: const Color(0xFF64748B),
              ),
              _StatTile(
                label: 'Present',
                value: '$present',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF10B981),
              ),
              _StatTile(
                label: 'Absent',
                value: '$absent',
                icon: Icons.cancel_outlined,
                color: const Color(0xFFEF4444),
              ),
              _StatTile(
                label: 'Attendance %',
                value: '$percentage%',
                icon: Icons.bar_chart_outlined,
                color: const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Day-wise Records',
            icon: Icons.list_alt_outlined,
            children: dayEntries.map((e) {
              return _AttendanceDayTile(record: e.value);
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _AttendanceDayTile extends StatelessWidget {
  final AttendanceModel record;
  const _AttendanceDayTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd().format(record.date);
    final isAbsent = record.status == AttendanceStatus.absent;
    final isCheckedOut = record.status == AttendanceStatus.checkedOut;

    final checkIn = record.checkInTime != null
        ? DateFormat.jm().format(record.checkInTime!)
        : '—';
    final checkOut = record.checkOutTime != null
        ? DateFormat.jm().format(record.checkOutTime!)
        : '—';
    final workedHours = isCheckedOut
        ? _fmtDuration(record.totalWorkDuration)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAbsent ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAbsent ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAbsent ? Icons.cancel_outlined : Icons.check_circle_outline,
            color: isAbsent ? const Color(0xFFEF4444) : const Color(0xFF10B981),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                if (!isAbsent)
                  Text(
                    'In: $checkIn  •  Out: $checkOut',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAbsent
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isAbsent ? 'Absent' : 'Present',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (workedHours != null) ...[
                const SizedBox(height: 4),
                Text(
                  workedHours,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE TAB — Dummy data (replace when real data is available)
// ══════════════════════════════════════════════════════════════════════════════

class _PerformanceTab extends StatelessWidget {
  final _quarters = const [
    {'quarter': 'Q4 2024', 'date': '2024-12-31', 'score': '92%'},
    {'quarter': 'Q3 2024', 'date': '2024-09-30', 'score': '88%'},
  ];

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(
        children: [
          Expanded(
            child: _StatTile(
              label: 'Completed Reviews',
              value: '2',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              label: 'Status',
              value: 'All Done',
              icon: Icons.flag_outlined,
              color: const Color(0xFF2563EB),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _SectionCard(
        title: 'Quarterly Reviews',
        icon: Icons.trending_up_outlined,
        children: _quarters.map((q) => _QuarterTile(data: q)).toList(),
      ),
    ],
  );
}

class _QuarterTile extends StatelessWidget {
  final Map<String, String> data;
  const _QuarterTile({required this.data});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.assessment_outlined,
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
                data['quarter']!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'Review Date: ${data['date']}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFD1FAE5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF059669),
                size: 13,
              ),
              const SizedBox(width: 4),
              Text(
                data['score']!,
                style: const TextStyle(
                  color: Color(0xFF059669),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SALARY TAB — Real data from payslips collection
// ══════════════════════════════════════════════════════════════════════════════

class _SalaryTab extends StatefulWidget {
  final String userId;
  const _SalaryTab({required this.userId});

  @override
  State<_SalaryTab> createState() => _SalaryTabState();
}

class _SalaryTabState extends State<_SalaryTab> {
  List<PayslipModel> _payslips = [];
  PayslipModel? _selected;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPayslips();
  }

  Future<void> _loadPayslips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('payslips')
          .where('employeeId', isEqualTo: widget.userId)
          .orderBy('year', descending: true)
          .orderBy('monthNum', descending: true)
          .get();

      final list = snapshot.docs.map((d) => PayslipModel.fromDoc(d)).toList();

      setState(() {
        _payslips = list;
        _selected = list.isNotEmpty ? list.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Loading ──────────────────────────────────────────────────────────────
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ── Error ────────────────────────────────────────────────────────────────
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFEF4444),
                size: 48,
              ),
              const SizedBox(height: 12),
              const Text(
                'Failed to load payslips',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPayslips,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // ── Empty ────────────────────────────────────────────────────────────────
    if (_payslips.isEmpty || _selected == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No payslips found',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              'Payslips will appear here once payroll is run by HR.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final p = _selected!;

    // ── Resolved values from PayslipModel ────────────────────────────────────
    final double grossPay = p.grossPay;
    final double totalDeductions = p.totalDeductions;
    final double netPay = p.netPay;
    final double totalAllowances = p.totalAllowances;

    // Status colour
    Color statusColor;
    switch (p.status) {
      case PayslipStatus.paid:
        statusColor = const Color(0xFF10B981);
        break;
      case PayslipStatus.approved:
        statusColor = const Color(0xFF2563EB);
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Month selector chips ─────────────────────────────────────────────
        if (_payslips.length > 1) ...[
          const Text(
            'Select Payslip',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _payslips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final ps = _payslips[i];
                final isSelected = ps.id == _selected!.id;
                final label = DateFormat.yMMM().format(
                  DateTime(ps.year, ps.monthNum),
                );
                return GestureDetector(
                  onTap: () => setState(() => _selected = ps),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Month + status header ────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              p.month,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    p.status == PayslipStatus.paid
                        ? Icons.check_circle_outline
                        : p.status == PayslipStatus.approved
                        ? Icons.thumb_up_outlined
                        : Icons.hourglass_empty_outlined,
                    color: statusColor,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    p.status.name.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Overview tiles ───────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _SalaryOverviewTile(
                label: 'Gross Pay',
                value: grossPay,
                icon: Icons.trending_up,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SalaryOverviewTile(
                label: 'Deductions',
                value: totalDeductions,
                icon: Icons.remove_circle_outline,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SalaryOverviewTile(
          label: 'Net Pay',
          value: netPay,
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFF2563EB),
        ),
        const SizedBox(height: 16),

        // ── Earnings breakdown ───────────────────────────────────────────────
        _SectionCard(
          title: 'Earnings',
          icon: Icons.trending_up_outlined,
          children: [
            _SalaryRow(
              label: 'Basic Salary',
              amount: p.basicSalary,
              isDeduction: false,
            ),

            // Dynamic allowances from PayrollConfig
            ...p.allowances.map(
              (a) => _SalaryRow(
                label: a.name,
                amount: a.resolve(p.basicSalary),
                isDeduction: false,
                suffix: a.type == AllowanceType.percentOfBasic
                    ? ' (${a.amount.toStringAsFixed(0)}%)'
                    : null,
              ),
            ),

            if (p.performanceBonus > 0)
              _SalaryRow(
                label: 'Performance Bonus',
                amount: p.performanceBonus,
                isDeduction: false,
              ),

            const Divider(height: 20),
            _SalaryRow(
              label: 'Total Earnings',
              amount: grossPay,
              isDeduction: false,
              isBold: true,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Deductions breakdown ─────────────────────────────────────────────
        _SectionCard(
          title: 'Deductions',
          icon: Icons.remove_circle_outline,
          children: [
            if (p.performanceDeduction > 0)
              _SalaryRow(
                label: 'Performance Deduction',
                amount: p.performanceDeduction,
                isDeduction: true,
              ),
            if (p.loanDeduction > 0)
              _SalaryRow(
                label: 'Loan Deduction',
                amount: p.loanDeduction,
                isDeduction: true,
              ),

            if (totalDeductions == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: const Color(0xFF10B981),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'No deductions this month',
                      style: TextStyle(fontSize: 13, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
              ),

            const Divider(height: 20),
            _SalaryRow(
              label: 'Total Deductions',
              amount: totalDeductions,
              isDeduction: true,
              isBold: true,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Performance snapshot ─────────────────────────────────────────────
        _SectionCard(
          title: 'Performance Snapshot',
          icon: Icons.bar_chart_outlined,
          children: [
            _PerformanceRow(
              label: 'Total Tasks',
              value: '${p.totalTasksInMonth}',
              icon: Icons.task_outlined,
              color: const Color(0xFF64748B),
            ),
            _PerformanceRow(
              label: 'Completed',
              value: '${p.completedTasks}',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF10B981),
            ),
            _PerformanceRow(
              label: 'Missed',
              value: '${p.missedTasks}',
              icon: Icons.cancel_outlined,
              color: const Color(0xFFEF4444),
            ),
            _PerformanceRow(
              label: 'Weekend Tasks',
              value: '${p.weekendTasks}',
              icon: Icons.weekend_outlined,
              color: const Color(0xFF8B5CF6),
            ),
            const Divider(height: 20),
            // Performance score bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Performance Score',
                      style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                    ),
                    Text(
                      '${p.performanceScore.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: p.performanceScore >= 80
                            ? const Color(0xFF10B981)
                            : p.performanceScore >= 50
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (p.performanceScore / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      p.performanceScore >= 80
                          ? const Color(0xFF10B981)
                          : p.performanceScore >= 50
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Generated / approved dates ───────────────────────────────────────
        _SectionCard(
          title: 'Payslip Info',
          icon: Icons.receipt_long_outlined,
          children: [
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Generated At',
              value: DateFormat.yMMMd().add_jm().format(p.generatedAt),
            ),
            if (p.approvedAt != null)
              _InfoRow(
                icon: Icons.verified_outlined,
                label: 'Approved At',
                value: DateFormat.yMMMd().add_jm().format(p.approvedAt!),
              ),
            _InfoRow(
              icon: Icons.badge_outlined,
              label: 'Employee',
              value: p.employeeName,
            ),
            _InfoRow(
              icon: Icons.work_outline,
              label: 'Role',
              value: p.employeeRole,
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Performance row helper ────────────────────────────────────────────────────
class _PerformanceRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _PerformanceRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// SALARY OVERVIEW TILE
// ──────────────────────────────────────────────────────────────────────────────

class _SalaryOverviewTile extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  const _SalaryOverviewTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border(left: BorderSide(color: color, width: 4)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Rs ${NumberFormat('#,##0').format(value)}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// SALARY ROW
// ──────────────────────────────────────────────────────────────────────────────

class _SalaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isDeduction;
  final bool isBold;
  final String? suffix;
  const _SalaryRow({
    required this.label,
    required this.amount,
    required this.isDeduction,
    this.isBold = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            suffix != null ? '$label$suffix' : label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF475569),
            ),
          ),
        ),
        Text(
          '${isDeduction ? '-' : ''}Rs ${NumberFormat('#,##0').format(amount)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isDeduction
                ? const Color(0xFFEF4444)
                : const Color(0xFF10B981),
          ),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF2563EB), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: children),
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF2563EB), size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border(left: BorderSide(color: color, width: 4)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}
