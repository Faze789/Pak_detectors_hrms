// ============================================================
// WEEKLY BREAKDOWN SHEET  (shared, used by both HR and Employee)
//
// CHANGE: _ActionButtons.done → shows TeamRemarksDialog before
// calling vm.markTaskStatus, so team remarks are captured and
// stored in the existing task document (no new collection).
// ============================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/performance_models.dart';
import 'employee_performance_screen.dart' show showTeamRemarksDialog;
import 'performance_widgets.dart';

class WeeklyBreakdownSheet extends StatefulWidget {
  final QuarterlyGoalModel task;
  final dynamic vm; // EmployeePerformanceViewModel | HRPerformanceViewModel
  final bool isEmployeeView;

  const WeeklyBreakdownSheet({
    super.key,
    required this.task,
    required this.vm,
    required this.isEmployeeView,
  });

  @override
  State<WeeklyBreakdownSheet> createState() =>
      _WeeklyBreakdownSheetState();
}

class _WeeklyBreakdownSheetState extends State<WeeklyBreakdownSheet> {
  // ── Helpers ───────────────────────────────────────────────

  int get _maxWeeks {
    final natural =
        widget.task.endDate.difference(widget.task.startDate).inDays ~/ 7;
    return natural.clamp(1, 13);
  }

  List<WeeklyTaskModel> get _scheduled =>
      (widget.vm.weeklyTasksTemp as List<WeeklyTaskModel>)
          .where((t) => !t.isUnscheduled)
          .toList();

  List<WeeklyTaskModel> get _unscheduled =>
      (widget.vm.weeklyTasksTemp as List<WeeklyTaskModel>)
          .where((t) => t.isUnscheduled)
          .toList();

  bool get _canAddWeek {
    if (_scheduled.length >= _maxWeeks) return false;
    final nextDue = _nextDueDate;
    return nextDue != null && !nextDue.isAfter(widget.task.endDate);
  }

  DateTime? get _nextDueDate {
    final scheduled = _scheduled;
    final highest = scheduled.isEmpty
        ? 0
        : scheduled.map((t) => t.weekNumber).reduce((a, b) => a > b ? a : b);
    return widget.task.startDate.add(Duration(days: (highest + 1) * 7));
  }

  int get _nextWeekNumber {
    final scheduled = _scheduled;
    if (scheduled.isEmpty) return 1;
    return scheduled
        .map((t) => t.weekNumber)
        .reduce((a, b) => a > b ? a : b) +
        1;
  }

  int get _remaining => (_maxWeeks - _scheduled.length).clamp(0, 13);

  // ── Grouping helpers ──────────────────────────────────────

  Map<String, List<WeeklyTaskModel>> _groupByMonth(
      List<WeeklyTaskModel> tasks) {
    final map = <String, List<WeeklyTaskModel>>{};
    for (final t in tasks) {
      final month = DateFormat('MMM yyyy').format(t.dueDate);
      map.putIfAbsent(month, () => []).add(t);
    }
    return map;
  }

  Map<String, List<WeeklyTaskModel>> _groupByEmployee(
      List<WeeklyTaskModel> tasks) {
    final map = <String, List<WeeklyTaskModel>>{};
    for (final t in tasks) {
      map.putIfAbsent(t.employeeId, () => []).add(t);
    }
    return map;
  }

  String _empName(String employeeId) {
    try {
      final employees =
      widget.vm.employees as List<Map<String, dynamic>>;
      final match = employees.firstWhere(
            (e) => e['id'] == employeeId,
        orElse: () => {'name': employeeId},
      );
      return match['name'] as String? ?? employeeId;
    } catch (_) {
      return employeeId;
    }
  }

  // ── Add week ──────────────────────────────────────────────

