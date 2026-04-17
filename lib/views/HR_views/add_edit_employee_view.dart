import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/employee_model.dart';
import '../../viewmodels/employee_viewmodel.dart';

enum EmployeeFormMode { add, edit }

class AddEditEmployeeView extends StatefulWidget {
  final EmployeeFormMode mode;
  final Employee? employee;

  const AddEditEmployeeView({super.key, required this.mode, this.employee});

  @override
  State<AddEditEmployeeView> createState() => _AddEditEmployeeViewState();
}

class _AddEditEmployeeViewState extends State<AddEditEmployeeView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController roleController;
  late TextEditingController departmentController;
  late TextEditingController locationController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController salaryController;
  late TextEditingController annualLeaveCtrl;
  late TextEditingController sickLeaveCtrl;
  late TextEditingController casualLeaveCtrl;
  late TextEditingController unpaidLeaveCtrl;

  EmployeeStatus status = EmployeeStatus.active;

  bool get isEdit => widget.mode == EmployeeFormMode.edit;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.employee?.name ?? '');
    roleController = TextEditingController(text: widget.employee?.role ?? '');
    departmentController = TextEditingController(
      text: widget.employee?.department ?? '',
    );
    locationController = TextEditingController(
      text: widget.employee?.location ?? '',
    );
    emailController = TextEditingController(text: widget.employee?.email ?? '');
    phoneController = TextEditingController(text: widget.employee?.phone ?? '');
    salaryController = TextEditingController(
      text: widget.employee?.salary != 0
          ? widget.employee?.salary.toString() ?? ''
          : '',
    );
    annualLeaveCtrl = TextEditingController(
      text: widget.employee?.annualLeaveQuota.toString() ?? '4',
    );
    sickLeaveCtrl = TextEditingController(
      text: widget.employee?.sickLeaveQuota.toString() ?? '3',
    );
    casualLeaveCtrl = TextEditingController(
      text: widget.employee?.casualLeaveQuota.toString() ?? '6',
    );
    unpaidLeaveCtrl = TextEditingController(
      text: widget.employee?.unpaidLeaveQuota.toString() ?? '0',
    );
    status = widget.employee?.status ?? EmployeeStatus.active;
  }

  @override
  void dispose() {
    nameController.dispose();
    roleController.dispose();
    departmentController.dispose();
    locationController.dispose();
    emailController.dispose();
    phoneController.dispose();
    salaryController.dispose();
    annualLeaveCtrl.dispose();
    sickLeaveCtrl.dispose();
    casualLeaveCtrl.dispose();
    unpaidLeaveCtrl.dispose();
    super.dispose();
  }

  void saveEmployee() {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<EmployeeViewModel>();

    if (isEdit) {
      final updatedEmployee = widget.employee!.copyWith(
        name: nameController.text.trim(),
        role: roleController.text.trim(),
        department: departmentController.text.trim(),
        location: locationController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        status: status,
        salary: double.tryParse(salaryController.text.trim()) ?? 0.0,
        annualLeaveQuota: int.tryParse(annualLeaveCtrl.text.trim()) ?? 4,
        sickLeaveQuota: int.tryParse(sickLeaveCtrl.text.trim()) ?? 3,
        casualLeaveQuota: int.tryParse(casualLeaveCtrl.text.trim()) ?? 6,
        unpaidLeaveQuota: int.tryParse(unpaidLeaveCtrl.text.trim()) ?? 0,
      );
      vm.updateEmployee(updatedEmployee);
    } else {
      final newEmployee = Employee(
        uid: '',
        name: nameController.text.trim(),
        role: roleController.text.trim(),
        department: departmentController.text.trim(),
        location: locationController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        status: status,
        joinDate: '',
        salary: double.tryParse(salaryController.text.trim()) ?? 0.0,
        // New employees get default quotas; HR can edit after creation
        annualLeaveQuota: 4,
        sickLeaveQuota: 3,
        casualLeaveQuota: 6,
        unpaidLeaveQuota: 0,
      );
      vm.addEmployee(newEmployee);
    }

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEdit
              ? 'Employee updated successfully'
              : 'Employee added successfully',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Employee' : 'Add Employee'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Basic Info ───────────────────────────────────────────
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: roleController,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: departmentController,
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v))
                        return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: salaryController,
                    decoration: const InputDecoration(
                      labelText: 'Salary',
                      border: OutlineInputBorder(),
                      prefixText: 'PKR ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v != null &&
                          v.isNotEmpty &&
                          double.tryParse(v) == null) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<EmployeeStatus>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: EmployeeStatus.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => status = v);
                    },
                  ),

                  // ── Leave Quotas (edit only) ─────────────────────────────
                  if (isEdit) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Leave Quotas (days / year)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _leaveField(annualLeaveCtrl, 'Annual Leave'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _leaveField(sickLeaveCtrl, 'Sick Leave'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _leaveField(casualLeaveCtrl, 'Casual Leave'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _leaveField(unpaidLeaveCtrl, 'Unpaid Leave'),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Save Button ──────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saveEmployee,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(isEdit ? 'Save Changes' : 'Add Employee'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leaveField(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixText: 'days',
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (int.tryParse(v) == null) return 'Whole number only';
        return null;
      },
    );
  }
}
