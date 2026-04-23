import 'package:flutter/material.dart';
import 'package:hrms_app/models/employee_model.dart';
import 'package:hrms_app/viewmodels/task_viewmodel.dart';
import 'package:hrms_app/views/HR_views/CheckAssignedTasks.dart';
import 'package:provider/provider.dart';

class AssignTaskToLeadForm extends StatefulWidget {
  final Employee lead;

  const AssignTaskToLeadForm({super.key, required this.lead});

  @override
  State<AssignTaskToLeadForm> createState() => _AssignTaskToLeadFormState();
}

class _AssignTaskToLeadFormState extends State<AssignTaskToLeadForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _selectedDuration;
  bool _isPrimary = true;
  final Set<String> _selectedMemberUids = {};
  bool _membersInitialized = false;

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
      final taskVm = context.read<TaskViewModel>();
      taskVm.loadMembersByLeadId(widget.lead.emp_id);
      taskVm.loadUnassignedEmployees();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;

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
          // Auto-select all members on first load
          if (!_membersInitialized && taskVm.members.isNotEmpty) {
            _membersInitialized = true;
            for (final m in taskVm.members) {
              _selectedMemberUids.add(m['uid'] ?? m['emp_id'] ?? '');
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Assigned To Card ─────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF93C5FD),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: const Color(0xFFDBEAFE),
                            child: Text(
                              lead.name.isNotEmpty
                                  ? lead.name[0].toUpperCase()
                                  : 'P',
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Assigning to',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lead.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      lead.emp_id,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      lead.department,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Current Team Members ──────────────────────────────
                  _buildLabel('Team Members'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: taskVm.members.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.group_outlined,
                                  size: 20,
                                  color: Color(0xFF94A3B8),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'No team members yet',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: taskVm.members.map((m) {
                              final id = m['uid'] ?? m['emp_id'] ?? '';
                              final isSelected = _selectedMemberUids.contains(
                                id,
                              );
                              return CheckboxListTile(
                                value: isSelected,
                                activeColor: const Color(0xFF2563EB),
                                title: Text(
                                  m['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                subtitle: Text(
                                  m['emp_id'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedMemberUids.add(id);
                                    } else {
                                      _selectedMemberUids.remove(id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 20),

                  // ── Available (Unassigned) Employees ───────────────────
                  if (taskVm.unassignedEmployees.isNotEmpty) ...[
                    _buildLabel('Available Employees (No Lead Assigned)'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD1FAE5)),
                      ),
                      child: Column(
                        children: taskVm.unassignedEmployees.map((m) {
                          final id = m['uid'] ?? m['emp_id'] ?? '';
                          final isSelected = _selectedMemberUids.contains(id);
                          return CheckboxListTile(
                            value: isSelected,
                            activeColor: const Color(0xFF16A34A),
                            title: Text(
                              m['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            subtitle: Text(
                              '${m['emp_id'] ?? ''} · ${m['role'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedMemberUids.add(id);
                                } else {
                                  _selectedMemberUids.remove(id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Task Type (Primary / Secondary) ────────────────────
                  _buildLabel('Task Type'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: RadioGroup<bool>(
                      groupValue: _isPrimary,
                      onChanged: (v) => setState(() => _isPrimary = v!),
                      child: Column(
                        children: [
                          RadioListTile<bool>(
                            value: true,
                            activeColor: const Color(0xFF2563EB),
                            title: const Text(
                              'Primary',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          RadioListTile<bool>(
                            value: false,
                            activeColor: const Color(0xFF2563EB),
                            title: const Text(
                              'Secondary',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
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

                  // ── Duration Dropdown ────────────────────────────────
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
                        setState(() {
                          _selectedDuration = v;
                        });
                      },
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
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Task title is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Task Description ─────────────────────────────────
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
                  const SizedBox(height: 32),

                  // ── Submit Button ────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: taskVm.isSubmitting
                          ? null
                          : () async {
                              if (_selectedMemberUids.isEmpty) {
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
                              if (!_formKey.currentState!.validate()) {
                                return;
                              }

                              // Save lead_id for any selected unassigned employees
                              for (final emp in taskVm.unassignedEmployees) {
                                final id = emp['uid'] ?? emp['emp_id'] ?? '';
                                if (_selectedMemberUids.contains(id) &&
                                    (emp['uid'] ?? '').isNotEmpty) {
                                  await taskVm.assignEmployeeToLead(
                                    emp['uid'],
                                    widget.lead.emp_id,
                                  );
                                }
                              }

                              // Combine both lists and filter by selection
                              final allEmployees = [
                                ...taskVm.members,
                                ...taskVm.unassignedEmployees,
                              ];
                              final selectedMembers = allEmployees
                                  .where(
                                    (m) => _selectedMemberUids.contains(
                                      m['uid'] ?? m['emp_id'] ?? '',
                                    ),
                                  )
                                  .toList();

                              final success = await taskVm.assignTask(
                                lead_id: widget.lead.emp_id,
                                leadName: widget.lead.name,
                                department: widget.lead.department,
                                title: _titleCtrl.text.trim(),
                                description: _descCtrl.text.trim(),
                                duration: _selectedDuration!,
                                members: selectedMembers,
                                taskType: _isPrimary
                                    ? 'primary'
                                    : 'secondary',
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CheckAssignedTasks(),
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
                      child: taskVm.isSubmitting
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
