import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/task_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../employee_views/EmployeeGoalsScreen.dart';
import '../employee_views/team_reports_screen.dart';
import '../HR_views/employee_reports_screen.dart';

class TaskNotificationsScreen extends StatelessWidget {
  final String recipientId;
  const TaskNotificationsScreen({super.key, required this.recipientId});

  /// Determine the target screen based on notification type/title and user role
  void _navigateToScreen(BuildContext context, Map<String, dynamic> n) {
    final type = (n['type'] ?? '').toString();
    final title = (n['title'] ?? '').toString();
    final user = context.read<AuthViewModel>().currentUser;
    final role = user?.role ?? '';

    Widget targetScreen;

    // Report-related notifications
    if (type == 'report' || title.contains('Report')) {
      if (role == 'hr') {
        targetScreen = const EmployeeReportsScreen();
      } else {
        targetScreen = const TeamReportsScreen();
      }
    } else {
      // Task, team, and all other notifications → Goals/Tasks screen
      targetScreen = const EmployeeGoalsScreen();
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => targetScreen),
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
