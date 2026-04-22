import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';
import '../../widgets/edit_task_dialog.dart';

class EmployeeGoalsScreen extends StatefulWidget {
  const EmployeeGoalsScreen({super.key});

  @override
  State<EmployeeGoalsScreen> createState() => _EmployeeGoalsScreenState();
}

class _EmployeeGoalsScreenState extends State<EmployeeGoalsScreen> {
  String? _empId;
  bool _fetchingEmpId = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final user = context.read<AuthViewModel>().currentUser;
      if (user != null && user.role.toLowerCase().contains('lead')) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final empId = doc.data()?['emp_id'] ?? '';
        if (!mounted) return;
        setState(() {
          _empId = empId;
          _fetchingEmpId = false;
        });
        if (empId.isNotEmpty) {
          context.read<TaskViewModel>().loadTasksByLeadId(empId);
        }
      } else {
        if (!mounted) return;
        setState(() => _fetchingEmpId = false);
      }
    });
  }

  void _refreshTasks() {
    if (_empId != null) {
      context.read<TaskViewModel>().loadTasksByLeadId(_empId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthViewModel>().currentUser;

    if (_fetchingEmpId) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }

    if (user == null || !user.role.toLowerCase().contains('lead')) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 56, color: Color(0xFFCBD5E1)),
            SizedBox(height: 12),
            Text(
              'Only Project Leads can view assigned goals',
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _refreshTasks,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
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
                  Icon(Icons.flag_outlined, size: 56, color: Color(0xFFCBD5E1)),
                  SizedBox(height: 12),
                  Text(
                    'No goals assigned to you yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tasks assigned by HR will appear here',
                    style: TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'My Goals',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${taskVm.tasks.length} task${taskVm.tasks.length == 1 ? '' : 's'} assigned to you',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFBFDBFE),
                      ),
                    ),
                  ],
                ),
              ),

              // Task list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _empId != null
                      ? taskVm.loadTasksByLeadId(_empId!)
                      : Future.value(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: taskVm.tasks.length,
                    itemBuilder: (context, index) {
                      return _buildTaskCard(context, taskVm.tasks[index]);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Task Card ──────────────────────────────────────────────────────────────

  Widget _buildTaskCard(BuildContext context, Map<String, dynamic> task) {
    final status = (task['status'] ?? 'pending').toString();
    final isApproved = status == 'approved';
    final members = task['members'] as Map<String, dynamic>? ?? {};

    // Build the status label
    String statusLabel;
    Color statusBg;
    Color statusFg;

    if (isApproved) {
      final approvedAt = task['approvedAt'] as Timestamp?;
      final dateStr = approvedAt != null
          ? '${approvedAt.toDate().day}/${approvedAt.toDate().month}/${approvedAt.toDate().year}'
          : '';
      statusLabel = dateStr.isNotEmpty ? 'Approved since $dateStr' : 'Approved';
      statusBg = const Color(0xFFD1FAE5);
      statusFg = const Color(0xFF065F46);
    } else {
      statusLabel = status[0].toUpperCase() + status.substring(1);
      statusBg = const Color(0xFFFEF3C7);
      statusFg = const Color(0xFF92400E);
    }

    final createdAt = task['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isApproved ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showTaskDetails(context, task),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status + Duration + Options row
              Row(
                children: [
                  // Status badge
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isApproved)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.check_circle,
                                size: 12,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          Flexible(
                            child: Text(
                              statusLabel,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusFg,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Duration
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          size: 12,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task['duration'] ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Options menu (only if not yet approved)
                  if (!isApproved) _buildOptionsMenu(task),
                  if (isApproved)
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                task['title'] ?? 'Untitled',
                style: const TextStyle(
                  fontSize: 16,
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
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),

              // Department + Members
              Row(
                children: [
                  // _chipWidget(
                  //   Icons.business_outlined,
                  //   task['department'] ?? '',
                  // ),
                  const SizedBox(width: 8),
                  _chipWidget(
                    Icons.group_outlined,
                    '${members.length} members',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Options Popup (Edit / Approve) ─────────────────────────────────────────

  Widget _buildOptionsMenu(Map<String, dynamic> task) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF94A3B8)),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onSelected: (value) {
        if (value == 'edit') {
          _showTaskDetails(context, task, startInEditMode: true);
        } else if (value == 'approve') {
          _approveTask(task);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Edit Description'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'approve',
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 16,
                color: Color(0xFF16A34A),
              ),
              SizedBox(width: 8),
              Text('Approve'),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Approve Task ───────────────────────────────────────────────────────────

  Future<void> _approveTask(
    Map<String, dynamic> task, {
    String? newDescription,
  }) async {
    final user = context.read<AuthViewModel>().currentUser;
    final leadName = user?.name ?? 'Lead';

    final success = await context.read<TaskViewModel>().editTask(
      taskId: task['id'],
      currentData: task,
      newTitle: task['title'] ?? '',
      newDescription: newDescription ?? task['description'] ?? '',
      newDuration: task['duration'] ?? '',
      newStatus: 'approved',
      modifiedBy: leadName,
      modifiedByRole: 'project lead',
    );

    if (!mounted) return;

    if (success) {
      _refreshTasks();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task approved successfully'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<TaskViewModel>().errorMessage ?? 'Failed to approve',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── Bottom Sheet (Task Details + Editable Description + Approve) ───────────

  void _showTaskDetails(
    BuildContext context,
    Map<String, dynamic> task, {
    bool startInEditMode = false,
  }) {
    final members = task['members'] as Map<String, dynamic>? ?? {};
    final isAlreadyApproved = task['status'] == 'approved';

    bool isEditing = startInEditMode && !isAlreadyApproved;
    final descController = TextEditingController(
      text: task['description'] ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.3,
              maxChildSize: 0.85,
              expand: false,
              builder: (_, scrollController) {
                // Approved date string
                String? approvedDateStr;
                if (isAlreadyApproved) {
                  final approvedAt = task['approvedAt'] as Timestamp?;
                  if (approvedAt != null) {
                    final d = approvedAt.toDate();
                    approvedDateStr = '${d.day}/${d.month}/${d.year}';
                  }
                }

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
                          _detailChip(
                            Icons.person_outline,
                            task['leadName'] ?? '',
                          ),
                          _detailChip(
                            Icons.business_outlined,
                            task['department'] ?? '',
                          ),
                          _detailChip(
                            Icons.schedule_outlined,
                            task['duration'] ?? '',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Approved banner or pending badge
                      if (isAlreadyApproved)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 20,
                                color: Color(0xFF065F46),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      approvedDateStr != null
                                          ? 'Approved since $approvedDateStr'
                                          : 'Approved',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                    if (task['lastModifiedBy'] != null)
                                      Text(
                                        'by ${task['lastModifiedBy']} (${task['lastModifiedByRole'] ?? ''})',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Pending',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Description — editable or read-only
                      Row(
                        children: [
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const Spacer(),
                          if (!isAlreadyApproved && !isEditing)
                            GestureDetector(
                              onTap: () =>
                                  setSheetState(() => isEditing = true),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 14,
                                    color: Color(0xFF2563EB),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isEditing)
                            GestureDetector(
                              onTap: () {
                                descController.text = task['description'] ?? '';
                                setSheetState(() => isEditing = false);
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      if (isEditing)
                        TextField(
                          controller: descController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Update description...',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFCBD5E1),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                                width: 1.5,
                              ),
                            ),
                          ),
                        )
                      else
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
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        )
                      else
                        ...members.entries.map((entry) {
                          final m = entry.value as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
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

                      // Action buttons
                      if (!isAlreadyApproved)
                        Row(
                          children: [
                            // Approve button
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  _approveTask(
                                    task,
                                    newDescription: isEditing
                                        ? descController.text.trim()
                                        : null,
                                  );
                                },
                                icon: const Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Approve',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // History button
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFF2563EB),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        // Already approved — only show History
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              showTaskHistorySheet(context, task);
                            },
                            icon: const Icon(
                              Icons.history_rounded,
                              size: 16,
                              color: Color(0xFF2563EB),
                            ),
                            label: const Text(
                              'View History',
                              style: TextStyle(color: Color(0xFF2563EB)),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
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

  // ─── Helper widgets ─────────────────────────────────────────────────────────

  Widget _chipWidget(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailChip(IconData icon, String text) {
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
