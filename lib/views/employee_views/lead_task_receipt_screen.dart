import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/task_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';
import '../../widgets/task_timeline.dart';
import 'lead_edit_and_accept_dialog.dart';
import 'lead_review_screen.dart';
import 'lead_team_manager_sheet.dart';
import 'showAssignToMembersSheet.dart';

/// Lead's main entry screen for an HR-assigned task.
///
/// Pre-acceptance (`leadAcceptanceState == 'awaiting'`) presents the four
/// required options from spec §2:
///   1. Manage team for this task
///   2. Edit task, then accept
///   3. Accept without editing
///   4. Break down and assign to members
///
/// Once the lead has accepted (option 2, 3, or 4), the screen swaps to
/// post-acceptance actions: continue/edit breakdown, review submissions,
/// submit to HR (enabled once all weeks are accepted).
class LeadTaskReceiptScreen extends StatefulWidget {
  const LeadTaskReceiptScreen({super.key, required this.taskId});

  final String taskId;

  @override
  State<LeadTaskReceiptScreen> createState() => _LeadTaskReceiptScreenState();
}

class _LeadTaskReceiptScreenState extends State<LeadTaskReceiptScreen> {
  Stream<DocumentSnapshot<Map<String, dynamic>>> get _taskStream =>
      FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Task Receipt',
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
            tooltip: 'Timeline',
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _LeadTimelineRoute(taskId: widget.taskId),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _taskStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Task not found.',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            );
          }
          final task = snap.data!.data()!;
          task['id'] = snap.data!.id;
          final state = (task['leadAcceptanceState'] ?? 'awaiting') as String;
          return _Body(task: task, awaiting: state == 'awaiting');
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.task, required this.awaiting});

  final Map<String, dynamic> task;
  final bool awaiting;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TaskHeaderCard(task: task),
              const SizedBox(height: 16),
              if (awaiting)
                _AwaitingActions(task: task)
              else
                _PostAcceptanceActions(task: task),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header card ─────────────────────────────────────────────────────────

class _TaskHeaderCard extends StatelessWidget {
  const _TaskHeaderCard({required this.task});
  final Map<String, dynamic> task;

