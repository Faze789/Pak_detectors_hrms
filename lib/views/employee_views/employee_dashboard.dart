// lib/screens/employee_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/leave_viewmodel.dart';
import '../../viewmodels/attendance_viewmodel.dart';
import '../../viewmodels/employee_viewmodel.dart';
import '../../models/leave_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Breakpoints
// ─────────────────────────────────────────────────────────────────────────────
abstract class _BP {
  static const double mobile = 600;
  static const double tablet = 900;
}

// ─────────────────────────────────────────────────────────────────────────────
// Employee Dashboard Screen
// ─────────────────────────────────────────────────────────────────────────────
class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  // Static project data (replace with real VM when available)
  static const List<Map<String, dynamic>> _projects = [
    {
      'name': 'E-Commerce Platform',
      'progress': 75,
      'deadline': 'Mar 15',
      'team': 8,
    },
    {
      'name': 'Mobile App Redesign',
      'progress': 45,
      'deadline': 'Apr 20',
      'team': 5,
    },
    {
      'name': 'Analytics Dashboard',
      'progress': 90,
      'deadline': 'Feb 28',
      'team': 4,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthViewModel>().currentUser?.uid ?? '';
      if (uid.isNotEmpty) {
        context.read<LeaveViewModel>().initForEmployee(uid);
        context.read<AttendanceViewModel>().getMonthlyArchive(
          uid,
          DateTime.now().year,
          DateTime.now().month,
        );
        context.read<EmployeeViewModel>().loadEmployees(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final leaveVm = context.watch<LeaveViewModel>();
    final attVm = context.watch<AttendanceViewModel>();
    final empVm = context.watch<EmployeeViewModel>();

    final user = auth.currentUser;
    final userName = user?.name ?? 'User';
    final uid = user?.uid ?? '';

    // ── Attendance stats from archive ─────────────────────────────────────
    final now = DateTime.now();
    final archiveKey = '${now.year}_${now.month.toString().padLeft(2, '0')}';
    final archive = attVm.monthlyArchiveCache[archiveKey];
    int presentDays = 0;
    int totalDays = 0;
    if (archive != null) {
      totalDays = archive.days.length;
      presentDays = archive.days.values
          .where((r) => r.status.name != 'absent')
          .length;
    }
    final attendancePct = totalDays > 0
        ? ((presentDays / totalDays) * 100).round()
        : 0;

    // ── Leave stats from LeaveViewModel ───────────────────────────────────
    final myLeaves = leaveVm.myLeaves;
    final pendingLeaves = myLeaves
        .where((l) => l.status == LeaveStatus.pending)
        .length;
    final approvedDays = myLeaves
        .where(
          (l) => l.status == LeaveStatus.approved && l.type == LeaveType.annual,
        )
        .fold(0, (s, l) => s + l.days);
    final annualUsed = approvedDays;
    const annualTotal = 20;
    const sickTotal = 10;
    const casualTotal = 8;
    final sickUsed = myLeaves
        .where(
          (l) => l.status == LeaveStatus.approved && l.type == LeaveType.sick,
        )
        .fold(0, (s, l) => s + l.days);
    final casualUsed = myLeaves
        .where(
          (l) => l.status == LeaveStatus.approved && l.type == LeaveType.casual,
        )
        .fold(0, (s, l) => s + l.days);

    // ── Employee profile from EmployeeViewModel ───────────────────────────
    final employee = empVm.employees.isNotEmpty
        ? empVm.employees.firstWhere(
            (e) => e.uid == uid,
            orElse: () => empVm.employees.first,
          )
        : null;

    final department = employee?.department ?? '—';
    final role = employee?.role ?? user?.role ?? '—';
    final joinDate = employee?.joinDate ?? '—';
    final initials = _initials(userName);

    // ── Metric cards ──────────────────────────────────────────────────────
    final metrics = [
      _MetricData(
        title: 'Attendance',
        value: '$attendancePct%',
        subtitle: '$presentDays / $totalDays days',
        icon: Icons.event_available_outlined,
        iconColor: const Color(0xFF3B82F6),
        borderColor: const Color(0xFF3B82F6),
        backgroundColor: const Color(0xFFDBEAFE),
      ),
      _MetricData(
        title: 'Annual Leave',
        value: '${annualTotal - annualUsed}',
        subtitle: '$annualUsed / $annualTotal used',
        icon: Icons.calendar_today_outlined,
        iconColor: const Color(0xFFA855F7),
        borderColor: const Color(0xFFA855F7),
        backgroundColor: const Color(0xFFF3E8FF),
      ),
      _MetricData(
        title: 'Sick Leave',
        value: '${sickTotal - sickUsed}',
        subtitle: '$sickUsed / $sickTotal used',
        icon: Icons.health_and_safety_outlined,
        iconColor: const Color(0xFF10B981),
        borderColor: const Color(0xFF10B981),
        backgroundColor: const Color(0xFFD1FAE5),
      ),
      _MetricData(
        title: 'Pending',
        value: '$pendingLeaves',
        subtitle: 'leave request${pendingLeaves != 1 ? 's' : ''}',
        icon: Icons.access_time_outlined,
        iconColor: const Color(0xFFF59E0B),
        borderColor: const Color(0xFFF59E0B),
        backgroundColor: const Color(0xFFFEF3C7),
      ),
    ];

    // ── Leave balances ─────────────────────────────────────────────────────
    final leaveBalances = [
      {
        'type': 'Annual Leave',
        'total': annualTotal,
        'used': annualUsed,
        'available': annualTotal - annualUsed,
        'color': const Color(0xFF3B82F6),
      },
      {
        'type': 'Sick Leave',
        'total': sickTotal,
        'used': sickUsed,
        'available': sickTotal - sickUsed,
        'color': const Color(0xFF10B981),
      },
      {
        'type': 'Casual Leave',
        'total': casualTotal,
        'used': casualUsed,
        'available': casualTotal - casualUsed,
        'color': const Color(0xFFFCD34D),
      },
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= _BP.tablet;
    final hPadding = screenWidth < _BP.mobile ? 12.0 : 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WelcomeHeader(userName: userName),
            const SizedBox(height: 20),
            _MetricCardsRow(metrics: metrics),
            const SizedBox(height: 18),
            isDesktop
                ? _DesktopLayout(
                    projects: _projects,
                    leaveBalances: leaveBalances,
                    profileData: _ProfileData(
                      name: userName,
                      role: role,
                      initials: initials,
                      department: department,
                      joinDate: joinDate,
                      uid: uid,
                    ),
                  )
                : _MobileLayout(
                    projects: _projects,
                    leaveBalances: leaveBalances,
                    profileData: _ProfileData(
                      name: userName,
                      role: role,
                      initials: initials,
                      department: department,
                      joinDate: joinDate,
                      uid: uid,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────
class _MetricData {
  final String title, value, subtitle;
  final IconData icon;
  final Color iconColor, borderColor, backgroundColor;
  const _MetricData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.backgroundColor,
  });
}

class _ProfileData {
  final String name, role, initials, department, joinDate, uid;
  const _ProfileData({
    required this.name,
    required this.role,
    required this.initials,
    required this.department,
    required this.joinDate,
    required this.uid,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Welcome Header
// ─────────────────────────────────────────────────────────────────────────────
class _WelcomeHeader extends StatelessWidget {
  final String userName;
  const _WelcomeHeader({required this.userName});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Good Morning, $userName! 👋',
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        "Here's your overview for today",
        style: TextStyle(fontSize: 15, color: Color(0xFF475569)),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric Cards Row
// ─────────────────────────────────────────────────────────────────────────────
class _MetricCardsRow extends StatelessWidget {
  final List<_MetricData> metrics;
  const _MetricCardsRow({required this.metrics});

  static const double _h = 96, _w = 200, _gap = 14;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < _BP.mobile;
    if (isMobile) {
      return SizedBox(
        height: _h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: metrics.length,
          separatorBuilder: (_, __) => const SizedBox(width: _gap),
          itemBuilder: (_, i) => SizedBox(
            width: _w,
            height: _h,
            child: _MetricCard(data: metrics[i]),
          ),
        ),
      );
    }
    return Row(
      children: [
        for (int i = 0; i < metrics.length; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          Expanded(
            child: SizedBox(
              height: _h,
              child: _MetricCard(data: metrics[i]),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric Card
// ─────────────────────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final _MetricData data;
  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border(left: BorderSide(color: data.borderColor, width: 4)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
      ],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF10B981)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: data.backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(data.icon, color: data.iconColor, size: 20),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Layouts
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopLayout extends StatelessWidget {
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> leaveBalances;
  final _ProfileData profileData;
  const _DesktopLayout({
    required this.projects,
    required this.leaveBalances,
    required this.profileData,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 2,
        child: Column(
          children: [
            _ActiveProjectsCard(projects: projects),
            const SizedBox(height: 18),
            _LeaveBalanceCard(leaveBalances: leaveBalances),
          ],
        ),
      ),
      const SizedBox(width: 18),
      Expanded(flex: 1, child: _ProfileCard(data: profileData)),
    ],
  );
}

class _MobileLayout extends StatelessWidget {
  final List<Map<String, dynamic>> projects;
  final List<Map<String, dynamic>> leaveBalances;
  final _ProfileData profileData;
  const _MobileLayout({
    required this.projects,
    required this.leaveBalances,
    required this.profileData,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ActiveProjectsCard(projects: projects),
      const SizedBox(height: 18),
      _LeaveBalanceCard(leaveBalances: leaveBalances),
      const SizedBox(height: 18),
      _ProfileCard(data: profileData),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Card Shell
// ─────────────────────────────────────────────────────────────────────────────
class _CardShell extends StatelessWidget {
  final String title, subtitle;
  final Widget body;
  const _CardShell({
    required this.title,
    required this.subtitle,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),
            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.all(14), child: body),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Active Projects Card (static data — swap with ProjectViewModel when ready)
// ─────────────────────────────────────────────────────────────────────────────
class _ActiveProjectsCard extends StatelessWidget {
  final List<Map<String, dynamic>> projects;
  const _ActiveProjectsCard({required this.projects});

  @override
  Widget build(BuildContext context) => _CardShell(
    title: 'Active Projects',
    subtitle: 'Track progress',
    body: Column(
      children: [
        for (int i = 0; i < projects.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _ProjectItem(project: projects[i]),
        ],
      ],
    ),
  );
}

class _ProjectItem extends StatelessWidget {
  final Map<String, dynamic> project;
  const _ProjectItem({required this.project});

  @override
  Widget build(BuildContext context) {
    final progress = project['progress'] as int;
    final color = progress >= 75
        ? const Color(0xFF10B981)
        : progress >= 50
        ? const Color(0xFF3B82F6)
        : const Color(0xFFFCD34D);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  project['name'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$progress%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Due: ${project['deadline']} · ${project['team']} members',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 7,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leave Balance Card — real data
// ─────────────────────────────────────────────────────────────────────────────
class _LeaveBalanceCard extends StatelessWidget {
  final List<Map<String, dynamic>> leaveBalances;
  const _LeaveBalanceCard({required this.leaveBalances});

  @override
  Widget build(BuildContext context) => _CardShell(
    title: 'Leave Balance',
    subtitle: 'Your allocations',
    body: Column(
      children: [
        for (int i = 0; i < leaveBalances.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _LeaveItem(leave: leaveBalances[i]),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Request Leave',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _LeaveItem extends StatelessWidget {
  final Map<String, dynamic> leave;
  const _LeaveItem({required this.leave});

  @override
  Widget build(BuildContext context) {
    final available = leave['available'] as int;
    final used = leave['used'] as int;
    final total = leave['total'] as int;

    final Color badgeBg, badgeFg;
    if (available > 5) {
      badgeBg = const Color(0xFFD1FAE5);
      badgeFg = const Color(0xFF10B981);
    } else if (available > 0) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeFg = const Color(0xFFF59E0B);
    } else {
      badgeBg = const Color(0xFFFEE2E2);
      badgeFg = const Color(0xFFEF4444);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leave['type'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '$used / $total used',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$available left',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: badgeFg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Card — real data from AuthViewModel + EmployeeViewModel
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final _ProfileData data;
  const _ProfileCard({required this.data});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
      ],
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFFA855F7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(44),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                data.initials,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Name
        Text(
          data.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 3),

        // Role
        Text(
          data.role,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 3),

        // UID
        Text(
          data.uid,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 14),
        const Divider(color: Color(0xFFF1F5F9), height: 1),
        const SizedBox(height: 14),

        // Details
        _DetailRow('Department', data.department),
        const SizedBox(height: 10),
        _DetailRow('Role', data.role),
        const SizedBox(height: 10),
        _DetailRow('Join Date', data.joinDate),
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'View Profile',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
    ],
  );
}
