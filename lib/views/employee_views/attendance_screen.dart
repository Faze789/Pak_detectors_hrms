// lib/screens/attendance/attendance_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/attendance_model.dart';
import '../../models/leave_model.dart';
import '../../viewmodels/attendance_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

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

class _AttendanceScreenState extends State<AttendanceScreen> {
  late final Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthViewModel>().currentUser?.uid;
      if (uid != null) context.read<AttendanceViewModel>().loadToday(uid);
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
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
        if (vm.onBreak) {
          return const _StatusCfg(
            'On Break',
            Color(0xFFB45309),
            Color(0xFFFFFBEB),
            Color(0xFFF59E0B),
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
  //
  // FIX: null todayAttendance means no record yet — show check-in prompt.
  // _AbsentCard is ONLY shown when the record explicitly has absent status.
  // Previously dailyStatus returned absent when todayAttendance was null,
  // causing the absent card to show all morning before noon.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMainCard(AttendanceViewModel vm, String uid) {
    if (vm.isWeekend) return const _WeekendCard();
    if (vm.holidayName != null) return _HolidayCard(name: vm.holidayName!);

    // No record yet — show check-in prompt regardless of time
    if (vm.todayAttendance == null) {
      return _MainCard(
        vm: vm,
        cfg: _statusCfg(vm),
        onCheckIn: () => vm.checkIn(uid),
        onCheckOut: () => vm.checkOut(uid),
        onStartBreak: () => vm.startBreak(uid),
        onEndBreak: () => vm.endBreak(uid),
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
            onCheckOut: () => vm.checkOut(uid),
            onStartBreak: () => vm.startBreak(uid),
            onEndBreak: () => vm.endBreak(uid),
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
            onCheckOut: () => vm.checkOut(uid),
            onStartBreak: () => vm.startBreak(uid),
            onEndBreak: () => vm.endBreak(uid),
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
          onCheckOut: () => vm.checkOut(uid),
          onStartBreak: () => vm.startBreak(uid),
          onEndBreak: () => vm.endBreak(uid),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthViewModel>().currentUser?.uid;
    if (uid == null) {
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
                          _buildMainCard(vm, uid),
                          const SizedBox(height: 16),
                          _StatsGrid(vm: vm),
                          const SizedBox(height: 16),
                          _ActivityLog(vm: vm),
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
      flexibleSpace: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 20,
            vertical: isMobile ? 8 : 10,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                color: Color(0xFF2563EB),
                size: 24,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Time Clock',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (!isMobile)
                    const Text(
                      'Track your work hours and breaks',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMobile)
                    Text(
                      _fmtDate(now),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  Text(
                    _fmtClock(now),
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2563EB),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
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
      subtitle: 'Your leave has been approved by HR.\nEnjoy your time off!',
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
  final VoidCallback onCheckIn, onCheckOut, onStartBreak, onEndBreak;

  const _MainCard({
    required this.vm,
    required this.cfg,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onStartBreak,
    required this.onEndBreak,
  });

  Color get _barColor {
    if (!vm.checkedIn) return const Color(0xFFCBD5E1);
    return vm.onBreak ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
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
    return Column(
      children: [
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
    return Column(
      children: [
        _TimerBox(
          gradient: const LinearGradient(
            colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
          ),
          border: const Color(0xFFBFDBFE),
          header: vm.todayAttendance?.checkInTime != null
              ? 'Checked in at ${_fmtShortTime(vm.todayAttendance!.checkInTime!)}'
              : 'Checked in',
          headerIcon: Icons.check_circle_outline_rounded,
          headerIconColor: const Color(0xFF10B981),
          timerText: _hms(vm.workSeconds),
          timerColor: const Color(0xFF0F172A),
          timerSize: isMobile ? 42 : 52,
          sub: 'Total Work Time',
        ),
        const SizedBox(height: 14),
        if (vm.onBreak) ...[
          _TimerBox(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFBEB), Color(0xFFFFF7ED)],
            ),
            border: const Color(0xFFFCD34D),
            header: 'On break',
            headerIcon: Icons.pause_rounded,
            headerIconColor: const Color(0xFFB45309),
            timerText: _hms(vm.breakSeconds),
            timerColor: const Color(0xFF78350F),
            timerSize: isMobile ? 28 : 36,
            sub: 'Break Duration',
          ),
          const SizedBox(height: 14),
        ],
        if (vm.breaks.isNotEmpty) ...[
          _BreakLog(breaks: vm.breaks),
          const SizedBox(height: 14),
        ],
        isMobile
            ? Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: vm.onBreak
                        ? _ActionButton(
                            label: 'End Break',
                            icon: Icons.play_arrow_rounded,
                            gradient: const [
                              Color(0xFF2563EB),
                              Color(0xFF1D4ED8),
                            ],
                            onTap: onEndBreak,
                          )
                        : _OutlinedActionButton(
                            label: 'Start Break',
                            icon: Icons.pause_rounded,
                            color: const Color(0xFFB45309),
                            borderColor: const Color(0xFFFCD34D),
                            onTap: onStartBreak,
                          ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: _ActionButton(
                      label: 'Check Out',
                      icon: Icons.logout_rounded,
                      gradient: const [Color(0xFFDC2626), Color(0xFFB91C1C)],
                      onTap: onCheckOut,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: vm.onBreak
                        ? _ActionButton(
                            label: 'End Break',
                            icon: Icons.play_arrow_rounded,
                            gradient: const [
                              Color(0xFF2563EB),
                              Color(0xFF1D4ED8),
                            ],
                            onTap: onEndBreak,
                          )
                        : _OutlinedActionButton(
                            label: 'Start Break',
                            icon: Icons.pause_rounded,
                            color: const Color(0xFFB45309),
                            borderColor: const Color(0xFFFCD34D),
                            onTap: onStartBreak,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      label: 'Check Out',
                      icon: Icons.logout_rounded,
                      gradient: const [Color(0xFFDC2626), Color(0xFFB91C1C)],
                      onTap: onCheckOut,
                    ),
                  ),
                ],
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
                  decoration: BoxDecoration(
                    color: vm.onBreak
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  vm.onBreak ? 'On Break' : 'Working',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: vm.onBreak
                        ? const Color(0xFFB45309)
                        : const Color(0xFF10B981),
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

// ══════════════════════════════════════════════════════════════════════════════
// Stats Grid
// ══════════════════════════════════════════════════════════════════════════════
class _StatsGrid extends StatelessWidget {
  final AttendanceViewModel vm;
  const _StatsGrid({required this.vm});

  String _statusValue() {
    if (vm.isWeekend) return 'Weekend';
    if (vm.holidayName != null) return 'Holiday';
    if (vm.todayAttendance == null) return 'Offline';
    switch (vm.dailyStatus) {
      case AttendanceStatus.onLeave:
        return 'On Leave';
      case AttendanceStatus.firstHalfLeave:
        return '½ AM Leave';
      case AttendanceStatus.secondHalfLeave:
        return '½ PM Leave';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return vm.checkedIn ? 'Late' : 'Late (out)';
      default:
        return vm.checkedIn ? (vm.onBreak ? 'On Break' : 'Active') : 'Offline';
    }
  }

  String _statusSub() {
    if (vm.isWeekend) return 'Rest day';
    if (vm.holidayName != null) return 'Public holiday';
    if (vm.todayAttendance == null) return 'Not clocked in yet';
    switch (vm.dailyStatus) {
      case AttendanceStatus.onLeave:
        return 'HR-approved leave';
      case AttendanceStatus.firstHalfLeave:
        return 'Morning leave approved';
      case AttendanceStatus.secondHalfLeave:
        return 'Afternoon leave approved';
      case AttendanceStatus.absent:
        return 'No check-in today';
      case AttendanceStatus.late:
        return 'Arrived after start time';
      default:
        return vm.checkedIn ? 'Currently working' : 'Not clocked in';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isWide = sw >= _BP.tablet;

    final productivityLabel = vm.productivity >= 90
        ? 'Excellent'
        : vm.productivity >= 70
        ? 'Good'
        : 'Fair';

    final cards = [
      _StatCard(
        label: 'Work Time',
        value: _shortDur(vm.workSeconds),
        sub: '${(vm.workSeconds % 60).toString().padLeft(2, '0')}s',
        icon: Icons.timer_rounded,
        iconColor: const Color(0xFF2563EB),
        iconBg: const Color(0xFFDBEAFE),
        accentColor: const Color(0xFF2563EB),
      ),
      _StatCard(
        label: 'Break Time',
        value: _shortDur(vm.breakSeconds),
        sub: '${(vm.breakSeconds % 60).toString().padLeft(2, '0')}s',
        icon: Icons.pause_circle_outline_rounded,
        iconColor: const Color(0xFFD97706),
        iconBg: const Color(0xFFFEF3C7),
        accentColor: const Color(0xFFF59E0B),
      ),
      _StatCard(
        label: 'Productivity',
        value: '${vm.productivity}%',
        sub: productivityLabel,
        subColor: const Color(0xFF10B981),
        icon: Icons.bar_chart_rounded,
        iconColor: const Color(0xFF059669),
        iconBg: const Color(0xFFD1FAE5),
        accentColor: const Color(0xFF10B981),
      ),
      _StatCard(
        label: 'Status',
        value: _statusValue(),
        sub: _statusSub(),
        icon: Icons.bolt_rounded,
        iconColor: const Color(0xFF7C3AED),
        iconBg: const Color(0xFFEDE9FE),
        accentColor: const Color(0xFF7C3AED),
      ),
    ];

    if (isWide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      );
    }
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 12),
              Expanded(child: cards[3]),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final Color? subColor;
  final IconData icon;
  final Color iconColor, iconBg, accentColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    this.subColor,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accentColor, width: 4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (subColor != null) ...[
                          Icon(
                            Icons.trending_up_rounded,
                            size: 12,
                            color: subColor,
                          ),
                          const SizedBox(width: 2),
                        ],
                        Flexible(
                          child: Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: subColor ?? const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Activity Log
// ══════════════════════════════════════════════════════════════════════════════
class _ActivityLog extends StatelessWidget {
  final AttendanceViewModel vm;
  const _ActivityLog({required this.vm});

  List<_LogEntry> _buildEntries() {
    final record = vm.todayAttendance;
    final entries = <_LogEntry>[];
    if (record == null) return entries;
    if (record.checkInTime != null) {
      entries.add(
        _LogEntry(
          type: 'check-in',
          time: record.checkInTime!,
          location: record.checkInAddress ?? 'Office - Main Building',
        ),
      );
    }
    for (final b in record.breaks) {
      entries.add(_LogEntry(type: 'break-start', time: b.breakStart));
      if (b.breakEnd != null) {
        entries.add(_LogEntry(type: 'break-end', time: b.breakEnd!));
      }
    }
    if (record.checkOutTime != null) {
      entries.add(
        _LogEntry(
          type: 'check-out',
          time: record.checkOutTime!,
          location: record.checkOutAddress ?? 'Office - Main Building',
        ),
      );
    }
    entries.sort((a, b) => b.time.compareTo(a.time));
    return entries;
  }

  IconData _emptyIcon() {
    if (vm.isWeekend) return Icons.weekend_rounded;
    if (vm.holidayName != null) return Icons.celebration_rounded;
    if (vm.dailyStatus == AttendanceStatus.absent)
      return Icons.person_off_rounded;
    if (vm.dailyStatus == AttendanceStatus.onLeave)
      return Icons.beach_access_rounded;
    if (vm.dailyStatus == AttendanceStatus.firstHalfLeave)
      return Icons.wb_sunny_outlined;
    if (vm.dailyStatus == AttendanceStatus.secondHalfLeave)
      return Icons.nights_stay_outlined;
    return Icons.timeline_rounded;
  }

  String _emptyTitle() {
    if (vm.isWeekend) return 'Weekend — rest day';
    if (vm.holidayName != null) return vm.holidayName!;
    if (vm.dailyStatus == AttendanceStatus.absent) return 'Marked absent today';
    if (vm.dailyStatus == AttendanceStatus.onLeave) return 'On approved leave';
    if (vm.dailyStatus == AttendanceStatus.firstHalfLeave)
      return 'First half leave approved';
    if (vm.dailyStatus == AttendanceStatus.secondHalfLeave)
      return 'Second half leave approved';
    return 'No activity yet';
  }

  String _emptySub() {
    if (vm.isWeekend) return 'No tracking on weekends';
    if (vm.holidayName != null) return 'No tracking on public holidays';
    if (vm.dailyStatus == AttendanceStatus.absent)
      return 'Contact HR if this is a mistake';
    if (vm.dailyStatus == AttendanceStatus.onLeave)
      return 'No time tracking during leave';
    if (vm.dailyStatus == AttendanceStatus.firstHalfLeave)
      return 'Check in after 1 PM to start tracking';
    if (vm.dailyStatus == AttendanceStatus.secondHalfLeave)
      return 'Check out at 1 PM when ready';
    return 'Check in to start tracking your time';
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries();
    return _CardShell(
      icon: Icons.timeline_rounded,
      title: "Today's Activity Log",
      child: entries.isEmpty
          ? _EmptyState(
              icon: _emptyIcon(),
              title: _emptyTitle(),
              sub: _emptySub(),
            )
          : Column(children: entries.map((e) => _LogRow(entry: e)).toList()),
    );
  }
}

class _LogEntry {
  final String type;
  final DateTime time;
  final String? location;
  const _LogEntry({required this.type, required this.time, this.location});
}

class _LogRow extends StatelessWidget {
  final _LogEntry entry;
  const _LogRow({required this.entry});

  Color get _iconBg =>
      const {
        'check-in': Color(0xFFD1FAE5),
        'check-out': Color(0xFFFEE2E2),
        'break-start': Color(0xFFFEF3C7),
      }[entry.type] ??
      const Color(0xFFDBEAFE);

  IconData get _icon =>
      const {
        'check-in': Icons.login_rounded,
        'check-out': Icons.logout_rounded,
        'break-start': Icons.pause_rounded,
      }[entry.type] ??
      Icons.play_arrow_rounded;

  Color get _iconColor =>
      const {
        'check-in': Color(0xFF059669),
        'check-out': Color(0xFFDC2626),
        'break-start': Color(0xFFD97706),
      }[entry.type] ??
      const Color(0xFF2563EB);

  String get _label =>
      const {
        'check-in': 'Checked In',
        'check-out': 'Checked Out',
        'break-start': 'Break Started',
      }[entry.type] ??
      'Break Ended';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: _iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (entry.location != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          entry.location!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmtMonoTime(entry.time),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                _fmtShortDate(entry.time),
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Reusable small widgets
// ══════════════════════════════════════════════════════════════════════════════

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

class _CardShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _CardShell({
    required this.icon,
    required this.title,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => Card(
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.all(16), child: child),
      ],
    ),
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

class _TimerBox extends StatelessWidget {
  final LinearGradient gradient;
  final Color border, headerIconColor, timerColor;
  final String header, timerText, sub;
  final IconData headerIcon;
  final double timerSize;

  const _TimerBox({
    required this.gradient,
    required this.border,
    required this.header,
    required this.headerIcon,
    required this.headerIconColor,
    required this.timerText,
    required this.timerColor,
    required this.timerSize,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border, width: 2),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(headerIcon, size: 15, color: headerIconColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                header,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: headerIconColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          timerText,
          style: TextStyle(
            fontSize: timerSize,
            fontWeight: FontWeight.bold,
            color: timerColor,
            fontFeatures: const [FontFeature.tabularFigures()],
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          sub,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
      ],
    ),
  );
}

class _BreakLog extends StatelessWidget {
  final List<BreakEntry> breaks;
  const _BreakLog({required this.breaks});

  String _dur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFDE68A)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Break Log',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF92400E),
          ),
        ),
        const SizedBox(height: 10),
        ...breaks.asMap().entries.map((e) {
          final i = e.key + 1;
          final b = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$i',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _fmtShortTime(b.breakStart),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 12,
                    color: Colors.black38,
                  ),
                ),
                Text(
                  b.breakEnd != null ? _fmtShortTime(b.breakEnd!) : 'Ongoing',
                  style: TextStyle(
                    fontSize: 12,
                    color: b.breakEnd != null
                        ? const Color(0xFF475569)
                        : const Color(0xFFF59E0B),
                    fontWeight: b.breakEnd == null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                const Spacer(),
                Text(
                  _dur(b.duration),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
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

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
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

class _OutlinedActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color, borderColor;
  final VoidCallback onTap;
  const _OutlinedActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  );
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