  void _addWeekTask() {
    if (!_canAddWeek) return;
    final nextWeek = _nextWeekNumber;
    final dueDate =
    widget.task.startDate.add(Duration(days: nextWeek * 7));
    (widget.vm.weeklyTasksTemp as List<WeeklyTaskModel>).add(
      WeeklyTaskModel(
        id:            '',
        goalId:        widget.task.id,
        employeeId:    widget.task.employeeId,
        weekNumber:    nextWeek,
        title:         '',
        description:   '',
        dueDate:       dueDate,
        status:        TaskStatus.pending,
        isUnscheduled: false,
        priority:      TaskPriority.normal,
      ),
    );
    setState(() {});
    widget.vm.notifyListeners();
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fmt      = DateFormat('dd MMM yy');
    final allTasks = widget.vm.weeklyTasksTemp as List<WeeklyTaskModel>;
    final totalWeeks  = _maxWeeks;
    final scheduled   = _scheduled;
    final unscheduled = _unscheduled;

    final completed =
        allTasks.where((t) => t.status == TaskStatus.completed).length;
    final missed =
        allTasks.where((t) => t.status == TaskStatus.missed).length;
    final pending =
        allTasks.where((t) => t.status == TaskStatus.pending).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── Drag handle ────────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: kSlate200,
                  borderRadius: BorderRadius.circular(2)),
            ),

            // ── Header ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: kBlueSoft,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.list_alt_outlined,
                        color: kBlue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isEmployeeView
                              ? 'My Weekly Plan'
                              : 'Weekly Breakdown',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(widget.task.title,
                            style: const TextStyle(
                                fontSize: 12, color: kSlate),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
            ),

            // ── Mini stats bar ──────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kBlueSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBlueBorder),
              ),
              child: Row(
                children: [
                  _MiniStat('Start', fmt.format(widget.task.startDate)),
                  _MiniStat('End',   fmt.format(widget.task.endDate)),
                  _MiniStat('Max',   '$totalWeeks wks'),
                  _MiniStat('Done',  '$completed'),
                  _MiniStat('Missed','$missed'),
                  _MiniStat('Pending','$pending'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Week progress pill ──────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _Dot(color: kBlue,  label: 'Pending: $pending'),
                const SizedBox(width: 14),
                _Dot(color: kGreen, label: 'Done: $completed'),
                const SizedBox(width: 14),
                _Dot(color: kRed,   label: 'Missed: $missed'),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: kBlueSoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kBlueBorder)),
                  child: Text(
                    '${scheduled.length} / $totalWeeks weeks',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: kBlue),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),

            // ── Task list ───────────────────────────────────
            Expanded(
              child: allTasks.isEmpty
                  ? _emptyState()
                  : ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Unscheduled section ─────────────
                  if (unscheduled.isNotEmpty) ...[
                    _sectionHeader(
                      icon:  Icons.bolt_rounded,
                      color: kOrange,
                      label: 'Unscheduled Tasks (HR Assigned)',
                      count: unscheduled.length,
                    ),
                    ...unscheduled.map((t) => _WeekRow(
                      task:                t,
                      vm:                  widget.vm,
                      isEmployeeView:      widget.isEmployeeView,
                      showUnscheduledBadge: true,
                    )),
                    const SizedBox(height: 16),
                  ],

                  // ── Scheduled section ───────────────
                  if (scheduled.isNotEmpty) ...[
                    _sectionHeader(
                      icon:  Icons.calendar_today_rounded,
                      color: kBlue,
                      label: 'Scheduled Weekly Tasks',
                      count: scheduled.length,
                    ),

                    // HR → Employee → Month grouping
                    if (!widget.isEmployeeView)
                      ..._groupByEmployee(scheduled)
                          .entries
                          .map((empEntry) {
                        final empName  = _empName(empEntry.key);
                        final empTasks = empEntry.value;
                        final done     = empTasks
                            .where((t) =>
                        t.status == TaskStatus.completed)
                            .length;
                        final score = empTasks.isNotEmpty
                            ? (done / empTasks.length * 100).round()
                            : 0;
                        final scoreColor = score >= 90
                            ? const Color(0xFF059669)
                            : score >= 60
                            ? const Color(0xFFD97706)
                            : kRed;

                        return Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            // ── Employee header ─────────
                            Container(
                              margin: const EdgeInsets.only(
                                  bottom: 8),
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF3B82F6),
                                    Color(0xFF8B5CF6),
                                  ],
                                ),
                                borderRadius:
                                BorderRadius.circular(10),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    empName
                                        .split(' ')
                                        .map((n) => n.isEmpty
                                        ? ''
                                        : n[0])
                                        .take(2)
                                        .join(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight:
                                        FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(empName,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight:
                                              FontWeight.bold,
                                              fontSize: 14)),
                                      Text(
                                        '${empTasks.length} task${empTasks.length == 1 ? '' : 's'}  ·  $done completed',
                                        style: TextStyle(
                                            color: Colors.white
                                                .withOpacity(0.8),
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4),
                                  decoration: BoxDecoration(
                                    color: scoreColor
                                        .withOpacity(0.15),
                                    borderRadius:
                                    BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white
                                            .withOpacity(0.3)),
                                  ),
                                  child: Text('$score%',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight:
                                          FontWeight.bold,
                                          fontSize: 13)),
                                ),
                              ]),
                            ),

                            // ── Month groups indented ───
                            ..._groupByMonth(empTasks)
                                .entries
                                .map((monthEntry) => Padding(
                              padding:
                              const EdgeInsets.only(
                                  left: 12),
                              child: _MonthSection(
                                month: monthEntry.key,
                                tasks: monthEntry.value,
                                vm:    widget.vm,
                                isEmployeeView:
                                widget.isEmployeeView,
                              ),
                            )),

                            const SizedBox(height: 8),
                          ],
                        );
                      })

                    // Employee → flat Month grouping
                    else
                      ..._groupByMonth(scheduled)
                          .entries
                          .map((entry) => _MonthSection(
                        month: entry.key,
                        tasks: entry.value,
                        vm:    widget.vm,
                        isEmployeeView:
                        widget.isEmployeeView,
                      )),
                  ],

                  // ── Add week tile / max-reached note ─
                  if (_canAddWeek)
                    _AddWeekTile(
                      onTap:          _addWeekTask,
                      remaining:      _remaining,
                      nextWeekNumber: _nextWeekNumber,
                      nextDueDate:    _nextDueDate!,
                    )
                  else if (allTasks.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kSlate100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 16, color: kSlate),
                        const SizedBox(width: 8),
                        Text(
                          'All $totalWeeks weeks planned. Max reached.',
                          style: const TextStyle(
                              fontSize: 12, color: kSlate),
                        ),
                      ]),
                    ),
                ],
              ),
            ),

            // ── Footer ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: kSlate200))),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await widget.vm.saveWeeklyBreakdown();
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Weekly Plan',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sub-builders ──────────────────────────────────────────

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: kBlueSoft,
                borderRadius: BorderRadius.circular(36)),
            child: const Icon(Icons.add_task_rounded,
                color: kBlue, size: 36),
          ),
          const SizedBox(height: 16),
          const Text('No weekly tasks yet',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: kSlateDark)),
          const SizedBox(height: 8),
          Text(
            widget.isEmployeeView
                ? 'Tap "Add Week 1" to start planning.'
                : 'Add the first week or wait for the employee.',
            style: const TextStyle(fontSize: 12, color: kSlate),
            textAlign: TextAlign.center,
          ),
          if (_canAddWeek) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addWeekTask,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Week 1'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _sectionHeader({
    required IconData icon,
    required Color    color,
    required String   label,
    required int      count,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(width: 6),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MONTH SECTION
