import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hrms_app/viewmodels/task_viewmodel.dart';
import 'package:hrms_app/widgets/edit_task_dialog.dart';
import 'package:provider/provider.dart';

class CheckAssignedTasks extends StatefulWidget {
  const CheckAssignedTasks({super.key});

  @override
  State<CheckAssignedTasks> createState() => _CheckAssignedTasksState();
}

class _CheckAssignedTasksState extends State<CheckAssignedTasks> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<TaskViewModel>().loadAllTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Assigned Tasks',
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
          if (taskVm.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            );
          }

          if (taskVm.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    taskVm.errorMessage!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (taskVm.tasks.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 56,
                    color: Color(0xFFCBD5E1),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No tasks assigned yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: taskVm.tasks.length,
              itemBuilder: (context, index) {
                final task = taskVm.tasks[index];
                return _buildTaskCard(context, task);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, Map<String, dynamic> task) {
    final status = task['status'] ?? 'pending';
    final isCompleted = status == 'completed';
    final isApproved = status == 'approved';
    final isSubmitted = status == 'submitted';
    final members = task['members'] as Map<String, dynamic>? ?? {};
    final createdAt = task['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
        : '';

    // Calculate remaining days
    final deadline = task['deadline'] as Timestamp?;
    final int? remainingDays = deadline
        ?.toDate()
        .difference(DateTime.now())
        .inDays;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showTaskDetails(context, task),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status badge + duration
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFFD1FAE5)
                          : isSubmitted
                              ? const Color(0xFFEDE9FE)
                              : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isCompleted
                            ? const Color(0xFF065F46)
                            : isSubmitted
                                ? const Color(0xFF6D28D9)
                                : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    task['duration'] ?? '',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                task['title'] ?? 'Untitled',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),

              // Description
              Text(
                task['description'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const Spacer(),

              // Lead name
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: const Color(0xFFDBEAFE),
                    child: Text(
                      (task['leadName'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task['leadName'] ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
              // Remaining days
              if (remainingDays != null && !isApproved && !isCompleted) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: remainingDays <= 0
                          ? const Color(0xFFDC2626)
                          : remainingDays <= 3
                          ? const Color(0xFFD97706)
                          : const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      remainingDays > 0
                          ? '$remainingDays day${remainingDays == 1 ? '' : 's'} left'
                          : remainingDays == 0
                          ? 'Due today'
                          : 'Overdue by ${-remainingDays} day${remainingDays == -1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: remainingDays <= 0
                            ? const Color(0xFFDC2626)
                            : remainingDays <= 3
                            ? const Color(0xFFD97706)
                            : const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),

              // Members count + date
              Row(
                children: [
                  const Icon(
                    Icons.group_outlined,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${members.length} members',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows full task details in a bottom sheet when a card is tapped
  void _showTaskDetails(BuildContext context, Map<String, dynamic> task) {
    final members = task['members'] as Map<String, dynamic>? ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
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
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    task['title'] ?? 'Untitled',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _infoChip(Icons.person_outline, task['leadName'] ?? ''),
                      _infoChip(
                        Icons.business_outlined,
                        task['department'] ?? '',
                      ),
                      _infoChip(
                        Icons.schedule_outlined,
                        task['duration'] ?? '',
                      ),
                      _infoChip(
                        Icons.flag_outlined,
                        (task['status'] ?? 'pending').toString().toUpperCase(),
                      ),
                      if (task['taskType'] != null)
                        _infoChip(
                          Icons.category_outlined,
                          (task['taskType'] as String).toUpperCase(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Previous Description (if task was modified)
                  if (task['previousDescription'] != null &&
                      task['previousDescription'].toString().isNotEmpty &&
                      task['previousDescription'] != task['description']) ...[
                    const Text(
                      'Previous Description',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(
                        task['previousDescription'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF991B1B),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Description
                  Text(
                    task['previousDescription'] != null &&
                            task['previousDescription'].toString().isNotEmpty &&
                            task['previousDescription'] != task['description']
                        ? 'Modified Description'
                        : 'Description',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    task['description'] ?? 'No description',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Members
                  Text(
                    'Team Members (${members.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (members.isEmpty)
                    const Text(
                      'No members assigned',
                      style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    )
                  else
                    ...members.entries.map((entry) {
                      final m = entry.value as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFFDBEAFE),
                              child: Text(
                                (m['name'] ?? '?')[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                m['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
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
                                m['emp_id'] ?? '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 20),

                  // Submission details (if submitted or completed)
                  if (task['projectSummary'] != null &&
                      task['projectSummary'].toString().isNotEmpty) ...[
                    const Text(
                      'Project Summary',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Text(
                        task['projectSummary'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (task['submissionText'] != null &&
                      task['submissionText'].toString().isNotEmpty) ...[
                    const Text(
                      'Submission Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        task['submissionText'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (task['submittedBy'] != null)
                      Text(
                        'Submitted by ${task['submittedBy']}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    if (task['submissionPdfUrl'] != null &&
                        task['submissionPdfUrl'].toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFFDC2626)),
                          const SizedBox(width: 4),
                          const Text(
                            'PDF attached',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],

                  // Rejection reason (if task was rejected before)
                  if (task['rejectionReason'] != null &&
                      task['rejectionReason'].toString().isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Previous Rejection Reason',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            task['rejectionReason'],
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Accept/Reject for submitted tasks
                  if (task['status'] == 'submitted')
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              final success = await context
                                  .read<TaskViewModel>()
                                  .acceptSubmission(task['id']);
                              if (success) {
                                context.read<TaskViewModel>().loadAllTasks();
                              }
                            },
                            icon: const Icon(Icons.check_circle, size: 16, color: Colors.white),
                            label: const Text('Accept', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showRejectDialog(context, task);
                            },
                            icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.white),
                            label: const Text('Reject', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    // Edit & History buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              showDialog(
                                context: context,
                                builder: (_) => EditTaskDialog(
                                  task: task,
                                  modifiedBy: 'HR',
                                  modifiedByRole: 'hr',
                                  onSaved: () {
                                    context.read<TaskViewModel>().loadAllTasks();
                                  },
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Edit',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              showTaskHistorySheet(context, task);
                            },
                            icon: const Icon(
                              Icons.history_rounded,
                              size: 16,
                              color: Color(0xFF2563EB),
                            ),
                            label: const Text(
                              'History',
                              style: TextStyle(color: Color(0xFF2563EB)),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRejectDialog(BuildContext context, Map<String, dynamic> task) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Reject Submission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Provide a reason for rejection:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason for rejection...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              final success = await context
                  .read<TaskViewModel>()
                  .rejectSubmission(task['id'], reasonCtrl.text.trim());
              if (success) {
                context.read<TaskViewModel>().loadAllTasks();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF2563EB)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }
}
