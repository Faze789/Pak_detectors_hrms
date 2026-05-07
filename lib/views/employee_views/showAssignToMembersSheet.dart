import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/storage_service.dart';
import '../../services/task_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/task_viewmodel.dart';

/// Lead's per-(week, member) breakdown sheet — single-week mode.
///
/// Each call assigns ONE week's work. The lead writes per-member
/// instructions and saves; for `weekNumber > task.currentWeek` the save
/// implicitly activates the new phase (start=NOW, end=NOW+cycle) inside
/// [TaskService.upsertWeeklyAssignment]. For `weekNumber == currentWeek`
/// it edits the existing assignments in place.
///
/// `weekNumber` defaults to `task['currentWeek']` (or 1 if absent), so the
/// "Continue Breakdown" entry from the receipt screen always lands on the
/// active week. Pass `weekNumber: N` from the review screen's "Assign Week
/// N Tasks" button to assign a future phase.
///
/// Pre-v2 tasks fall back to the legacy single-pass forwardTaskToAllMembers
/// flow so existing behaviour is preserved.
void showAssignToMembersSheet(
  BuildContext context,
  Map<String, dynamic> task, {
  VoidCallback? onAssigned,
  String? leadEmpId,
  int? weekNumber,
}) {
  final resolvedLeadEmpId =
      (leadEmpId ?? task['lead_id'] ?? '').toString().toLowerCase();

  final sw = MediaQuery.of(context).size.width;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: sw >= 768
        ? const BoxConstraints(maxWidth: 720, minWidth: 400)
        : null,
    builder: (_) => _BreakdownSheet(
      task: task,
      leadEmpId: resolvedLeadEmpId,
      onAssigned: onAssigned,
      weekNumber: weekNumber,
    ),
  );
}

class _BreakdownSheet extends StatefulWidget {
  const _BreakdownSheet({
    required this.task,
    required this.leadEmpId,
    this.onAssigned,
    this.weekNumber,
  });

  final Map<String, dynamic> task;
  final String leadEmpId;
  final VoidCallback? onAssigned;
  final int? weekNumber;

  @override
  State<_BreakdownSheet> createState() => _BreakdownSheetState();
}

class _BreakdownSheetState extends State<_BreakdownSheet> {
  late final bool _isV2;
  late final int _totalWeeks;
  late final List<Map<String, dynamic>> _members;
  // Mutable so the smart auto-advance in [_hydrateV2FromFirestore] can bump
  // it from currentWeek → currentWeek+1 when the caller forgot to pin one
  // and the current week is already fully accepted.
  late int _weekNumber;

  // v2 state ───────────────────────────────────────────────────────
  // empId -> instruction controller for this week.
  final Map<String, TextEditingController> _v2Ctrl = {};
  final List<PlatformFile> _v2Attachments = [];
  bool _v2Loading = false;
  bool _v2Saving = false;

  // v1 (legacy) state ──────────────────────────────────────────────
  TextEditingController? _commonInstructionCtrl;
  final Map<String, TextEditingController> _legacyMemberCtrl = {};
  bool _legacyPerMemberMode = false;
  bool _legacySubmitting = false;

  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _isV2 = widget.task['schemaVersion'] == 2;
    _totalWeeks = (widget.task['totalWeeks'] ?? 1) as int;

    final raw =
        widget.task['members'] as Map<String, dynamic>? ?? <String, dynamic>{};
    _members = [];
    for (final v in raw.values) {
      if (v is Map<String, dynamic>) {
        final empId = (v['emp_id'] ?? '').toString().toLowerCase();
        if (empId.isEmpty || empId == widget.leadEmpId) continue;
        _members.add(v);
      }
    }

