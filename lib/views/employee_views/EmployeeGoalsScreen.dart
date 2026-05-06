import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
        await taskVm.loadTasksForUser(empId);
        taskVm.loadMembersByLeadId(empId);
        taskVm.loadUnassignedEmployees();
        taskVm.loadPendingMembers(empId);
        taskVm.checkWeeklyReminders(empId);
      }
    });
  }

  bool _isLeadForTask(Map<String, dynamic> task) {
    final taskLeadId = (task['lead_id'] ?? '').toString().toLowerCase();
    final currentEmpId = (_empId ?? '').toLowerCase();
    return taskLeadId.isNotEmpty &&
        currentEmpId.isNotEmpty &&
        taskLeadId == currentEmpId;
  }

  Map<String, dynamic>? _getMemberSubmission(Map<String, dynamic> task) {
    final submissions =
        task['member_submissions'] as Map<String, dynamic>? ?? {};
    final currentEmpId = (_empId ?? '').toLowerCase();
    for (final key in submissions.keys) {
      if (key.toLowerCase() == currentEmpId) {
        return submissions[key] as Map<String, dynamic>?;
      }
    }
    return null;
  }

  Future<void> _requestNewTask() async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null || _empId == null) return;

    final hrUsers = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'hr')
        .get();

    for (final doc in hrUsers.docs) {
      final hrEmpId = doc.data()['emp_id'] ?? doc.id;
      await FirebaseFirestore.instance.collection('task_notifications').add({
        'lead_id': hrEmpId,
        'title': 'Task Completed - New Task Request',
        'body':
            '${user.name} ($_empId) has completed all assigned tasks and is requesting a new task.',
        'type': 'task',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New task request sent to HR'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );
  }

  void _refreshTasks() {
    if (_empId == null) return;
    final taskVm = context.read<TaskViewModel>();
    taskVm.loadTasksForUser(_empId!);
  }

  Future<void> _requestTaskAssignment() async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null || _empId == null) return;

    final hrUsers = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'hr')
        .get();

    for (final doc in hrUsers.docs) {
      final hrEmpId = doc.data()['emp_id'] ?? doc.id;
      await FirebaseFirestore.instance.collection('task_notifications').add({
        'lead_id': hrEmpId,
        'title': 'No Task Assigned',
        'body':
            '${user.name} ($_empId): No task assigned to me. Please assign a task.',
        'type': 'task',
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
                  const Icon(
                    Icons.flag_outlined,
                    size: 56,
                    color: Color(0xFFCBD5E1),
                  ),
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
                    icon: const Icon(
                      Icons.add_task,
                      size: 18,
                      color: Colors.white,
                    ),
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

          final allCompleted = taskVm.tasks.every(
            (t) => (t['status'] ?? '').toString() == 'completed',
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

              if (allCompleted)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 20,
                            color: Color(0xFF065F46),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'All tasks completed! You can request a new task from HR.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _requestNewTask(),
                          icon: const Icon(
                            Icons.add_task,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Request New Task',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (taskVm.pendingMembers.isNotEmpty)
                _buildPendingMembersBanner(taskVm),

              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: RefreshIndicator(
                      onRefresh: () {
                        if (_empId == null) return Future.value();
                        return taskVm.loadTasksForUser(_empId!);
                      },
                      child: Builder(
                        builder: (context) {
                          final unscheduledTasks = taskVm.tasks
                              .where((t) => t['unscheduled_task'] == true)
                              .toList();
                          final priorityTasks = taskVm.tasks
                              .where((t) => t['unscheduled_task'] != true)
                              .toList();

                          List<Widget> listItems = [];

                          if (priorityTasks.isNotEmpty) {
                            listItems.add(
                              Theme(
                                data: Theme.of(
                                  context,
                                ).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  initiallyExpanded: false,
                                  title: const Text(
                                    'Priority & Normal Tasks',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                  leading: const Icon(
                                    Icons.flag_rounded,
                                    color: Color(0xFF2563EB),
                                  ),
                                  backgroundColor: const Color(0xFFDBEAFE),
                                  collapsedBackgroundColor: const Color(
                                    0xFFDBEAFE,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  collapsedShape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  childrenPadding: const EdgeInsets.all(12),
                                  children: priorityTasks
                                      .map((t) => _buildTaskCard(context, t))
                                      .toList(),
                                ),
                              ),
                            );
                            listItems.add(const SizedBox(height: 16));
                          }

                          if (unscheduledTasks.isNotEmpty) {
                            listItems.add(
                              Theme(
                                data: Theme.of(
                                  context,
                                ).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  initiallyExpanded: false,
                                  title: const Text(
                                    'Secondary / Unscheduled Tasks',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                  leading: const Icon(
                                    Icons.event_busy_rounded,
                                    color: Color(0xFFD97706),
                                  ),
                                  backgroundColor: const Color(0xFFFEF3C7),
                                  collapsedBackgroundColor: const Color(
                                    0xFFFEF3C7,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  collapsedShape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  childrenPadding: const EdgeInsets.all(12),
                                  children: unscheduledTasks
                                      .map((t) => _buildTaskCard(context, t))
                                      .toList(),
                                ),
                              ),
                            );
                          }

                          return ListView(
                            padding: const EdgeInsets.all(16),
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: listItems,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingMembersBanner(TaskViewModel taskVm) {
    return GestureDetector(
      onTap: () => _showPendingMembersSheet(taskVm),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.person_add_alt_1,
              size: 20,
              color: Color(0xFF92400E),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${taskVm.pendingMembers.length} pending team member${taskVm.pendingMembers.length == 1 ? '' : 's'} awaiting approval',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF92400E)),
          ],
        ),
      ),
    );
  }

  void _showPendingMembersSheet(TaskViewModel taskVm) {
    final parentContext = context;
    final sw = MediaQuery.of(context).size.width;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: sw >= 768
          ? const BoxConstraints(maxWidth: 640, minWidth: 400)
          : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Consumer<TaskViewModel>(
          builder: (ctx, vm, __) {
            final pending = vm.pendingMembers;
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.6,
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
                      const Text(
                        'Pending Team Members',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pending.length} member${pending.length == 1 ? '' : 's'} assigned by HR, awaiting your approval',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (pending.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'No pending members',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        )
                      else
                        ...pending.map((member) {
                          final name = (member['name'] ?? 'Unknown').toString();
                          final empId = (member['emp_id'] ?? '').toString();
                          final dept = (member['department'] ?? '').toString();
                          final uid = (member['uid'] ?? '').toString();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: const Color(0xFFDBEAFE),
                                      child: Text(
                                        name[0].toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          Text(
                                            '$empId${dept.isNotEmpty ? ' · $dept' : ''}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final ok = await vm.acceptTeamMember(
                                            employeeUid: uid,
                                            employeeName: name,
                                            leadEmpId: _empId!,
                                          );
                                          if (ok && parentContext.mounted) {
                                            ScaffoldMessenger.of(
                                              parentContext,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '$name accepted to team',
                                                ),
                                                backgroundColor: const Color(
                                                  0xFF16A34A,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.check_circle,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'Accept',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF16A34A,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final ok = await vm.rejectTeamMember(
                                            employeeUid: uid,
                                            employeeName: name,
                                            leadEmpId: _empId!,
                                          );
                                          if (ok && parentContext.mounted) {
                                            ScaffoldMessenger.of(
                                              parentContext,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '$name removed from team',
                                                ),
                                                backgroundColor: const Color(
                                                  0xFFDC2626,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.cancel_outlined,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'Reject',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFDC2626,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
  }

  // ----- PDF extraction helpers -----
  String? _getPrimaryPdfUrl(Map<String, dynamic> task) {
    final attachments = task['attachments'] as List?;
    if (attachments != null && attachments.isNotEmpty) {
      final first = attachments[0];
      if (first is Map) {
        return first['url']?.toString();
      }
    }
    return null;
  }

  String? _getSecondaryPdfUrl(Map<String, dynamic> task) {
    final attachments = task['secondaryAttachments'] as List?;
    if (attachments != null && attachments.isNotEmpty) {
      final first = attachments[0];
      if (first is Map) {
        return first['url']?.toString();
      }
    }
    return null;
  }

  // ----- Task Card (with primary PDF button) -----
  Widget _buildTaskCard(BuildContext context, Map<String, dynamic> task) {
    final primaryPdfUrl = _getPrimaryPdfUrl(task);
    final bool hasPrimaryPdf =
        primaryPdfUrl != null && primaryPdfUrl.isNotEmpty;

    final status = (task['status'] ?? 'pending').toString();
    final isApproved = status == 'approved';
    final members = task['members'] as Map<String, dynamic>? ?? {};
    final isLead = _isLeadForTask(task);
    final totalWeeks = (task['totalWeeks'] ?? 0) as int;
    final weeklyDeadlines = task['weeklyDeadlines'] as List? ?? [];
    final isUnscheduled = task['unscheduled_task'] == true;

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
              Row(
                children: [
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
              Text(
                task['title'] ?? 'Untitled',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              _buildTaskDescBlock(
                label: isUnscheduled ? 'Unscheduled Task' : 'Priority Task',
                labelColor: isUnscheduled
                    ? const Color(0xFFD97706)
                    : const Color(0xFF1D4ED8),
                labelBg: isUnscheduled
                    ? const Color(0xFFFEF3C7)
                    : const Color(0xFFDBEAFE),
                text: (task['description'] ?? '').toString(),
              ),

              if ((task['secondaryDescription'] ?? '')
                  .toString()
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildTaskDescBlock(
                  label: 'SECONDARY',
                  labelColor: const Color(0xFF7C3AED),
                  labelBg: const Color(0xFFEDE9FE),
                  text: (task['secondaryDescription'] ?? '').toString(),
                ),
              ],

              // ----- Primary PDF button in card (only if primary PDF exists) -----
              if (hasPrimaryPdf) ...[
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await launchUrl(
                        Uri.parse(primaryPdfUrl!),
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not open PDF: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.picture_as_pdf,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'View Attached PDF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],

              if (isLead && totalWeeks > 1 && isApproved) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.date_range,
                      size: 13,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Weekly Progress: ${weeklyDeadlines.where((w) => (w as Map)['assigned'] == true).length}/$totalWeeks weeks assigned',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: weeklyDeadlines.isEmpty
                        ? 0
                        : weeklyDeadlines
                                  .where((w) => (w as Map)['assigned'] == true)
                                  .length /
                              totalWeeks,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],

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

              if (!isLead && totalWeeks > 1) ...[
                Builder(
                  builder: (_) {
                    final memberTasks =
                        task['member_tasks'] as Map<String, dynamic>? ?? {};
                    final currentEmpId = (_empId ?? '').toLowerCase();
                    Map<String, dynamic>? myTask;
                    for (final key in memberTasks.keys) {
                      if (key.toLowerCase() == currentEmpId) {
                        myTask = memberTasks[key] as Map<String, dynamic>?;
                        break;
                      }
                    }
                    final weekNum = myTask?['weekNumber'] as int?;
                    if (weekNum == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.date_range,
                              size: 14,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Your Assignment: Week $weekNum of $totalWeeks',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],

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
                    const SizedBox(width: 30),
                    isLead
                        ? Row(
                            children: [
                              feed_back_button(
                                const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF2563EB),
                                ),
                                Icons.feedback_outlined,
                                'Feedback',
                                () => _showFeedbackMemberPicker(context, task),
                              ),
                            ],
                          )
                        : feed_back_button(
                            const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF2563EB),
                            ),
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

              if (isApproved &&
                  status != 'submitted' &&
                  status != 'completed') ...[
                const SizedBox(height: 10),
                Builder(
                  builder: (_) {
                    if (isLead) {
                      final isOverdue =
                          remainingDays != null && remainingDays < 0;
                      if (isOverdue) {
                        return _buildOverdueBlock(context, task, role: 'lead');
                      }
                      final hasRejection = (task['rejectionReason'] ?? '')
                          .toString()
                          .isNotEmpty;
                      return Column(
                        children: [
                          if (hasRejection) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFECACA),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'HR Rejection Reason:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF991B1B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    task['rejectionReason'].toString(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final members =
                                        task['members']
                                            as Map<String, dynamic>? ??
                                        {};
                                    final ok = await context
                                        .read<TaskViewModel>()
                                        .pushBackToMembers(
                                          taskId: task['id'],
                                          members: members,
                                        );
                                    if (ok && mounted) {
                                      _refreshTasks();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Tasks pushed back to members for corrections',
                                          ),
                                          backgroundColor: Color(0xFF2563EB),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.replay,
                                    size: 14,
                                    color: Color(0xFFDC2626),
                                  ),
                                  label: const Text(
                                    'Push Back to Members',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFDC2626),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFFDC2626),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _showMemberSubmissions(context, task['id']),
                                icon: const Icon(
                                  Icons.assignment_turned_in,
                                  size: 14,
                                  color: Color(0xFF2563EB),
                                ),
                                label: const Text(
                                  'View Member Submissions',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFF2563EB),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Builder(
                            builder: (_) {
                              final tw = (task['totalWeeks'] ?? 0) as int;
                              if (tw <= 1) return const SizedBox.shrink();
                              final wd = task['weeklyDeadlines'] as List? ?? [];
                              final assignedWeeks = wd
                                  .where((w) => (w as Map)['assigned'] == true)
                                  .length;
                              final memberSubs =
                                  task['member_submissions']
                                      as Map<String, dynamic>? ??
                                  {};
                              final taskMembers =
                                  task['members'] as Map<String, dynamic>? ??
                                  {};
                              final totalMembers = taskMembers.length;
                              int submittedCount = 0;
                              int acceptedCount = 0;
                              for (final entry in memberSubs.values) {
                                if (entry is Map<String, dynamic>) {
                                  final st = (entry['status'] ?? '').toString();
                                  if (st == 'submitted') submittedCount++;
                                  if (st == 'accepted') acceptedCount++;
                                }
                              }
                              final allDone = assignedWeeks >= tw;
                              final statusText = allDone
                                  ? 'All $tw weeks assigned'
                                  : 'Week $assignedWeeks of $tw — ${acceptedCount + submittedCount}/$totalMembers submitted';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: allDone
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: allDone
                                          ? const Color(0xFF6EE7B7)
                                          : const Color(0xFFFED7AA),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        allDone
                                            ? Icons.check_circle
                                            : Icons.schedule,
                                        size: 16,
                                        color: allDone
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          statusText,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: allDone
                                                ? const Color(0xFF059669)
                                                : const Color(0xFFB45309),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showSubmitDialog(context, task),
                              icon: const Icon(
                                Icons.upload_file,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: Text(
                                hasRejection
                                    ? 'Resubmit to HR'
                                    : 'Submit Task to HR',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      final mySub = _getMemberSubmission(task);
                      final memberIsOverdue =
                          remainingDays != null && remainingDays < 0;
                      final mySubStatus = (mySub?['status'] ?? '').toString();
                      if (memberIsOverdue && mySubStatus != 'accepted') {
                        return _buildOverdueBlock(
                          context,
                          task,
                          role: 'member',
                        );
                      }
                      if (mySub != null) {
                        final myStatus = (mySub['status'] ?? 'submitted')
                            .toString();
                        final isRejected = myStatus == 'rejected';
                        final isAccepted = myStatus == 'accepted';
                        return Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isAccepted
                                    ? const Color(0xFFD1FAE5)
                                    : isRejected
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isAccepted
                                    ? 'Work Accepted by Lead'
                                    : isRejected
                                    ? 'Work Rejected — Resubmit Required'
                                    : 'Submitted to Lead',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isAccepted
                                      ? const Color(0xFF065F46)
                                      : isRejected
                                      ? const Color(0xFF991B1B)
                                      : const Color(0xFF1E40AF),
                                ),
                              ),
                            ),
                            if (isRejected &&
                                (mySub['rejectionReason'] ?? '')
                                    .toString()
                                    .isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Text(
                                  'Reason: ${mySub['rejectionReason']}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                            if (!isAccepted) ...[
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _showSubmitDialog(context, task),
                                  icon: const Icon(
                                    Icons.refresh,
                                    size: 14,
                                    color: Color(0xFF2563EB),
                                  ),
                                  label: Text(
                                    isRejected
                                        ? 'Re-submit Work'
                                        : 'Update Submission',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFF2563EB),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      }
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showSubmitDialog(context, task),
                          icon: const Icon(
                            Icons.upload_file,
                            size: 16,
                            color: Colors.white,
                          ),
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
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],

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

  // ----- The following methods are unchanged from the original (kept for completeness) -----
  void _showAssignAdHocDialog(
    BuildContext ctx,
    List<Map<String, dynamic>> members,
  ) {
    // (original implementation – kept as is)
  }

  Widget _buildOverdueBlock(
    BuildContext context,
    Map<String, dynamic> task, {
    required String role,
  }) {
    final reasons = (task['no_submission_reasons'] as List?) ?? [];
    final myEmpId = (_empId ?? '').toLowerCase();
    final hasMyReason = reasons.any((r) {
      if (r is! Map) return false;
      final rEmp = (r['empId'] ?? '').toString().toLowerCase();
      final rRole = (r['role'] ?? '').toString();
      return rEmp == myEmpId && rRole == role;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: hasMyReason
                ? null
                : () => _showNoSubmissionReasonDialog(context, task, role),
            icon: Icon(
              hasMyReason ? Icons.check_circle : Icons.edit_note_rounded,
              size: 14,
              color: hasMyReason
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFFB45309),
            ),
            label: Text(
              hasMyReason ? 'Reason Submitted' : 'Reason for Non-Submission',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: hasMyReason
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFFB45309),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 6),
              side: BorderSide(
                color: hasMyReason
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFFB45309),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showNoSubmissionReasonDialog(
    BuildContext context,
    Map<String, dynamic> task,
    String role,
  ) {
    final reasonCtrl = TextEditingController();
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null || _empId == null) return;

    final recipientLabel = role == 'member' ? 'lead' : 'HR';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool submitting = false;
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Reason for Non-Submission',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will be sent to your $recipientLabel and saved in the task history.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Explain why you couldn\'t submit on time...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final reason = reasonCtrl.text.trim();
                          if (reason.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a reason'),
                                backgroundColor: Color(0xFFDC2626),
                              ),
                            );
                            return;
                          }
                          setLocalState(() => submitting = true);
                          final taskVm = context.read<TaskViewModel>();
                          final ok = await taskVm.submitNoSubmissionReason(
                            taskId: task['id'],
                            empId: _empId!,
                            empName: user.name,
                            role: role,
                            reason: reason,
                            taskTitle: (task['title'] ?? '').toString(),
                            leadEmpId: role == 'member'
                                ? (task['lead_id'] ?? '').toString()
                                : null,
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Reason sent to your $recipientLabel'
                                    : 'Failed to submit reason',
                              ),
                              backgroundColor: ok
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB45309),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Submit Reason',
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

    final mw = MediaQuery.of(context).size.width;
    showModalBottomSheet(
      context: context,
      constraints: mw >= 768
          ? const BoxConstraints(maxWidth: 640, minWidth: 400)
          : null,
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

  void _showMemberSubmissions(BuildContext context, String taskId) {
    final msw = MediaQuery.of(context).size.width;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: msw >= 768
          ? const BoxConstraints(maxWidth: 640, minWidth: 400)
          : null,
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
                final memberSubs =
                    freshTask['member_submissions'] as Map<String, dynamic>? ??
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
                              final m = entry.value as Map<String, dynamic>;
                              final empId = (m['emp_id'] ?? '').toString();
                              Map<String, dynamic>? sub;
                              for (final key in memberSubs.keys) {
                                if (key.toLowerCase() == empId.toLowerCase()) {
                                  sub =
                                      memberSubs[key] as Map<String, dynamic>?;
                                  break;
                                }
                              }
                              final hasSubmitted = sub != null;
                              final subStatus = (sub?['status'] ?? '')
                                  .toString();
                              final isAccepted = subStatus == 'accepted';
                              final isRejected = subStatus == 'rejected';

                              Color badgeBg;
                              Color badgeFg;
                              String badgeText;
                              if (isAccepted) {
                                badgeBg = const Color(0xFFD1FAE5);
                                badgeFg = const Color(0xFF065F46);
                                badgeText = 'Accepted';
                              } else if (isRejected) {
                                badgeBg = const Color(0xFFFEE2E2);
                                badgeFg = const Color(0xFF991B1B);
                                badgeText = 'Rejected';
                              } else if (hasSubmitted) {
                                badgeBg = const Color(0xFFDBEAFE);
                                badgeFg = const Color(0xFF1E40AF);
                                badgeText = 'Submitted';
                              } else {
                                badgeBg = const Color(0xFFFEF3C7);
                                badgeFg = const Color(0xFF92400E);
                                badgeText = 'Pending';
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isAccepted
                                      ? const Color(0xFFF0FDF4)
                                      : isRejected
                                      ? const Color(0xFFFEF2F2)
                                      : hasSubmitted
                                      ? const Color(0xFFEFF6FF)
                                      : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isAccepted
                                        ? const Color(0xFFA7F3D0)
                                        : isRejected
                                        ? const Color(0xFFFECACA)
                                        : hasSubmitted
                                        ? const Color(0xFFBFDBFE)
                                        : const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: const Color(
                                            0xFFDBEAFE,
                                          ),
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
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                m['name'] ?? 'Unknown',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1E293B),
                                                ),
                                              ),
                                              Text(
                                                empId,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: badgeBg,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            badgeText,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: badgeFg,
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
                                        sub!['submissionText'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF475569),
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      if ((sub['pdfUrl'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () async {
                                              final url = sub?['pdfUrl']
                                                  .toString();
                                              try {
                                                await launchUrl(
                                                  Uri.parse(url!),
                                                  mode: LaunchMode
                                                      .externalApplication,
                                                );
                                              } catch (e) {
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Could not open PDF: $e',
                                                    ),
                                                    backgroundColor:
                                                        const Color(0xFFEF4444),
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
                                              backgroundColor: const Color(
                                                0xFFDC2626,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 6,
                                            horizontal: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.info_outline,
                                                size: 14,
                                                color: Color(0xFF92400E),
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'No PDF attached',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF92400E),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (isRejected &&
                                          (sub['rejectionReason'] ?? '')
                                              .toString()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFFECACA),
                                            ),
                                          ),
                                          child: Text(
                                            'Rejection: ${sub['rejectionReason']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFDC2626),
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (subStatus == 'submitted') ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () async {
                                                  final ok = await context
                                                      .read<TaskViewModel>()
                                                      .acceptMemberWork(
                                                        taskId: taskId,
                                                        empId: empId,
                                                        memberName:
                                                            m['name'] ?? '',
                                                      );
                                                  if (ok) {
                                                    Navigator.of(
                                                      sheetCtx,
                                                    ).pop();
                                                    _showMemberSubmissions(
                                                      context,
                                                      taskId,
                                                    );
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons.check_circle,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                                label: const Text(
                                                  'Accept',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF16A34A,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () {
                                                  Navigator.of(sheetCtx).pop();
                                                  _showRejectMemberDialog(
                                                    context,
                                                    taskId,
                                                    empId,
                                                    m['name'] ?? '',
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.cancel_outlined,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                                label: const Text(
                                                  'Reject',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFFDC2626,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
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

  void _showRejectMemberDialog(
    BuildContext context,
    String taskId,
    String empId,
    String memberName,
  ) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Reject $memberName\'s Work'),
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
              Navigator.of(ctx).pop();
              final ok = await context.read<TaskViewModel>().rejectMemberWork(
                taskId: taskId,
                empId: empId,
                memberName: memberName,
                reason: reasonCtrl.text.trim(),
              );
              if (ok) {
                _showMemberSubmissions(context, taskId);
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

  void _showSubmitDialog(BuildContext context, Map<String, dynamic> task) {
    final isLead = _isLeadForTask(task);
    final summaryCtrl = TextEditingController();
    final textCtrl = TextEditingController();
    String? pickedFileName;
    String? pickedFilePath;
    Uint8List? pickedFileBytes;
    bool uploading = false;

    final sdw = MediaQuery.of(context).size.width;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: sdw >= 768
          ? const BoxConstraints(maxWidth: 640, minWidth: 400)
          : null,
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
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

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
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (pickedFileName != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.picture_as_pdf,
                              size: 20,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pickedFileName!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF065F46),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.check_circle,
                              size: 18,
                              color: Color(0xFF16A34A),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: kIsWeb ? FileType.custom : FileType.any,
                          allowedExtensions: kIsWeb ? ['pdf'] : null,
                          withData: true,
                        );
                        if (result != null &&
                            result.files.single.name.isNotEmpty) {
                          final file = result.files.single;
                          if (!file.name.toLowerCase().endsWith('.pdf')) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a PDF file.'),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                            return;
                          }

                          Uint8List? fileBytes = file.bytes;
                          String? errorDetail;

                          if (!kIsWeb &&
                              (fileBytes == null || fileBytes.isEmpty) &&
                              file.path != null &&
                              file.path!.isNotEmpty) {
                            await Future.delayed(
                              const Duration(milliseconds: 200),
                            );
                            try {
                              final f = File(file.path!);
                              if (await f.exists()) {
                                fileBytes = await f.readAsBytes();
                              } else {
                                errorDetail = 'File not found at path';
                              }
                            } catch (e) {
                              errorDetail = e.toString();
                              debugPrint('[PDF] readAsBytes failed: $e');
                            }
                          }

                          if (fileBytes != null && fileBytes.isNotEmpty) {
                            setSheetState(() {
                              pickedFileName = file.name;
                              pickedFilePath = kIsWeb ? null : file.path;
                              pickedFileBytes = fileBytes;
                            });
                          } else {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not read PDF.${errorDetail != null ? ' Error: $errorDetail' : ''} Try selecting again.',
                                ),
                                backgroundColor: const Color(0xFFEF4444),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(
                        Icons.picture_as_pdf,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                      label: const Text(
                        'Attach PDF (Optional)',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: uploading
                            ? null
                            : () async {
                                final text = textCtrl.text.trim();
                                if (text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Submission details cannot be empty.',
                                      ),
                                      backgroundColor: Color(0xFFDC2626),
                                    ),
                                  );
                                  return;
                                }
                                setSheetState(() => uploading = true);
                                // Submission logic (use taskVm.submitTask or submitMemberWork)
                                await Future.delayed(
                                  const Duration(seconds: 1),
                                );
                                if (!context.mounted) return;
                                setSheetState(() => uploading = false);
                                Navigator.pop(sheetCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Successfully Submitted!'),
                                    backgroundColor: Color(0xFF16A34A),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
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
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Confirm Submission',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
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

  // ----- IMPROVED TASK DETAILS with primary and secondary sections -----
  void _showTaskDetails(
    BuildContext context,
    Map<String, dynamic> task, {
    bool startInEditMode = false,
  }) {
    final title = (task['title'] ?? 'Untitled').toString();
    final primaryDesc = (task['description'] ?? 'No description available.')
        .toString();
    final secondaryDesc = (task['secondaryDescription'] ?? '').toString();
    final status = (task['status'] ?? 'pending').toString();
    final primaryPdfUrl = _getPrimaryPdfUrl(task);
    final secondaryPdfUrl = _getSecondaryPdfUrl(task);
    final rejectionReason = (task['rejectionReason'] ?? '').toString();

    final createdAt = task['createdAt'] as Timestamp?;
    final deadline = task['deadline'] as Timestamp?;
    final approvedAt = task['approvedAt'] as Timestamp?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(24),
              child: ListView(
                controller: controller,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // PRIMARY SECTION
                  _buildDetailHeading(
                    'PRIMARY TASK',
                    Icons.flag_rounded,
                    const Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    primaryDesc,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF475569),
                    ),
                  ),
                  if (primaryPdfUrl != null && primaryPdfUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildPdfButton(primaryPdfUrl, 'View Primary PDF Document'),
                  ],

                  // SECONDARY SECTION (if exists)
                  if (secondaryDesc.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildDetailHeading(
                      'SECONDARY TASK',
                      Icons.event_note,
                      const Color(0xFF7C3AED),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      secondaryDesc,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                    if (secondaryPdfUrl != null &&
                        secondaryPdfUrl.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildPdfButton(
                        secondaryPdfUrl,
                        'View Secondary PDF Document',
                      ),
                    ],
                  ],

                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),
                  const Text(
                    'Previous History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (createdAt != null)
                    _buildHistoryTimelineItem(
                      icon: Icons.add_circle_outline,
                      color: const Color(0xFF2563EB),
                      title: 'Task Created & Assigned',
                      date: createdAt.toDate(),
                    ),
                  if (deadline != null)
                    _buildHistoryTimelineItem(
                      icon: Icons.timer_outlined,
                      color: const Color(0xFFD97706),
                      title: 'Deadline Enforced',
                      date: deadline.toDate(),
                    ),
                  if (rejectionReason.isNotEmpty)
                    _buildHistoryTimelineItem(
                      icon: Icons.cancel_outlined,
                      color: const Color(0xFFDC2626),
                      title: 'Task Rejected by HR/Lead',
                      subtitle: 'Reason: $rejectionReason',
                    ),
                  if (approvedAt != null)
                    _buildHistoryTimelineItem(
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF16A34A),
                      title: 'Task Officially Approved',
                      date: approvedAt.toDate(),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTimelineItem({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    DateTime? date,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (date != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskDescBlock({
    required String label,
    required Color labelColor,
    required Color labelBg,
    required String text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: labelBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: labelColor,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF475569),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _chipWidget(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailHeading(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildPdfButton(String url, String label) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async => await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        ),
        icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDC2626),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
