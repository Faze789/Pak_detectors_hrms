import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// A unified model to represent any event in the task's lifecycle.
class AuditRecord {
  final String id;
  final DateTime timestamp;
  final String type; // 'hr_create', 'lead_breakdown', 'submission', 'review'
  final String title;
  final String subtitle;
  final String actorName;
  final String actorRole;
  final Map<String, dynamic> payload;

  AuditRecord({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.actorName,
    required this.actorRole,
    required this.payload,
  });
}

class HRTaskAuditScreen extends StatefulWidget {
  final String taskId;
  final String? highlightedEventId;
  final int? highlightedWeekNumber;

  const HRTaskAuditScreen({
    super.key,
    required this.taskId,
    this.highlightedEventId,
    this.highlightedWeekNumber,
  });

  @override
  State<HRTaskAuditScreen> createState() => _HRTaskAuditScreenState();
}

class _HRTaskAuditScreenState extends State<HRTaskAuditScreen> {
  bool _isLoadingTimeline = true;
  String? _errorMessage;

  List<AuditRecord> _auditTimeline = [];

  StreamSubscription? _eventsSub;
  StreamSubscription? _assignmentsSub;

  List<QueryDocumentSnapshot> _rawEvents = [];
  List<QueryDocumentSnapshot> _rawAssignments = [];

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _assignmentsSub?.cancel();
    super.dispose();
  }

  void _setupRealtimeListeners() {
    final firestore = FirebaseFirestore.instance;

    // Listen to Events Subcollection (HR Create, Lead Breakdown)
    _eventsSub = firestore
        .collection('tasks')
        .doc(widget.taskId)
        .collection('events')
        .snapshots()
        .listen((snapshot) {
          _rawEvents = snapshot.docs;
          _processAndCombineData();
        }, onError: (err) => setState(() => _errorMessage = err.toString()));

    // Listen to Weekly Assignments Subcollection (Member Submissions & Reviews)
    _assignmentsSub = firestore
        .collection('tasks')
        .doc(widget.taskId)
        .collection('weekly_assignments')
        .snapshots()
        .listen((snapshot) {
          _rawAssignments = snapshot.docs;
          _processAndCombineData();
        }, onError: (err) => setState(() => _errorMessage = err.toString()));
  }

  void _processAndCombineData() {
    List<AuditRecord> combined = [];

    // 1. Process Events
    for (var doc in _rawEvents) {
      final data = doc.data() as Map<String, dynamic>;
      final createdAt = data['createdAt'] as Timestamp?;
      if (createdAt == null) continue;

      final type = data['payload']?['type'] ?? data['type'] ?? 'unknown';
      final actorName = data['actorName'] ?? 'Unknown Actor';
      final actorRole = data['actorRole'] ?? 'system';
      final payload = data['payload'] as Map<String, dynamic>? ?? {};

      String title = 'Event Occurred';
      String subtitle = '';

      if (type == 'hr_create') {
        title = 'Task Created by HR';
        subtitle = 'Task "${payload['title'] ?? ''}" was initialized.';
      } else if (type == 'lead_breakdown') {
        title = 'Task Breakdown Assigned';
        subtitle =
            'Assigned week ${data['weekNumber'] ?? payload['weekNumber']} to ${payload['memberName'] ?? 'Member'}.';
      }

      combined.add(
        AuditRecord(
          id: doc.id,
          timestamp: createdAt.toDate(),
          type: type,
          title: title,
          subtitle: subtitle,
          actorName: actorName,
          actorRole: actorRole,
          payload: payload,
        ),
      );
    }

    // 2. Process Weekly Assignments
    for (var doc in _rawAssignments) {
      final data = doc.data() as Map<String, dynamic>;
      final attempts = data['attempts'] as List<dynamic>? ?? [];
      final memberName = data['memberName'] ?? 'Unknown Member';
      final weekNum = data['weekNumber'] ?? '?';

      for (int i = 0; i < attempts.length; i++) {
        final attempt = attempts[i] as Map<String, dynamic>;

        // Check for Submission event
        final submittedAt = attempt['submittedAt'] as Timestamp?;
        if (submittedAt != null) {
          combined.add(
            AuditRecord(
              id: '${doc.id}_submit_$i',
              timestamp: submittedAt.toDate(),
              type: 'submission',
              title: 'Member Submitted Work',
              subtitle:
                  'Week $weekNum submission (Attempt ${attempt['attemptNumber'] ?? i + 1})',
              actorName: memberName,
              actorRole: 'member',
              payload: attempt,
            ),
          );
        }

        // Check for Review event (Lead Accepted or Rejected)
        final reviewedAt = attempt['reviewedAt'] as Timestamp?;
        if (reviewedAt != null) {
          final status = attempt['status'] ?? 'reviewed';
          combined.add(
            AuditRecord(
              id: '${doc.id}_review_$i',
              timestamp: reviewedAt.toDate(),
              type: 'review',
              title: status == 'accepted'
                  ? 'Lead Accepted Submission'
                  : 'Lead Rejected Submission',
              subtitle:
                  'Review for Week $weekNum (Attempt ${attempt['attemptNumber'] ?? i + 1})',
              actorName: attempt['reviewedBy']?.toString().isNotEmpty == true
                  ? attempt['reviewedBy']
                  : 'Lead',
              actorRole: 'lead',
              payload: attempt,
            ),
          );
        }
      }
    }

    // Sort Descending (Newest first)
    combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    setState(() {
      _auditTimeline = combined;
      _isLoadingTimeline = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
            .doc(widget.taskId)
            .snapshots(),
        builder: (context, taskSnap) {
          if (!taskSnap.hasData || !taskSnap.data!.exists) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            );
          }

          final task = taskSnap.data!.data()!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summary(task),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(child: _buildTimelineList()),
            ],
          );
        },
      ),
    );
  }

  Widget _summary(Map<String, dynamic> task) {
    return Container(
      width: double.infinity,
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  Widget _buildTimelineList() {
    if (_isLoadingTimeline) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error loading timeline:\n$_errorMessage',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_auditTimeline.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off, size: 48, color: Color(0xFFCBD5E1)),
            SizedBox(height: 12),
            Text(
              'No history recorded yet.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _auditTimeline.length,
      itemBuilder: (context, index) {
        final record = _auditTimeline[index];
        final isLast = index == _auditTimeline.length - 1;
        final isHighlighted = record.id == widget.highlightedEventId;

        return _buildTimelineItem(record, isLast, isHighlighted);
      },
    );
  }

  Widget _buildTimelineItem(
    AuditRecord record,
    bool isLast,
    bool isHighlighted,
  ) {
    Color iconColor;
    Color bgColor;
    IconData iconData;

    if (record.actorRole == 'hr' || record.type == 'hr_create') {
      iconColor = const Color(0xFF7C3AED); // Purple
      bgColor = const Color(0xFFEDE9FE);
      iconData = Icons.admin_panel_settings;
    } else if (record.actorRole == 'lead' || record.type == 'lead_breakdown') {
      if (record.type == 'review' && record.payload['status'] == 'rejected') {
        iconColor = const Color(0xFFDC2626); // Red
        bgColor = const Color(0xFFFEE2E2);
        iconData = Icons.cancel;
      } else if (record.type == 'review' &&
          record.payload['status'] == 'accepted') {
        iconColor = const Color(0xFF16A34A); // Green
        bgColor = const Color(0xFFDCFCE7);
        iconData = Icons.check_circle;
      } else {
        iconColor = const Color(0xFFD97706); // Orange
        bgColor = const Color(0xFFFEF3C7);
        iconData = Icons.assignment_ind;
      }
    } else {
      // Member submission
      iconColor = const Color(0xFF2563EB); // Blue
      bgColor = const Color(0xFFDBEAFE);
      iconData = Icons.upload_file;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Icon(iconData, size: 16, color: iconColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: const Color(0xFFE2E8F0)),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isHighlighted ? const Color(0xFFFEF9C3) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isHighlighted
                        ? const Color(0xFFFACC15)
                        : const Color(0xFFE2E8F0),
                    width: isHighlighted ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            record.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Text(
                          _formatDate(record.timestamp),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.person,
                          size: 12,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${record.actorName} • ${record.actorRole.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    if (_buildPayloadDetails(record) != null) ...[
                      const SizedBox(height: 8),
                      _buildPayloadDetails(record)!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildPayloadDetails(AuditRecord record) {
    if (record.type == 'lead_breakdown') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Instruction: "${record.payload['instruction'] ?? 'N/A'}"',
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF334155),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    } else if (record.type == 'submission') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Notes: "${record.payload['text'] ?? 'No text provided'}"',
          style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
        ),
      );
    } else if (record.type == 'review' &&
        record.payload['status'] == 'rejected') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Reason: "${record.payload['rejectReason'] ?? 'None given'}"',
          style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
        ),
      );
    }
    return null;
  }

  String _formatDate(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $h:$m';
  }
}
