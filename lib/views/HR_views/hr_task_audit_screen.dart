import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/task_service.dart';
import '../../widgets/task_timeline.dart';

/// HR's read-only audit view for a v2 task.
///
/// Renders the full chronological event chain (HR → Lead → each Member,
/// across every week) using [TaskTimeline]. Optionally jumps straight to a
/// specific event when launched from a notification deep-link.
class HRTaskAuditScreen extends StatelessWidget {
  const HRTaskAuditScreen({
    super.key,
    required this.taskId,
    this.highlightedEventId,
    this.highlightedWeekNumber,
  });

  final String taskId;
  final String? highlightedEventId;
  final int? highlightedWeekNumber;

  @override
  Widget build(BuildContext context) {
    final svc = TaskService();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Task Audit',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
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
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .doc(taskId)
            .snapshots(),
        builder: (context, taskSnap) {
          if (!taskSnap.hasData || !taskSnap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final task = taskSnap.data!.data()!;
          final totalWeeks = (task['totalWeeks'] ?? 1) as int;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summary(task),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: TaskTimeline(
                  eventsStream: svc.streamEvents(taskId),
                  highlightedEventId: highlightedEventId,
                  totalWeeks: totalWeeks,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summary(Map<String, dynamic> task) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task['title'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _chip(Icons.person_outline, 'Lead: ${task['leadName'] ?? '—'}'),
              _chip(
                Icons.calendar_view_week_rounded,
                '${task['totalWeeks'] ?? 1} weeks',
              ),
              _chip(
                Icons.flag_outlined,
                'Status: ${task['status'] ?? 'pending'}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF2563EB)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1D4ED8),
          ),
        ),
      ],
    ),
  );
}
