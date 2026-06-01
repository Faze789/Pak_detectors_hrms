import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hrms_app/views/employee_views/attendance_screen.dart';
import 'package:hrms_app/views/employee_views/employee_payroll_screen.dart';
import 'package:hrms_app/views/employee_views/EmployeeGoalsScreen.dart';
import 'package:hrms_app/views/employee_views/lead_leave_approvals_screen.dart';
import 'package:hrms_app/views/employee_views/submit_report_screen.dart';
import 'package:hrms_app/views/employee_views/team_reports_screen.dart';
import 'package:hrms_app/views/employee_views/my_profile_screen.dart';
import 'package:hrms_app/views/employee_views/my_letters_screen.dart';
import 'package:hrms_app/views/employee_views/request_loan_advance_screen.dart';
import 'package:hrms_app/views/meetings_screens/employee_meetings_screen.dart';
import 'package:hrms_app/views/performance_screens/employee_performance_screen.dart';
import 'package:provider/provider.dart';
import '../../../navigation/app_notification_router.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../widgets/sidebar.dart';
import '../employee_dashboard.dart';

class EmployeeDashboardWithSidebar extends StatefulWidget {
  const EmployeeDashboardWithSidebar({super.key});

  @override
  State<EmployeeDashboardWithSidebar> createState() =>
      _EmployeeDashboardWithSidebarState();
}

class _EmployeeDashboardWithSidebarState
    extends State<EmployeeDashboardWithSidebar> {
  String activeTab = 'employee-dashboard';

  StreamSubscription? _notifSub;
  final Set<String> _seenNotifIds = {};
  bool _initialNotifLoadDone = false;

  @override
  void initState() {
    super.initState();
    EmployeeLetterDeepLink.pending.addListener(_onLetterDeepLink);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeLetterDeepLink();
      _loadEmpIdAndListen();
    });
  }

  @override
  void dispose() {
    EmployeeLetterDeepLink.pending.removeListener(_onLetterDeepLink);
    _notifSub?.cancel();
    super.dispose();
  }

  void _onLetterDeepLink() => _consumeLetterDeepLink();

  void _consumeLetterDeepLink() {
    final req = EmployeeLetterDeepLink.pending.value;
    if (req == null) return;
    EmployeeLetterDeepLink.pending.value = null;

    setState(() => activeTab = 'my-letters');

    final letterId = req.letterId;
    if (letterId == null || letterId.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await openLetterById(context, letterId);
    });
  }

  Future<void> _loadEmpIdAndListen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!mounted) return;
    final empId = (doc.data()?['emp_id'] ?? '').toString().toLowerCase();
    if (empId.isEmpty) return;
    _startNotificationListener(empId);
  }

  void _startNotificationListener(String empId) {
    _notifSub?.cancel();
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
            if (leadId != empId) continue;

            final docId = change.doc.id;
            if (_seenNotifIds.contains(docId)) continue;
            _seenNotifIds.add(docId);

            if (!_initialNotifLoadDone) continue;

            final type = (data['type'] ?? '').toString();
            if (type != 'company_letter') continue;

            final title = (data['title'] ?? '').toString();
            final body = (data['body'] ?? '').toString();
            final referenceId = (data['referenceId'] ?? '').toString();
            if (!mounted || title.isEmpty) continue;

            _showLetterNotificationPopup(
              title: title,
              body: body,
              referenceId: referenceId,
            );
          }
          _initialNotifLoadDone = true;
        });
  }

  void _showLetterNotificationPopup({
    required String title,
    required String body,
    required String referenceId,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _LetterNotificationPopup(
        title: title,
        body: body,
        onDismiss: () => entry.remove(),
        onTap: () {
          entry.remove();
          handleNotificationDeepLink({
            'type': 'company_letter',
            'referenceId': referenceId,
          });
        },
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 6), () {
      if (entry.mounted) entry.remove();
    });
  }

  void _handleTabChange(String tabId) {
    setState(() => activeTab = tabId);

    const comingSoon = {
      'my-payslips': 'My Payslips',
      'settings': 'Settings',
      'help': 'Help Center',
    };

    if (comingSoon.containsKey(tabId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${comingSoon[tabId]} screen — Coming soon')),
      );
    }
  }

  String get _userRole {
    final user = context.read<AuthViewModel>().currentUser;
    return user?.role ?? 'employee';
  }

  Widget _buildContent() {
    // Resolve uid once — safe because user is always logged in at this point
    final user = context.read<AuthViewModel>().currentUser;

    switch (activeTab) {
      case 'employee-dashboard':
        return EmployeeDashboardScreen(
          onNavigate: _handleTabChange,
        );
      case 'employee-goals':
        return EmployeeGoalsScreen();
      case 'lead-leave-approvals':
        return const LeadLeaveApprovalsScreen();
      case 'submit-report':
        return const SubmitReportScreen();
      case 'team-reports':
        return const TeamReportsScreen();
      case 'attendance-clock':
        return const AttendanceScreen();
      case 'my-profile':
        return MyProfileScreen(userId: user!.uid);
      case 'my-performance':
        return EmployeePerformanceScreen(
          employeeId: user!.uid,
          employeeName: user.name,
          employeeRole: user.role,
        );
      case 'my-meetings':
        return EmployeeMeetingsScreen(
          employeeId: user!.uid,
          employeeName: user.name,
        );
      case 'my-payslips':
        return EmployeePayslipScreen(
          employeeId: user!.uid,
          employeeName: user.name,
        );
      case 'my-letters':
        return const MyLettersScreen();
      case 'request-loan-advance':
        return const RequestLoanAdvanceScreen();
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
              userRole: _userRole,
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
            userRole: _userRole,
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }
}

class _LetterNotificationPopup extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _LetterNotificationPopup({
    required this.title,
    required this.body,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 12,
      right: 12,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.description_rounded,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      const Text(
                        'Tap to open My Letters',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, size: 18),
                  color: const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
