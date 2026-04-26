import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hrms_app/viewmodels/task_viewmodel.dart';
import 'package:hrms_app/views/HR_views/CheckAssignedTasks.dart';
import 'package:provider/provider.dart';

class AssignTaskToLeadForm extends StatefulWidget {
  const AssignTaskToLeadForm({super.key});

  @override
  State<AssignTaskToLeadForm> createState() => _AssignTaskToLeadFormState();
}

class _AssignTaskToLeadFormState extends State<AssignTaskToLeadForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _selectedDuration;
  bool _isPrimary = true;
  String? _selectedDepartment;

  // Lead selection — only one lead per task
  String? _selectedLeadEmpId;

  // Member selection — multiple employees
  final Set<String> _selectedMemberEmpIds = {};

  // Attachments — picked files ready to upload
  final List<PlatformFile> _pickedFiles = [];
  bool _uploading = false;

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
    'Monthly': 30,
    'Every 2 Months': 60,
    'Quarterly': 90,
  };

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
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: kIsWeb ? FileType.custom : FileType.any,
      allowedExtensions: kIsWeb ? ['pdf', 'doc', 'docx', 'png', 'jpg'] : null,
      withData: true,
    );
    if (result == null) return;
    setState(() => _pickedFiles.addAll(result.files));
  }

  /// Upload all picked files to Firebase Storage, returns list of attachment maps
  Future<List<Map<String, dynamic>>> _uploadAttachments() async {
    final attachments = <Map<String, dynamic>>[];
    for (final file in _pickedFiles) {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref =
          FirebaseStorage.instance.ref('task_attachments/$fileName');

      if (file.bytes != null) {
        await ref.putData(file.bytes!);
      } else if (file.path != null) {
        await ref.putFile(File(file.path!));
      } else {
        continue;
      }

      final url = await ref.getDownloadURL();
      final ext = file.extension?.toLowerCase() ?? '';
      attachments.add({
        'name': file.name,
        'url': url,
        'type': ext,
      });
    }
    return attachments;
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
          // Filter users by selected department
          final allUsers = _selectedDepartment == null
              ? taskVm.allUsers
              : taskVm.allUsers
                    .where(
                      (u) =>
                          (u['department'] ?? '').toString().toLowerCase() ==
                          _selectedDepartment!.toLowerCase(),
                    )
                    .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
                        ..._departments.map((dept) {
                          return DropdownMenuItem<String>(
                            value: dept,
                            child: Text(dept),
                          );
                        }),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _selectedDepartment = v;
                          // Clear selections when department changes
                          _selectedLeadEmpId = null;
                          _selectedMemberEmpIds.clear();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Select Lead ──────────────────────────────────────
                  _buildLabel('Select Lead'),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose one person to lead this task.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedLeadEmpId != null
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFE2E8F0),
                      ),
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
                        : Column(
                            children: allUsers.map((user) {
                              final empId = (user['emp_id'] ?? '').toString();
                              final isSelected = _selectedLeadEmpId == empId;
                              return RadioListTile<String>(
                                value: empId,
                                groupValue: _selectedLeadEmpId,
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
                                secondary: isSelected
                                    ? const Icon(
                                        Icons.star_rounded,
                                        color: Color(0xFF2563EB),
                                        size: 20,
                                      )
                                    : null,
                                onChanged: (v) {
                                  setState(() {
                                    _selectedLeadEmpId = v;
                                    // Remove lead from members if selected
                                    _selectedMemberEmpIds.remove(v);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // ── Select Employees / Members ──────────────────────
                  _buildLabel('Select Employees'),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose team members for this task.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 8),
                  Container(
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
                        : Column(
                            children: allUsers
                                .where((user) {
                                  // Exclude the selected lead from member list
                                  final empId = (user['emp_id'] ?? '')
                                      .toString();
                                  return empId != _selectedLeadEmpId;
                                })
                                .map((user) {
                                  final empId = (user['emp_id'] ?? '')
                                      .toString();
                                  final isSelected = _selectedMemberEmpIds
                                      .contains(empId);
                                  return CheckboxListTile(
                                    value: isSelected,
                                    activeColor: const Color(0xFF16A34A),
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
                                        }
                                      });
                                    },
                                  );
                                })
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 24),

                  // ── Task Type (Primary / Secondary) ────────────────
                  _buildLabel('Task Type'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            value: true,
                            groupValue: _isPrimary,
                            activeColor: const Color(0xFF2563EB),
                            title: const Text(
                              'Primary',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onChanged: (v) => setState(() => _isPrimary = v!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            value: false,
                            groupValue: _isPrimary,
                            activeColor: const Color(0xFF2563EB),
                            title: const Text(
                              'Secondary',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onChanged: (v) => setState(() => _isPrimary = v!),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

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
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 20),

                  // ── Duration Dropdown ───────────────────────────────
                  _buildLabel('Duration'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedDuration,
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
                      items: _durations.keys.map((key) {
                        return DropdownMenuItem<String>(
                          value: key,
                          child: Text(key),
                        );
                      }).toList(),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please select a duration';
                        }
                        return null;
                      },
                      onChanged: (v) {
                        setState(() => _selectedDuration = v);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Task Title ──────────────────────────────────────
                  _buildLabel('Task Title'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _titleCtrl,
                    hint: 'e.g. Complete sprint review',
                    icon: Icons.title_rounded,
                    maxLines: 1,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Task title is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Task Description ────────────────────────────────
                  _buildLabel('Task Description'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _descCtrl,
                    hint: 'Describe what needs to be done...',
                    icon: Icons.description_outlined,
                    maxLines: 5,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Task description is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Attachments ────────────────────────────────────
                  _buildLabel('Attachments (optional)'),
                  const SizedBox(height: 4),
                  const Text(
                    'Attach PDF, DOC, or image files for this task.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 8),
                  Container(
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
                        if (_pickedFiles.isNotEmpty) ...[
                          ..._pickedFiles.asMap().entries.map((entry) {
                            final i = entry.key;
                            final f = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.attach_file,
                                      size: 16, color: Color(0xFF2563EB)),
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
                                    onTap: () =>
                                        setState(() => _pickedFiles.removeAt(i)),
                                    child: const Icon(Icons.close,
                                        size: 16, color: Color(0xFFEF4444)),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 6),
                        ],
                        OutlinedButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.upload_file_rounded, size: 18),
                          label: Text(
                            _pickedFiles.isEmpty
                                ? 'Choose Files'
                                : 'Add More Files',
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
                  ),
                  const SizedBox(height: 32),

                  // ── Submit Button ───────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (taskVm.isSubmitting || _uploading)
                          ? null
                          : () async {
                              // Validate lead selection
                              if (_selectedLeadEmpId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please select a lead'),
                                    backgroundColor: Color(0xFFEF4444),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              // Validate member selection
                              if (_selectedMemberEmpIds.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select at least one employee',
                                    ),
                                    backgroundColor: Color(0xFFEF4444),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              // Validate form fields
                              if (!_formKey.currentState!.validate()) {
                                return;
                              }

                              // Find lead info from allUsers
                              final leadUser = allUsers.firstWhere(
                                (u) =>
                                    (u['emp_id'] ?? '') == _selectedLeadEmpId,
                                orElse: () => <String, dynamic>{},
                              );
                              final leadName = (leadUser['name'] ?? '')
                                  .toString();
                              final leadDept = (leadUser['department'] ?? '')
                                  .toString();

                              // Build members list from selected emp_ids
                              final selectedMembers = allUsers
                                  .where(
                                    (u) => _selectedMemberEmpIds.contains(
                                      (u['emp_id'] ?? '').toString(),
                                    ),
                                  )
                                  .toList();

                              // Upload attachments if any
                              List<Map<String, dynamic>>? attachments;
                              if (_pickedFiles.isNotEmpty) {
                                setState(() => _uploading = true);
                                try {
                                  attachments = await _uploadAttachments();
                                } catch (e) {
                                  if (!context.mounted) return;
                                  setState(() => _uploading = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('File upload failed: $e'),
                                      backgroundColor: const Color(0xFFEF4444),
                                    ),
                                  );
                                  return;
                                }
                                setState(() => _uploading = false);
                              }

                              final success = await taskVm.assignTask(
                                lead_id: _selectedLeadEmpId!,
                                leadName: leadName,
                                department: leadDept,
                                title: _titleCtrl.text.trim(),
                                description: _descCtrl.text.trim(),
                                duration: _selectedDuration!,
                                members: selectedMembers,
                                taskType: _isPrimary ? 'primary' : 'secondary',
                                attachments: attachments,
                              );

                              if (!context.mounted) return;
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Task assigned successfully'),
                                    backgroundColor: Color(0xFF10B981),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CheckAssignedTasks(),
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
          );
        },
      ),
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
