// lib/screens/employee_views/leave_notifications_widget.dart
//
// Displays in-app leave notifications for an employee.
// Reads from: notifications/{employeeUid}/items  (written by HR on review)
//
// Usage — add anywhere in employee home/profile screen:
//
//   LeaveNotificationsWidget(employeeUid: uid)
//
// Each notification can be tapped to mark as read.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LeaveNotificationsWidget extends StatelessWidget {
  final String employeeUid;
  const LeaveNotificationsWidget({super.key, required this.employeeUid});

  Stream<QuerySnapshot> get _stream => FirebaseFirestore.instance
      .collection('notifications')
      .doc(employeeUid)
      .collection('items')
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots();

  Future<void> _markRead(String docId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(employeeUid)
        .collection('items')
        .doc(docId)
        .update({'read': true});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const SizedBox.shrink();

        // Unread count badge
        final unread = docs.where((d) => !(d['read'] as bool? ?? false)).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_rounded,
                    color: Color(0xFF2563EB),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Leave Notifications',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ...docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final read = d['read'] as bool? ?? false;
              final title = d['title'] as String? ?? '';
              final body = d['body'] as String? ?? '';
              final status = d['status'] as String? ?? '';
              final ts = d['createdAt'];
              final when = ts is Timestamp
                  ? DateFormat('MMM d, HH:mm').format(ts.toDate())
                  : '';

              final bool isApproved = status == 'approved';

              return GestureDetector(
                onTap: () => _markRead(doc.id),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: read ? Colors.white : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: read
                          ? const Color(0xFFE2E8F0)
                          : isApproved
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFFFECACA),
                      width: read ? 1 : 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isApproved
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isApproved
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: isApproved
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
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
                                      fontWeight: read
                                          ? FontWeight.w500
                                          : FontWeight.bold,
                                      fontSize: 13,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                if (!read)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF2563EB),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              body,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF475569),
                                height: 1.4,
                              ),
                            ),
                            if (when.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                when,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ── Unread count stream (for nav badge) ──────────────────────────────────────
Stream<int> leaveNotificationUnreadCount(String employeeUid) {
  return FirebaseFirestore.instance
      .collection('notifications')
      .doc(employeeUid)
      .collection('items')
      .where('read', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);
}
