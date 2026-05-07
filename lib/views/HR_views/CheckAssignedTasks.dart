import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hrms_app/viewmodels/task_viewmodel.dart';
import 'package:hrms_app/views/HR_views/hr_task_audit_screen.dart';
import 'package:hrms_app/widgets/edit_task_dialog.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
            tabs: [
              Tab(text: 'Priority Tasks'),
              Tab(text: 'Unscheduled Tasks'),
            ],
          ),
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
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
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

            // Separate tasks into Priority and Unscheduled
            final priorityTasks = taskVm.tasks
                .where((t) => t['unscheduled_task'] != true)
                .toList();
            final unscheduledTasks = taskVm.tasks
                .where((t) => t['unscheduled_task'] == true)
                .toList();

            return TabBarView(
              children: [
                _buildTaskGrid(priorityTasks),
                _buildTaskGrid(unscheduledTasks),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds a grid view for a specific list of tasks
  Widget _buildTaskGrid(List<Map<String, dynamic>> taskList) {
    if (taskList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 56, color: Color(0xFFCBD5E1)),
            SizedBox(height: 12),
            Text(
              'No tasks assigned in this category',
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200
            ? 4
            : width >= 768
            ? 3
            : 2;
        final aspectRatio = width >= 768 ? 0.78 : 0.72;

        return Padding(
          padding: EdgeInsets.all(width >= 768 ? 24 : 16),
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: aspectRatio,
            ),
            itemCount: taskList.length,
            itemBuilder: (context, index) {
              final task = taskList[index];
              return _buildTaskCard(context, task);
            },
          ),
        );
      },
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

    // Extract goals fields with fallbacks for naming variations
    final primaryGoal = task['description'] ?? task['description'];
    final primaryPdf = task['primaryGoalsPdf'] ?? task['primaryGoalPdf'];
    final normalGoal =
        task['secondaryDescription'] ?? task['secondaryDescription'];
    final normalPdf = task['normalGoalsPdf'] ?? task['normalGoalPdf'];

    final parentContext = context;
    final sheetWidth = MediaQuery.of(context).size.width;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: sheetWidth >= 768
          ? const BoxConstraints(maxWidth: 640, minWidth: 400)
          : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
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
                  const SizedBox(height: 24),

                  // ── GOALS SECTION ──
                  if ((primaryGoal != null &&
                          primaryGoal.toString().isNotEmpty) ||
                      (normalGoal != null &&
                          normalGoal.toString().isNotEmpty)) ...[
                    const Row(
                      children: [
                        Icon(
                          Icons.track_changes_rounded,
                          color: Color(0xFF334155),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Assigned Goals',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Primary Goal Card
                    if (primaryGoal != null &&
                        primaryGoal.toString().isNotEmpty)
                      _buildGoalCard(
                        context: context,
                        title: 'Primary Goal',
                        description: primaryGoal.toString(),
                        pdfUrl: primaryPdf?.toString(),
                        icon: Icons.star_rounded,
                        color: const Color(0xFF4F46E5), // Indigo
                        bgColor: const Color(0xFFEEF2FF),
                        borderColor: const Color(0xFFC7D2FE),
                      ),

                    if (normalGoal != null &&
                        normalGoal.toString().isNotEmpty) ...[
                      if (primaryGoal != null &&
                          primaryGoal.toString().isNotEmpty)
                        const SizedBox(height: 12),

                      // Normal Goal Card
                      _buildGoalCard(
                        context: context,
                        title: 'Normal Goal',
                        description: normalGoal.toString(),
                        pdfUrl: normalPdf?.toString(),
                        icon: Icons.flag_outlined,
                        color: const Color(0xFF0D9488), // Teal
                        bgColor: const Color(0xFFF0FDFA),
                        borderColor: const Color(0xFFCCFBF1),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],

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
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final url = task['submissionPdfUrl'].toString();
                            try {
                              await launchUrl(
                                Uri.parse(url),
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Could not open PDF: $e'),
                                  backgroundColor: const Color(0xFFEF4444),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.picture_as_pdf,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'View Submitted PDF',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
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
                              final taskVm = parentContext
                                  .read<TaskViewModel>();
                              Navigator.of(parentContext).pop();
                              final success = await taskVm.acceptSubmission(
                                task['id'],
                              );
                              if (success) {
                                taskVm.loadAllTasks();
                              }
                            },
                            icon: const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Accept',
                              style: TextStyle(color: Colors.white),
                            ),
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
                              Navigator.of(parentContext).pop();
                              _showRejectDialog(parentContext, task);
                            },
                            icon: const Icon(
                              Icons.cancel_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Reject',
                              style: TextStyle(color: Colors.white),
                            ),
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
                  else if (task['status'] == 'completed')
                    // Comparison view button for completed tasks
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(parentContext).pop();
                          _showComparisonView(parentContext, task);
                        },
                        icon: const Icon(
                          Icons.compare_arrows,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'View Comparison: Requirements vs Delivery',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    )
                  else
                    // Edit & History buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(parentContext).pop();
                              showDialog(
                                context: parentContext,
                                builder: (_) => EditTaskDialog(
                                  task: task,
                                  modifiedBy: 'HR',
                                  modifiedByRole: 'hr',
                                  onSaved: () {
                                    parentContext
                                        .read<TaskViewModel>()
                                        .loadAllTasks();
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
                              Navigator.of(parentContext).pop();
                              showTaskHistorySheet(parentContext, task);
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
                  if (task['schemaVersion'] == 2) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(parentContext).pop();
                          Navigator.of(parentContext).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  HRTaskAuditScreen(taskId: task['id']),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.fact_check_outlined,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                        label: const Text(
                          'Full Audit Timeline',
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
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Comparison view: original requirements vs final delivery
  void _showComparisonView(BuildContext context, Map<String, dynamic> task) {
    final members = task['members'] as Map<String, dynamic>? ?? {};
    final memberSubs =
        task['member_submissions'] as Map<String, dynamic>? ?? {};

    final compWidth = MediaQuery.of(context).size.width;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: compWidth >= 768
          ? const BoxConstraints(maxWidth: 700, minWidth: 400)
          : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.92,
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
                  const SizedBox(height: 16),

                  // Title
                  Row(
                    children: [
                      const Icon(
                        Icons.compare_arrows,
                        color: Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task['title'] ?? 'Untitled',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── ORIGINAL REQUIREMENTS ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 18,
                              color: Color(0xFF2563EB),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Original Requirements (HR)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          task['previousDescription'] != null &&
                                  task['previousDescription']
                                      .toString()
                                      .isNotEmpty
                              ? task['previousDescription'].toString()
                              : task['description'] ?? 'No description',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _infoChip(
                              Icons.schedule_outlined,
                              task['duration'] ?? '',
                            ),
                            _infoChip(
                              Icons.business_outlined,
                              task['department'] ?? '',
                            ),
                            if (task['taskType'] != null)
                              _infoChip(
                                Icons.category_outlined,
                                (task['taskType'] as String).toUpperCase(),
                              ),
                          ],
                        ),
                        // HR attachments
                        if ((task['attachments'] as List?)?.isNotEmpty ??
                            false) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Attached Files',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...(task['attachments'] as List).map((att) {
                            final a = att as Map<String, dynamic>;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: InkWell(
                                onTap: () async {
                                  try {
                                    await launchUrl(
                                      Uri.parse(a['url']),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } catch (_) {}
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      (a['type'] ?? '') == 'pdf'
                                          ? Icons.picture_as_pdf
                                          : Icons.attach_file,
                                      size: 14,
                                      color: (a['type'] ?? '') == 'pdf'
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF2563EB),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        a['name'] ?? 'File',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF2563EB),
                                          fontWeight: FontWeight.w500,
                                          decoration: TextDecoration.underline,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.open_in_new,
                                      size: 12,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Divider with arrow
                  const Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.arrow_downward,
                          color: Color(0xFF94A3B8),
                          size: 24,
                        ),
                        Text(
                          'DELIVERED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── FINAL DELIVERY ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: Color(0xFF16A34A),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Final Delivery (Lead)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (task['projectSummary'] != null &&
                            task['projectSummary'].toString().isNotEmpty) ...[
                          const Text(
                            'Project Summary',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            task['projectSummary'].toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF166534),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (task['submissionText'] != null &&
                            task['submissionText'].toString().isNotEmpty) ...[
                          const Text(
                            'Submission Details',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            task['submissionText'].toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF334155),
                              height: 1.5,
                            ),
                          ),
                        ],
                        if (task['submittedBy'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Submitted by ${task['submittedBy']}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                        if (task['submissionPdfUrl'] != null &&
                            task['submissionPdfUrl'].toString().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              try {
                                await launchUrl(
                                  Uri.parse(
                                    task['submissionPdfUrl'].toString(),
                                  ),
                                  mode: LaunchMode.externalApplication,
                                );
                              } catch (_) {}
                            },
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.picture_as_pdf,
                                  size: 16,
                                  color: Color(0xFFDC2626),
                                ),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'View Submitted PDF',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFDC2626),
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.open_in_new,
                                  size: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── MEMBER CONTRIBUTIONS ──
                  if (memberSubs.isNotEmpty) ...[
                    Text(
                      'Member Contributions (${memberSubs.length}/${members.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...members.entries.map((entry) {
                      final m = entry.value as Map<String, dynamic>;
                      final empId = (m['emp_id'] ?? '').toString();
                      Map<String, dynamic>? sub;
                      for (final key in memberSubs.keys) {
                        if (key.toLowerCase() == empId.toLowerCase()) {
                          sub = memberSubs[key] as Map<String, dynamic>?;
                          break;
                        }
                      }
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: sub != null
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sub != null
                                ? const Color(0xFFBBF7D0)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFFDBEAFE),
                                  child: Text(
                                    (m['name'] ?? '?')[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${m['name'] ?? 'Unknown'} ($empId)',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                if (sub != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD1FAE5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      (sub['status'] ?? 'submitted')
                                          .toString()
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (sub != null &&
                                (sub['submissionText'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                sub['submissionText'].toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            // Member's PDF
                            if (sub != null &&
                                (sub['pdfUrl'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...[
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  try {
                                    await launchUrl(
                                      Uri.parse(sub!['pdfUrl'].toString()),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  } catch (_) {}
                                },
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.picture_as_pdf,
                                      size: 14,
                                      color: Color(0xFFDC2626),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'View PDF',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFDC2626),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 16),
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
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFCBD5E1),
                ),
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              final taskVm = context.read<TaskViewModel>();
              Navigator.of(ctx).pop();
              final success = await taskVm.rejectSubmission(
                task['id'],
                reasonCtrl.text.trim(),
                leadEmpId: (task['lead_id'] ?? '').toString(),
              );
              if (success) {
                taskVm.loadAllTasks();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Helper to build a professional looking Goal Card
  Widget _buildGoalCard({
    required BuildContext context,
    required String title,
    required String description,
    required String? pdfUrl,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF334155),
              height: 1.5,
            ),
          ),
          if (pdfUrl != null && pdfUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                try {
                  await launchUrl(
                    Uri.parse(pdfUrl),
                    mode: LaunchMode.externalApplication,
                  );
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open PDF'),
                        backgroundColor: Color(0xFFEF4444),
                      ),
                    );
                  }
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.picture_as_pdf,
                      size: 16,
                      color: Color(0xFFDC2626),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'View Goal PDF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