// ─────────────────────────────────────────────────────────────

class _MonthSection extends StatelessWidget {
  final String               month;
  final List<WeeklyTaskModel> tasks;
  final dynamic              vm;
  final bool                 isEmployeeView;

  const _MonthSection({
    required this.month,
    required this.tasks,
    required this.vm,
    required this.isEmployeeView,
  });

  @override
  Widget build(BuildContext context) {
    final completed =
        tasks.where((t) => t.status == TaskStatus.completed).length;
    final score =
    tasks.isNotEmpty ? (completed / tasks.length * 100).round() : 0;
    final Color sc = score >= 90
        ? const Color(0xFF059669)
        : score >= 60
        ? const Color(0xFFD97706)
        : kRed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: kSlateBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kSlate200)),
          child: Row(
            children: [
              const Icon(Icons.calendar_month,
                  size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(month,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kSlateDark)),
              const Spacer(),
              Text('$completed / ${tasks.length}',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF94A3B8))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: sc.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$score%',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: sc)),
              ),
            ],
          ),
        ),
        ...tasks.map((t) => _WeekRow(
          task:                t,
          vm:                  vm,
          isEmployeeView:      isEmployeeView,
          showUnscheduledBadge: false,
        )),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WEEK ROW
// ─────────────────────────────────────────────────────────────

