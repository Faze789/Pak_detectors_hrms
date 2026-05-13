import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hrms_app/services/storage_service.dart';
import 'package:hrms_app/viewmodels/auth_viewmodel.dart';
import 'package:hrms_app/viewmodels/task_viewmodel.dart';
import 'package:hrms_app/views/HR_views/CheckAssignedTasks.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class AssignTaskToLeadForm extends StatefulWidget {
  const AssignTaskToLeadForm({super.key, required this.unscheduled_task});

  final bool unscheduled_task;

  @override
  State<AssignTaskToLeadForm> createState() => _AssignTaskToLeadFormState();
}

class _AssignTaskToLeadFormState extends State<AssignTaskToLeadForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _secondaryDescCtrl = TextEditingController();

  String? _selectedDuration;
  String? _selectedDepartment;

  // Step 1: HR picks members from full list
  final Set<String> _selectedMemberEmpIds = {};

  // Step 2: HR picks one lead from the selected members
  String? _selectedLeadEmpId;

  final List<PlatformFile> _pickedFiles = [];
  final List<PlatformFile> _secondaryPickedFiles = [];
  bool _uploading = false;

  // Custom Date Tracking
  DateTimeRange? _selectedDateRange;
  int? _customTotalDays;
  int? _customAssignedDays; // This will hold the "divided by 7" result

  static const List<String> _departments = [
    'IT',
    'Marketing',
    'Finance',
    'HR',
    'Sales',
    'Operations',
    'Design',
    'Support',
  ];

  final Map<String, int> _durations = {
    'Weekly': 7,
    'Bi-Weekly': 14,
    'Monthly': 28,
  };

  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<TaskViewModel>().loadAllNonHRUsers();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _secondaryDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles({required List<PlatformFile> target}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null) return;
    setState(() => target.addAll(result.files));
  }

  // ─── Opens the Date Range Picker & Calculates Duration (Total Days / 7) ────
  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: 'Select Task Date Range',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // 1. Get exact calendar days (inclusive)
      final int totalDays = picked.end.difference(picked.start).inDays + 1;

      // 2. Divide by 7 to get full weeks, then multiply by 7 to get exact assigned days
      // E.g., 27 days ~/ 7 = 3.  3 * 7 = 21 assigned days.
      final int assignedDays = (totalDays ~/ 7) * 7;

      setState(() {
        _selectedDateRange = picked;
        _customTotalDays = totalDays;
        _customAssignedDays = assignedDays;
        _selectedDuration = 'Custom Dates';
      });
    } else {
      if (_selectedDuration == 'Custom Dates' && _selectedDateRange == null) {
        setState(() => _selectedDuration = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Assign Task',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<TaskViewModel>(
        builder: (context, taskVm, _) {
          final allUsers = _selectedDepartment == null
              ? taskVm.allUsers
              : taskVm.allUsers
                    .where(
                      (u) =>
                          (u['department'] ?? '').toString().toLowerCase() ==
                          _selectedDepartment!.toLowerCase(),
                    )
                    .toList();

          final selectedUsers = allUsers
              .where(
                (u) => _selectedMemberEmpIds.contains(
                  (u['emp_id'] ?? '').toString(),
                ),
              )
              .toList();

          final screenWidth = MediaQuery.of(context).size.width;
          final isDesktop = screenWidth >= 768;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 48 : 24,
              vertical: 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Filter by Department ─────────────────────────────
                      _buildLabel('Filter by Department'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedDepartment,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            hintText: 'All Departments',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            prefixIcon: Icon(
                              Icons.business_outlined,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Departments'),
                            ),
                            ..._departments.map(
                              (dept) => DropdownMenuItem<String>(
                                value: dept,
                                child: Text(dept),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _selectedDepartment = v;
                              _selectedMemberEmpIds.clear();
                              _selectedLeadEmpId = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── STEP 1: Select Employees ─────────────────────────
                      _buildStepHeader(
                        step: '1',
                        title: 'Select Project Members',
                        subtitle:
                            'Choose all employees who will work on this task.',
                      ),
                      const SizedBox(height: 10),
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: isDesktop ? 300 : 240,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: allUsers.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    'Loading users...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              )
                            : Scrollbar(
                                thumbVisibility: false,
                                child: ListView(
                                  shrinkWrap: true,
                                  children: allUsers.map((user) {
                                    final empId = (user['emp_id'] ?? '')
                                        .toString();
                                    final isSelected = _selectedMemberEmpIds
                                        .contains(empId);
                                    return CheckboxListTile(
                                      value: isSelected,
                                      activeColor: const Color(0xFF2563EB),
                                      title: Text(
                                        user['name'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      subtitle: Text(
                                        '$empId · ${user['department'] ?? user['role'] ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            _selectedMemberEmpIds.add(empId);
                                          } else {
                                            _selectedMemberEmpIds.remove(empId);
                                            if (_selectedLeadEmpId == empId) {
                                              _selectedLeadEmpId = null;
                                            }
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),

                      // Selected count chip
                      if (_selectedMemberEmpIds.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_selectedMemberEmpIds.length} member${_selectedMemberEmpIds.length == 1 ? '' : 's'} selected',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),

                      // ── STEP 2: Choose Lead from selected members ─────────
                      _buildStepHeader(
                        step: '2',
                        title: 'Choose Project Lead',
                        subtitle: _selectedMemberEmpIds.isEmpty
                            ? 'Select members above first, then pick one as lead.'
                            : 'Pick one of the selected members to be the lead.',
                        dimmed: _selectedMemberEmpIds.isEmpty,
                      ),
                      const SizedBox(height: 10),

                      if (_selectedMemberEmpIds.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.person_search_outlined,
                                size: 32,
                                color: Color(0xFFCBD5E1),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No members selected yet',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          constraints: BoxConstraints(
                            maxHeight: isDesktop ? 280 : 220,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedLeadEmpId != null
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFE2E8F0),
                              width: _selectedLeadEmpId != null ? 1.5 : 1,
                            ),
                          ),
                          child: Scrollbar(
                            thumbVisibility: false,
                            child: ListView(
                              shrinkWrap: true,
                              children: selectedUsers.map((user) {
                                final empId = (user['emp_id'] ?? '').toString();
                                final isLead = _selectedLeadEmpId == empId;
                                return RadioListTile<String>(
                                  value: empId,
                                  groupValue: _selectedLeadEmpId,
                                  activeColor: const Color(0xFF2563EB),
                                  title: Text(
                                    user['name'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isLead
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$empId · ${user['department'] ?? user['role'] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  secondary: isLead
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDBEAFE),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.star_rounded,
                                                size: 13,
                                                color: Color(0xFF2563EB),
                                              ),
                                              SizedBox(width: 3),
                                              Text(
                                                'Lead',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF2563EB),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : null,
                                  onChanged: (v) {
                                    setState(() => _selectedLeadEmpId = v);
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      const SizedBox(height: 28),

                      // ── Task Details header ──────────────────────────────
                      const Text(
                        'Task Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Fill in the details for the task you want to assign.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Duration ─────────────────────────────────────────
                      _buildLabel('Duration'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedDuration,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            hintText: 'Select duration',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          items: [
                            ..._durations.keys.map(
                              (key) => DropdownMenuItem<String>(
                                value: key,
                                child: Text(key),
                              ),
                            ),
                            const DropdownMenuItem<String>(
                              value: 'Custom Dates',
                              child: Text(
                                'Custom Dates (Select Range)',
                                style: TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Please select a duration'
                              : null,
                          onChanged: (v) {
                            if (v == 'Custom Dates') {
                              _pickCustomDateRange();
                            } else {
                              setState(() {
                                _selectedDuration = v;
                                _selectedDateRange = null;
                                _customTotalDays = null;
                                _customAssignedDays = null;
                              });
                            }
                          },
                        ),
                      ),

                      // ── Show Custom Date Info Box if selected ────────────
                      if (_selectedDuration == 'Custom Dates' &&
                          _selectedDateRange != null)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFDBEAFE),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.calendar_month_rounded,
                                  color: Color(0xFF2563EB),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${DateFormat('MMM d, yyyy').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, yyyy').format(_selectedDateRange!.end)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Calendar Range: $_customTotalDays days\nAssigned Task Duration: $_customAssignedDays days',
                                      style: const TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _pickCustomDateRange,
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF2563EB),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                child: const Text('Change'),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // ── Task Title ───────────────────────────────────────
                      _buildLabel('Task Title'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _titleCtrl,
                        hint: 'e.g. Complete sprint review',
                        icon: Icons.title_rounded,
                        maxLines: 1,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Task title is required'
                            : null,
                      ),
                      const SizedBox(height: 20),

                      // ── Primary / Unscheduled Description ────────────────
                      _buildLabel(
                        widget.unscheduled_task
                            ? 'Unscheduled Task Description'
                            : 'Priority Task Description',
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _descCtrl,
                        hint: widget.unscheduled_task
                            ? 'Describe the unscheduled task for the lead...'
                            : 'Describe the priority task for the lead...',
                        icon: Icons.description_outlined,
                        maxLines: 5,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? widget.unscheduled_task
                                  ? 'Unscheduled task description is required'
                                  : 'Priority task description is required'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      _buildAttachmentsBox(
                        label: widget.unscheduled_task
                            ? 'Unscheduled Task Attachments (optional)'
                            : 'Priority Attachments (optional)',
                        files: _pickedFiles,
                      ),
                      const SizedBox(height: 24),

                      // ── Secondary Description ────────────────────────────
                      if (!widget.unscheduled_task) ...[
                        _buildLabel('Normal Task Description (optional)'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _secondaryDescCtrl,
                          hint: 'Optional second task — leave blank if none.',
                          icon: Icons.notes_outlined,
                          maxLines: 4,
                          validator: (_) => null,
                        ),
                        const SizedBox(height: 8),
                        _buildAttachmentsBox(
                          label: 'Normal Task Attachments (optional)',
                          files: _secondaryPickedFiles,
                        ),
                        const SizedBox(height: 32),
                      ],

                      // ── Submit ───────────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (taskVm.isSubmitting || _uploading)
                              ? null
                              : () async {
                                  if (_selectedMemberEmpIds.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please select at least one member',
                                        ),
                                        backgroundColor: Color(0xFFEF4444),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  if (_selectedLeadEmpId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please select a lead from the selected members',
                                        ),
                                        backgroundColor: Color(0xFFEF4444),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  if (!_formKey.currentState!.validate()) {
                                    return;
                                  }

                                  if (_selectedDuration == 'Custom Dates' &&
                                      _selectedDateRange == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please select the custom date range from the calendar.',
                                        ),
                                        backgroundColor: Color(0xFFEF4444),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }

                                  final leadUser = allUsers.firstWhere(
                                    (u) =>
                                        (u['emp_id'] ?? '') ==
                                        _selectedLeadEmpId,
                                    orElse: () => <String, dynamic>{},
                                  );
                                  final leadName = (leadUser['name'] ?? '')
                                      .toString();
                                  final leadDept =
                                      (leadUser['department'] ?? '').toString();

                                  final selectedMembers = allUsers
                                      .where(
                                        (u) => _selectedMemberEmpIds.contains(
                                          (u['emp_id'] ?? '').toString(),
                                        ),
                                      )
                                      .toList();

                                  final hrUser = context
                                      .read<AuthViewModel>()
                                      .currentUser;
                                  final hrUid = hrUser?.uid ?? '';
                                  final hrName = hrUser?.name ?? '';
                                  final hrRole = hrUser?.role ?? 'hr';

                                  List<Map<String, dynamic>>? attachments;
                                  List<Map<String, dynamic>>?
                                  secondaryAttachments;

                                  if (_pickedFiles.isNotEmpty ||
                                      _secondaryPickedFiles.isNotEmpty) {
                                    setState(() => _uploading = true);
                                    try {
                                      final ts =
                                          DateTime.now().millisecondsSinceEpoch;
                                      final basePrefix =
                                          'task_attachments/${ts}_${_selectedLeadEmpId ?? 'lead'}';

                                      if (_pickedFiles.isNotEmpty) {
                                        attachments = await _storage
                                            .uploadManyPdfs(
                                              pathPrefix: '$basePrefix/primary',
                                              files: _pickedFiles,
                                              uploadedBy: hrUid,
                                              uploaderRole: 'hr',
                                            );
                                      }
                                      if (_secondaryPickedFiles.isNotEmpty) {
                                        secondaryAttachments = await _storage
                                            .uploadManyPdfs(
                                              pathPrefix:
                                                  '$basePrefix/secondary',
                                              files: _secondaryPickedFiles,
                                              uploadedBy: hrUid,
                                              uploaderRole: 'hr',
                                            );
                                      }
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      setState(() => _uploading = false);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'File upload failed: $e',
                                          ),
                                          backgroundColor: const Color(
                                            0xFFEF4444,
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() => _uploading = false);
                                  }

                                  // Set up correct duration label based on calculations.
                                  // For Custom Dates we ALSO pass the explicit
                                  // day count (`customDurationDays`) so the
                                  // service doesn't have to re-parse the
                                  // label — this guarantees a 14-day custom
                                  // task lands as `totalWeeks = 2`, a 35-day
                                  // task as `totalWeeks = 5`, etc.
                                  final isCustom =
                                      _selectedDuration == 'Custom Dates';
                                  final String finalDurationStr = isCustom
                                      ? 'Custom ($_customAssignedDays Days)'
                                      : _selectedDuration!;
                                  final int? customDays = isCustom
                                      ? _customAssignedDays
                                      : null;

                                  final success = await taskVm.assignTask(
                                    lead_id: _selectedLeadEmpId!,
                                    leadName: leadName,
                                    department: leadDept,
                                    title: _titleCtrl.text.trim(),
                                    description: _descCtrl.text.trim(),
                                    duration: finalDurationStr,
                                    customDurationDays: customDays,
                                    members: selectedMembers,
                                    unscheduled_task: widget.unscheduled_task,
                                    attachments: attachments,
                                    secondaryDescription:
                                        widget.unscheduled_task ||
                                            _secondaryDescCtrl.text
                                                .trim()
                                                .isEmpty
                                        ? null
                                        : _secondaryDescCtrl.text.trim(),
                                    secondaryAttachments:
                                        widget.unscheduled_task
                                        ? null
                                        : secondaryAttachments,
                                    createdBy: hrUid,
                                    createdByName: hrName,
                                    createdByRole: hrRole,
                                  );

                                  if (!context.mounted) return;
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Task assigned successfully',
                                        ),
                                        backgroundColor: Color(0xFF10B981),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CheckAssignedTasks(),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF93C5FD),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: (taskVm.isSubmitting || _uploading)
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send_rounded, size: 18),
                                    SizedBox(width: 10),
                                    Text(
                                      'Assign Task',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepHeader({
    required String step,
    required String title,
    required String subtitle,
    bool dimmed = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: dimmed ? const Color(0xFFCBD5E1) : const Color(0xFF2563EB),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: dimmed
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF475569),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildAttachmentsBox({
    required String label,
    required List<PlatformFile> files,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          if (files.isNotEmpty) ...[
            ...files.asMap().entries.map((entry) {
              final i = entry.key;
              final f = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.attach_file,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        f.name,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => files.removeAt(i)),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
          ],
          OutlinedButton.icon(
            onPressed: () => _pickFiles(target: files),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(
              files.isEmpty ? 'Choose Files' : 'Add More Files',
              style: const TextStyle(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          prefixIcon: Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 14 : 0),
            child: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 48),
        ),
        validator: validator,
      ),
    );
  }
}
