import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:hrms_app/views/lead_employee_chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
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
      if (user == null) {
        if (!mounted) return;
        setState(() => _fetchingEmpId = false);
        return;
      }

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
        final taskVm = context.read<TaskViewModel>();
        // Load all tasks where user is lead OR member
        taskVm.loadTasksForUser(empId);
        taskVm.loadMembersByLeadId(empId);
        taskVm.loadUnassignedEmployees();
      }
    });
  }

  /// Check if current user is the lead for a specific task
  bool _isLeadForTask(Map<String, dynamic> task) {
    final taskLeadId = (task['lead_id'] ?? '').toString().toLowerCase();
    final currentEmpId = (_empId ?? '').toLowerCase();
    return taskLeadId.isNotEmpty &&
        currentEmpId.isNotEmpty &&
        taskLeadId == currentEmpId;
  }

  /// Check if current user (as member) has already submitted work for this task
  bool _hasMemberSubmitted(Map<String, dynamic> task) {
    final submissions =
        task['member_submissions'] as Map<String, dynamic>? ?? {};
    final currentEmpId = (_empId ?? '').toLowerCase();
    return submissions.keys.any((k) => k.toLowerCase() == currentEmpId);
  }

  void _refreshTasks() {
    if (_empId == null) return;
    final taskVm = context.read<TaskViewModel>();
    taskVm.loadTasksForUser(_empId!);
  }

  Future<void> _requestTaskAssignment() async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null || _empId == null) return;

    // Find all HR users and notify them
    final hrUsers = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'hr')
        .get();

    for (final doc in hrUsers.docs) {
      final hrEmpId = doc.data()['emp_id'] ?? doc.id;
      await FirebaseFirestore.instance.collection('task_notifications').add({
        'lead_id': hrEmpId,
        'title': 'Task Request',
        'body': '${user.name} (${_empId}) is requesting a task assignment',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Task request sent to HR'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthViewModel>().currentUser;

    if (_fetchingEmpId) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }

    if (user == null) {
      return const Center(
        child: Text(
          'Please log in to view goals',
          style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8)),
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
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flag_outlined, size: 56, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 12),
                  const Text(
                    'No goals assigned to you yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tasks assigned by HR will appear here',
                    style: TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _requestTaskAssignment(),
                    icon: const Icon(Icons.add_task, size: 18, color: Colors.white),
                    label: const Text(
                      'Request Task Assignment',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
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
                  onRefresh: () {
                    if (_empId == null) return Future.value();
                    return taskVm.loadTasksForUser(_empId!);
                  },
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
    final isLead = _isLeadForTask(task);

    // Build the status label
    String statusLabel;
    Color statusBg;
    Color statusFg;

    if (status == 'completed') {
      statusLabel = 'Completed';
      statusBg = const Color(0xFFD1FAE5);
      statusFg = const Color(0xFF065F46);
    } else if (status == 'submitted') {
      statusLabel = 'Submitted';
      statusBg = const Color(0xFFEDE9FE);
      statusFg = const Color(0xFF6D28D9);
    } else if (isApproved) {
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

    // Calculate remaining days
    final deadline = task['deadline'] as Timestamp?;
    final int? remainingDays = deadline
        ?.toDate()
        .difference(DateTime.now())
        .inDays;

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
                  // Role badge — LEAD or MEMBER
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isLead
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLead ? Icons.star_rounded : Icons.person_outline,
                          size: 12,
                          color: isLead
                              ? const Color(0xFF92400E)
                              : const Color(0xFF6D28D9),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isLead ? 'LEAD' : 'MEMBER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isLead
                                ? const Color(0xFF92400E)
                                : const Color(0xFF6D28D9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Options menu (lead only, not approved)
                  if (isLead && !isApproved) _buildOptionsMenu(task),
                  if (!isLead || isApproved)
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

              // Remaining days countdown
              if (remainingDays != null && !isApproved) ...[
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
              const SizedBox(height: 12),

              // Lead info (for employees)
              if (!isLead && task['leadName'] != null) ...[
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
                        'Lead: ${task['leadName']}',
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
                const SizedBox(height: 8),
              ],

              // Members + Task type
              Row(
                children: [
                  _chipWidget(
                    Icons.group_outlined,
                    '${members.length} members',
                  ),
                  if (task['taskType'] != null) ...[
                    const SizedBox(width: 8),
                    _chipWidget(
                      Icons.category_outlined,
                      (task['taskType'] as String).toUpperCase(),
                    ),
                    SizedBox(width: 30),
                    isLead
                        ? Row(
                            children: [
                              feed_back_button(
                                TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF2563EB),
                                ),
                                Icons.feedback_outlined,
                                'Feedback',
                                () => _showFeedbackMemberPicker(context, task),
                              ),

                              //  check_status ? status(
                              //           TextStyle(fontSize: 11, color: Color(0xFF2563EB)),
                              //           Icons.check_circle_outline,
                              //           'Approved',
                              //           () {
                              //             _approveTask(task);
                              //             Navigator.pop(context);
                              //           },
                              //         )
                            ],
                          )
                        : feed_back_button(
                            TextStyle(fontSize: 11, color: Color(0xFF2563EB)),
                            Icons.feedback_outlined,
                            'Send a query',
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LeadEmployeeChatScreen(
                                    taskId: task['id'] ?? '',
                                    taskTitle: task['title'] ?? '',
                                    leadEmpId: task['lead_id'] ?? '',
                                    leadName: task['leadName'] ?? '',
                                    employeeEmpId: _empId ?? '',
                                    employeeName:
                                        context
                                            .read<AuthViewModel>()
                                            .currentUser
                                            ?.name ??
                                        '',
                                    currentUserEmpId: _empId ?? '',
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ],
              ),

              // Submit section for approved tasks
              if (isApproved && status != 'submitted' && status != 'completed') ...[
                const SizedBox(height: 10),
                Builder(builder: (_) {
                  if (isLead) {
                    final isOverdue = remainingDays != null && remainingDays < 0;
                    if (isOverdue) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Text(
                          'Deadline passed — cannot submit',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      );
                    }
                    // Lead: show member submissions + Submit Task to HR
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _showMemberSubmissions(context, task['id']),
                              icon: const Icon(Icons.assignment_turned_in,
                                  size: 14, color: Color(0xFF2563EB)),
                              label: const Text(
                                'View Member Submissions',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                side: const BorderSide(
                                    color: Color(0xFF2563EB)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _showSubmitDialog(context, task),
                            icon: const Icon(Icons.upload_file,
                                size: 16, color: Colors.white),
                            label: const Text(
                              'Submit Task to HR',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Member: check if already submitted
                    if (_hasMemberSubmitted(task)) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Submitted to Lead',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      );
                    }
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showSubmitDialog(context, task),
                        icon: const Icon(Icons.upload_file,
                            size: 16, color: Colors.white),
                        label: const Text(
                          'Submit Work',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    );
                  }
                }),
              ],

              // Show submitted badge
              if (status == 'submitted') ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Submitted — Awaiting HR Review',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6D28D9),
                    ),
                  ),
                ),
              ],

              // Show completed badge
              if (status == 'completed') ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Completed',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget feed_back_button(
    TextStyle textStyle,
    IconData icon,
    String label,
    VoidCallback onPressed,
  ) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 12, color: const Color(0xFF2563EB)),
      label: Text(label, style: textStyle),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        side: const BorderSide(color: Color(0xFF2563EB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  // ─── Feedback Member Picker (Lead picks which member to chat with) ────────

  void _showFeedbackMemberPicker(
    BuildContext context,
    Map<String, dynamic> task,
  ) {
    final members = task['members'] as Map<String, dynamic>? ?? {};
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No members assigned to this task'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const Text(
                'Select Member to Chat',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              ...members.entries.map((entry) {
                final m = entry.value as Map<String, dynamic>;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFDBEAFE),
                    child: Text(
                      (m['name'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  title: Text(
                    m['name'] ?? 'Unknown',
                    style: const TextStyle(
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
                  trailing: const Icon(
                    Icons.chat_outlined,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LeadEmployeeChatScreen(
                          taskId: task['id'] ?? '',
                          taskTitle: task['title'] ?? '',
                          leadEmpId: task['lead_id'] ?? '',
                          leadName: task['leadName'] ?? '',
                          employeeEmpId: m['emp_id'] ?? '',
                          employeeName: m['name'] ?? '',
                          currentUserEmpId: _empId ?? '',
                        ),
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ─── Member Submissions View (Lead only) ────────────────────────────────────

  void _showMemberSubmissions(BuildContext context, String taskId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('tasks')
                  .doc(taskId)
                  .get(),
              builder: (ctx, snapshot) {
                // Loading state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 250,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  );
                }

                // Error / not found
                if (snapshot.hasError) {
                  return SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'Error loading submissions: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: Text('Task not found')),
                  );
                }

                final freshTask = snapshot.data!.data()!;
                final memberSubs = freshTask['member_submissions']
                        as Map<String, dynamic>? ??
                    {};
                final members =
                    freshTask['members'] as Map<String, dynamic>? ?? {};

                return Padding(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                            'Member Submissions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${memberSubs.length} of ${members.length} members submitted',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (members.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No members assigned to this task',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            )
                          else
                            ...members.entries.map((entry) {
                              final m =
                                  entry.value as Map<String, dynamic>;
                              final empId =
                                  (m['emp_id'] ?? '').toString();
                              // Case-insensitive lookup
                              Map<String, dynamic>? sub;
                              for (final key in memberSubs.keys) {
                                if (key.toLowerCase() ==
                                    empId.toLowerCase()) {
                                  sub = memberSubs[key]
                                      as Map<String, dynamic>?;
                                  break;
                                }
                              }
                              final hasSubmitted = sub != null;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: hasSubmitted
                                      ? const Color(0xFFF0FDF4)
                                      : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: hasSubmitted
                                        ? const Color(0xFFA7F3D0)
                                        : const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor:
                                              const Color(0xFFDBEAFE),
                                          child: Text(
                                            (m['name'] ?? '?')[0]
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2563EB),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                m['name'] ?? 'Unknown',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  color:
                                                      Color(0xFF1E293B),
                                                ),
                                              ),
                                              Text(
                                                empId,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: hasSubmitted
                                                ? const Color(0xFFD1FAE5)
                                                : const Color(0xFFFEF3C7),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            hasSubmitted
                                                ? 'Submitted'
                                                : 'Pending',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: hasSubmitted
                                                  ? const Color(
                                                      0xFF065F46)
                                                  : const Color(
                                                      0xFF92400E),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (hasSubmitted) ...[
                                      const SizedBox(height: 10),
                                      const Divider(height: 1),
                                      const SizedBox(height: 10),
                                      Text(
                                        sub['submissionText'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF475569),
                                          height: 1.4,
                                        ),
                                      ),
                                      if ((sub['pdfUrl'] ?? '')
                                          .toString()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        GestureDetector(
                                          onTap: () async {
                                            final uri = Uri.parse(
                                                sub!['pdfUrl']);
                                            if (await canLaunchUrl(
                                                uri)) {
                                              await launchUrl(uri,
                                                  mode: LaunchMode
                                                      .externalApplication);
                                            }
                                          },
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  const Color(0xFFFEF2F2),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      8),
                                              border: Border.all(
                                                color: const Color(
                                                    0xFFFECACA),
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize:
                                                  MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.picture_as_pdf,
                                                  size: 16,
                                                  color:
                                                      Color(0xFFDC2626),
                                                ),
                                                SizedBox(width: 6),
                                                Text(
                                                  'View PDF',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: Color(
                                                        0xFFDC2626),
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                                Icon(
                                                  Icons.open_in_new,
                                                  size: 12,
                                                  color:
                                                      Color(0xFFDC2626),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
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
      project_status_from_employeer: 'pending',
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

  // ─── Submit Task Dialog ──────────────────────────────────────────────────────

  void _showSubmitDialog(BuildContext context, Map<String, dynamic> task) {
    final isLead = _isLeadForTask(task);
    final summaryCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    String? pickedFileName;
    String? pickedFilePath;
    Uint8List? pickedFileBytes;
    bool uploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    Text(
                      isLead ? 'Submit Task' : 'Submit Work',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Project Summary (lead only)
                    if (isLead) ...[
                      const Text(
                        'Project Summary',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: summaryCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Write a summary of the project...',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFCBD5E1),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Submission text
                    const Text(
                      'Submission Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: textCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Describe what you have done...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFCBD5E1),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // PDF picker
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf'],
                          withData: true,
                        );
                        if (result != null && result.files.single.name.isNotEmpty) {
                          setSheetState(() {
                            pickedFileName = result.files.single.name;
                            pickedFilePath = result.files.single.path;
                            pickedFileBytes = result.files.single.bytes;
                          });
                        }
                      },
                      icon: const Icon(Icons.attach_file, size: 16, color: Color(0xFF2563EB)),
                      label: Text(
                        pickedFileName ?? 'Attach PDF (optional)',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: uploading
                            ? null
                            : () async {
                                if (textCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please add submission details'),
                                      backgroundColor: Color(0xFFEF4444),
                                    ),
                                  );
                                  return;
                                }
                                if (isLead && summaryCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please write a project summary'),
                                      backgroundColor: Color(0xFFEF4444),
                                    ),
                                  );
                                  return;
                                }

                                setSheetState(() => uploading = true);

                                // Upload PDF if selected
                                String? pdfUrl;
                                if (pickedFileName != null &&
                                    (pickedFilePath != null || pickedFileBytes != null)) {
                                  try {
                                    final ref = FirebaseStorage.instance.ref(
                                        'task_submissions/${task['id']}/$pickedFileName');
                                    if (pickedFilePath != null) {
                                      await ref.putFile(File(pickedFilePath!));
                                    } else {
                                      await ref.putData(pickedFileBytes!);
                                    }
                                    pdfUrl = await ref.getDownloadURL();
                                  } catch (e) {
                                    if (!mounted) return;
                                    setSheetState(() => uploading = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('PDF upload failed: $e'),
                                        backgroundColor: const Color(0xFFEF4444),
                                      ),
                                    );
                                    return;
                                  }
                                }

                                final user = context.read<AuthViewModel>().currentUser;
                                bool success;

                                if (isLead) {
                                  // Lead submits the whole task to HR
                                  success = await context.read<TaskViewModel>().submitTask(
                                    taskId: task['id'],
                                    summary: summaryCtrl.text.trim(),
                                    submissionText: textCtrl.text.trim(),
                                    submittedBy: user?.name ?? '',
                                    submittedByRole: 'lead',
                                    pdfUrl: pdfUrl,
                                  );
                                } else {
                                  // Member submits work to lead
                                  success = await context.read<TaskViewModel>().submitMemberWork(
                                    taskId: task['id'],
                                    empId: _empId!,
                                    memberName: user?.name ?? '',
                                    submissionText: textCtrl.text.trim(),
                                    leadEmpId: task['lead_id'] ?? '',
                                    taskTitle: task['title'] ?? '',
                                    pdfUrl: pdfUrl,
                                  );
                                }

                                if (!mounted) return;
                                Navigator.of(sheetCtx).pop();

                                if (success) {
                                  _refreshTasks();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isLead
                                          ? 'Task submitted for HR review'
                                          : 'Work submitted to lead'),
                                      backgroundColor: const Color(0xFF16A34A),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          disabledBackgroundColor: const Color(0xFF86EFAC),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: uploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Submit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
                          if (task['taskType'] != null)
                            _detailChip(
                              Icons.category_outlined,
                              (task['taskType'] as String).toUpperCase(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Status banner
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

                      // Previous Description (if task was modified)
                      if (task['previousDescription'] != null &&
                          task['previousDescription'].toString().isNotEmpty &&
                          task['previousDescription'] !=
                              task['description']) ...[
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

                      // Description — editable or read-only
                      Row(
                        children: [
                          Text(
                            task['previousDescription'] != null &&
                                    task['previousDescription']
                                        .toString()
                                        .isNotEmpty &&
                                    task['previousDescription'] !=
                                        task['description']
                                ? 'Modified Description'
                                : 'Description',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const Spacer(),
                          if (_isLeadForTask(task) &&
                              !isAlreadyApproved &&
                              !isEditing)
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
                      // Manage Members button (lead only, not approved)
                      if (_isLeadForTask(task) &&
                          !isAlreadyApproved) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              _showManageMembersDialog(context, task);
                            },
                            icon: const Icon(
                              Icons.group_add_outlined,
                              size: 16,
                              color: Color(0xFF2563EB),
                            ),
                            label: const Text(
                              'Manage Members',
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
                      const SizedBox(height: 20),

                      // Action buttons (lead: approve+history, employee: history only)
                      if (_isLeadForTask(task) && !isAlreadyApproved)
                        // Pending: Approve + History
                        Row(
                          children: [
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
                        // Employee view OR already approved — show History
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

  // ─── Manage Members Dialog ─────────────────────────────────────────────────

  void _showManageMembersDialog(
    BuildContext context,
    Map<String, dynamic> task,
  ) {
    final taskVm = context.read<TaskViewModel>();
    final teamMembers = taskVm.members; // employees with this lead_id
    final unassigned = taskVm.unassignedEmployees; // employees with no lead_id
    final currentMembers = task['members'] as Map<String, dynamic>? ?? {};
    final leadEmpId = task['lead_id'] ?? '';

    // Build set of currently assigned emp_ids (on this task)
    final Set<String> selectedIds = {};
    for (final entry in currentMembers.values) {
      if (entry is Map<String, dynamic>) {
        selectedIds.add(entry['emp_id'] ?? '');
      }
    }

    // Track which unassigned emp_ids were originally NOT in the team
    final Set<String> originalUnassignedIds = unassigned
        .map((m) => (m['emp_id'] ?? '') as String)
        .toSet();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Manage Members',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Current team members
                    if (teamMembers.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
                        child: Text(
                          'Team Members',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      ...teamMembers.map((m) {
                        final empId = m['emp_id'] ?? '';
                        final isSelected = selectedIds.contains(empId);
                        return CheckboxListTile(
                          value: isSelected,
                          activeColor: const Color(0xFF2563EB),
                          title: Text(
                            m['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            empId,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          onChanged: (v) {
                            setDialogState(() {
                              if (v == true) {
                                selectedIds.add(empId);
                              } else {
                                selectedIds.remove(empId);
                              }
                            });
                          },
                        );
                      }),
                    ],

                    // Unassigned employees
                    if (unassigned.isNotEmpty) ...[
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.only(left: 16, top: 4, bottom: 4),
                        child: Text(
                          'Available Employees (No Lead)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),

                      // unassigned employees who can be added to the task (only if they are selected, and were originally unassigned, we will assign them to the lead)
                      ...unassigned.map((m) {
                        final empId = m['emp_id'] ?? '';
                        final isSelected = selectedIds.contains(empId);
                        return CheckboxListTile(
                          value: isSelected,
                          activeColor: const Color(0xFF16A34A),
                          title: Text(
                            m['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '$empId · ${m['role'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          onChanged: (v) {
                            setDialogState(() {
                              if (v == true) {
                                selectedIds.add(empId);
                              } else {
                                selectedIds.remove(empId);
                              }
                            });
                          },
                        );
                      }),
                    ],

                    if (teamMembers.isEmpty && unassigned.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No employees available'),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Save lead_id for newly selected unassigned employees
                    for (final emp in unassigned) {
                      final empId = emp['emp_id'] ?? '';
                      final uid = emp['uid'] ?? '';
                      if (selectedIds.contains(empId) &&
                          originalUnassignedIds.contains(empId) &&
                          uid.isNotEmpty) {
                        await taskVm.assignEmployeeToLead(uid, leadEmpId);
                      }
                    }

                    // Build new members map from all sources
                    final allEmployees = [...teamMembers, ...unassigned];
                    final Map<String, dynamic> newMembersMap = {};
                    int index = 1;
                    for (final m in allEmployees) {
                      final empId = m['emp_id'] ?? '';
                      if (selectedIds.contains(empId)) {
                        newMembersMap['$index'] = {
                          'name': m['name'] ?? '',
                          'emp_id': empId,
                        };
                        index++;
                      }
                    }

                    final success = await taskVm.updateTaskMembers(
                      taskId: task['id'],
                      membersMap: newMembersMap,
                    );

                    if (!context.mounted) return;
                    Navigator.of(dialogContext).pop();

                    if (success) {
                      // Refresh members and unassigned lists
                      if (_empId != null) {
                        taskVm.loadMembersByLeadId(_empId!);
                        taskVm.loadUnassignedEmployees();
                      }
                      _refreshTasks();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Members updated'),
                          backgroundColor: Color(0xFF16A34A),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
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