class _WeekRow extends StatelessWidget {
  final WeeklyTaskModel task;
  final dynamic         vm;
  final bool            isEmployeeView;
  final bool            showUnscheduledBadge;

  const _WeekRow({
    required this.task,
    required this.vm,
    required this.isEmployeeView,
    this.showUnscheduledBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final fmt         = DateFormat('dd MMM');
    final isPending   = task.status == TaskStatus.pending;
    final isCompleted = task.status == TaskStatus.completed;
    final isMissed    = task.status == TaskStatus.missed;

    Color bg, border;
    if (isCompleted) {
      bg = kGreenSoft; border = const Color(0xFFBBF7D0);
    } else if (isMissed) {
      bg = kRedSoft;   border = const Color(0xFFFECACA);
    } else {
      bg = Colors.white; border = kSlate200;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Week number circle ────────────────────────────
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isCompleted
                  ? const Color(0xFF059669)
                  : isMissed
                  ? kRed
                  : const Color(0xFF475569),
              borderRadius: BorderRadius.circular(17),
            ),
            alignment: Alignment.center,
            child: Text('${task.weekNumber}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const SizedBox(width: 10),

          // ── Content ──────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row + optional unscheduled badge
                Row(children: [
                  Flexible(
                    child: Text(
                      task.title.isEmpty
                          ? 'Week ${task.weekNumber}'
                          : task.title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (showUnscheduledBadge || task.isUnscheduled) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: kOrangeSoft,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: const Color(0xFFFBD38D)),
                      ),
                      child: const Text('Unscheduled',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: kOrange)),
                    ),
                  ],
                ]),

                // Editable fields for pending tasks
                if (isPending) ...[
                  const SizedBox(height: 8),
                  TextField(
                    decoration: formDec('Week ${task.weekNumber} title'),
                    controller:
                    TextEditingController(text: task.title),
                    onChanged: (v) {
                      final idx = (vm.weeklyTasksTemp
                      as List<WeeklyTaskModel>)
                          .indexOf(task);
                      if (idx != -1) {
                        vm.updateTempTask(
                            idx, task.copyWith(title: v));
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    decoration: formDec('Description (optional)'),
                    maxLines: 2,
                    controller:
                    TextEditingController(text: task.description),
                    onChanged: (v) {
                      final idx = (vm.weeklyTasksTemp
                      as List<WeeklyTaskModel>)
                          .indexOf(task);
                      if (idx != -1) {
                        vm.updateTempTask(
                            idx, task.copyWith(description: v));
                      }
                    },
                  ),
                ] else ...[
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(task.description,
                        style: const TextStyle(
                            fontSize: 11, color: kSlate)),
                  ],
                ],

                // Due / completed meta
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 10, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 3),
                  Text('Due: ${fmt.format(task.dueDate)}',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF94A3B8))),
                  if (task.completedAt != null) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.check_circle_outline,
                        size: 10, color: Color(0xFF059669)),
                    const SizedBox(width: 3),
                    Text('Done ${fmt.format(task.completedAt!)}',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF059669))),
                  ],
                ]),

                // ── Team remarks read-only (completed tasks) ──
                if (isCompleted &&
                    task.teamRemarks != null &&
                    task.teamRemarks!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _TeamRemarksReadView(remarks: task.teamRemarks!),
                ],
              ],
            ),
          ),

          // ── Right side: action buttons or status chip ─────
          const SizedBox(width: 8),
          if (isEmployeeView && isPending)
            _ActionButtons(task: task, vm: vm)
          else
            _StatusChip(status: task.status),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TEAM REMARKS READ VIEW
// ─────────────────────────────────────────────────────────────

