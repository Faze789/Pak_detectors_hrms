import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hrms_app/views/HR_views/AssignTaskByHR.dart';
import 'package:hrms_app/views/HR_views/employee_screen.dart';
import 'package:hrms_app/views/HR_views/hr_attendance_screen.dart';
import 'package:hrms_app/views/HR_views/hr_branch_management.dart';
import 'package:hrms_app/views/HR_views/hr_leave_screen.dart';
import 'package:hrms_app/views/HR_views/hr_report_screen.dart';
import 'package:hrms_app/views/HR_views/payroll_screen.dart';
import 'package:hrms_app/views/HR_views/recruitment_screen.dart';
import 'package:hrms_app/views/HR_views/hr_monthly_goals_screen.dart';
import 'package:hrms_app/views/HR_views/task_notifications_screen.dart';
import 'package:hrms_app/views/meetings_screens/hr_meeting_screen.dart';
import 'package:hrms_app/views/performance_screens/hr_performance_screen.dart';
import '../../../widgets/sidebar.dart';
import '../hr_dashboard.dart';

class HRDashboardWithSidebar extends StatefulWidget {
  const HRDashboardWithSidebar({super.key});

  @override
  State<HRDashboardWithSidebar> createState() => _HRDashboardWithSidebarState();
}

class _HRDashboardWithSidebarState extends State<HRDashboardWithSidebar> {
  String activeTab = 'dashboard';

  // Current user info loaded from Firebase
  String _hrUserId = '';
  String _hrUserName = '';
  String _hrEmpId = '';

  // Real-time notification listener
  StreamSubscription? _notifSub;
  final Set<String> _seenNotifIds = {};
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;
    final empId = (doc.data()?['emp_id'] ?? user.uid).toString();
    setState(() {
      _hrUserId = user.uid;
      _hrUserName = doc.data()?['name'] ?? user.displayName ?? 'HR';
      _hrEmpId = empId;
    });

    _startNotificationListener(empId);
  }

  void _startNotificationListener(String empId) {
    final lower = empId.toLowerCase();
    _notifSub = FirebaseFirestore.instance
        .collection('task_notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;

        final data = change.doc.data();
        if (data == null) continue;

        final leadId = (data['lead_id'] ?? '').toString().toLowerCase();
        if (leadId != lower) continue;

        final docId = change.doc.id;
        if (_seenNotifIds.contains(docId)) continue;
        _seenNotifIds.add(docId);

        // Skip the initial batch load — only show popup for truly new ones
        if (!_initialLoadDone) continue;

        final title = (data['title'] ?? '').toString();
        final body = (data['body'] ?? '').toString();
        if (title.isNotEmpty && mounted) {
          _showNotificationPopup(title, body);
        }
      }
      _initialLoadDone = true;
    });
  }

  void _showNotificationPopup(String title, String body) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _NotificationPopup(
        title: title,
        body: body,
        onDismiss: () => entry.remove(),
        onTap: () {
          entry.remove();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskNotificationsScreen(recipientId: _hrEmpId),
            ),
          );
        },
      ),
    );

    overlay.insert(entry);

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (entry.mounted) entry.remove();
    });
  }

  void _handleTabChange(String tabId) {
    setState(() => activeTab = tabId);

    const comingSoon = {
      'reports': 'Reports',
      'documents': 'Documents',
      'help': 'Help Center',
    };

    if (comingSoon.containsKey(tabId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${comingSoon[tabId]} screen — Coming soon')),
      );
    }
  }

  Widget _buildContent() {
    switch (activeTab) {
      case 'dashboard':
        return const HRDashboardScreen();
      case 'employees':
        return const EmployeeListView();

      // will implement this feature tomorrow

      case 'assign-task-employee-by-hr':
        return const AssignTaskByHR();

      // case 'payroll':
      //   return const PayrollScreen();
      case 'attendance':
        return HRAttendanceScreen();
      case 'leaves':
        return const HRLeaveScreen();
      case 'performance':
        return const HRPerformanceScreen();
      case 'settings':
        return const HRBranchManagement();
      case 'recruitment':
        return const RecruitmentScreen();
      case 'payroll':
        return const HRPayrollScreen();
      case 'monthly-goals':
        return const HRMonthlyGoalsScreen();
      case 'reports':
        return HRReportScreen();
      case 'meetings':

        // Show loader while user data is still being fetched
        if (_hrUserId.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return HRMeetingsScreen(hrUserId: _hrUserId, hrUserName: _hrUserName);
      default:
        return Center(
          child: Text(
            'Content for $activeTab',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      drawer: isDesktop
          ? null
          : Sidebar.buildDrawer(
              activeTab: activeTab,
              onTabChange: _handleTabChange,
              userRole: 'hr',
            ),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Color(0xFF475569),
                  ),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              title: const Text(
                'HRMS Pro',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
      body: Row(
        children: [
          Sidebar(
            activeTab: activeTab,
            onTabChange: _handleTabChange,
            userRole: 'hr',
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }
}

// ─── Notification Popup Overlay ──────────────────────────────────────────────

class _NotificationPopup extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _NotificationPopup({
    required this.title,
    required this.body,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_NotificationPopup> createState() => _NotificationPopupState();
}

class _NotificationPopupState extends State<_NotificationPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.body,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap to view',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
