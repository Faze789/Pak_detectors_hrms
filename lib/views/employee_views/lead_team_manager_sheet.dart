import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';

/// Bottom sheet that lets the lead add/remove members for a task.
///
/// Spec §2 option 1: "Edit the member list: add or remove members.
/// Validation: at least one member must remain selected. The screen cannot
/// be saved with zero members."
///
/// On save, writes the new `members` map to the task and logs a
/// `lead_team_change` event via [TaskViewModel.leadUpdateMembers].
Future<bool?> showLeadTeamManagerSheet(
  BuildContext context,
  Map<String, dynamic> task,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LeadTeamManagerSheet(task: task),
  );
}

class _LeadTeamManagerSheet extends StatefulWidget {
  const _LeadTeamManagerSheet({required this.task});
  final Map<String, dynamic> task;

  @override
  State<_LeadTeamManagerSheet> createState() => _LeadTeamManagerSheetState();
}

class _LeadTeamManagerSheetState extends State<_LeadTeamManagerSheet> {
  final Set<String> _selectedEmpIds = {};
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final raw =
        widget.task['members'] as Map<String, dynamic>? ?? <String, dynamic>{};
    for (final v in raw.values) {
      if (v is Map<String, dynamic>) {
        final id = (v['emp_id'] ?? '').toString();
        if (id.isNotEmpty) _selectedEmpIds.add(id);
      }
    }
    Future.microtask(() async {
      if (!mounted) return;
      await context.read<TaskViewModel>().loadAllNonHRUsers();
      if (mounted) setState(() => _loaded = true);
    });
  }

  Map<String, dynamic> _buildMembersMap(List<Map<String, dynamic>> users) {
    final ordered = users
        .where((u) => _selectedEmpIds.contains((u['emp_id'] ?? '').toString()))
        .toList();
    final map = <String, dynamic>{};
    for (var i = 0; i < ordered.length; i++) {
      map['${i + 1}'] = {
        'name': ordered[i]['name'] ?? '',
        'emp_id': ordered[i]['emp_id'] ?? '',
      };
    }
    return map;
  }

  Future<void> _save() async {
    if (_selectedEmpIds.isEmpty) {
      _snack('At least one member is required.', error: true);
      return;
    }
    setState(() => _saving = true);
    final taskVm = context.read<TaskViewModel>();
    final user = context.read<AuthViewModel>().currentUser;
    final newMembers = _buildMembersMap(taskVm.allUsers);
    final ok = await taskVm.leadUpdateMembers(
      taskId: widget.task['id'],
      previousMembers:
          widget.task['members'] as Map<String, dynamic>? ??
          <String, dynamic>{},
      newMembers: newMembers,
      leadEmpId: (widget.task['lead_id'] ?? user?.uid ?? '').toString(),
      leadName: user?.name ?? 'Lead',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop(true);
      _snack('Team updated.');
    } else {
      _snack(taskVm.errorMessage ?? 'Failed to update team.', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error
            ? const Color(0xFFEF4444)
            : const Color(0xFF16A34A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.group_outlined,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Manage Team',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedEmpIds.isEmpty
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_selectedEmpIds.length} selected',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _selectedEmpIds.isEmpty
                              ? const Color(0xFFB91C1C)
                              : const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'At least one member must remain selected.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              // List
              Expanded(
                child: Consumer<TaskViewModel>(
                  builder: (context, vm, _) {
                    if (!_loaded) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final users = vm.allUsers;
                    if (users.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No users available.',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollCtrl,
                      itemCount: users.length,
                      itemBuilder: (_, i) {
                        final u = users[i];
                        final empId = (u['emp_id'] ?? '').toString();
                        final selected = _selectedEmpIds.contains(empId);
                        return CheckboxListTile(
                          value: selected,
                          activeColor: const Color(0xFF2563EB),
                          title: Text(
                            u['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: Text(
                            '$empId · ${u['department'] ?? u['role'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedEmpIds.add(empId);
                              } else {
                                _selectedEmpIds.remove(empId);
                              }
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              // Save button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: (_saving || _selectedEmpIds.isEmpty)
                          ? null
                          : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        disabledBackgroundColor: const Color(0xFF93C5FD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Team',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
