import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/task_viewmodel.dart';

/// A dialog that lets HR or Lead edit a task's title, description, duration, and status.
/// Shows original vs modified version after saving.
class EditTaskDialog extends StatefulWidget {
  final Map<String, dynamic> task;
  final String modifiedBy;
  final String modifiedByRole;

  /// Called after successful save so the parent can refresh its list.
  final VoidCallback? onSaved;

  const EditTaskDialog({
    super.key,
    required this.task,
    required this.modifiedBy,
    required this.modifiedByRole,
    this.onSaved,
  });

  @override
  State<EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<EditTaskDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _durationCtrl;
  late String _status;

  final _formKey = GlobalKey<FormState>();

  static const _statusOptions = ['pending', 'in progress', 'completed'];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task['title'] ?? '');
    _descCtrl = TextEditingController(text: widget.task['description'] ?? '');
    _durationCtrl = TextEditingController(text: widget.task['duration'] ?? '');
    _status = widget.task['status'] ?? 'pending';
    if (!_statusOptions.contains(_status)) _status = 'pending';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final taskVm = context.read<TaskViewModel>();
    final success = await taskVm.editTask(
      taskId: widget.task['id'],
      project_status_from_employeer:
          widget.task['project_status_from_employeer'],
      currentData: widget.task,
      newTitle: _titleCtrl.text.trim(),
      newDescription: _descCtrl.text.trim(),
      newDuration: _durationCtrl.text.trim(),
      newStatus: _status,
      modifiedBy: widget.modifiedBy,
      modifiedByRole: widget.modifiedByRole,
    );

    if (!mounted) return;

    if (success) {
      widget.onSaved?.call();
      Navigator.of(context).pop();
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
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Consumer<TaskViewModel>(
        builder: (context, taskVm, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(
                        Icons.edit_note_rounded,
                        color: Color(0xFF2563EB),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
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
                      // Version badge
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
                          'v${widget.task['version'] ?? 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Title
                  _buildLabel('Title'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: _inputDecoration('Enter task title'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  _buildLabel('Description'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: _inputDecoration('Enter description'),
                    maxLines: 3,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Duration
                  _buildLabel('Duration'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _durationCtrl,
                    decoration: _inputDecoration('e.g. 2 weeks'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Status dropdown
                  _buildLabel('Status'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: _inputDecoration(''),
                    items: _statusOptions
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              s[0].toUpperCase() + s.substring(1),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: taskVm.isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: taskVm.isSubmitting ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: taskVm.isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
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
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
    );
  }
}

/// A bottom sheet that shows all versions of a task (history + current).
void showTaskHistorySheet(
  BuildContext context,
  Map<String, dynamic> currentTask,
) {
  final taskVm = context.read<TaskViewModel>();
  taskVm.loadTaskHistory(currentTask['id']);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) {
          return Consumer<TaskViewModel>(
            builder: (ctx, vm, _) {
              final history = vm.taskHistory;
              final currentVersion = currentTask['version'] ?? 1;

              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
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
                    const Text(
                      'Version History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Current version (latest)
                    _versionCard(
                      version: currentVersion,
                      title: currentTask['title'] ?? '',
                      description: currentTask['description'] ?? '',
                      duration: currentTask['duration'] ?? '',
                      status: currentTask['status'] ?? '',
                      isCurrent: true,
                      modifiedBy: currentTask['lastModifiedBy'],
                      timestamp: currentTask['lastModifiedAt'] as Timestamp?,
                    ),

                    if (history.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Center(
                          child: Text(
                            'No previous versions',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      )
                    else
                      ...history.reversed.map(
                        (h) => _versionCard(
                          version: h['version'] ?? 0,
                          title: h['title'] ?? '',
                          description: h['description'] ?? '',
                          duration: h['duration'] ?? '',
                          status: h['status'] ?? '',
                          isCurrent: false,
                          modifiedBy: h['savedBy'],
                          timestamp: h['savedAt'] as Timestamp?,
                        ),
                      ),

                    // ─── Non-Submission Reasons ──────────────────────────
                    Builder(builder: (_) {
                      final reasons =
                          (currentTask['no_submission_reasons'] as List?) ??
                              [];
                      if (reasons.isEmpty) return const SizedBox.shrink();

                      // Sort by submittedAt descending (newest first)
                      final sorted = List<Map>.from(
                        reasons.whereType<Map>(),
                      );
                      sorted.sort((a, b) {
                        final at = a['submittedAt'] as Timestamp?;
                        final bt = b['submittedAt'] as Timestamp?;
                        if (at == null && bt == null) return 0;
                        if (at == null) return 1;
                        if (bt == null) return -1;
                        return bt.compareTo(at);
                      });

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          const Text(
                            'Non-Submission Reasons',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...sorted.map((r) => _reasonCard(r)),
                        ],
                      );
                    }),

                    const SizedBox(height: 16),
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

Widget _versionCard({
  required int version,
  required String title,
  required String description,
  required String duration,
  required String status,
  required bool isCurrent,
  String? modifiedBy,
  Timestamp? timestamp,
}) {
  final dateStr = timestamp != null
      ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year} ${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
      : '';

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isCurrent ? const Color(0xFFEFF6FF) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
        width: isCurrent ? 1.5 : 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isCurrent
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF94A3B8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isCurrent ? 'Current (v$version)' : 'v$version',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: status == 'completed'
                    ? const Color(0xFFD1FAE5)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status.isNotEmpty
                    ? status[0].toUpperCase() + status.substring(1)
                    : '',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: status == 'completed'
                      ? const Color(0xFF065F46)
                      : const Color(0xFF92400E),
                ),
              ),
            ),
            const Spacer(),
            if (dateStr.isNotEmpty)
              Text(
                dateStr,
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.schedule_outlined,
              size: 12,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(width: 4),
            Text(
              duration,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
            if (modifiedBy != null) ...[
              const Spacer(),
              Text(
                'by $modifiedBy',
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

Widget _reasonCard(Map r) {
  final empName = (r['empName'] ?? '').toString();
  final role = (r['role'] ?? '').toString();
  final reason = (r['reason'] ?? '').toString();
  final sentTo = (r['sentTo'] ?? '').toString();
  final forWeek = r['forWeek'];
  final ts = r['submittedAt'] as Timestamp?;
  final dateStr = ts != null
      ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year} ${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
      : '';

  final isLead = role == 'lead';
  final accentColor = isLead
      ? const Color(0xFF7C3AED)
      : const Color(0xFFB45309);
  final bgColor = isLead
      ? const Color(0xFFF5F3FF)
      : const Color(0xFFFFF7ED);

  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: accentColor.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                role.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (forWeek != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Week $forWeek',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            const Spacer(),
            if (dateStr.isNotEmpty)
              Text(
                dateStr,
                style:
                    const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          empName,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Sent to ${sentTo.toUpperCase()}',
          style: const TextStyle(
            fontSize: 10,
            fontStyle: FontStyle.italic,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          reason,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF374151),
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}
