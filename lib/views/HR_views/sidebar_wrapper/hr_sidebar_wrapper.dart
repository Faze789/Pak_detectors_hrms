import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hrms_app/views/HR_views/AssignTaskByHR.dart';
import 'package:hrms_app/views/HR_views/CheckAssignedTasks.dart';
import 'package:hrms_app/views/HR_views/employee_screen.dart';
import 'package:hrms_app/views/HR_views/hr_attendance_screen.dart';
import 'package:hrms_app/views/HR_views/hr_branch_management.dart';
import 'package:hrms_app/views/HR_views/hr_leave_screen.dart';
import 'package:hrms_app/views/HR_views/hr_report_screen.dart';
import 'package:hrms_app/views/HR_views/payroll_screen.dart';
import 'package:hrms_app/views/HR_views/recruitment_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;
    setState(() {
      _hrUserId = user.uid;
      _hrUserName = doc.data()?['name'] ?? user.displayName ?? 'HR';
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