class _TeamRemarksReadView extends StatelessWidget {
  final List<Map<String, String>> remarks;
  const _TeamRemarksReadView({required this.remarks});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.groups_rounded, size: 13, color: kGreen),
            SizedBox(width: 6),
            Text('Team Remarks',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF065F46))),
          ]),
          const SizedBox(height: 8),
          ...remarks.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: kGreen, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 12),
                      children: [
                        TextSpan(
                          text: '${r['name'] ?? ''}: ',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF065F46)),
                        ),
                        TextSpan(
                          text: r['remark']?.isNotEmpty == true
                              ? r['remark']
                              : '(no remark)',
                          style: const TextStyle(
                              color: Color(0xFF047857)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ADD WEEK TILE
// ─────────────────────────────────────────────────────────────

class _AddWeekTile extends StatelessWidget {
  final VoidCallback onTap;
  final int          remaining;
  final int          nextWeekNumber;
  final DateTime     nextDueDate;

  const _AddWeekTile({
    required this.onTap,
    required this.remaining,
    required this.nextWeekNumber,
    required this.nextDueDate,
  });

  @override
  Widget build(BuildContext context) {
    final dueFmt = DateFormat('dd MMM yyyy').format(nextDueDate);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kBlueSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBlueBorder, width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: kBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Week $nextWeekNumber',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: kSlateDark)),
                Text(
                  'Due $dueFmt  ·  $remaining week${remaining == 1 ? '' : 's'} remaining',
                  style:
                  const TextStyle(fontSize: 11, color: kSlate),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: kBlue),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ACTION BUTTONS (employee — mark done / missed)
// ─────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final WeeklyTaskModel task;
  final dynamic         vm;

  const _ActionButtons({required this.task, required this.vm});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _Btn(
          label: '✓ Done',
          bg: const Color(0xFFD1FAE5),
          fg: const Color(0xFF059669),
          // "Done" → show TeamRemarksDialog first
          onTap: () => _confirmDone(context)),
      const SizedBox(height: 6),
      _Btn(
          label: '✗ Missed',
          bg: const Color(0xFFFEE2E2),
          fg: kRed,
          // "Missed" → standard confirm (no remarks needed)
          onTap: () => _confirmMissed(context)),
    ],
  );

  // ── Done: show TeamRemarksDialog, then confirm ─────────────
  void _confirmDone(BuildContext context) async {
    // Step 1 — collect team remarks
    final remarks = await showTeamRemarksDialog(context);
    if (remarks == null) return; // user cancelled

    // Step 2 — confirm marking complete
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as Completed?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will count toward your quarterly score.',
              style: TextStyle(fontSize: 13),
            ),
            if (remarks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Team members recorded:',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF065F46))),
                    const SizedBox(height: 6),
                    ...remarks.map((r) => Text(
                      '• ${r['name']}'
                          '${r['remark']!.isNotEmpty ? ': ${r['remark']}' : ''}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF047857)),
                    )),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes, Completed'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Step 3 — call markTaskStatus with remarks
    await vm.markTaskStatus(
      goalId:      task.goalId,
      taskId:      task.id,
      status:      TaskStatus.completed,
      teamRemarks: remarks,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✓ Week ${task.weekNumber} marked complete'),
        backgroundColor: const Color(0xFF059669),
      ));
    }
  }

  // ── Missed: standard confirm ───────────────────────────────
  void _confirmMissed(BuildContext context) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Mark as Missed?',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          content: const Text(
            'This will lower your performance score and may '
                'result in a salary deduction.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await vm.markTaskStatus(
                    goalId: task.goalId,
                    taskId: task.id,
                    status: TaskStatus.missed);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Week ${task.weekNumber} marked missed'),
                        backgroundColor: kRed,
                      ));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Yes, Missed'),
            ),
          ],
        ));
  }
}

// ─────────────────────────────────────────────────────────────
// STATUS CHIP
// ─────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final TaskStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color fg, bg;
    String label;
    switch (status) {
      case TaskStatus.completed:
        fg = const Color(0xFF059669);
        bg = const Color(0xFFD1FAE5);
        label = 'Done';
        break;
      case TaskStatus.missed:
        fg = kRed;
        bg = const Color(0xFFFEE2E2);
        label = 'Missed';
        break;
      case TaskStatus.weekend:
        fg = const Color(0xFFD97706);
        bg = kOrangeSoft;
        label = 'Weekend';
        break;
      default:
        fg = kSlate;
        bg = kSlate100;
        label = 'Pending';
    }
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SMALL HELPERS
// ─────────────────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  final String       label;
  final Color        bg;
  final Color        fg;
  final VoidCallback onTap;

  const _Btn({
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg)),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: kSlateDark)),
        Text(label,
            style: const TextStyle(
                fontSize: 9, color: Color(0xFF94A3B8))),
      ],
    ),
  );
}

class _Dot extends StatelessWidget {
  final Color  color;
  final String label;
  const _Dot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style: const TextStyle(fontSize: 11, color: kSlate)),
    ],
  );
}