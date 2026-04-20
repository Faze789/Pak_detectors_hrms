import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/employee_model.dart';
import '../../viewmodels/attendance_viewmodel.dart';
import '../../viewmodels/document_viewmodel.dart';
import '../../viewmodels/employee_viewmodel.dart';
import '../../viewmodels/leave_viewmodel.dart';
import '../../widgets/employee_card.dart';

import 'employee_profile_screen.dart';
import 'add_edit_employee_view.dart';

class EmployeeListView extends StatefulWidget {
  const EmployeeListView({super.key});

  @override
  State<EmployeeListView> createState() => _EmployeeListViewState();
}

class _EmployeeListViewState extends State<EmployeeListView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    /// Load registered employees (role == employee)
    Future.microtask(() {
      context.read<EmployeeViewModel>().loadEmployees('');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Navigate to Add Employee Screen
  void _goToAddEmployee() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddEditEmployeeView(mode: EmployeeFormMode.add),
      ),
    );

    /// Reload after returning
    context.read<EmployeeViewModel>().loadEmployees('');
  }

  /// Navigate to Edit Employee Screen
  void _goToEditEmployee(Employee employee) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditEmployeeView(
          employee: employee,
          mode: EmployeeFormMode.edit,
        ),
      ),
    );

    context.read<EmployeeViewModel>().loadEmployees('');
  }

  // / Show employee profile
  void _showEmployeeProfile(Employee employee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AttendanceViewModel()),
              ChangeNotifierProvider(create: (_) => LeaveViewModel()),
              // ChangeNotifierProvider(create: (_) => PayrollViewModel()),
              ChangeNotifierProvider(create: (_) => DocumentViewModel()),
            ],
            child: EmployeeProfileView(employee: employee),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EmployeeViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: CustomScrollView(
        slivers: [
          /// ================= HEADER =================
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,

            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: const Color(0xFFE2E8F0)),
            ),

            title: Row(
              children: [
                /// ICON
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.group, color: Colors.white),
                ),

                const SizedBox(width: 12),

                /// TITLE
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Registered Employees',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        '${vm.totalEmployees} team members',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            /// ADD BUTTON
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: ElevatedButton.icon(
                  onPressed: _goToAddEmployee,
                  icon: const Icon(Icons.add),
                  label: const Text("Add"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),

          /// ================= SEARCH =================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: TextField(
                controller: _searchController,
                onChanged: vm.filterEmployees,
                decoration: InputDecoration(
                  hintText: "Search employee...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          /// ================= LOADING =================
          if (vm.isLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          /// ================= EMPTY =================
          else if (vm.filteredEmployees.isEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    "No Registered Employees Found",
                    style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                  ),
                ),
              ),
            )
          /// ================= GRID =================
          else
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 320,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 24,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final employee = vm.filteredEmployees[index];

                  return EmployeeCard(
                    employee: employee,
                    employee_id: employee,
                    onViewTap: () => _showEmployeeProfile(employee),
                    onEditTap: () => _goToEditEmployee(employee),
                  );
                }, childCount: vm.filteredEmployees.length),
              ),
            ),
        ],
      ),
    );
  }
}
