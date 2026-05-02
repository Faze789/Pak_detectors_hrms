// lib/screens/employee_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hrms_app/services/attendance_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/attendance_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/leave_viewmodel.dart';
import '../../viewmodels/attendance_viewmodel.dart';
import '../../viewmodels/employee_viewmodel.dart';
import '../../models/leave_model.dart';

enum _LocPermStatus { unknown, enabled, denied, permanentlyDenied, servicesOff }

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

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen>
    with WidgetsBindingObserver {
  _LocPermStatus _locStatus = _LocPermStatus.unknown;
  bool _initialDialogShown = false;
  DateTime _selectedCalendarDay = DateTime.now();
  DateTime _focusedCalendarMonth = DateTime.now();

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
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = context.read<AuthViewModel>().currentUser?.uid ?? '';

      // Check location permission and prompt if not granted
      await _checkLocationPermission(promptIfNotGranted: true);
      if (!mounted) return;

      if (uid.isNotEmpty) {
        context.read<LeaveViewModel>().initForEmployee(uid);
        final attVm = context.read<AttendanceViewModel>();
        await attVm.loadToday(uid);
        if (!mounted) return;

        await attVm.getMonthlyArchive(
          uid,
          DateTime.now().year,
          DateTime.now().month,
        );
        if (!mounted) return;

        context.read<EmployeeViewModel>().loadEmployees(uid);
      }
    });
  }

  Future<void> _onCheckIn() async {
    if (_locStatus != _LocPermStatus.enabled) {
      _handleLocationAction();
      return;
    }
    final uid = context.read<AuthViewModel>().currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    final attVm = context.read<AttendanceViewModel>();
    await attVm.checkInFromCity(uid);

    if (!mounted) return;
    final err = attVm.errorMessage;
    if (err != null && err.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: const Color(0xFFDC2626)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checked in successfully'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    }
  }

  Future<void> _onCheckOut() async {
    final uid = context.read<AuthViewModel>().currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    final attVm = context.read<AttendanceViewModel>();
    await attVm.checkOutAnywhere(uid);

    if (!mounted) return;
    final err = attVm.errorMessage;
    if (err != null && err.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: const Color(0xFFDC2626)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checked out successfully'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check permission when user comes back from OS Settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkLocationPermission(promptIfNotGranted: false);
    }
  }

  void _logLocations() async {
    // Add async here
    const locations = {
      'Lahore': {'lat': 31.376609, 'lng': 74.1747195},
      'Islamabad': {'lat': 33.593685, 'lng': 73.161049},
      'Karachi': {'lat': 25.042857, 'lng': 67.337571},
      'UAE': {'lat': 24.341222, 'lng': 54.532972},
    };

    // AttendanceService isn't registered with Provider — instantiate directly.
    final attendanceService = AttendanceService();

    debugPrint('───── Configured Locations (${locations.length}) ─────');
    for (final entry in locations.entries) {
      debugPrint(
        '  • ${entry.key} | lat=${entry.value['lat']}, lng=${entry.value['lng']}',
      );
    }

    try {
      final position = await attendanceService.getMedianPosition();
      debugPrint(
        'Current Median Position: lat=${position.latitude}, '
        'lng=${position.longitude}, accuracy=${position.accuracy}m',
      );
    } catch (e) {
      debugPrint('Error getting position: $e');
    }

    debugPrint('────────────────────────────────────────');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Logged ${locations.length} locations — check debug console',
        ),
        backgroundColor: const Color(0xFF2563EB),
      ),
    );
  }

  Future<void> _checkLocationPermission({
    required bool promptIfNotGranted,
  }) async {
    try {
      final servicesOn = await Geolocator.isLocationServiceEnabled();
      if (!servicesOn) {
        if (mounted) {
          setState(() => _locStatus = _LocPermStatus.servicesOff);
        }
        if (promptIfNotGranted && mounted && !_initialDialogShown) {
          _initialDialogShown = true;
          _showLocationDialog();
        }
        return;
      }

      final perm = await Geolocator.checkPermission();
      _LocPermStatus newStatus;
      switch (perm) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          newStatus = _LocPermStatus.enabled;
          break;
        case LocationPermission.deniedForever:
          newStatus = _LocPermStatus.permanentlyDenied;
          break;
        default:
          newStatus = _LocPermStatus.denied;
      }

      if (mounted) setState(() => _locStatus = newStatus);

      if (newStatus != _LocPermStatus.enabled &&
          promptIfNotGranted &&
          mounted &&
          !_initialDialogShown) {
        _initialDialogShown = true;
        _showLocationDialog();
      }
    } catch (e) {
      debugPrint('[LocationCheck] $e');
    }
  }

  void _showLocationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isServicesOff = _locStatus == _LocPermStatus.servicesOff;
        final isPermDenied = _locStatus == _LocPermStatus.permanentlyDenied;
        final title = isServicesOff
            ? 'Turn On Location Services'
            : isPermDenied
            ? 'Location Permission Required'
            : 'Enable Location Access';
        final body = isServicesOff
            ? 'GPS is turned off on your device. Attendance check-in needs '
                  'location to verify you\'re at the office. Open settings to '
                  'turn it on.'
            : isPermDenied
            ? 'You\'ve previously denied location access. Open the app '
                  'settings to enable it manually.'
            : 'This app needs your location to verify attendance '
                  'check-in. We only access your location when you check '
                  'in or out.';
        final actionLabel = isServicesOff
            ? 'Open Location Settings'
            : isPermDenied
            ? 'Open App Settings'
            : 'Enable Location';

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          icon: const Icon(
            Icons.location_on_rounded,
            color: Color(0xFF2563EB),
            size: 36,
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: Text(
            body,
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Not Now',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _handleLocationAction();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLocationAction() async {
    switch (_locStatus) {
      case _LocPermStatus.servicesOff:
        await Geolocator.openLocationSettings();
        // didChangeAppLifecycleState will re-check on resume
        break;
      case _LocPermStatus.permanentlyDenied:
        await Geolocator.openAppSettings();
        break;
      case _LocPermStatus.denied:
      case _LocPermStatus.unknown:
        await Geolocator.requestPermission();
        await _checkLocationPermission(promptIfNotGranted: false);
        break;
      case _LocPermStatus.enabled:
        // already enabled, nothing to do
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final leaveVm = context.watch<LeaveViewModel>();
    final attVm = context.watch<AttendanceViewModel>();
    final empVm = context.watch<EmployeeViewModel>();

    // final location_permission = context.watch<AttendanceService>();

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
            _LocationStatusBanner(
              status: _locStatus,
              onTap: _handleLocationAction,
            ),
            _WelcomeHeader(userName: userName),
            const SizedBox(height: 18),
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
// Attendance Today Card
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceTodayCard extends StatelessWidget {
  final AttendanceModel? attendance;
  final bool busy;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  const _AttendanceTodayCard({
    required this.attendance,
    required this.busy,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d').format(now);
    final checkIn = attendance?.checkInTime;
    final checkOut = attendance?.checkOutTime;
    final isCheckedIn = checkIn != null && checkOut == null;
    final isDone = checkIn != null && checkOut != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row(
          //   children: [
          //     const Icon(
          //       Icons.event_available_rounded,
          //       color: Colors.white,
          //       size: 20,
          //     ),
          //     const SizedBox(width: 8),
          //     Text(
          //       dateStr,
          //       style: const TextStyle(
          //         fontSize: 14,
          //         fontWeight: FontWeight.w700,
          //         color: Colors.white,
          //       ),
          //     ),
          //   ],
          // ),
          // const SizedBox(height: 14),
          // Row(
          //   children: [
          //     Expanded(
          //       child: _timeBlock(
          //         label: 'Check In',
          //         value: checkIn != null
          //             ? DateFormat('HH:mm').format(checkIn)
          //             : '—',
          //       ),
          //     ),
          //     const SizedBox(width: 12),
          //     Expanded(
          //       child: _timeBlock(
          //         label: 'Check Out',
          //         value: checkOut != null
          //             ? DateFormat('HH:mm').format(checkOut)
          //             : '—',
          //       ),
          //     ),
          //   ],
          // ),
          const SizedBox(height: 14),
          if (!isCheckedIn && !isDone)
            _btn(
              label: busy ? 'Checking In…' : 'Check In',
              icon: Icons.login_rounded,
              color: Colors.white,
              fg: const Color(0xFF1D4ED8),
              onPressed: busy ? null : onCheckIn,
            )
          else if (isCheckedIn)
            _btn(
              label: busy ? 'Checking Out…' : 'Check Out',
              icon: Icons.logout_rounded,
              color: const Color(0xFFFCA5A5),
              fg: const Color(0xFF7F1D1D),
              onPressed: busy ? null : onCheckOut,
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '✓ Done for today',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timeBlock({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFBFDBFE),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn({
    required String label,
    required IconData icon,
    required Color color,
    required Color fg,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: fg),
        label: Text(
          label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance Calendar Card — monthly grid with day-status colors
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceCalendarCard extends StatelessWidget {
  final MonthlyArchive? archive;
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;

  const _AttendanceCalendarCard({
    required this.archive,
    required this.focusedMonth,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onMonthChanged,
  });

  /// Returns the color & label for a day based on its attendance record.
  ({Color bg, Color fg, String label}) _statusFor(DateTime day) {
    if (archive == null) {
      return (
        bg: const Color(0xFFF1F5F9),
        fg: const Color(0xFF64748B),
        label: '',
      );
    }
    final key = MonthlyArchive.dayKey(day);
    final rec = archive!.days[key];
    if (rec == null) {
      // Past day with no record = absent. Future day = neutral.
      final today = DateUtils.dateOnly(DateTime.now());
      final dayOnly = DateUtils.dateOnly(day);
      if (dayOnly.isAfter(today)) {
        return (bg: Colors.transparent, fg: const Color(0xFF64748B), label: '');
      }
      return (
        bg: const Color(0xFFF1F5F9),
        fg: const Color(0xFF64748B),
        label: '',
      );
    }

    // Has record
    final hasCheckIn = rec.checkInTime != null;
    final hasCheckOut = rec.checkOutTime != null;
    final isAbsent = rec.status.isAbsent;
    final isLeave = rec.status.isAnyLeave;

    if (isLeave) {
      return (
        bg: const Color(0xFFDBEAFE),
        fg: const Color(0xFF1E40AF),
        label: 'L',
      );
    }
    if (isAbsent) {
      return (
        bg: const Color(0xFFFEE2E2),
        fg: const Color(0xFF991B1B),
        label: 'A',
      );
    }
    if (hasCheckIn && !hasCheckOut) {
      // ← Per spec: missing checkout = RED
      return (
        bg: const Color(0xFFFEE2E2),
        fg: const Color(0xFF991B1B),
        label: '!',
      );
    }
    if (hasCheckIn && hasCheckOut) {
      return (
        bg: const Color(0xFFD1FAE5),
        fg: const Color(0xFF065F46),
        label: '✓',
      );
    }
    return (bg: Colors.transparent, fg: const Color(0xFF64748B), label: '');
  }

  @override
  Widget build(BuildContext context) {
    final selKey = archive != null ? MonthlyArchive.dayKey(selectedDay) : '';
    final selectedRec = archive?.days[selKey];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              'Attendance History',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          TableCalendar(
            firstDay: DateTime(2024, 1, 1),
            lastDay: DateTime.now().add(const Duration(days: 30)),
            focusedDay: focusedMonth,
            selectedDayPredicate: (d) => isSameDay(d, selectedDay),
            onDaySelected: (sel, foc) => onDaySelected(sel),
            onPageChanged: onMonthChanged,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            headerStyle: const HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
              titleTextStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),

            calendarBuilders: CalendarBuilders(
              defaultBuilder: (ctx, day, _) => _dayCell(day, isToday: false),
              todayBuilder: (ctx, day, _) => _dayCell(day, isToday: true),
              selectedBuilder: (ctx, day, _) => _dayCell(day, isSelected: true),
              outsideBuilder: (ctx, day, _) => _dayCell(day, faded: true),
            ),
          ),
          const SizedBox(height: 8),
          _legend(),
          const Divider(height: 16),
          _selectedDayDetails(selectedDay, selectedRec),
          if (archive != null) ...[
            const SizedBox(height: 8),
            _statsRow(archive!),
          ],
        ],
      ),
    );
  }

  Widget _dayCell(
    DateTime day, {
    bool isToday = false,
    bool isSelected = false,
    bool faded = false,
  }) {
    final s = _statusFor(day);
    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2563EB) : s.bg,
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(color: const Color(0xFF2563EB), width: 1.5)
            : null,
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : faded
                  ? const Color(0xFFCBD5E1)
                  : s.fg,
            ),
          ),
          if (s.label.isNotEmpty && !isSelected)
            Positioned(
              right: 2,
              bottom: 1,
              child: Text(
                s.label,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: s.fg,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legend() {
    Widget chip(Color bg, Color fg, String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        chip(const Color(0xFFD1FAE5), const Color(0xFF065F46), '✓ Present'),
        chip(
          const Color(0xFFFEE2E2),
          const Color(0xFF991B1B),
          '! Missed checkout',
        ),
        chip(const Color(0xFFFEE2E2), const Color(0xFF991B1B), 'A Absent'),
        chip(const Color(0xFFDBEAFE), const Color(0xFF1E40AF), 'L Leave'),
      ],
    );
  }

  Widget _selectedDayDetails(DateTime day, AttendanceModel? rec) {
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(day);
    if (rec == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateStr,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'No record',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }
    final ci = rec.checkInTime;
    final co = rec.checkOutTime;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Check-in:  ${ci != null ? DateFormat('HH:mm').format(ci) : '—'}'
            '   Check-out: ${co != null ? DateFormat('HH:mm').format(co) : '—'}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
          if (rec.checkInAddress != null && rec.checkInAddress!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '📍 ${rec.checkInAddress}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _statsRow(MonthlyArchive a) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stat(
            label: 'Present',
            value: a.presentDays,
            color: const Color(0xFF065F46),
          ),
          _stat(
            label: 'Absent',
            value: a.absentDays,
            color: const Color(0xFF991B1B),
          ),
          _stat(
            label: 'Leave',
            value: a.leaveDays,
            color: const Color(0xFF1E40AF),
          ),
        ],
      ),
    );
  }

  Widget _stat({
    required String label,
    required int value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    );
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
// Location Status Banner
// ─────────────────────────────────────────────────────────────────────────────
class _LocationStatusBanner extends StatelessWidget {
  final _LocPermStatus status;
  final Future<void> Function() onTap;

  const _LocationStatusBanner({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (status == _LocPermStatus.unknown) return const SizedBox.shrink();

    final isEnabled = status == _LocPermStatus.enabled;
    final IconData icon;
    final Color bg;
    final Color border;
    final Color fg;
    final String label;
    final String? actionLabel;

    switch (status) {
      case _LocPermStatus.enabled:
        icon = Icons.check_circle_rounded;
        bg = const Color(0xFFECFDF5);
        border = const Color(0xFF6EE7B7);
        fg = const Color(0xFF065F46);
        label = 'Location enabled';
        actionLabel = null;
        break;
      case _LocPermStatus.servicesOff:
        icon = Icons.location_off_rounded;
        bg = const Color(0xFFFEF2F2);
        border = const Color(0xFFFCA5A5);
        fg = const Color(0xFF991B1B);
        label = 'Location services off — GPS is disabled on your device';
        actionLabel = 'Open Settings';
        break;
      case _LocPermStatus.permanentlyDenied:
        icon = Icons.block_rounded;
        bg = const Color(0xFFFEF2F2);
        border = const Color(0xFFFCA5A5);
        fg = const Color(0xFF991B1B);
        label = 'Location permission blocked — open app settings to enable';
        actionLabel = 'Open Settings';
        break;
      case _LocPermStatus.denied:
        icon = Icons.location_disabled_rounded;
        bg = const Color(0xFFFFFBEB);
        border = const Color(0xFFFCD34D);
        fg = const Color(0xFF92400E);
        label = 'Location permission needed for attendance check-in';
        actionLabel = 'Enable';
        break;
      case _LocPermStatus.unknown:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: isEnabled ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
              if (actionLabel != null) ...[
                const SizedBox(width: 8),
                Text(
                  actionLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: fg, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
