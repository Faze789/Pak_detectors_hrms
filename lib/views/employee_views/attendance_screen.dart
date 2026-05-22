// lib/screens/attendance/attendance_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hrms_app/viewmodels/leave_approvals_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/attendance_model.dart';
import '../../models/leave_model.dart';
import '../../models/leave_policy.dart';
import '../../viewmodels/attendance_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/request_leave_sheet.dart';
import 'my_leave_requests_screen.dart';

// ─── Responsive breakpoints ───────────────────────────────────────────────────
abstract class _BP {
  static const double mobile = 500;
  static const double tablet = 900;
}

// ─── Formatters ───────────────────────────────────────────────────────────────
String _fmtClock(DateTime dt) => DateFormat('HH:mm:ss').format(dt);
String _fmtDate(DateTime dt) => DateFormat('EEEE, MMMM d, yyyy').format(dt);
String _fmtShortTime(DateTime dt) => DateFormat('HH:mm').format(dt);
String _fmtMonoTime(DateTime dt) => DateFormat('HH:mm:ss').format(dt);
String _fmtShortDate(DateTime dt) => DateFormat('MMM d').format(dt);

String _hms(int secs) {
  final h = (secs ~/ 3600).toString().padLeft(2, '0');
  final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
  final s = (secs % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

String _shortDur(int secs) {
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

// ══════════════════════════════════════════════════════════════════════════════
// Screen
// ══════════════════════════════════════════════════════════════════════════════
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with WidgetsBindingObserver {
  late final Timer _clockTimer;
  DateTime _now = DateTime.now();
  DateTime _lastReloadDay = DateTime.now();
  // Hides the attendance card behind a "Mark My Attendance" CTA until
  // the user taps. Auto-reveals if there's already a record for today.
  bool _attendanceRevealed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final newNow = DateTime.now();
      // Daily rollover: if the calendar day flipped while the screen was
      // open (e.g. user kept the app on overnight), force a fresh
      // loadToday so vm.todayAttendance is repopulated for the new day
      // instead of carrying yesterday's record forward and tripping
      // "Day complete" the moment they open it.
      // ── AFTER ────────────────────────────────────────────────────────────
      if (!DateTimeUtils.isSameDay(_lastReloadDay, newNow)) {
        _lastReloadDay = newNow;
        // Clear revealed flag so tomorrow starts from the CTA, not
        // a stale card left over from yesterday's session.
        setState(() => _attendanceRevealed = false);
        final uid = context.read<AuthViewModel>().currentUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          context.read<AttendanceViewModel>().loadToday(uid);
        }
      }
      // ── END AFTER ────────────────────────────────────────────────────────
      setState(() => _now = newNow);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthViewModel>().currentUser?.uid;
      if (uid != null) context.read<AttendanceViewModel>().loadToday(uid);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Re-pull today's attendance when the user comes back to the app —
    // this catches the overnight-open case AND any scenario where the
    // backend changed the record while the app was backgrounded.
    if (state == AppLifecycleState.resumed && mounted) {
      final uid = context.read<AuthViewModel>().currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        _lastReloadDay = DateTime.now();
        context.read<AttendanceViewModel>().loadToday(uid);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer.cancel();
    super.dispose();
  }

  /// Returns the number of weekdays (Monday–Friday) between [start] and [end] inclusive.
  int _countWeekdays(DateTime start, DateTime end) {
    int count = 0;
    DateTime current = start;
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  /// Opens the leave-request bottom sheet. The sheet handles
  /// leave-type selection (gender-aware), date range, optional reason,
  /// and a "Read policy" button. We only run the submission flow here.
  Future<void> _onRequestLeaveTap(
    BuildContext context,
    AttendanceViewModel vm,
  ) async {
    final auth = context.read<AuthViewModel>();
    final uid = auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    // Fetch the employee's gender so the leave-type dropdown can show /
    // hide Maternity / Paternity correctly. Falls back to null on any
    // error (Maternity/Paternity then hidden, Custom still available).
    String? gender;
    try {
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final raw = userSnap.data()?['gender'];
      if (raw is String && raw.trim().isNotEmpty) {
        gender = raw.trim().toLowerCase();
      }
    } catch (_) {/* ignore — gender stays null */}

    if (!mounted) return;
    final result = await showRequestLeaveSheet(context, gender: gender);
    if (result == null || !mounted) return;

    if (result.workingDays > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You can only request up to 4 working days of leave at a time.',
          ),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      await vm.submitLeaveRequest(
        uid,
        result.dateRange.start,
        result.dateRange.end,
        result.workingDays,
        leaveType: result.type.value,
        leaveTypeLabel: result.type.label,
        reason: result.reason,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.type.label} request for ${result.workingDays} '
            'working day(s) sent successfully.',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send request: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  /// Called when the user taps "Mark My Attendance".
  Future<void> _onMarkAttendanceTap() async {
    final granted = await _ensureLocationReady();
    if (!mounted) return;
    if (!granted) return;
    setState(() => _attendanceRevealed = true);
  }

  Future<void> _onCheckOut(AttendanceViewModel vm, String uid) async {
    await vm.checkOut(uid);
    if (mounted && vm.errorMessage == null) {
      setState(() => _attendanceRevealed = false);
    }
  }

  /// Returns true if GPS is on AND permission is granted
  Future<bool> _ensureLocationReady() async {
    // 1. GPS hardware on?
    final servicesOn = await Geolocator.isLocationServiceEnabled();
    if (!servicesOn) {
      if (!mounted) return false;
      await _showLocationDialog(
        title: 'Turn On Location',
        body:
            'GPS is off on this device. Attendance check-in needs your '
            'location to verify you\'re at the office. Open settings to '
            'turn it on.',
        actionLabel: 'Open Location Settings',
        onAction: Geolocator.openLocationSettings,
      );
      return false;
    }

    // 2. App-level permission?
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      if (!mounted) return false;
      await _showLocationDialog(
        title: 'Location Permission Blocked',
        body:
            'You\'ve previously denied location for this app. Open the '
            'app settings to enable it manually.',
        actionLabel: 'Open App Settings',
        onAction: Geolocator.openAppSettings,
      );
      return false;
    }
    if (perm != LocationPermission.always &&
        perm != LocationPermission.whileInUse) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required to check in.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _showLocationDialog({
    required String title,
    required String body,
    required String actionLabel,
    required Future<bool> Function() onAction,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(
          Icons.location_on_rounded,
          color: Color(0xFF2563EB),
          size: 36,
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Text(body, style: const TextStyle(fontSize: 13, height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await onAction();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  // ── Status badge config ───────────────────────────────────────────────────
  _StatusCfg _statusCfg(AttendanceViewModel vm) {
    if (vm.isWeekend) {
      return const _StatusCfg(
        'Weekend',
        Color(0xFF0369A1),
        Color(0xFFE0F2FE),
        Color(0xFF0EA5E9),
      );
    }
    if (vm.holidayName != null) {
      return const _StatusCfg(
        'Holiday',
        Color(0xFF92400E),
        Color(0xFFFEF3C7),
        Color(0xFFF59E0B),
      );
    }
    switch (vm.dailyStatus) {
      case AttendanceStatus.onLeave:
        return const _StatusCfg(
          'On Leave',
          Color(0xFF6D28D9),
          Color(0xFFEDE9FE),
          Color(0xFF7C3AED),
        );
      case AttendanceStatus.firstHalfLeave:
        return const _StatusCfg(
          '½ AM Leave',
          Color(0xFF6D28D9),
          Color(0xFFF5F3FF),
          Color(0xFF7C3AED),
        );
      case AttendanceStatus.secondHalfLeave:
        return const _StatusCfg(
          '½ PM Leave',
          Color(0xFF0E7490),
          Color(0xFFECFEFF),
          Color(0xFF0891B2),
        );
      case AttendanceStatus.absent:
        return const _StatusCfg(
          'Absent',
          Color(0xFF991B1B),
          Color(0xFFFEF2F2),
          Color(0xFFEF4444),
        );
      case AttendanceStatus.late:
        return const _StatusCfg(
          'Late',
          Color(0xFF92400E),
          Color(0xFFFEF3C7),
          Color(0xFFF59E0B),
        );
      default:
        if (!vm.checkedIn) {
          return const _StatusCfg(
            'Offline',
            Color(0xFF64748B),
            Color(0xFFF1F5F9),
            Color(0xFF94A3B8),
          );
        }
        return const _StatusCfg(
          'Active',
          Color(0xFF065F46),
          Color(0xFFECFDF5),
          Color(0xFF10B981),
        );
    }
  }

  // ── Main card dispatcher ──────────────────────────────────────────────────
  Widget _buildMainCard(AttendanceViewModel vm, String uid) {
    if (vm.isWeekend) return const _WeekendCard();
    if (vm.holidayName != null) return _HolidayCard(name: vm.holidayName!);

    if (vm.todayAttendance == null) {
      return _MainCard(
        vm: vm,
        cfg: _statusCfg(vm),
        onCheckIn: () => vm.checkIn(uid),
        onCheckOut: () => _onCheckOut(vm, uid),
      );
    }

    switch (vm.dailyStatus) {
      case AttendanceStatus.absent:
        return const _AbsentCard();

      case AttendanceStatus.onLeave:
        return _OnLeaveCard(leave: vm.todayLeave);

      case AttendanceStatus.firstHalfLeave:
        if (vm.checkedIn) {
          return _MainCard(
            vm: vm,
            cfg: _statusCfg(vm),
            onCheckIn: () => vm.checkIn(uid),
            onCheckOut: () => _onCheckOut(vm, uid), // ← and this line
          );
        }
        return _HalfDayLeaveCard(
          isFirstHalf: true,
          leave: vm.todayLeave,
          halfDayMarkLabel: vm.halfDayMarkLabel,
        );

      case AttendanceStatus.secondHalfLeave:
        if (vm.checkedIn) {
          return _MainCard(
            vm: vm,
            cfg: _statusCfg(vm),
            onCheckIn: () => vm.checkIn(uid),
            onCheckOut: () => _onCheckOut(vm, uid),
          );
        }
        return _HalfDayLeaveCard(
          isFirstHalf: false,
          leave: vm.todayLeave,
          halfDayMarkLabel: vm.halfDayMarkLabel,
        );

      default:
        return _MainCard(
          vm: vm,
          cfg: _statusCfg(vm),
          onCheckIn: () => vm.checkIn(uid),
          onCheckOut: () => _onCheckOut(vm, uid),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthViewModel>().currentUser?.uid;
    // Treat empty uid the same as null. A stale UserModel or a doc loaded
    // by id where the id field was missing can leave uid == ''. Without
    // this guard the screen renders, the Check-In button calls
    // vm.checkIn('') and the service crashes inside Firestore with the
    // unhelpful "a document path must be a non-empty string" error.
    if (uid == null || uid.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view attendance.')),
      );
    }

    return Consumer<AttendanceViewModel>(
      builder: (context, vm, _) {
        final isLoading = vm.state == ViewState.loading;
        final sw = MediaQuery.of(context).size.width;
        final hPad = sw < _BP.mobile ? 12.0 : 16.0;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    _StickyHeader(now: _now),
                    SliverToBoxAdapter(
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 8),
                          child: Row(
                            children: [
                              // 1. Request to Leave Button (Always visible)
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _onRequestLeaveTap(context, vm),
                                  icon: const Icon(
                                    Icons.edit_calendar_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Request Leave',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _showMyLeaveRequests(context, uid),
                                  icon: const Icon(
                                    Icons.history_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'My Requests',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0891B2),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                              // 2. Leave Approvals Button (Conditionally visible)
                              if (vm.isCurrentUserLead) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const LeaveApprovalsScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.fact_check_outlined,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Approvals',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F172A),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: hPad,
                        vertical: 16,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (vm.errorMessage != null &&
                              vm.errorMessage!.isNotEmpty) ...[
                            _ErrorBanner(
                              message: vm.errorMessage!,
                              onDismiss: vm.clearError,
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_attendanceRevealed || vm.todayAttendance != null)
                            _buildMainCard(vm, uid)
                          else
                            _MarkAttendanceCta(
                              onTap: () => _onMarkAttendanceTap(),
                            ),
                          const SizedBox(height: 24),
                          _MonthlyHistorySection(uid: uid),
                          const SizedBox(height: 32),
                        ]),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _showMyLeaveRequests(BuildContext context, String uid) async {
    // Push the live-streaming MyLeaveRequestsScreen instead of the older
    // one-shot bottom sheet. The new screen subscribes to
    // request_for_leave for this uid so HR decisions appear instantly,
    // and renders pending / approved / declined with proper status chips.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyLeaveRequestsScreen()),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// My Leave Requests Sheet
// ══════════════════════════════════════════════════════════════════════════════
class _MyLeaveRequestsSheet extends StatelessWidget {
  final AttendanceViewModel vm;
  const _MyLeaveRequestsSheet({required this.vm});

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

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'declined':
        return 'Declined';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = vm.myLeaveRequests;

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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFEFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: Color(0xFF0891B2),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'My Leave Requests',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: requests.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 48,
                          color: Color(0xFFCBD5E1),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No leave requests yet',
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
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final req = requests[i];
                      final status = (req['status'] ?? 'pending') as String;
                      final startTs = req['startDate'] as Timestamp?;
                      final endTs = req['endDate'] as Timestamp?;
                      final days = req['totalDays'] ?? 1;
                      final note = (req['note'] ?? '').toString();
                      final reason = (req['rejectionReason'] ?? '').toString();

                      final dateStr = startTs != null && endTs != null
                          ? days == 1
                                ? DateFormat(
                                    'EEE, MMM d yyyy',
                                  ).format(startTs.toDate())
                                : '${DateFormat('MMM d').format(startTs.toDate())}'
                                      ' – '
                                      '${DateFormat('MMM d, yyyy').format(endTs.toDate())}'
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
                                        _statusLabel(status),
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
                            if (note.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Note: $note',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            if (status == 'declined' && reason.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
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
// Sticky Header
// ══════════════════════════════════════════════════════════════════════════════
class _StickyHeader extends StatelessWidget {
  final DateTime now;
  const _StickyHeader({required this.now});

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < _BP.mobile;

    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      elevation: 1,
      toolbarHeight: isMobile ? 64 : 72,
      flexibleSpace: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 20,
          vertical: isMobile ? 8 : 10,
        ),
        child: Row(
          children: [
            // const Icon(
            //   Icons.access_time_rounded,
            //   color: Color(0xFF2563EB),
            //   size: 24,
            // ),
            // const SizedBox(width: 8),
            // Column(
            //   crossAxisAlignment: CrossAxisAlignment.start,
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   children: [
            //     const Text(
            //       'Time Clock',
            //       style: TextStyle(
            //         fontSize: 18,
            //         fontWeight: FontWeight.bold,
            //         color: Color(0xFF0F172A),
            //       ),
            //     ),
            //     if (!isMobile)
            //       const Text(
            //         'Track your work hours',
            //         style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            //       ),
            //   ],
            // ),

            // const Spacer(),
            // Column(
            //   crossAxisAlignment: CrossAxisAlignment.end,
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   children: [
            //     // if (!isMobile)
            //     //   Text(
            //     //     _fmtDate(now),
            //     //     style: const TextStyle(
            //     //       fontSize: 10,
            //     //       color: Color(0xFF64748B),
            //     //     ),
            //     //   ),
            //     Text(
            //       _fmtClock(now),
            //       style: TextStyle(
            //         fontSize: isMobile ? 15 : 18,
            //         fontWeight: FontWeight.bold,
            //         color: const Color(0xFF2563EB),
            //         fontFeatures: const [FontFeature.tabularFigures()],
            //       ),
            //     ),
            //   ],
            // ),
            const SizedBox(width: 8),

            Tooltip(
              message: 'Attendance & Leave Policy',
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const _AttendancePolicyDialog(),
                  );
                },
                icon: const Icon(Icons.fact_check_rounded, size: 20),
                label: const Text(
                  'Policy',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF334155),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Status Config
// ══════════════════════════════════════════════════════════════════════════════
class _StatusCfg {
  final String label;
  final Color fg, bg, dot;
  const _StatusCfg(this.label, this.fg, this.bg, this.dot);
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared Info Card shell
// ══════════════════════════════════════════════════════════════════════════════
class _InfoCard extends StatelessWidget {
  final Color barColor;
  final Color badgeBg, badgeFg;
  final String badgeLabel;
  final IconData badgeIcon;
  final Color iconBg, iconColor;
  final IconData icon;
  final String title, subtitle;
  final Widget? detailBox;

  const _InfoCard({
    required this.barColor,
    required this.badgeBg,
    required this.badgeFg,
    required this.badgeLabel,
    required this.badgeIcon,
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.detailBox,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < _BP.mobile;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Container(height: 6, color: barColor),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: isMobile ? 20 : 32,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 14, color: badgeFg),
                      const SizedBox(width: 6),
                      Text(
                        badgeLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: badgeFg,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isMobile ? 20 : 28),
                Container(
                  width: isMobile ? 96 : 120,
                  height: isMobile ? 96 : 120,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(isMobile ? 48 : 60),
                  ),
                  child: Icon(icon, size: isMobile ? 48 : 60, color: iconColor),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                if (detailBox != null) ...[
                  const SizedBox(height: 20),
                  detailBox!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Weekend Card
// ══════════════════════════════════════════════════════════════════════════════
class _WeekendCard extends StatelessWidget {
  const _WeekendCard();
  @override
  Widget build(BuildContext context) => _InfoCard(
    barColor: const Color(0xFF0EA5E9),
    badgeBg: const Color(0xFFE0F2FE),
    badgeFg: const Color(0xFF0369A1),
    badgeLabel: 'Weekend',
    badgeIcon: Icons.weekend_rounded,
    iconBg: const Color(0xFFE0F2FE),
    iconColor: const Color(0xFF0EA5E9),
    icon: Icons.weekend_rounded,
    title: 'Enjoy your weekend!',
    subtitle: 'No attendance tracking today.\nSee you on the next working day.',
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Holiday Card
// ══════════════════════════════════════════════════════════════════════════════
class _HolidayCard extends StatelessWidget {
  final String name;
  const _HolidayCard({required this.name});
  @override
  Widget build(BuildContext context) => _InfoCard(
    barColor: const Color(0xFFF59E0B),
    badgeBg: const Color(0xFFFEF3C7),
    badgeFg: const Color(0xFF92400E),
    badgeLabel: 'Public Holiday',
    badgeIcon: Icons.celebration_rounded,
    iconBg: const Color(0xFFFEF3C7),
    iconColor: const Color(0xFFF59E0B),
    icon: Icons.celebration_rounded,
    title: name,
    subtitle: 'No attendance tracking today.\nHave a great holiday!',
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Absent Card
// ══════════════════════════════════════════════════════════════════════════════
class _AbsentCard extends StatelessWidget {
  const _AbsentCard();
  @override
  Widget build(BuildContext context) => _InfoCard(
    barColor: const Color(0xFFEF4444),
    badgeBg: const Color(0xFFFEF2F2),
    badgeFg: const Color(0xFF991B1B),
    badgeLabel: 'Absent',
    badgeIcon: Icons.cancel_outlined,
    iconBg: const Color(0xFFFEF2F2),
    iconColor: const Color(0xFFEF4444),
    icon: Icons.person_off_rounded,
    title: 'No check-in recorded today',
    subtitle: 'You have been marked absent.\nContact HR if this is a mistake.',
    detailBox: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFEF4444)),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Absence recorded — contact HR if this is incorrect',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
            ),
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// On Leave Card
// ══════════════════════════════════════════════════════════════════════════════
class _OnLeaveCard extends StatelessWidget {
  final LeaveModel? leave;
  const _OnLeaveCard({this.leave});

  @override
  Widget build(BuildContext context) {
    Widget? detail;
    if (leave != null) {
      detail = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: Column(
          children: [
            _LeaveRow(
              icon: Icons.event_note_rounded,
              label: 'Leave type',
              value: leave!.type.label,
            ),
            const SizedBox(height: 10),
            _LeaveRow(
              icon: Icons.schedule_rounded,
              label: 'Duration',
              value: leave!.duration.label,
            ),
          ],
        ),
      );
    }

    return _InfoCard(
      barColor: const Color(0xFF7C3AED),
      badgeBg: const Color(0xFFEDE9FE),
      badgeFg: const Color(0xFF6D28D9),
      badgeLabel: 'On Leave',
      badgeIcon: Icons.beach_access_rounded,
      iconBg: const Color(0xFFEDE9FE),
      iconColor: const Color(0xFF7C3AED),
      icon: Icons.beach_access_rounded,
      title: leave?.type.label ?? 'Approved Leave',
      subtitle: 'Your leave request was accepted.\nEnjoy your day(s) off!',
      detailBox: detail,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Half Day Leave Card
// ══════════════════════════════════════════════════════════════════════════════
class _HalfDayLeaveCard extends StatelessWidget {
  final bool isFirstHalf;
  final LeaveModel? leave;
  final String halfDayMarkLabel;

  const _HalfDayLeaveCard({
    required this.isFirstHalf,
    required this.halfDayMarkLabel,
    this.leave,
  });

  @override
  Widget build(BuildContext context) {
    final color = isFirstHalf
        ? const Color(0xFF7C3AED)
        : const Color(0xFF0891B2);
    final bgColor = isFirstHalf
        ? const Color(0xFFF5F3FF)
        : const Color(0xFFECFEFF);
    final label = isFirstHalf ? 'First Half Leave' : 'Second Half Leave';
    final icon = isFirstHalf
        ? Icons.wb_sunny_outlined
        : Icons.nights_stay_outlined;
    final title = isFirstHalf
        ? 'Morning Off — Check in after $halfDayMarkLabel'
        : 'Afternoon Off — You may leave at $halfDayMarkLabel';
    final subtitle = isFirstHalf
        ? 'Your morning leave is approved.\nPlease check in after $halfDayMarkLabel.'
        : 'Your afternoon leave is approved.\nYou may check out at $halfDayMarkLabel.';

    return _InfoCard(
      barColor: color,
      badgeBg: bgColor,
      badgeFg: color,
      badgeLabel: label,
      badgeIcon: icon,
      iconBg: bgColor,
      iconColor: color,
      icon: icon,
      title: title,
      subtitle: subtitle,
      detailBox: leave != null
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  _LeaveRow(
                    icon: Icons.event_note_rounded,
                    label: 'Leave type',
                    value: leave!.type.label,
                  ),
                  const SizedBox(height: 8),
                  _LeaveRow(
                    icon: Icons.schedule_rounded,
                    label: 'Duration',
                    value: leave!.duration.label,
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class _LeaveRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  Color? valueColor;
  _LeaveRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF7C3AED)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6D28D9),
            fontWeight: FontWeight.w600,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: valueColor ?? const Color(0xFF475569),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Main Card (present / late / checked-in flow)
// ══════════════════════════════════════════════════════════════════════════════
class _MainCard extends StatelessWidget {
  final AttendanceViewModel vm;
  final _StatusCfg cfg;
  final VoidCallback onCheckIn, onCheckOut;

  const _MainCard({
    required this.vm,
    required this.cfg,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  Color get _barColor {
    if (!vm.checkedIn) return const Color(0xFFCBD5E1);
    return const Color(0xFF10B981); // Always green when checked in now
  }

  String _locationLabel() {
    final addr = vm.todayAttendance?.checkInAddress;
    if (addr != null && addr.isNotEmpty) return addr;
    final lat = vm.todayAttendance?.checkInLatitude;
    final lng = vm.todayAttendance?.checkInLongitude;
    if (lat != null && lng != null) {
      return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    }
    return 'Office - Main Building';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < _BP.mobile;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            height: 6,
            color: _barColor,
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: isMobile ? 20 : 32,
            ),
            child: Column(
              children: [
                _PulsingBadge(cfg: cfg),
                SizedBox(height: isMobile ? 20 : 28),
                if (!vm.checkedIn)
                  _buildNotCheckedIn(isMobile)
                else
                  _buildCheckedIn(isMobile),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotCheckedIn(bool isMobile) {
    final now = DateTime.now();
    final att = vm.todayAttendance;

    // (1) Same-day filter — yesterday's stale record never blocks today.
    final attIsForToday = att != null && DateTimeUtils.isSameDay(att.date, now);

    // (2) Validity filter — a "completed" record where checkInTime and
    //     checkOutTime are within 60 s is almost certainly a glitch
    //     (accidental double-tap, immediate-cleanup race, malformed
    //     archive row). Such records should NOT lock the user out:
    //     treat them as no-op and offer the Check-In button so they
    //     can start a clean cycle today.
    bool isValidCompletedCycle(AttendanceModel a) {
      final ci = a.checkInTime;
      final co = a.checkOutTime;
      if (ci == null || co == null) return false;
      return co.difference(ci).inSeconds > 60;
    }

    final hasValidCheckOut = attIsForToday && isValidCompletedCycle(att);
    final statusCheckedOut =
        attIsForToday &&
        vm.dailyStatus == AttendanceStatus.checkedOut &&
        isValidCompletedCycle(att);
    final completedToday = hasValidCheckOut || statusCheckedOut;

    // Honor HR-defined work-hour override for the check-in window's lower
    // bound. With no override, check-in opens at 8 AM (1 hour before the
    // default 9 AM start). With an override, check-in opens STRICTLY at
    // override.workStart — HR set a specific time, we enforce it (no
    // 1-hour grace). The upper bound (pastWindowClose) is already
    // override-aware via vm.isPastDailyCutoffSync.
    final ov = vm.activeOverride;
    final beforeOpening = ov != null
        ? (now.hour < ov.workStartHour ||
              (now.hour == ov.workStartHour && now.minute < ov.workStartMinute))
        : now.hour < 8;

    // Approved leave for today blocks check-in entirely (full-day leave
    // is the most common case; first/second-half are handled inline by
    // the regular check-in flow because the user still works half the day).
    final onLeaveToday = attIsForToday &&
        att.status.isAnyLeave &&
        att.status != AttendanceStatus.firstHalfLeave &&
        att.status != AttendanceStatus.secondHalfLeave;

    final pastWindowClose = vm.isPastDailyCutoffSync(now);
    final hideCheckIn =
        onLeaveToday || completedToday || beforeOpening || pastWindowClose;
    if (hideCheckIn) {
      final reason = onLeaveToday
          ? _CheckInClosedReason.onLeave
          : completedToday
              ? _CheckInClosedReason.completed
              : pastWindowClose
                  ? _CheckInClosedReason.windowClosed
                  : _CheckInClosedReason.beforeWindow;
      final opensAtLabel = ov != null
          ? _fmtAmPm(ov.workStartHour, ov.workStartMinute)
          : '8:00 AM';
      final closesAtLabel = ov != null
          ? _fmtAmPm(ov.workEndHour, ov.workEndMinute + 30)
          : '6:30 PM';
      return _CheckInClosed(
        isMobile: isMobile,
        reason: reason,
        forDate: _attendanceDateForBadge(now),
        opensAtLabel: opensAtLabel,
        closesAtLabel: closesAtLabel,
      );
    }
    return Column(
      children: [
        _AttendanceDateChip(
          forDate: _attendanceDateForBadge(now),
          prefix: 'Checking in for',
        ),
        SizedBox(height: isMobile ? 14 : 18),
        Container(
          width: isMobile ? 96 : 120,
          height: isMobile ? 96 : 120,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDBEAFE), Color(0xFFEDE9FE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(isMobile ? 48 : 60),
          ),
          child: Icon(
            Icons.access_time_rounded,
            size: isMobile ? 48 : 60,
            color: const Color(0xFF2563EB),
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        Text(
          'Ready to start your day?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tap below to check in and begin tracking',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        ),
        SizedBox(height: isMobile ? 20 : 28),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextButton.icon(
              onPressed: onCheckIn,
              icon: const Icon(
                Icons.login_rounded,
                color: Colors.white,
                size: 20,
              ),
              label: const Text(
                'Check In',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: const [
            _IconLabel(Icons.location_on_outlined, 'Office - Main Building'),
            _IconLabel(Icons.wifi_rounded, 'Connected'),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckedIn(bool isMobile) {
    final dateAnchor = vm.todayAttendance?.checkInTime ?? DateTime.now();
    return Column(
      children: [
        _AttendanceDateChip(
          forDate: _attendanceDateForBadge(dateAnchor),
          prefix: 'Checked in for',
        ),
        SizedBox(height: isMobile ? 12 : 16),
        // Static "Checked In" Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 56,
                color: Color(0xFF10B981),
              ),
              const SizedBox(height: 12),
              const Text(
                'Checked In',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF065F46),
                ),
              ),
              const SizedBox(height: 6),
              if (vm.todayAttendance?.checkInTime != null)
                Text(
                  'Time: ${_fmtShortTime(vm.todayAttendance!.checkInTime!)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF047857),
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: vm.isLate
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  vm.isLate ? 'Status: Late' : 'Status: On Time',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: vm.isLate
                        ? const Color(0xFFB45309)
                        : const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Builder(
          builder: (_) {
            final now = DateTime.now();
            // Honors HR-defined work-hour override for the signed-in user.
            final pastCheckoutCutoff = vm.isPastDailyCutoffSync(now);
            final closedLabel = vm.activeOverride != null
                ? 'Check Out Closed (${_fmtAmPm(vm.activeOverride!.workEndHour, vm.activeOverride!.workEndMinute + 30)})'
                : 'Check Out Closed (6:30 PM)';
            return SizedBox(
              width: double.infinity,
              child: _ActionButton(
                label: pastCheckoutCutoff ? closedLabel : 'Check Out',
                icon: pastCheckoutCutoff
                    ? Icons.lock_clock_rounded
                    : Icons.logout_rounded,
                gradient: pastCheckoutCutoff
                    ? const [Color(0xFF94A3B8), Color(0xFF64748B)]
                    : const [Color(0xFFDC2626), Color(0xFFB91C1C)],
                onTap: pastCheckoutCutoff ? null : onCheckOut,
              ),
            );
          },
        ),

        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    _locationLabel(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'Working',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
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

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback? onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  );
}

enum _CheckInClosedReason { completed, beforeWindow, windowClosed, onLeave }

String _fmtAmPm(int hour, int minute) {
  int h = hour;
  int m = minute;
  // Normalize a possibly-overflowed minute (e.g. 18 + 30 = 48 m means +1 h, 18 → 19)
  h += m ~/ 60;
  m = m % 60;
  final period = h >= 12 ? 'PM' : 'AM';
  final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$displayHour:${m.toString().padLeft(2, '0')} $period';
}

String _attendanceDateForBadge(DateTime when) {
  const months = [
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
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final wd = weekdays[when.weekday - 1];
  final mo = months[when.month - 1];
  return '$wd, ${when.day} $mo ${when.year}';
}

class _AttendanceDateChip extends StatelessWidget {
  final String forDate;
  final String? prefix;
  const _AttendanceDateChip({required this.forDate, this.prefix});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            size: 12,
            color: Color(0xFF2563EB),
          ),
          const SizedBox(width: 6),
          Text(
            '${prefix ?? "For"} $forDate',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1D4ED8),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInClosed extends StatelessWidget {
  final bool isMobile;
  final _CheckInClosedReason reason;
  final String forDate;
  final String opensAtLabel;
  final String closesAtLabel;
  const _CheckInClosed({
    required this.isMobile,
    required this.reason,
    required this.forDate,
    this.opensAtLabel = '8:00 AM', // fallback = global default
    this.closesAtLabel = '6:30 PM',
  });

  @override
  Widget build(BuildContext context) {
    final (
      IconData icon,
      Color iconColor,
      String title,
      String sub,
    ) = switch (reason) {
      _CheckInClosedReason.completed => (
        Icons.task_alt_rounded,
        const Color(0xFF059669),
        'Day complete',
        'You\'ve already checked in and checked out for this date.\n'
            'Check-in re-opens tomorrow at $opensAtLabel.', // ← dynamic
      ),
      _CheckInClosedReason.beforeWindow => (
        Icons.bedtime_outlined,
        const Color(0xFF7C3AED),
        'Check-in opens at $opensAtLabel', // ← dynamic
        'You can check in once the daily window opens.',
      ),
      _CheckInClosedReason.windowClosed => (
        Icons.lock_clock_rounded,
        const Color(0xFFDC2626),
        'Check-in window closed',
        'Daily check-in closes at $closesAtLabel. Today has been recorded.\n' // ← dynamic
            'Check-in re-opens tomorrow at $opensAtLabel.', // ← dynamic
      ),
      _CheckInClosedReason.onLeave => (
        Icons.beach_access_rounded,
        const Color(0xFF7C3AED),
        'On approved leave',
        "Today is on your approved leave. Check-in / check-out are\n"
            "disabled and no penalty applies. Enjoy your day off.",
      ),
    };
    return Column(
      children: [
        _AttendanceDateChip(forDate: forDate),
        SizedBox(height: isMobile ? 14 : 18),
        Container(
          width: isMobile ? 96 : 120,
          height: isMobile ? 96 : 120,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(isMobile ? 48 : 60),
          ),
          child: Icon(icon, size: isMobile ? 44 : 56, color: iconColor),
        ),
        SizedBox(height: isMobile ? 14 : 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(icon, size: 32, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.red.shade200),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: Colors.red.shade700, fontSize: 13),
          ),
        ),
        GestureDetector(
          onTap: onDismiss,
          child: Icon(
            Icons.close_rounded,
            color: Colors.red.shade400,
            size: 18,
          ),
        ),
      ],
    ),
  );
}

class _IconLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconLabel(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      ),
    ],
  );
}

class _PulsingBadge extends StatefulWidget {
  final _StatusCfg cfg;
  const _PulsingBadge({required this.cfg});
  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
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
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: widget.cfg.bg,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _anim,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.cfg.dot,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          widget.cfg.label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: widget.cfg.fg,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// "Mark My Attendance" CTA
// ─────────────────────────────────────────────────────────────────────────────
class _MarkAttendanceCta extends StatelessWidget {
  final VoidCallback onTap;
  const _MarkAttendanceCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.fingerprint_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Mark Your Attendance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Tap to check in for today and view your attendance details.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFDBEAFE),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(
                Icons.login_rounded,
                size: 18,
                color: Color(0xFF1D4ED8),
              ),
              label: const Text(
                'Mark My Attendance',
                style: TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Monthly attendance history section.
// ─────────────────────────────────────────────────────────────────────────────
class _MonthlyHistorySection extends StatefulWidget {
  final String uid;
  const _MonthlyHistorySection({required this.uid});

  @override
  State<_MonthlyHistorySection> createState() => _MonthlyHistorySectionState();
}

class _MonthlyHistorySectionState extends State<_MonthlyHistorySection> {
  late DateTime _selectedMonth;
  bool _loading = false;
  MonthlyArchive? _archive;

  static const _monthLabels = [
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(_selectedMonth));
  }

  Future<void> _load(DateTime month) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final vm = context.read<AttendanceViewModel>();
      final archive = await vm.getMonthlyArchiveSilent(
        widget.uid,
        month.year,
        month.month,
      );
      if (!mounted) return;
      setState(() {
        _archive = archive;
        _selectedMonth = month;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _archive = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DateTime> get _months {
    final now = DateTime.now();
    return List.generate(12, (i) {
      final m = now.month - i;
      final yShift = (m - 1) ~/ 12;
      final monthMod = ((m - 1) % 12 + 12) % 12 + 1;
      return DateTime(now.year + yShift, monthMod, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attendance History',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap a month to see your stats',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _months.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final m = _months[i];
                final selected =
                    m.year == _selectedMonth.year &&
                    m.month == _selectedMonth.month;
                return GestureDetector(
                  onTap: () => _load(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 64,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _monthLabels[m.month - 1],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          m.year.toString(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? const Color(0xFFBFDBFE)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _MonthlyStatsPanel(month: _selectedMonth, archive: _archive),
            if (_archive != null && _archive!.days.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Daily Records',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              _MonthlyRecordsList(archive: _archive!),
            ],
          ],
        ],
      ),
    );
  }
}

class _MonthlyStatsPanel extends StatelessWidget {
  final DateTime month;
  final MonthlyArchive? archive;
  const _MonthlyStatsPanel({required this.month, required this.archive});

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(month);
    final present = archive?.presentDays ?? 0;
    final absent = archive?.absentDays ?? 0;
    final leave = archive?.leaveDays ?? 0;
    final total = archive?.totalDays ?? 0;
    final late =
        archive?.days.values
            .where((d) => d.status == AttendanceStatus.late)
            .length ??
        0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 16,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 6),
              Text(
                monthLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                '$total records',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (archive == null || total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No attendance records for this month yet.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Present',
                    value: present,
                    color: const Color(0xFF10B981),
                    bg: const Color(0xFFD1FAE5),
                    icon: Icons.check_circle_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    label: 'Absent',
                    value: absent,
                    color: const Color(0xFFEF4444),
                    bg: const Color(0xFFFEE2E2),
                    icon: Icons.cancel_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    label: 'Leave',
                    value: leave,
                    color: const Color(0xFF3B82F6),
                    bg: const Color(0xFFDBEAFE),
                    icon: Icons.beach_access_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    label: 'Late',
                    value: late,
                    color: const Color(0xFFF59E0B),
                    bg: const Color(0xFFFEF3C7),
                    icon: Icons.schedule_rounded,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final Color bg;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Detailed Monthly Records List
// ══════════════════════════════════════════════════════════════════════════════
class _MonthlyRecordsList extends StatelessWidget {
  final MonthlyArchive archive;
  const _MonthlyRecordsList({required this.archive});

  @override
  Widget build(BuildContext context) {
    // Sort days descending (newest at the top)
    final days = archive.days.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView.separated(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(), // Let the main scroll view handle scrolling
      itemCount: days.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final record = days[index];
        return _DailyRecordTile(record: record);
      },
    );
  }
}

class _DailyRecordTile extends StatelessWidget {
  final AttendanceModel record;
  const _DailyRecordTile({required this.record});

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.checkedIn:
      case AttendanceStatus.checkedOut:
        return const Color(0xFF10B981); // Green for present
      case AttendanceStatus.late:
        return const Color(0xFFF59E0B); // Amber for late
      case AttendanceStatus.absent:
        return const Color(0xFFEF4444); // Red for absent
      case AttendanceStatus.onLeave:
      case AttendanceStatus.firstHalfLeave:
      case AttendanceStatus.secondHalfLeave:
        return const Color(0xFF8B5CF6); // Purple for leave
      default:
        return const Color(0xFF64748B); // Slate for others
    }
  }

  String _formatStatus(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.checkedIn:
        return 'Present';
      case AttendanceStatus.checkedOut:
        return 'Present';
      case AttendanceStatus.firstHalfLeave:
        return '½ AM Leave';
      case AttendanceStatus.secondHalfLeave:
        return '½ PM Leave';
      case AttendanceStatus.onLeave:
        return 'On Leave';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.absent:
        return 'Absent';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(record.status);
    final statusLabel = _formatStatus(record.status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Date Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('dd').format(record.date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  DateFormat('EEE').format(record.date),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Times & Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.login_rounded,
                      size: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      record.checkInTime != null
                          ? _fmtShortTime(record.checkInTime!)
                          : '--:--',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.logout_rounded,
                      size: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      record.checkOutTime != null
                          ? _fmtShortTime(record.checkOutTime!)
                          : '--:--',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Total Hours (if checked out)
          if (record.checkInTime != null && record.checkOutTime != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Worked',
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
                Text(
                  _shortDur(
                    record.totalWorkSeconds ??
                        record.checkOutTime!
                            .difference(record.checkInTime!)
                            .inSeconds,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// Drop this class anywhere in your attendance_screen.dart file
class _AttendancePolicyDialog extends StatelessWidget {
  const _AttendancePolicyDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.rule_rounded,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Attendance Policy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildPolicySection(
              title: 'Late Check-In',
              icon: Icons.login_rounded,
              rules: [
                'Up to 9:15 AM: 15% daily salary deduction',
                'After 10:00 AM: 50% daily salary deduction',
              ],
            ),
            const SizedBox(height: 16),
            _buildPolicySection(
              title: 'Early Check-Out',
              icon: Icons.logout_rounded,
              rules: [
                'Between 5:00 PM & shift end: 25% daily salary deduction',
                'Before 5:00 PM: 50% daily salary deduction',
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Understood',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection({
    required String title,
    required IconData icon,
    required List<String> rules,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...rules.map(
          (rule) => Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Color(0xFF94A3B8))),
                Expanded(
                  child: Text(
                    rule,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
