import 'package:flutter/material.dart';
import '../../models/meeting_model.dart';
import '../../services/meeting_service.dart';
import '../../widgets/meeting_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  final String userId;
  const NotificationsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final service = MeetingService();

    IconData notifIcon(String type) {
      switch (type) {
        case 'new_meeting':
          return Icons.calendar_month_rounded;
        case 'meeting_approved':
          return Icons.check_circle_rounded;
        case 'meeting_rejected':
          return Icons.cancel_rounded;
        case 'meeting_request':
          return Icons.pending_actions_rounded;
        default:
          return Icons.notifications_rounded;
      }
    }

    Color notifColor(String type) {
      switch (type) {
        case 'new_meeting':
          return const Color(0xFF3B82F6);
        case 'meeting_approved':
          return const Color(0xFF10B981);
        case 'meeting_rejected':
          return const Color(0xFFEF4444);
        case 'meeting_request':
          return const Color(0xFFF59E0B);
        default:
          return Colors.grey;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => service.markAllNotificationsRead(userId),
            child: const Text(
              'Mark all read',
              style: TextStyle(color: Color(0xFF3B82F6), fontSize: 13),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: service.streamNotifications(userId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifs = snap.data ?? [];
          if (notifs.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_off_rounded,
              title: 'No notifications',
              subtitle:
                  'You\'re all caught up! Notifications will appear here.',
              color: Color(0xFF3B82F6),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifs.length,
            itemBuilder: (_, i) {
              final n = notifs[i];
              final color = notifColor(n.type);
              return Dismissible(
                key: Key(n.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: Colors.red.shade100,
                  child: const Icon(Icons.delete_rounded, color: Colors.red),
                ),
                onDismissed: (_) => service.markNotificationRead(n.id),
                child: GestureDetector(
                  onTap: () {
                    service.markNotificationRead(n.id);
                    // Navigate back to the meetings screen
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.isRead
                          ? Colors.white
                          : color.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: n.isRead
                            ? Colors.grey.shade100
                            : color.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
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
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            notifIcon(n.type),
                            color: color,
                            size: 20,
                          ),
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
                                      n.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: n.isRead
                                            ? FontWeight.w500
                                            : FontWeight.bold,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  if (!n.isRead)
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
                                n.body,
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
                                    MeetingTheme.formatTimeAgo(n.createdAt),
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
