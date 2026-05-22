import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/employee_model.dart';
import '../../viewmodels/document_viewmodel.dart';
import '../../viewmodels/employee_viewmodel.dart';
import '../../widgets/employee_attachment_section.dart';

enum EmployeeFormMode { add, edit }

class AddEditEmployeeView extends StatefulWidget {
  final EmployeeFormMode mode;
  final Employee? employee_id;
  final Employee? employee;

  const AddEditEmployeeView({
    super.key,
    required this.mode,
    this.employee,
    this.employee_id,
  });

  @override
  State<AddEditEmployeeView> createState() => _AddEditEmployeeViewState();
}

class _AddEditEmployeeViewState extends State<AddEditEmployeeView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController emp_id_controller;
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
  late TextEditingController jobDescriptionCtrl;
  late TextEditingController emergencyPhoneCtrl;
  late TextEditingController personalEmailCtrl;

  EmployeeStatus status = EmployeeStatus.active;
  String _selectedRole = 'employee';
  // 'in_station' or 'out_station' — drives per-quarter leave quota
  // (3 days/qtr in-station, 4 days/qtr out-of-station per policy).
  // Defaults to in_station for new and existing employees with no value.
  String _selectedStation = 'in_station';
  // Gender drives which leave-type options appear in the request UI:
  //   'female' → maternity option shown
  //   'male'   → paternity option shown
  //   null     → neither shown (HR can flip when known)
  String? _selectedGender;
  bool _resettingPassword = false;
  bool _passwordVisible = false;
  final _newPasswordCtrl = TextEditingController();

  bool get isEdit => widget.mode == EmployeeFormMode.edit;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.employee?.name ?? '');
    emp_id_controller = TextEditingController(
      text: widget.employee?.emp_id ?? '',
    );
    roleController = TextEditingController(text: widget.employee?.role ?? '');
    final existingRole = (widget.employee?.role ?? '').toLowerCase();
    _selectedRole = existingRole.contains('project lead')
        ? 'project lead'
        : 'employee';
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
    jobDescriptionCtrl = TextEditingController(
      text: widget.employee?.jobDescription ?? '',
    );
    emergencyPhoneCtrl = TextEditingController(
      text: widget.employee?.emergencyPhone ?? '',
    );
    personalEmailCtrl = TextEditingController(
      text: widget.employee?.personalEmail ?? '',
    );
    status = widget.employee?.status ?? EmployeeStatus.active;
    _selectedStation = widget.employee?.station ?? 'in_station';
    _selectedGender = widget.employee?.gender;

    if (isEdit && widget.employee != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context
            .read<DocumentViewModel>()
            .loadDocuments(employeeId: widget.employee!.uid);
      });
    }
  }

  @override
  void dispose() {
    emp_id_controller.dispose();
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
    jobDescriptionCtrl.dispose();
    emergencyPhoneCtrl.dispose();
    personalEmailCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  /// Calls the `adminSetEmployeePassword` Cloud Function to set the
  /// employee's Firebase Auth password AND store it in Firestore so HR
  /// can view it later.
  Future<void> _setEmployeePassword() async {
    final newPassword = _newPasswordCtrl.text.trim();
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final empUid = widget.employee?.uid ?? '';
    final empName = widget.employee?.name ?? 'this employee';
    if (empUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee uid is missing'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Reset Password?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Set a new password for $empName.\n\n'
          'The employee will need to be told the new password — they\'ll '
          'receive an in-app notification but not the password itself.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _resettingPassword = true);
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('adminSetEmployeePassword');
      await callable.call({'uid': empUid, 'newPassword': newPassword});

      if (!mounted) return;
      _newPasswordCtrl.clear();
      // Refresh employee data so the "last set" field updates
      await context.read<EmployeeViewModel>().loadEmployees('');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successfully'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: ${e.message ?? e.code}'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _resettingPassword = false);
    }
  }

  void saveEmployee() {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<EmployeeViewModel>();

    if (isEdit) {
      // emp_id is intentionally NOT updated — it's immutable after creation.
      final updatedEmployee = widget.employee!.copyWith(
        name: nameController.text.trim(),
        role: _selectedRole,
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
        jobDescription: jobDescriptionCtrl.text.trim(),
        emergencyPhone: emergencyPhoneCtrl.text.trim(),
        personalEmail: personalEmailCtrl.text.trim(),
        station: _selectedStation,
        gender: _selectedGender,
      );
      vm.updateEmployee(updatedEmployee);
    } else {
      final newEmployee = Employee(
        uid: '',
        emp_id: emp_id_controller.text.trim(),
        name: nameController.text.trim(),
        role: _selectedRole,
        department: departmentController.text.trim(),
        location: locationController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        status: status,
        joinDate: '',
        salary: double.tryParse(salaryController.text.trim()) ?? 0.0,
        annualLeaveQuota: 4,
        sickLeaveQuota: 3,
        casualLeaveQuota: 6,
        unpaidLeaveQuota: 0,
        jobDescription: jobDescriptionCtrl.text.trim(),
        emergencyPhone: emergencyPhoneCtrl.text.trim(),
        personalEmail: personalEmailCtrl.text.trim(),
        station: _selectedStation,
        gender: _selectedGender,
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
                    controller: emp_id_controller,
                    enabled: !isEdit,
                    decoration: InputDecoration(
                      labelText: 'Employee ID',
                      helperText: isEdit ? 'Cannot be changed' : null,
                      border: const OutlineInputBorder(),
                      filled: isEdit,
                      fillColor: isEdit ? const Color(0xFFF1F5F9) : null,
                      suffixIcon: isEdit
                          ? const Icon(Icons.lock_outline, size: 18)
                          : null,
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  // Role selection
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            value: 'employee',
                            groupValue: _selectedRole,
                            title: const Text(
                              'Team Member',
                              style: TextStyle(fontSize: 14),
                            ),
                            activeColor: const Color(0xFF2563EB),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _selectedRole = v;
                                  roleController.text = v;
                                });
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            value: 'project lead',
                            groupValue: _selectedRole,
                            title: const Text(
                              'Project Lead',
                              style: TextStyle(fontSize: 14),
                            ),
                            activeColor: const Color(0xFF2563EB),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _selectedRole = v;
                                  roleController.text = v;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
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
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                        return 'Invalid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: personalEmailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Personal Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                        return 'Invalid email';
                      }
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
                    controller: emergencyPhoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Emergency Phone Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.emergency_outlined),
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
                  // ── Station toggle ──────────────────────────────────────
                  // Drives the per-quarter leave quota: 3 days/qtr for
                  // in-station, 4 days/qtr for out-of-station (per policy).
                  // Defaults to in_station.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 4, top: 4, bottom: 6),
                          child: Text(
                            'Station',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'in_station',
                              label: Text('In-station'),
                              icon: Icon(Icons.business_rounded, size: 16),
                            ),
                            ButtonSegment(
                              value: 'out_station',
                              label: Text('Out-of-station'),
                              icon: Icon(Icons.flight_rounded, size: 16),
                            ),
                          ],
                          selected: {_selectedStation},
                          onSelectionChanged: (s) =>
                              setState(() => _selectedStation = s.first),
                          style: ButtonStyle(
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 4, top: 6),
                          child: Text(
                            'Leave quota: 3 days/quarter (in-station) · '
                            '4 days/quarter (out-of-station)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Gender dropdown ─────────────────────────────────────
                  // Determines whether the employee will see Maternity
                  // (female) or Paternity (male) as a leave-type option.
                  // Optional — leaving it unset just hides both.
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      helperText:
                          'Enables Maternity (female) or Paternity (male) leave option',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.wc_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Prefer not to specify'),
                      ),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                    ],
                    onChanged: (v) => setState(() => _selectedGender = v),
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

                  // ── Job Description ────────────────────────────────────
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: jobDescriptionCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Job Description',
                      hintText: 'Enter job description...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),

                  // ── Account Password (edit only) ─────────────────────────
                  if (isEdit) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Account Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCurrentPasswordCard(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _newPasswordCtrl,
                      obscureText: !_passwordVisible,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        hintText: 'min. 6 characters',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _passwordVisible = !_passwordVisible,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _resettingPassword ? null : _setEmployeePassword,
                        icon: _resettingPassword
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.lock_reset_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                        label: Text(
                          _resettingPassword
                              ? 'Resetting…'
                              : 'Reset Password',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  if (isEdit && widget.employee != null) ...[
                    EmployeeAttachmentSection(employee: widget.employee!),
                    const SizedBox(height: 24),
                  ] else if (!isEdit) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Save the employee first, then edit their profile to '
                        'upload offer letters and attachments.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

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

  Widget _buildCurrentPasswordCard() {
    final pw = widget.employee?.lastSetPassword;
    final setAt = widget.employee?.passwordSetAt;
    final hasPassword = pw != null && pw.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current password (last set by HR)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 6),
          if (!hasPassword)
            const Text(
              'Unknown — set by employee',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Color(0xFF92400E),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _passwordVisible ? pw : '•' * pw.length,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _passwordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                    size: 18,
                    color: const Color(0xFF92400E),
                  ),
                  onPressed: () => setState(
                    () => _passwordVisible = !_passwordVisible,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: Color(0xFF92400E),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pw));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password copied to clipboard'),
                        backgroundColor: Color(0xFF16A34A),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          if (hasPassword && setAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Set on ${setAt.day}/${setAt.month}/${setAt.year} '
              '${setAt.hour.toString().padLeft(2, '0')}:'
              '${setAt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF92400E),
              ),
            ),
          ],
        ],
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
