import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../navigation/app_notification_router.dart';
import '../../services/task_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../employee_views/EmployeeGoalsScreen.dart';
import '../employee_views/lead_review_screen.dart';
import '../employee_views/lead_task_receipt_screen.dart';
import '../employee_views/member_weekly_submit_screen.dart';
import '../employee_views/team_reports_screen.dart';
import '../HR_views/employee_reports_screen.dart';
import '../HR_views/AssignTaskByHR.dart';
import '../HR_views/hr_task_audit_screen.dart';

class TaskNotificationsScreen extends StatelessWidget {
  final String recipientId;
  const TaskNotificationsScreen({super.key, required this.recipientId});

  /// Route a tapped notification to the most specific screen possible.
  ///
  /// For v2 task notifications carrying `taskId`, deep-link straight to the
  /// task / week / event:
  ///   * HR  → [HRTaskAuditScreen] with the event highlighted
  ///   * Lead receiving a member-level event (has `weekNumber`) → [LeadReviewScreen]
  ///   * Lead receiving a task-level event → [LeadTaskReceiptScreen]
  ///   * Member → [MemberWeeklySubmitScreen]
  ///
  /// For pre-v2 task notifications and report notifications, keep the
  /// legacy "open the section root" behaviour.
  Future<void> _navigateToScreen(
    BuildContext context,
    Map<String, dynamic> n,
  ) async {
    final type = (n['type'] ?? '').toString();
    final title = (n['title'] ?? '').toString();
    final taskId = (n['taskId'] ?? '').toString();
    final weekNumber = n['weekNumber'] as int?;
    final user = context.read<AuthViewModel>().currentUser;
    final role = (user?.role ?? '').toLowerCase();
    final isHR = role == 'hr';

    if (type == 'company_letter' && !isHR) {
      final letterId = (n['referenceId'] ?? '').toString();
      if (context.mounted) Navigator.of(context).pop();
      await handleNotificationDeepLink({
        'type': 'company_letter',
        'referenceId': letterId,
      });
      return;
    }

    // Report notifications retain the existing top-level routing.
    if (type == 'report' || title.contains('Report')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              isHR ? const EmployeeReportsScreen() : const TeamReportsScreen(),
        ),
      );
      return;
    }

    // Try deep-link for v2 task notifications.
    if (taskId.isNotEmpty) {
      try {
        final taskDoc = await FirebaseFirestore.instance
            .collection('tasks')
            .doc(taskId)
            .get();
        if (taskDoc.exists && taskDoc.data()?['schemaVersion'] == 2) {
          if (!context.mounted) return;
          // Resolve the current user's empId for member routing.
          final myUid = user?.uid ?? '';
          String myEmpId = '';
          if (!isHR && myUid.isNotEmpty) {
            final me = await FirebaseFirestore.instance
                .collection('users')
                .doc(myUid)
                .get();
            myEmpId = (me.data()?['emp_id'] ?? '').toString();
          }
          if (!context.mounted) return;

          Widget target;
          if (isHR) {
            target = HRTaskAuditScreen(
              taskId: taskId,
              highlightedEventId: (n['eventId'] ?? '').toString().isEmpty
                  ? null
                  : (n['eventId']).toString(),
              highlightedWeekNumber: weekNumber,
            );
          } else {
            // Lead vs member: compare emp_id with task's lead_id.
            final leadId =
                (taskDoc.data()?['lead_id'] ?? '').toString().toLowerCase();
            final isLead =
                leadId.isNotEmpty && leadId == myEmpId.toLowerCase();
            if (isLead) {
              // If the notification was about a member's submission/barrier
              // (carries weekNumber + memberEmpId), jump into the review screen.
              if (weekNumber != null &&
                  (n['memberEmpId'] ?? '').toString().isNotEmpty) {
                target = LeadReviewScreen(taskId: taskId);
              } else {
                target = LeadTaskReceiptScreen(taskId: taskId);
              }
            } else {
              target = MemberWeeklySubmitScreen(
                taskId: taskId,
                empId: myEmpId,
              );
            }
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => target),
          );
          return;
        }
      } catch (_) {
        // Fall through to legacy routing.
      }
    }

    if (!context.mounted) return;
    // Legacy fallback for pre-v2 tasks (or notifications missing taskId).
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            isHR ? const AssignTaskByHR() : const EmployeeGoalsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = TaskService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Task Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () async {
              await service.clearAllTaskNotifications(recipientId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All notifications cleared'),
                  backgroundColor: Color(0xFF16A34A),
                ),
              );
            },
            child: const Text(
              'Clear All',
              style: TextStyle(color: Color(0xFFEF4444), fontSize: 13),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: service.streamTaskNotifications(recipientId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            );
          }
          final notifs = snap.data ?? [];
          if (notifs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_rounded,
                      size: 56, color: Color(0xFFCBD5E1)),
                  SizedBox(height: 12),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'You\'re all caught up!',
                    style: TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifs.length,
            itemBuilder: (_, i) {
              final n = notifs[i];
              final title = (n['title'] ?? '').toString();
              final body = (n['body'] ?? '').toString();
              final isRead = n['read'] == true;
              final createdAt = n['createdAt'] as Timestamp?;
              final notifId = (n['id'] ?? '').toString();

              // Pick icon + color based on title
              IconData icon;
              Color color;
              if (title.contains('Submitted')) {
                icon = Icons.upload_file_rounded;
                color = const Color(0xFF7C3AED);
              } else if (title.contains('Approved') || title.contains('Accepted')) {
                icon = Icons.check_circle_rounded;
                color = const Color(0xFF10B981);
              } else if (title.contains('Rejected')) {
                icon = Icons.cancel_rounded;
                color = const Color(0xFFEF4444);
              } else if (title.contains('No Task') || title.contains('Request')) {
                icon = Icons.assignment_late_rounded;
                color = const Color(0xFFF59E0B);
              } else if (title.contains('Modified')) {
                icon = Icons.edit_note_rounded;
                color = const Color(0xFF3B82F6);
              } else if (title.contains('Forwarded') || title.contains('Assigned')) {
                icon = Icons.forward_to_inbox_rounded;
                color = const Color(0xFF3B82F6);
              } else if (title.contains('Report')) {
                icon = Icons.description_rounded;
                color = const Color(0xFF8B5CF6);
              } else if (title.contains('Member')) {
                icon = Icons.person_rounded;
                color = const Color(0xFF6366F1);
              } else {
                icon = Icons.notifications_rounded;
                color = const Color(0xFF64748B);
              }

              // Format time
              String timeAgo = '';
              if (createdAt != null) {
                final diff = DateTime.now().difference(createdAt.toDate());
                if (diff.inMinutes < 1) {
                  timeAgo = 'Just now';
                } else if (diff.inMinutes < 60) {
                  timeAgo = '${diff.inMinutes}m ago';
                } else if (diff.inHours < 24) {
                  timeAgo = '${diff.inHours}h ago';
                } else if (diff.inDays < 7) {
                  timeAgo = '${diff.inDays}d ago';
                } else {
                  final d = createdAt.toDate();
                  timeAgo = '${d.day}/${d.month}/${d.year}';
                }
              }

              return Dismissible(
                key: Key(notifId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_rounded, color: Colors.red),
                ),
                onDismissed: (_) =>
                    service.markTaskNotificationRead(notifId),
                child: GestureDetector(
                  onTap: () {
                    if (!isRead) {
                      service.markTaskNotificationRead(notifId);
                    }
                    _navigateToScreen(context, n);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isRead
                          ? Colors.white
                          : color.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isRead
                            ? const Color(0xFFE2E8F0)
                            : color.withOpacity(0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isRead
                                            ? FontWeight.w500
                                            : FontWeight.bold,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                body,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    timeAgo,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