  @override
  Widget build(BuildContext context) {
    final state = (task['leadAcceptanceState'] ?? 'awaiting') as String;
    final totalWeeks = (task['totalWeeks'] ?? 1) as int;
    final members =
        task['members'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final attachments =
        (task['attachments'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    return Container(
      padding: const EdgeInsets.all(16),
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
              Expanded(
                child: Text(
                  task['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              _stateChip(state),
            ],
          ),
          const SizedBox(height: 8),
          if ((task['description'] ?? '').toString().isNotEmpty)
            Text(
              task['description'],
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                Icons.calendar_view_week_rounded,
                '$totalWeeks week${totalWeeks == 1 ? '' : 's'}',
              ),
              _chip(
                Icons.group_outlined,
                '${members.length} member${members.length == 1 ? '' : 's'}',
              ),
              _chip(
                Icons.label_outline,
                (task['duration'] ?? '').toString(),
              ),
              if (attachments.isNotEmpty)
                _chip(
                  Icons.picture_as_pdf,
                  '${attachments.length} attachment${attachments.length == 1 ? '' : 's'}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stateChip(String state) {
    final (label, fg, bg) = switch (state) {
      'awaiting' => ('Awaiting Lead', Color(0xFFB45309), Color(0xFFFEF3C7)),
      'accepted_as_is' => (
        'Accepted',
        Color(0xFF065F46),
        Color(0xFFDCFCE7),
      ),
      'accepted_with_edits' => (
        'Accepted (edited)',
        Color(0xFF065F46),
        Color(0xFFDCFCE7),
      ),
      _ => (state, Color(0xFF64748B), Color(0xFFE2E8F0)),
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

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF2563EB)),
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

// ── Awaiting state actions (4 options) ─────────────────────────────────

class _AwaitingActions extends StatelessWidget {
  const _AwaitingActions({required this.task});
  final Map<String, dynamic> task;

  Future<void> _handleAcceptAsIs(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Accept this task?'),
        content: const Text(
          'You\'re accepting HR\'s task without changes. You can still manage '
          'the team and break it down by week afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final user = context.read<AuthViewModel>().currentUser;
    final taskVm = context.read<TaskViewModel>();
    final result = await taskVm.leadAcceptTask(
      taskId: task['id'],
      variant: 'accepted_as_is',
      leadEmpId: (task['lead_id'] ?? user?.uid ?? '').toString(),
      leadName: user?.name ?? 'Lead',
      taskTitle: task['title'] ?? '',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result ? 'Task accepted.' : taskVm.errorMessage ?? 'Failed'),
        backgroundColor: result
            ? const Color(0xFF16A34A)
            : const Color(0xFFEF4444),
      ),
    );
  }

  void _handleBreakdown(BuildContext context) {
    final user = context.read<AuthViewModel>().currentUser;
    showAssignToMembersSheet(
      context,
      task,
      leadEmpId: (task['lead_id'] ?? user?.uid ?? '').toString(),
      onAssigned: () async {
        // First save in awaiting state implicitly accepts as-is.
        if (!context.mounted) return;
        final taskVm = context.read<TaskViewModel>();
        await taskVm.leadAcceptTask(
          taskId: task['id'],
          variant: 'accepted_as_is',
          leadEmpId: (task['lead_id'] ?? user?.uid ?? '').toString(),
          leadName: user?.name ?? 'Lead',
          taskTitle: task['title'] ?? '',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose how to handle this task',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Manage the team anytime. Options 2, 3, and 4 will accept the task.',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 12),
        _OptionCard(
          number: '1',
          icon: Icons.group_outlined,
          title: 'Manage Team',
          subtitle: 'Add or remove members. Min 1 required.',
          onTap: () => showLeadTeamManagerSheet(context, task),
        ),
        const SizedBox(height: 8),
        _OptionCard(
          number: '2',
          icon: Icons.edit_note_rounded,
          title: 'Edit & Accept',
          subtitle: 'Modify title, description, or attachments before accepting.',
          onTap: () => showLeadEditAndAcceptDialog(context, task),
        ),
        const SizedBox(height: 8),
        _OptionCard(
          number: '3',
          icon: Icons.check_circle_rounded,
          title: 'Accept Without Editing',
          subtitle: 'One-tap accept of HR\'s original task.',
          onTap: () => _handleAcceptAsIs(context),
        ),
        const SizedBox(height: 8),
        _OptionCard(
          number: '4',
          icon: Icons.dashboard_customize_rounded,
          title: 'Break Down & Assign',
          subtitle:
              'Write per-member instructions for each week and assign now.',
          onTap: () => _handleBreakdown(context),
        ),
      ],
    );
  }
}

// ── Post-acceptance actions ────────────────────────────────────────────

class _PostAcceptanceActions extends StatelessWidget {
  const _PostAcceptanceActions({required this.task});
  final Map<String, dynamic> task;

  Stream<QuerySnapshot<Map<String, dynamic>>> get _assignmentsStream =>
      FirebaseFirestore.instance
          .collection('tasks')
          .doc(task['id'])
          .collection('weekly_assignments')
          .snapshots();

  Future<void> _confirmSubmitToHr(BuildContext context) async {
    final summaryCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Submit to HR?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Submitting will hand the whole task back to HR for final review.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: summaryCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Optional summary for HR…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final user = context.read<AuthViewModel>().currentUser;
    final taskVm = context.read<TaskViewModel>();
    final result = await taskVm.leadSubmitTaskToHr(
      taskId: task['id'],
      leadEmpId: (task['lead_id'] ?? user?.uid ?? '').toString(),
      leadName: user?.name ?? 'Lead',
      taskTitle: task['title'] ?? '',
      summary: summaryCtrl.text.trim().isEmpty
          ? null
          : summaryCtrl.text.trim(),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result ? 'Submitted to HR.' : taskVm.errorMessage ?? 'Failed',
        ),
        backgroundColor: result
            ? const Color(0xFF16A34A)
            : const Color(0xFFEF4444),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskStatus = (task['status'] ?? '').toString();
    final totalWeeks = (task['totalWeeks'] ?? 1) as int;
    final currentWeek = (task['currentWeek'] ?? 1) as int;
    final deadlineTs = task['deadline'] as Timestamp?;
    final daysRemaining = deadlineTs == null
        ? 0
        : deadlineTs.toDate().difference(DateTime.now()).inDays;
    final withinSubmitWindow = deadlineTs != null && daysRemaining <= 3;
    final isFinalWeek = currentWeek == totalWeeks;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _assignmentsStream,
      builder: (context, snap) {
        // Compute "current week assignments exist" + "all current week accepted".
        final all = snap.data?.docs.map((d) => d.data()).toList() ??
            const <Map<String, dynamic>>[];
        final currentWeekAssignments =
            all.where((a) => a['weekNumber'] == currentWeek).toList();
        final hasCurrentAssignments = currentWeekAssignments.isNotEmpty;
        final allCurrentAccepted = currentWeekAssignments.isNotEmpty &&
            currentWeekAssignments
                .every((a) => a['status'] == 'accepted');
        final hasNextPhase = currentWeek < totalWeeks;
        final finalWeekAccepted = isFinalWeek && allCurrentAccepted;

        // Submit-to-HR gate (per spec):
        //   "lead can submit the task to HR only if all weeks tasks been
        //    done and assigned to members OR 3 days left for the deadline".
        // So either condition unlocks it (was AND before).
        final allWeeksDoneAndAccepted = isFinalWeek && finalWeekAccepted;
        final canSubmit =
            (allWeeksDoneAndAccepted || withinSubmitWindow) &&
                taskStatus != 'submitted';

        // ── Smart target week ──────────────────────────────────────
        // When this week's assignments are all accepted and there's a next
        // phase, advance the assign card to currentWeek + 1. Without this,
        // clicking "Continue Breakdown" defaults to currentWeek and just
        // edits the already-accepted week in place, never activating the
        // next phase. The explicit "Assign Week N+1 Tasks" button in
        // LeadReviewScreen also points at this same target.
        final shouldAdvance = allCurrentAccepted && hasNextPhase;
        final targetWeek = shouldAdvance ? currentWeek + 1 : currentWeek;

        final String assignLabel;
        final String assignSubtitle;
        if (shouldAdvance) {
          assignLabel = 'Assign Week $targetWeek Tasks';
          assignSubtitle =
              'Week $currentWeek is fully accepted. Define Week $targetWeek\'s work for each member.';
        } else if (hasCurrentAssignments) {
          assignLabel = 'Edit Week $currentWeek Tasks';
          assignSubtitle =
              'Update this week\'s per-member instructions or attachments.';
        } else {
          assignLabel = 'Assign Week $currentWeek Tasks';
          assignSubtitle =
              'Write fresh instructions for this week and assign to members.';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage this task',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              taskStatus == 'submitted'
                  ? 'Submitted to HR — awaiting their review.'
                  : 'Currently on Week $currentWeek of $totalWeeks. Assign fresh '
                      'work each phase.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            _OptionCard(
              icon: Icons.group_outlined,
              title: 'Manage Team',
              subtitle: 'Add or remove members. Min 1 required.',
              onTap: () => showLeadTeamManagerSheet(context, task),
            ),
            const SizedBox(height: 8),
            _OptionCard(
              icon: Icons.dashboard_customize_rounded,
              title: assignLabel,
              subtitle: assignSubtitle,
              onTap: () {
                final user = context.read<AuthViewModel>().currentUser;
                showAssignToMembersSheet(
                  context,
                  task,
                  leadEmpId:
                      (task['lead_id'] ?? user?.uid ?? '').toString(),
                  weekNumber: targetWeek,
                );
              },
            ),
            const SizedBox(height: 8),
            _OptionCard(
              icon: Icons.fact_check_outlined,
              title: 'Review Submissions',
              subtitle:
                  'Accept or reject member work. Next-week assignment opens here.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LeadReviewScreen(taskId: task['id']),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _OptionCard(
              icon: Icons.send_rounded,
              title: 'Submit to HR',
              subtitle: canSubmit
                  ? (allWeeksDoneAndAccepted
                      ? 'All weeks accepted — hand the task back to HR.'
                      : 'Final $daysRemaining day${daysRemaining == 1 ? '' : 's'} — submit what\'s ready.')
                  : taskStatus == 'submitted'
                      ? 'Already submitted.'
                      : 'Unlocks once every week is accepted '
                          'OR the final 3 days begin '
                          '($daysRemaining day${daysRemaining == 1 ? '' : 's'} remaining).',
              onTap: canSubmit ? () => _confirmSubmitToHr(context) : null,
            ),
          ],
        );
      },
    );
  }
}

// ── Lead timeline route (full event chain) ────────────────────────────

class _LeadTimelineRoute extends StatelessWidget {
  const _LeadTimelineRoute({required this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Task Timeline',
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
      body: TaskTimeline(eventsStream: TaskService().streamEvents(taskId)),
    );
  }
}

// ── Reusable option card ──────────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.number,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? number;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              if (number != null) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: disabled
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    number!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: disabled
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF2563EB),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: disabled
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: disabled
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: disabled
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF94A3B8),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