    if (_isV2) {
      _weekNumber = widget.weekNumber ??
          (widget.task['currentWeek'] as int? ?? 1);
      for (final m in _members) {
        final id = (m['emp_id'] ?? '').toString().toLowerCase();
        _v2Ctrl[id] = TextEditingController(
          text: widget.task['description'] ?? '',
        );
      }
      _hydrateV2FromFirestore();
    } else {
      _weekNumber = 1;
      _commonInstructionCtrl = TextEditingController(
        text: widget.task['description'] ?? '',
      );
      for (final m in _members) {
        final empId = (m['emp_id'] ?? '').toString();
        if (empId.isEmpty) continue;
        _legacyMemberCtrl[empId] = TextEditingController(
          text: widget.task['description'] ?? '',
        );
      }
    }
  }

  /// Pre-fill fields from any existing weekly_assignments docs for this week.
  ///
  /// Also performs a **defensive auto-advance**: when the resolved week's
  /// assignments are already all `accepted` and a next phase exists, bump
  /// `_weekNumber` to `currentWeek + 1`. This catches every path that
  /// dispatches into the sheet without explicitly pinning a week (e.g. the
  /// EmployeeGoalsScreen popup-menu "assign" → defaults to `task.currentWeek`)
  /// so the lead's intent ("assign the next week") doesn't silently get
  /// remapped to "rewrite the already-completed week's instructions in
  /// place" — which is exactly the trap that prevented `currentWeek` from
  /// ever advancing in your data.
  Future<void> _hydrateV2FromFirestore() async {
    setState(() => _v2Loading = true);
    try {
      final svc = TaskService();
      final existing = await svc.getAllWeeklyAssignments(widget.task['id']);

      // Auto-advance check — only when the resolved week IS the parent's
      // currentWeek. We don't override an explicitly-pinned future week
      // (e.g. LeadReviewScreen's "Assign Week N+1 Tasks" button) and we
      // don't auto-advance past totalWeeks.
      final taskCurrentWeek =
          (widget.task['currentWeek'] as int?) ?? 1;
      if (_weekNumber == taskCurrentWeek &&
          taskCurrentWeek < _totalWeeks) {
        final currentDocs = existing
            .where((a) => a['weekNumber'] == taskCurrentWeek)
            .toList();
        final allAccepted = currentDocs.isNotEmpty &&
            currentDocs.every((a) => a['status'] == 'accepted');
        if (allAccepted) {
          _weekNumber = taskCurrentWeek + 1;
        }
      }

      // Pre-fill text fields with any existing instruction for the resolved
      // week (works for both edit-current and assign-next cases).
      for (final a in existing) {
        if ((a['weekNumber'] as int?) != _weekNumber) continue;
        final empId = (a['empId'] ?? '').toString().toLowerCase();
        if (empId.isEmpty) continue;
        final ctrl = _v2Ctrl[empId];
        if (ctrl != null) {
          ctrl.text = (a['instruction'] ?? '').toString();
        }
      }
    } catch (_) {
      // ignore — start blank
    } finally {
      if (mounted) setState(() => _v2Loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in _v2Ctrl.values) {
      c.dispose();
    }
    _commonInstructionCtrl?.dispose();
    for (final c in _legacyMemberCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── v2 save ──────────────────────────────────────────────────────
  Future<void> _v2Save() async {
    final user = context.read<AuthViewModel>().currentUser;
    final taskVm = context.read<TaskViewModel>();
    final taskId = widget.task['id'] as String;

    final filled = _members.where((m) {
      final id = (m['emp_id'] ?? '').toString().toLowerCase();
      return (_v2Ctrl[id]?.text.trim().isNotEmpty ?? false);
    }).toList();
    if (filled.isEmpty) {
      _snack('Write an instruction for at least one member.', error: true);
      return;
    }

    setState(() => _v2Saving = true);

    // Upload attachments once, reuse for every member of this week.
    List<Map<String, dynamic>>? uploaded;
    if (_v2Attachments.isNotEmpty) {
      try {
        final ts = DateTime.now().millisecondsSinceEpoch;
        uploaded = await _storage.uploadManyPdfs(
          pathPrefix: 'task_attachments/$taskId/week_${_weekNumber}_$ts',
          files: _v2Attachments,
          uploadedBy: widget.leadEmpId,
          uploaderRole: 'lead',
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _v2Saving = false);
        _snack('Attachment upload failed: $e', error: true);
        return;
      }
    }

    var allOk = true;
    for (final m in filled) {
      final empId = (m['emp_id'] ?? '').toString();
      final memberName = (m['name'] ?? '').toString();
      final instruction = _v2Ctrl[empId.toLowerCase()]?.text.trim() ?? '';
      final ok = await taskVm.leadSetWeekInstruction(
        taskId: taskId,
        weekNumber: _weekNumber,
        empId: empId,
        memberName: memberName,
        instruction: instruction,
        leadEmpId: widget.leadEmpId,
        leadName: user?.name ?? 'Lead',
        taskTitle: widget.task['title'] ?? '',
        attachments: uploaded,
      );
      if (!ok) allOk = false;
    }

    if (!mounted) return;
    setState(() => _v2Saving = false);
    if (allOk) {
      Navigator.of(context).pop();
      widget.onAssigned?.call();
      _snack('Week $_weekNumber tasks assigned.');
    } else {
      _snack(taskVm.errorMessage ?? 'Some assignments failed.', error: true);
    }
  }

  Future<void> _v2PickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null) return;
    setState(() => _v2Attachments.addAll(result.files));
  }

  // ── v1 (legacy) submit ───────────────────────────────────────────
  Future<void> _legacySubmit() async {
    if (_commonInstructionCtrl!.text.trim().isEmpty &&
        !_legacyPerMemberMode) {
      _snack('Please enter instructions for the team.', error: true);
      return;
    }
    if (_legacyPerMemberMode) {
      for (final entry in _legacyMemberCtrl.entries) {
        if (entry.value.text.trim().isEmpty) {
          _snack('Please fill in instructions for all members.', error: true);
          return;
        }
      }
    }

    setState(() => _legacySubmitting = true);
    final taskVm = context.read<TaskViewModel>();
    final leadEmpId = widget.task['lead_id'] ?? '';
    final taskTitle = widget.task['title'] ?? '';
    final taskId = widget.task['id'] ?? '';

    bool allOk = true;
    if (_legacyPerMemberMode) {
      for (final m in _members) {
        final empId = (m['emp_id'] ?? '').toString();
        final memberName = (m['name'] ?? '').toString();
        if (empId.isEmpty) continue;
        final instructions = _legacyMemberCtrl[empId]?.text.trim() ?? '';
        final ok = await taskVm.forwardTaskToMember(
          taskId: taskId,
          empId: empId,
          memberName: memberName,
          instructions: instructions,
          leadEmpId: leadEmpId,
          taskTitle: taskTitle,
          weekNumber: 1,
        );
        if (!ok) allOk = false;
      }
    } else {
      final membersAsMap = <String, dynamic>{};
      for (var i = 0; i < _members.length; i++) {
        membersAsMap['${i + 1}'] = _members[i];
      }
      final ok = await taskVm.forwardTaskToAllMembers(
        taskId: taskId,
        members: membersAsMap,
        instructions: _commonInstructionCtrl!.text.trim(),
        weekNumber: 1,
        leadEmpId: leadEmpId,
        taskTitle: taskTitle,
      );
      if (!ok) allOk = false;
    }

    if (!mounted) return;
    setState(() => _legacySubmitting = false);
    if (allOk) {
      Navigator.of(context).pop();
      widget.onAssigned?.call();
      _snack('Task assigned to all members successfully!');
    } else {
      _snack(
        taskVm.errorMessage ?? 'Failed to assign task to members.',
        error: true,
      );
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error
            ? const Color(0xFFDC2626)
            : const Color(0xFF16A34A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
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
              _buildHeader(),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              if (_members.isEmpty)
                const Expanded(child: _NoMembersBanner())
              else if (_isV2)
                Expanded(child: _v2Body(scrollCtrl))
              else
                Expanded(child: _legacyBody(scrollCtrl)),
              if (_members.isNotEmpty) _buildFooter(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
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
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.dashboard_customize_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isV2
                          ? 'Assign Week $_weekNumber Tasks'
                          : 'Forward to Members',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      widget.task['title'] ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isV2)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Week $_weekNumber / $_totalWeeks',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _v2Body(ScrollController scrollCtrl) {
    if (_v2Loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              'Write fresh instructions for this week. Saving will activate '
              'the week (start = now) and notify each member.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._members.map((m) {
            final empId = (m['emp_id'] ?? '').toString();
            final name = (m['name'] ?? 'Unknown').toString();
            final ctrl = _v2Ctrl[empId.toLowerCase()];
            if (ctrl == null) return const SizedBox.shrink();
            return _memberInstructionCard(
              name: name,
              empId: empId,
              controller: ctrl,
            );
          }),
          const SizedBox(height: 6),
          _weekAttachmentsBox(),
        ],
      ),
    );
  }

  Widget _memberInstructionCard({
    required String name,
    required String empId,
    required TextEditingController controller,
  }) {
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
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
                const SizedBox(width: 8),
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
                        empId,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: controller,
              minLines: 3,
              maxLines: null,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
              decoration: InputDecoration(
                hintText: 'What should $name do this week?',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFCBD5E1),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekAttachmentsBox() {
    return Container(
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
          const Text(
            'Optional PDFs for this week (applied to every saved member)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          if (_v2Attachments.isNotEmpty)
            ..._v2Attachments.asMap().entries.map((e) {
              final i = e.key;
              final f = e.value;
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
                        f.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _v2Attachments.removeAt(i)),
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
            onPressed: _v2PickAttachments,
            icon: const Icon(Icons.upload_file_rounded, size: 16),
            label: const Text('Add PDF', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  // ── v1 (legacy) body ───────────────────────────────────────────
  Widget _legacyBody(ScrollController scrollCtrl) {
    return SingleChildScrollView(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: _legacyPerMemberMode
          ? _legacyPerMemberForm()
          : _legacyCommonForm(),
    );
  }

  Widget _legacyCommonForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Instructions for the Team',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            _toggle(_legacyPerMemberMode, () {
              setState(() => _legacyPerMemberMode = !_legacyPerMemberMode);
            }),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _commonInstructionCtrl,
          minLines: 5,
          maxLines: null,
          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: 'Common instructions for all members…',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legacyPerMemberForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Instructions per Member',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            _toggle(_legacyPerMemberMode, () {
              setState(() => _legacyPerMemberMode = !_legacyPerMemberMode);
            }),
          ],
        ),
        const SizedBox(height: 12),
        ..._members.map((m) {
          final empId = (m['emp_id'] ?? '').toString();
          final name = (m['name'] ?? 'Unknown').toString();
          final ctrl = _legacyMemberCtrl[empId];
          if (ctrl == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name · $empId',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ctrl,
                    minLines: 3,
                    maxLines: null,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      hintText: 'What should $name do?',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _toggle(bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on ? Icons.people_alt_rounded : Icons.people_outline,
              size: 14,
              color: on ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              on ? 'Per-member ON' : 'Per-member',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: on ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final saving = _isV2 ? _v2Saving : _legacySubmitting;
    final label = _isV2
        ? 'Assign Week $_weekNumber'
        : 'Assign to All Members';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: saving
                ? null
                : (_isV2 ? _v2Save : _legacySubmit),
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
            label: Text(
              saving ? 'Saving…' : label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              disabledBackgroundColor: const Color(0xFF93C5FD),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoMembersBanner extends StatelessWidget {
  const _NoMembersBanner();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Color(0xFF92400E),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No members are assigned to this task. Use "Manage Team" to add members.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w600,
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
