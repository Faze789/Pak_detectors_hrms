import 'package:flutter/material.dart';
import 'package:hrms_app/viewmodels/task_viewmodel.dart';
import 'package:provider/provider.dart';

class EditTaskDialog extends StatefulWidget {
  final Map<String, dynamic> task;
  final String modifiedBy;
  final String modifiedByRole;
  final VoidCallback onSaved;

  const EditTaskDialog({
    super.key,
    required this.task,
    required this.modifiedBy,
    required this.modifiedByRole,
    required this.onSaved,
  });

  @override
  State<EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<EditTaskDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _primaryGoalCtrl;
  late TextEditingController _normalGoalCtrl;
  late String _selectedDuration;
  late String _selectedStatus;

  /// Working copy of the task's members ({name, emp_id}). Edited in place by
  /// HR and written back via [TaskViewModel.updateTaskMembers] on save.
  late List<Map<String, dynamic>> _members;

  String get _leadId => (widget.task['lead_id'] ?? '').toString().toLowerCase();

  final List<String> _durations = [
    'weekly',
    'bi-weekly',
    'monthly',
    'bi-monthly',
    'quarterly',
  ];

  final List<String> _statuses = [
    'pending',
    'approved',
    'submitted',
    'completed',
  ];

  /// A priority task is one where unscheduled_task == false (or null/absent)
  bool get _isPriorityTask => widget.task['unscheduled_task'] != true;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task['title'] ?? '');
    _descCtrl = TextEditingController(text: widget.task['description'] ?? '');

    // Goals — support both naming variants used across the codebase
    _primaryGoalCtrl = TextEditingController(
      text: (widget.task['description'] ?? widget.task['description'] ?? ''),
    );
    _normalGoalCtrl = TextEditingController(
      text:
          (widget.task['secondaryDescription'] ??
          widget.task['secondaryDescription'] ??
          ''),
    );

    _selectedDuration = widget.task['duration'] ?? _durations.first;
    if (!_durations.contains(_selectedDuration)) {
      _selectedDuration = _durations.first;
    }

    _selectedStatus = widget.task['status'] ?? _statuses.first;
    if (!_statuses.contains(_selectedStatus)) {
      _selectedStatus = _statuses.first;
    }

    // Seed the editable member list from the task's `members` map.
    _members = [];
    final rawMembers = widget.task['members'] as Map<String, dynamic>? ?? {};
    for (final v in rawMembers.values) {
      if (v is Map<String, dynamic>) {
        _members.add({
          'name': (v['name'] ?? '').toString(),
          'emp_id': (v['emp_id'] ?? '').toString(),
        });
      }
    }
    // Load the full (non-HR) user list for the add-member picker.
    context.read<TaskViewModel>().loadAllNonHRUsers();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _primaryGoalCtrl.dispose();
    _normalGoalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title and description cannot be empty.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A task must have at least one member.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final taskVm = context.read<TaskViewModel>();

    // Persist the updated member list first so the audit history (written
    // inside editTask) snapshots the prior state and the new write reflects
    // HR's latest team change.
    final membersMap = <String, dynamic>{};
    for (int i = 0; i < _members.length; i++) {
      membersMap['${i + 1}'] = {
        'name': _members[i]['name'] ?? '',
        'emp_id': _members[i]['emp_id'] ?? '',
      };
    }
    await taskVm.updateTaskMembers(
      taskId: widget.task['id'],
      membersMap: membersMap,
    );

    final success = await taskVm.editTask(
      taskId: widget.task['id'],
      currentData: widget.task,
      project_status_from_employeer:
          widget.task['project_status_from_employee'] ?? 'pending',
      newTitle: title,
      newDescription: desc,
      newDuration: _selectedDuration,
      newStatus: _selectedStatus,
      modifiedBy: widget.modifiedBy,
      modifiedByRole: widget.modifiedByRole,
      // Pass updated goals only for priority tasks
      newPrimaryGoal: _isPriorityTask ? _primaryGoalCtrl.text.trim() : null,
      newNormalGoal: _isPriorityTask ? _normalGoalCtrl.text.trim() : null,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task updated successfully'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(taskVm.errorMessage ?? 'Failed to update task'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Edit Task',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Title ────────────────────────────────────────────
              _label('Task Title'),
              const SizedBox(height: 6),
              _textField(controller: _titleCtrl, hint: 'Enter task title'),
              const SizedBox(height: 16),

              // ── Description ──────────────────────────────────────
              _label('Description'),
              const SizedBox(height: 6),
              _textField(
                controller: _descCtrl,
                hint: 'Enter task description',
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // ── Goals Section (Priority tasks only) ──────────────
              if (_isPriorityTask) ...[
                const Divider(height: 24, color: Color(0xFFE2E8F0)),

                // Section header
                Row(
                  children: [
                    const Icon(
                      Icons.track_changes_rounded,
                      size: 18,
                      color: Color(0xFF334155),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Task Goals',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Priority Task',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Primary Goal card
                _buildGoalField(
                  label: 'Primary Goal',
                  controller: _primaryGoalCtrl,
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFF4F46E5),
                  bgColor: const Color(0xFFEEF2FF),
                  borderColor: const Color(0xFFC7D2FE),
                  hint: 'Describe the primary goal for this task...',
                ),
                const SizedBox(height: 12),

                // Normal Goal card
                _buildGoalField(
                  label: 'Normal Goal',
                  controller: _normalGoalCtrl,
                  icon: Icons.flag_outlined,
                  iconColor: const Color(0xFF0D9488),
                  bgColor: const Color(0xFFF0FDFA),
                  borderColor: const Color(0xFFCCFBF1),
                  hint: 'Describe the normal / secondary goal...',
                ),

                const Divider(height: 24, color: Color(0xFFE2E8F0)),
              ],

              // ── Team Members ─────────────────────────────────────
              _buildMembersSection(),

              // ── Duration ─────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Duration'),
                        const SizedBox(height: 6),
                        _dropdown(
                          value: _selectedDuration,
                          items: _durations,
                          onChanged: (v) =>
                              setState(() => _selectedDuration = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Status'),
                        const SizedBox(height: 6),
                        _dropdown(
                          value: _selectedStatus,
                          items: _statuses,
                          onChanged: (v) =>
                              setState(() => _selectedStatus = v!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Save button ──────────────────────────────────────
              Consumer<TaskViewModel>(
                builder: (context, taskVm, _) => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: taskVm.isSubmitting ? null : _save,
                    icon: taskVm.isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.save_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
                    label: Text(
                      taskVm.isSubmitting ? 'Saving...' : 'Save Changes',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Members editor (HR can add/remove; lead is locked) ─────────
  Widget _buildMembersSection() {
    return Consumer<TaskViewModel>(
      builder: (context, taskVm, _) {
        final addedIds = _members
            .map((m) => (m['emp_id'] ?? '').toString().toLowerCase())
            .toSet();
        final available = taskVm.allUsers
            .where(
              (u) => !addedIds.contains(
                (u['emp_id'] ?? '').toString().toLowerCase(),
              ),
            )
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.group_outlined,
                  size: 18,
                  color: Color(0xFF334155),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Team Members',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_members.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_members.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'No members — add at least one.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _members.map((m) {
                  final empId = (m['emp_id'] ?? '').toString();
                  final isLead = empId.toLowerCase() == _leadId;
                  return Chip(
                    label: Text(
                      '${m['name']}${isLead ? ' (Lead)' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: isLead
                        ? const Color(0xFFDBEAFE)
                        : const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isLead
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFFE2E8F0),
                    ),
                    deleteIcon: isLead
                        ? null
                        : const Icon(Icons.close, size: 16),
                    onDeleted: isLead
                        ? null
                        : () => setState(
                            () => _members.removeWhere(
                              (x) =>
                                  (x['emp_id'] ?? '').toString() == empId,
                            ),
                          ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: null,
                  isExpanded: true,
                  hint: Text(
                    available.isEmpty
                        ? (taskVm.allUsers.isEmpty
                              ? 'Loading users...'
                              : 'All users already added')
                        : '+ Add member',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  items: available.map((u) {
                    final empId = (u['emp_id'] ?? '').toString();
                    final dept = (u['department'] ?? u['role'] ?? '')
                        .toString();
                    return DropdownMenuItem<String>(
                      value: empId,
                      child: Text(
                        '${u['name'] ?? 'Unknown'}${dept.isEmpty ? '' : ' · $dept'}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: available.isEmpty
                      ? null
                      : (empId) {
                          if (empId == null) return;
                          final u = taskVm.allUsers.firstWhere(
                            (x) => (x['emp_id'] ?? '').toString() == empId,
                            orElse: () => <String, dynamic>{},
                          );
                          if (u.isEmpty) return;
                          setState(
                            () => _members.add({
                              'name': (u['name'] ?? '').toString(),
                              'emp_id': empId,
                            }),
                          );
                        },
                ),
              ),
            ),
            const Divider(height: 24, color: Color(0xFFE2E8F0)),
          ],
        );
      },
    );
  }

  // ── Goal field widget ──────────────────────────────────────────
  Widget _buildGoalField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFFCBD5E1),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: iconColor, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────
  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Color(0xFF475569),
    ),
  );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) => TextField(
    controller: controller,
    maxLines: maxLines,
    style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    ),
  );

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
        items: items
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(
                  e[0].toUpperCase() + e.substring(1),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

// ── Task History Sheet ─────────────────────────────────────────────────────

void showTaskHistorySheet(BuildContext context, Map<String, dynamic> task) {
  final taskVm = context.read<TaskViewModel>();
  taskVm.loadTaskHistory(task['id']);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) {
          return Consumer<TaskViewModel>(
            builder: (context, vm, _) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.history_rounded, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text(
                          'Task History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (vm.taskHistory.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No history available',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      )
                    else
                      ...vm.taskHistory.map((h) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
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
                                      'v${h['version'] ?? 1}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      h['title'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if ((h['description'] ?? '').isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  h['description'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                'Saved by ${h['savedBy'] ?? 'unknown'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}
