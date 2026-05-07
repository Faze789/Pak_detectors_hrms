import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/storage_service.dart';
import '../../services/task_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';
import '../../widgets/task_timeline.dart';

/// Member's per-week submission view for a v2 task.
///
/// Lists every week (1..totalWeeks). Each week is one of:
///   * **locked**     — `now < startDate`. Read-only with the start date.
///   * **active**     — `startDate ≤ now < endDate` and not yet accepted.
///                       Submit (or resubmit) is available.
///   * **expired**    — `now ≥ endDate` and no accepted attempt. Submit is
///                       hidden; the "Barrier to Task" button takes its place.
///   * **accepted**   — last attempt's status is `accepted`. Read-only.
///   * **barrier**    — already raised. Read-only with the reason.
class MemberWeeklySubmitScreen extends StatelessWidget {
  const MemberWeeklySubmitScreen({
    super.key,
    required this.taskId,
    required this.empId,
  });

  final String taskId;
  final String empId;

  Stream<DocumentSnapshot<Map<String, dynamic>>> get _taskStream =>
      FirebaseFirestore.instance.collection('tasks').doc(taskId).snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Weekly Tasks',
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
        actions: [
          IconButton(
            tooltip: 'My timeline',
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _MemberTimelineRoute(
                    taskId: taskId,
                    empId: empId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _taskStream,
        builder: (context, taskSnap) {
          if (taskSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!taskSnap.hasData || !taskSnap.data!.exists) {
            return const Center(child: Text('Task not found.'));
          }
          final task = taskSnap.data!.data()!;
          task['id'] = taskSnap.data!.id;
          // Members only see weeks the lead has actually activated. Weeks
          // beyond `currentWeek` haven't been broken down yet — the lead
          // assigns them dynamically via "Assign Week N Tasks".
          final currentWeek = (task['currentWeek'] ?? 1) as int;

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: TaskService().streamWeeklyAssignmentsForMember(
              taskId: taskId,
              empId: empId,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final assignments = snap.data ?? const [];
              final byWeek = {
                for (final a in assignments) (a['weekNumber'] as int): a,
              };

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TaskSummaryCard(task: task),
                        const SizedBox(height: 16),
                        for (int w = 1; w <= currentWeek; w++)
                          _WeekCard(
                            taskId: taskId,
                            empId: empId,
                            weekNumber: w,
                            task: task,
                            assignment: byWeek[w],
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

// ── Member timeline route (filtered by empId) ─────────────────────

class _MemberTimelineRoute extends StatelessWidget {
  const _MemberTimelineRoute({required this.taskId, required this.empId});
  final String taskId;
  final String empId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Timeline',
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
      body: TaskTimeline(
        eventsStream: TaskService().streamEventsForMember(taskId, empId),
      ),
    );
  }
}

// ── Summary card ───────────────────────────────────────────────────

class _TaskSummaryCard extends StatelessWidget {
  const _TaskSummaryCard({required this.task});
  final Map<String, dynamic> task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
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
          const SizedBox(height: 6),
          if ((task['description'] ?? '').toString().isNotEmpty)
            Text(
              task['description'],
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Text(
                'Lead: ${task['leadName'] ?? ''}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Week card ──────────────────────────────────────────────────────

enum _WeekStateKind { locked, active, expired, accepted, barrier, awaiting }

class _WeekCard extends StatefulWidget {
  const _WeekCard({
    required this.taskId,
    required this.empId,
    required this.weekNumber,
    required this.task,
    required this.assignment,
  });

  final String taskId;
  final String empId;
  final int weekNumber;
  final Map<String, dynamic> task;
  final Map<String, dynamic>? assignment;

  @override
  State<_WeekCard> createState() => _WeekCardState();
}

class _WeekCardState extends State<_WeekCard> {
  bool _expanded = false;

  _WeekStateKind _classify() {
    final a = widget.assignment;
    if (a == null) {
      // Lead hasn't broken down this week yet.
      // Use task's weekStartDates to determine if the calendar window is open.
      final starts =
          (widget.task['weekStartDates'] as List?)?.cast<Timestamp>() ??
          const <Timestamp>[];
      if ((widget.weekNumber - 1) >= starts.length) return _WeekStateKind.awaiting;
      final start = starts[widget.weekNumber - 1].toDate();
      if (DateTime.now().isBefore(start)) return _WeekStateKind.locked;
      return _WeekStateKind.awaiting;
    }
    final status = (a['status'] ?? 'pending').toString();
    if (status == 'accepted') return _WeekStateKind.accepted;
    if (status == 'barrier') return _WeekStateKind.barrier;
    final endTs = a['endDate'] as Timestamp?;
    final start = (a['startDate'] as Timestamp?)?.toDate();
    final end = endTs?.toDate();
    final now = DateTime.now();
    if (start != null && now.isBefore(start)) return _WeekStateKind.locked;
    if (end != null && !now.isBefore(end)) return _WeekStateKind.expired;
    return _WeekStateKind.active;
  }

  @override
  Widget build(BuildContext context) {
    final kind = _classify();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(kind),
          if (widget.assignment != null) _instructionBlock(),
          _stateBody(kind),
        ],
      ),
    );
  }

  Widget _header(_WeekStateKind kind) {
    final start = (widget.assignment?['startDate'] as Timestamp?)?.toDate();
    final end = (widget.assignment?['endDate'] as Timestamp?)?.toDate();
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    final range = (start != null && end != null)
        ? '${fmt(start)} → ${fmt(end)}'
        : '';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Week ${widget.weekNumber}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (range.isNotEmpty)
                  Text(
                    range,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
          _statusChip(kind),
        ],
      ),
    );
  }

  Widget _statusChip(_WeekStateKind kind) {
    final (label, fg, bg) = switch (kind) {
      _WeekStateKind.locked => ('Locked', Color(0xFF64748B), Color(0xFFE2E8F0)),
      _WeekStateKind.awaiting => (
        'Not yet assigned',
        Color(0xFF92400E),
        Color(0xFFFEF3C7),
      ),
      _WeekStateKind.active => ('Active', Color(0xFF065F46), Color(0xFFDCFCE7)),
      _WeekStateKind.expired => ('Expired', Color(0xFFB91C1C), Color(0xFFFEE2E2)),
      _WeekStateKind.accepted => (
        'Accepted',
        Color(0xFF065F46),
        Color(0xFFDCFCE7),
      ),
      _WeekStateKind.barrier => (
        'Barrier',
        Color(0xFFB91C1C),
        Color(0xFFFEE2E2),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _instructionBlock() {
    final a = widget.assignment!;
    final attachments =
        (a['attachments'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lead\'s instructions',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (a['instruction'] ?? '').toString(),
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E293B),
              height: 1.4,
            ),
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: attachments.map(_attachmentChip).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _attachmentChip(Map<String, dynamic> a) {
    return GestureDetector(
      onTap: () {
        final url = (a['url'] ?? '').toString();
        if (url.isNotEmpty) launchUrl(Uri.parse(url));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.picture_as_pdf,
              size: 13,
              color: Color(0xFF2563EB),
            ),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                (a['name'] ?? 'attachment.pdf').toString(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stateBody(_WeekStateKind kind) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: switch (kind) {
        _WeekStateKind.locked => _locked(),
        _WeekStateKind.awaiting => _awaiting(),
        _WeekStateKind.active => _activeBody(),
        _WeekStateKind.expired => _expiredBody(),
        _WeekStateKind.accepted => _attemptHistory(showHeading: true),
        _WeekStateKind.barrier => _barrierShown(),
      },
    );
  }

  Widget _locked() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Text(
        'This week is not active yet.',
        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      ),
    );
  }

  Widget _awaiting() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Text(
        'Your lead hasn\'t broken down this week yet. Hold tight.',
        style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      ),
    );
  }

  Widget _activeBody() {
    final attempts = _attemptsList();
    final canResubmit = attempts.isEmpty || attempts.last['status'] == 'rejected';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attempts.isNotEmpty) ...[
          _attemptHistory(showHeading: true),
          const SizedBox(height: 10),
        ],
        if (canResubmit)
          ElevatedButton.icon(
            onPressed: () => _showSubmitDialog(isResubmit: attempts.isNotEmpty),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text(
              attempts.isEmpty ? 'Submit Work' : 'Resubmit Work',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.hourglass_top_rounded,
                  size: 16,
                  color: Color(0xFF2563EB),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Awaiting your lead\'s review.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _expiredBody() {
    final attempts = _attemptsList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attempts.isNotEmpty) ...[
          _attemptHistory(showHeading: true),
          const SizedBox(height: 10),
        ],
        ElevatedButton.icon(
          onPressed: () => _showBarrierDialog(),
          icon: const Icon(Icons.report_gmailerrorred_rounded, size: 16),
          label: const Text(
            'Barrier to Task',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB91C1C),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _barrierShown() {
    final b = widget.assignment?['barrier'] as Map<String, dynamic>?;
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
            'Barrier raised',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB91C1C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (b?['reason'] ?? '').toString(),
            style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _attemptsList() {
    final raw = (widget.assignment?['attempts'] as List?) ?? const <dynamic>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Widget _attemptHistory({required bool showHeading}) {
    final attempts = _attemptsList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  '${attempts.length} attempt${attempts.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (_expanded || !showHeading)
          ...attempts.map(_attemptCard)
        else if (attempts.isNotEmpty)
          _attemptCard(attempts.last),
      ],
    );
  }

  Widget _attemptCard(Map<String, dynamic> attempt) {
    final status = (attempt['status'] ?? '').toString();
    final ts = attempt['submittedAt'] as Timestamp?;
    final reviewedTs = attempt['reviewedAt'] as Timestamp?;
    final attachments =
        (attempt['attachments'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final (badgeFg, badgeBg) = switch (status) {
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
                'Attempt ${attempt['attemptNumber'] ?? '?'}',
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
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeFg,
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
            (attempt['text'] ?? '').toString(),
            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: attachments.map(_attachmentChip).toList(),
            ),
          ],
          if (status == 'rejected' && (attempt['rejectReason'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 12,
                    color: Color(0xFFB91C1C),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Reason: ${attempt['rejectReason']}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7F1D1D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (reviewedTs != null) ...[
            const SizedBox(height: 4),
            Text(
              'Reviewed: ${_shortTs(reviewedTs.toDate())}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        ],
      ),
    );
  }

  String _shortTs(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _showSubmitDialog({required bool isResubmit}) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _SubmitDialog(
        taskId: widget.taskId,
        weekNumber: widget.weekNumber,
        empId: widget.empId,
        task: widget.task,
        isResubmit: isResubmit,
      ),
    );
  }

  Future<void> _showBarrierDialog() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Barrier to Task'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Why couldn\'t you complete this week\'s work?',
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
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    final user = context.read<AuthViewModel>().currentUser;
    final taskVm = context.read<TaskViewModel>();
    final ok = await taskVm.memberRaiseBarrier(
      taskId: widget.taskId,
      weekNumber: widget.weekNumber,
      empId: widget.empId,
      memberName: user?.name ?? 'Member',
      reason: reason,
      leadEmpId: (widget.task['lead_id'] ?? '').toString(),
      taskTitle: widget.task['title'] ?? '',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Barrier sent.' : taskVm.errorMessage ?? 'Failed',
        ),
        backgroundColor: ok
            ? const Color(0xFF16A34A)
            : const Color(0xFFEF4444),
      ),
    );
  }
}

// ── Submit dialog ─────────────────────────────────────────────────

class _SubmitDialog extends StatefulWidget {
  const _SubmitDialog({
    required this.taskId,
    required this.weekNumber,
    required this.empId,
    required this.task,
    required this.isResubmit,
  });

  final String taskId;
  final int weekNumber;
  final String empId;
  final Map<String, dynamic> task;
  final bool isResubmit;

  @override
  State<_SubmitDialog> createState() => _SubmitDialogState();
}

class _SubmitDialogState extends State<_SubmitDialog> {
  final TextEditingController _textCtrl = TextEditingController();
  final List<PlatformFile> _files = [];
  final StorageService _storage = StorageService();
  bool _saving = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null) return;
    setState(() => _files.addAll(result.files));
  }

  Future<void> _submit() async {
    if (_textCtrl.text.trim().isEmpty) {
      _snack('Write something before submitting.', error: true);
      return;
    }
    setState(() => _saving = true);
    final user = context.read<AuthViewModel>().currentUser;
    final taskVm = context.read<TaskViewModel>();
    List<Map<String, dynamic>>? uploaded;
    try {
      if (_files.isNotEmpty) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        uploaded = await _storage.uploadManyPdfs(
          pathPrefix:
              'task_attachments/${widget.taskId}/submissions/week_${widget.weekNumber}/${widget.empId}_$ts',
          files: _files,
          uploadedBy: widget.empId,
          uploaderRole: 'member',
        );
      }
      final ok = await taskVm.memberSubmitWeeklyWork(
        taskId: widget.taskId,
        weekNumber: widget.weekNumber,
        empId: widget.empId,
        memberName: user?.name ?? 'Member',
        text: _textCtrl.text.trim(),
        leadEmpId: (widget.task['lead_id'] ?? '').toString(),
        taskTitle: widget.task['title'] ?? '',
        attachments: uploaded,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (ok) {
        Navigator.of(context).pop();
        _snack('Submitted.');
      } else {
        _snack(taskVm.errorMessage ?? 'Submit failed', error: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.toString(), error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error
            ? const Color(0xFFEF4444)
            : const Color(0xFF16A34A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Color(0xFF2563EB),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.isResubmit
                          ? 'Resubmit Week ${widget.weekNumber}'
                          : 'Submit Week ${widget.weekNumber}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textCtrl,
                minLines: 4,
                maxLines: null,
                style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                decoration: InputDecoration(
                  hintText: 'Describe what you did this week…',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFCBD5E1),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_files.isNotEmpty)
                      ..._files.asMap().entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.picture_as_pdf,
                                size: 14,
                                color: Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  e.value.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _files.removeAt(e.key)),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    OutlinedButton.icon(
                      onPressed: _pick,
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: const Text(
                        'Attach PDF (optional)',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    disabledBackgroundColor: const Color(0xFF93C5FD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.isResubmit ? 'Resubmit' : 'Submit',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
