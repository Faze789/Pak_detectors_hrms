import 'package:flutter/material.dart';
import 'package:hrms_app/views/employee_views/attendance_screen.dart';
import 'package:hrms_app/views/employee_views/employee_payroll_screen.dart';
import 'package:hrms_app/views/employee_views/EmployeeGoalsScreen.dart';
import 'package:hrms_app/views/employee_views/leader_monthly_report_screen.dart';
import 'package:hrms_app/views/employee_views/my_profile_screen.dart';
import 'package:hrms_app/views/meetings_screens/employee_meetings_screen.dart';
import 'package:hrms_app/views/performance_screens/employee_performance_screen.dart';
import 'package:provider/provider.dart';
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

  Widget _buildContent() {
    // Resolve uid once — safe because user is always logged in at this point
    final user = context.read<AuthViewModel>().currentUser;

    switch (activeTab) {
      case 'employee-dashboard':
        return const EmployeeDashboardScreen();
      case 'employee-goals':
        return EmployeeGoalsScreen();
      case 'monthly-report':
        return const LeaderMonthlyReportScreen();
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
              userRole: 'employee',
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
            userRole: 'employee',
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }
}
