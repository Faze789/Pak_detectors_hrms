import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';
import 'showAssignToMembersSheet.dart';

/// Lead's review centre for a v2 task.
///
/// Shows every (week, member) pair grouped by week with the latest attempt's
/// status. Tapping a member opens a bottom sheet listing the full attempt
/// history (text + attachments) and lets the lead Accept or Reject (with a
/// reason). Each decision flows through [TaskViewModel.leadReviewWeeklyWork]
/// which logs the audit event and notifies the member + HR.
class LeadReviewScreen extends StatelessWidget {
  const LeadReviewScreen({super.key, required this.taskId});

  final String taskId;

  Stream<DocumentSnapshot<Map<String, dynamic>>> get _taskStream =>
      FirebaseFirestore.instance.collection('tasks').doc(taskId).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _assignmentsStream =>
      FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .collection('weekly_assignments')
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Review Submissions',
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
        stream: _taskStream,
        builder: (context, taskSnap) {
          if (!taskSnap.hasData || !taskSnap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final task = taskSnap.data!.data()!;
          task['id'] = taskSnap.data!.id;
          final totalWeeks = (task['totalWeeks'] ?? 1) as int;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _assignmentsStream,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snap.data!.docs.map((d) {
                final m = d.data();
                m['id'] = d.id;
                return m;
              }).toList();

              // Group by week
              final byWeek = <int, List<Map<String, dynamic>>>{};
              for (final a in all) {
                final w = a['weekNumber'] as int? ?? 0;
                byWeek.putIfAbsent(w, () => []).add(a);
              }

              if (all.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No weekly assignments yet. Use "Continue Breakdown" to '
                      'send instructions to members.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int w = 1; w <= totalWeeks; w++)
                          if ((byWeek[w] ?? []).isNotEmpty)
                            _WeekSection(
                              weekNumber: w,
                              task: task,
                              assignments: byWeek[w]!,
                              nextWeekHasAssignments:
                                  (byWeek[w + 1] ?? const []).isNotEmpty,
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

class _WeekSection extends StatelessWidget {
  const _WeekSection({
    required this.weekNumber,
    required this.task,
    required this.assignments,
    required this.nextWeekHasAssignments,
  });

  final int weekNumber;
  final Map<String, dynamic> task;
  final List<Map<String, dynamic>> assignments;

  /// Whether the next-week section already has assignment docs. Sourced from
  /// the parent's `byWeek` map (live from Firestore), so it's always in sync
  /// with what the user actually sees on screen.
  final bool nextWeekHasAssignments;

  bool get _allAccepted =>
      assignments.isNotEmpty &&
      assignments.every((a) => a['status'] == 'accepted');

  bool get _expired {
    if (assignments.isEmpty) return false;
    final endTs = assignments.first['endDate'] as Timestamp?;
    if (endTs == null) return false;
    return !DateTime.now().isBefore(endTs.toDate());
  }

  /// Multi-phase tasks (bi-weekly / monthly / etc.) have totalWeeks > 1.
  /// Single-phase weekly tasks (totalWeeks == 1) never show the assign-next
  /// button — there is no internal phase progression for them.
  bool get _hasNextWeek {
    final totalWeeks = (task['totalWeeks'] ?? 0) as int;
    return weekNumber < totalWeeks;
  }

  /// "Assign Week N+1 Tasks" appears on the LATEST week that has assignments
  /// (i.e. the next week hasn't been assigned yet) once every member of this
  /// week is accepted, or the week has expired. The dependency on
  /// `task.currentWeek` was dropped because that field can briefly fall out
  /// of sync with the actual state; the data signal `nextWeekHasAssignments`
  /// is sourced directly from the live Firestore snapshot, so the button
  /// appears the instant the lead accepts the last submission.
  bool get _showAssignNext =>
      _hasNextWeek &&
      !nextWeekHasAssignments &&
      (task['status'] ?? '') != 'submitted' &&
      (_allAccepted || _expired);

  void _openAssignNextWeekSheet(BuildContext context) {
    final user = context.read<AuthViewModel>().currentUser;
    showAssignToMembersSheet(
      context,
      task,
      leadEmpId: (task['lead_id'] ?? user?.uid ?? '').toString(),
      weekNumber: weekNumber + 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accepted = assignments.where((a) => a['status'] == 'accepted').length;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Week $weekNumber',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$accepted/${assignments.length} accepted',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              if (_expired) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Expired',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ...assignments.map(
            (a) => _MemberRow(
              assignment: a,
              task: task,
              weekNumber: weekNumber,
            ),
          ),
          if (_showAssignNext) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openAssignNextWeekSheet(context),
                icon: const Icon(
                  Icons.assignment_add,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  'Assign Week ${weekNumber + 1} Tasks',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.assignment,
    required this.task,
    required this.weekNumber,
  });

  final Map<String, dynamic> assignment;
  final Map<String, dynamic> task;
  final int weekNumber;

  @override
  Widget build(BuildContext context) {
    final name = (assignment['memberName'] ?? '').toString();
    final status = (assignment['status'] ?? 'pending').toString();
    final attempts =
        (assignment['attempts'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openReviewSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFDBEAFE),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${attempts.length} attempt${attempts.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            _statusChip(status),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final (label, fg, bg) = switch (status) {
      'pending' => ('Pending', Color(0xFF92400E), Color(0xFFFEF3C7)),
      'submitted' => ('Submitted', Color(0xFF1D4ED8), Color(0xFFDBEAFE)),
      'accepted' => ('Accepted', Color(0xFF065F46), Color(0xFFDCFCE7)),
      'rejected' => ('Rejected', Color(0xFFB91C1C), Color(0xFFFEE2E2)),
      'barrier' => ('Barrier', Color(0xFFB91C1C), Color(0xFFFEE2E2)),
      _ => (status, Color(0xFF64748B), Color(0xFFE2E8F0)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  void _openReviewSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(
        assignment: assignment,
        task: task,
        weekNumber: weekNumber,
      ),
    );
  }
}

// ── Review bottom sheet ───────────────────────────────────────────

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({
    required this.assignment,
    required this.task,
    required this.weekNumber,
  });

  final Map<String, dynamic> assignment;
  final Map<String, dynamic> task;
  final int weekNumber;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  bool _saving = false;

  List<Map<String, dynamic>> get _attempts =>
      (widget.assignment['attempts'] as List?)
          ?.cast<Map<String, dynamic>>() ??
      const <Map<String, dynamic>>[];

  bool get _canDecide {
    if (_attempts.isEmpty) return false;
    final last = _attempts.last;
    return last['status'] == 'submitted';
  }

  Future<void> _decide(bool accept) async {
    String? reason;
    if (!accept) {
      final ctrl = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Reason for rejection'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'What needs to change?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (ctrl.text.trim().isEmpty) return;
                Navigator.of(context).pop(ctrl.text.trim());
              },
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      if (reason == null) return;
    }
    if (!mounted) return;

    setState(() => _saving = true);
    final taskVm = context.read<TaskViewModel>();
    final user = context.read<AuthViewModel>().currentUser;
    final ok = await taskVm.leadReviewWeeklyWork(
      taskId: widget.task['id'],
      weekNumber: widget.weekNumber,
      empId: (widget.assignment['empId'] ?? '').toString(),
      memberName: (widget.assignment['memberName'] ?? '').toString(),
      accept: accept,
      leadEmpId: (widget.task['lead_id'] ?? user?.uid ?? '').toString(),
      leadName: user?.name ?? 'Lead',
      taskTitle: widget.task['title'] ?? '',
      rejectReason: reason,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Accepted.' : 'Rejected.'),
          backgroundColor: const Color(0xFF16A34A),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(taskVm.errorMessage ?? 'Failed'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.fact_check_outlined,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (widget.assignment['memberName'] ?? '').toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Week ${widget.weekNumber} · ${widget.task['title'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              // Body
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lead\'s instruction',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (widget.assignment['instruction'] ?? '').toString(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 12),
                      const Text(
                        'Submission attempts',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_attempts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No submissions yet.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        )
                      else
                        ..._attempts.map(_attemptCard),
                      if (widget.assignment['barrier'] != null) ...[
                        const SizedBox(height: 8),
                        _barrierCard(),
                      ],
                    ],
                  ),
                ),
              ),
              // Footer
              if (_canDecide)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : () => _decide(false),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Color(0xFFB91C1C),
                            ),
                            label: const Text(
                              'Reject',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB91C1C),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFFCA5A5),
                              ),
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
                            onPressed: _saving ? null : () => _decide(true),
                            icon: const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: Text(
                              _saving ? 'Saving…' : 'Accept',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
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
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _attemptCard(Map<String, dynamic> a) {
    final status = (a['status'] ?? '').toString();
    final ts = a['submittedAt'] as Timestamp?;
    final attachments =
        (a['attachments'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final (fg, bg) = switch (status) {
      'accepted' => (Color(0xFF065F46), Color(0xFFDCFCE7)),
      'rejected' => (Color(0xFFB91C1C), Color(0xFFFEE2E2)),
      _ => (Color(0xFF1D4ED8), Color(0xFFDBEAFE)),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Attempt ${a['attemptNumber'] ?? '?'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              const Spacer(),
              if (ts != null)
                Text(
                  _shortTs(ts.toDate()),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            (a['text'] ?? '').toString(),
            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: attachments
                  .map(
                    (att) => GestureDetector(
                      onTap: () {
                        final url = (att['url'] ?? '').toString();
                        if (url.isNotEmpty) launchUrl(Uri.parse(url));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.picture_as_pdf,
                              size: 11,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 3),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                (att['name'] ?? 'pdf').toString(),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (status == 'rejected' &&
              (a['rejectReason'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Reason: ${a['rejectReason']}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _barrierCard() {
    final b = widget.assignment['barrier'] as Map<String, dynamic>? ?? {};
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Member raised a barrier',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFB91C1C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (b['reason'] ?? '').toString(),
            style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
          ),
        ],
      ),
    );
  }

  String _shortTs(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
