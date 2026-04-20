import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/employee_model.dart';
import '../../viewmodels/attendance_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/document_viewmodel.dart';
import '../../viewmodels/leave_viewmodel.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/status_badge.dart';
import '../employee_tabs/attendance_tab.dart';
import '../employee_tabs/documents_tab.dart';
import '../employee_tabs/leaves_tab.dart';
import '../employee_tabs/personal_tab.dart';
import '../employee_tabs/salary_tab.dart';

class EmployeeProfileView extends StatefulWidget {
  final Employee employee;

  const EmployeeProfileView({super.key, required this.employee});

  @override
  State<EmployeeProfileView> createState() => _EmployeeProfileViewState();
}

class _EmployeeProfileViewState extends State<EmployeeProfileView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool _isHR;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 5, vsync: this);

    // Determine role once here so we can use it in initForHR/initForEmployee
    final currentUserRole =
        context.read<AuthViewModel>().currentUser?.role ?? '';
    _isHR = currentUserRole.toLowerCase() == 'hr';

    // Initialize the correct leave stream
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final leaveVm = context.read<LeaveViewModel>();
      if (_isHR) {
        leaveVm
            .initForHR(); // streams ALL leaves → filtered by uid in LeavesTab
      } else {
        leaveVm.initForEmployee(
          widget.employee.uid,
        ); // streams only this employee's leaves
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.employee.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),

      body: Column(
        children: [
          /// PROFILE HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF334155)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Avatar(
                  name: widget.employee.name,
                  department: widget.employee.department,
                  size: 100,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.employee.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.employee.role ?? 'Employee',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.employee.department ?? 'No Department',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.employee.email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
                const SizedBox(height: 14),
                StatusBadge(status: widget.employee.status),
              ],
            ),
          ),

          /// TAB BAR
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 3,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Personal'),
                Tab(text: 'Attendance'),
                Tab(text: 'Leaves'),
                Tab(text: 'Salary'),
                Tab(text: 'Documents'),
              ],
            ),
          ),

          /// TAB CONTENT
          Expanded(
            child: Container(
              color: Colors.white,
              child: TabBarView(
                controller: _tabController,
                children: [
                  PersonalTab(employee: widget.employee),

                  AttendanceTab(
                    employee: widget.employee,
                    attendanceVM: context.read<AttendanceViewModel>(),
                  ),

                  LeavesTab(
                    userId: widget.employee.uid,
                    employeeName: widget.employee.name,
                    employeeRole: widget.employee.role ?? 'Employee',
                    isHR: _isHR,
                  ),

                  SalaryTab(employee: widget.employee),

                  DocumentsTab(
                    employee: widget.employee,
                    documentVM: context.read<DocumentViewModel>(),
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
