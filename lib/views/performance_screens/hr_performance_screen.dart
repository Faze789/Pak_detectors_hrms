// ============================================================
// HR PERFORMANCE SCREEN
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/performance_models.dart';
import '../../viewmodels/performance_viewmodel.dart';
import 'performance_widgets.dart';

class HRPerformanceScreen extends StatelessWidget {
  const HRPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          HRPerformanceViewModel(service: context.read(), hrUserId: 'hr_001'),
      child: const _HRBody(),
    );
  }
}

class _HRBody extends StatelessWidget {
  const _HRBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HRPerformanceViewModel>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (vm.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vm.successMessage!),
            backgroundColor: kGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        vm.clearMessages();
      }
      if (vm.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vm.errorMessage!),
            backgroundColor: kRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        vm.clearMessages();
      }
    });

    return Scaffold(
      backgroundColor: kSlateBg,
      body: Column(
        children: [
          _HRHeader(vm: vm),
          Expanded(child: _buildTab(context, vm)),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, HRPerformanceViewModel vm) {
    return switch (vm.activeTab) {
      HRTab.dashboard => _DashboardTab(vm: vm),
      HRTab.adhoc => _AdhocTab(vm: vm),
      HRTab.quarterly => _QuarterlyTab(vm: vm),
      HRTab.goals => _EmployeeGoalsTab(vm: vm),
      HRTab.rules => _RulesTab(vm: vm),
    };
  }
}

// ─────────────────────────────────────────────────────────────
// HEADER + TAB BAR
// ─────────────────────────────────────────────────────────────

class _HRHeader extends StatelessWidget {
  final HRPerformanceViewModel vm;
  const _HRHeader({required this.vm});

  static const _tabs = [
    (HRTab.dashboard, Icons.trending_up_rounded, 'Dashboard'),
    (HRTab.adhoc, Icons.bolt_rounded, 'Unscheduled Tasks'),
    (HRTab.quarterly, Icons.calendar_today_rounded, 'Quarterly Tasks'),
    (HRTab.goals, Icons.flag_rounded, 'Goals'),
    (HRTab.rules, Icons.settings_rounded, 'Auto-Scoring Rules'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes_rounded, color: kBlue, size: 26),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Performance Management',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'HR Admin Panel',
                    style: TextStyle(fontSize: 12, color: kSlate),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _tabs.map((t) {
                final isActive = t.$1 == vm.activeTab;
                return GestureDetector(
                  onTap: () => vm.setTab(t.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? kBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          t.$2,
                          size: 16,
                          color: isActive ? Colors.white : kSlate,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          t.$3,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isActive ? Colors.white : kSlate,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 1 — DASHBOARD
// ─────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  final HRPerformanceViewModel vm;
  const _DashboardTab({required this.vm});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              StatCard(
                title: 'Quarterly Tasks',
                value: vm.allGoals.length.toString(),
                icon: Icons.track_changes_rounded,
                color: const Color(0xFF3B82F6),
              ),
              StatCard(
                title: 'Employee Goals',
                value: vm.allEmployeeGoals.length.toString(),
                icon: Icons.flag_rounded,
                color: const Color(0xFF0D9488),
              ),
              StatCard(
                title: 'Employees',
                value: vm.employees.length.toString(),
                icon: Icons.people_rounded,
                color: const Color(0xFF8B5CF6),
              ),
              StatCard(
                title: 'Open Barriers',
                value: vm.barriers.length.toString(),
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFF59E0B),
              ),
              StatCard(
                title: 'Unscheduled',
                value: vm.unscheduledTasks.length.toString(),
                icon: Icons.bolt_rounded,
                color: kOrange,
              ),
            ],
          ),
          const SizedBox(height: 24),
          PCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Employee Task Overview',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Real-time quarterly task progress',
                  style: TextStyle(fontSize: 12, color: kSlate),
                ),
                const SizedBox(height: 16),
                _EmployeeTable(vm: vm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeTable extends StatelessWidget {
  final HRPerformanceViewModel vm;
  const _EmployeeTable({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.employees.isEmpty) {
      return const EmptyState(message: 'No employees found.');
    }
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: kSlateBg),
          children: ['Employee', 'Role', 'Tasks', 'Progress']
              .map(
                (h) => Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    h,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        ...vm.employees.map((emp) {
          final goals = vm.goalsForEmployee(emp['id'] as String);
          final avgProgress = goals.isEmpty
              ? 0.0
              : goals.fold<double>(0, (sum, g) => sum + g.currentProgress) /
                    goals.length;
          return TableRow(
            children: [
              _cell(
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (emp['name'] as String)
                            .split(' ')
                            .map((n) => n[0])
                            .take(2)
                            .join(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        emp['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              _cell(
                Text(emp['role'] ?? '', style: const TextStyle(color: kSlate)),
              ),
              _cell(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: kBlueSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    goals.length.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: kBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                centered: true,
              ),
              _cell(ScoreBadge(score: avgProgress.toInt()), centered: true),
            ],
          );
        }),
      ],
    );
  }

  Widget _cell(Widget child, {bool centered = false}) => Padding(
    padding: const EdgeInsets.all(10),
    child: centered ? Center(child: child) : child,
  );
}

// ─────────────────────────────────────────────────────────────
// TAB 2 — UNSCHEDULED TASKS
// ─────────────────────────────────────────────────────────────

class _AdhocTab extends StatelessWidget {
  final HRPerformanceViewModel vm;
  const _AdhocTab({required this.vm});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(left: BorderSide(color: kOrange, width: 4)),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: kOrange, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Assign Unscheduled Task',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Assign urgent ad-hoc tasks. Choose whether to attach them '
                  'to a quarterly goal or send them directly as this week\'s '
                  'or next week\'s standalone task.',
                  style: TextStyle(fontSize: 13, color: kSlate),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    vm.showUnscheduledFormValue = !vm.showUnscheduledForm;
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Assign New Unscheduled Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (vm.showUnscheduledForm) ...[
                  const SizedBox(height: 16),
                  _UnscheduledForm(vm: vm),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'Recent Unscheduled Assignments (${vm.unscheduledTasks.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (vm.unscheduledTasks.isEmpty)
            const EmptyState(message: 'No unscheduled tasks assigned yet.')
          else
            ...vm.unscheduledTasks.map((e) => _UnscheduledCard(entry: e)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ATTACHMENT TYPE
// ─────────────────────────────────────────────────────────────

enum UnscheduledAttachment { quarterly, currentWeek, upcomingWeek }

extension UnscheduledAttachmentX on UnscheduledAttachment {
  String get label => switch (this) {
    UnscheduledAttachment.quarterly => 'Attach to Quarterly Task',
    UnscheduledAttachment.currentWeek => 'Current Week (standalone)',
    UnscheduledAttachment.upcomingWeek => 'Upcoming Week (standalone)',
  };
  String get value => switch (this) {
    UnscheduledAttachment.quarterly => 'quarterly',
    UnscheduledAttachment.currentWeek => 'currentWeek',
    UnscheduledAttachment.upcomingWeek => 'upcomingWeek',
  };
  IconData get icon => switch (this) {
    UnscheduledAttachment.quarterly => Icons.track_changes_rounded,
    UnscheduledAttachment.currentWeek => Icons.today_rounded,
    UnscheduledAttachment.upcomingWeek => Icons.event_rounded,
  };
  Color get color => switch (this) {
    UnscheduledAttachment.quarterly => kBlue,
    UnscheduledAttachment.currentWeek => kOrange,
    UnscheduledAttachment.upcomingWeek => const Color(0xFF8B5CF6),
  };
}

// ─────────────────────────────────────────────────────────────
// UNSCHEDULED FORM
// ─────────────────────────────────────────────────────────────

class _UnscheduledForm extends StatefulWidget {
  final HRPerformanceViewModel vm;
  const _UnscheduledForm({required this.vm});

  @override
  State<_UnscheduledForm> createState() => _UnscheduledFormState();
}

class _UnscheduledFormState extends State<_UnscheduledForm> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _empId;
  String? _goalId;
  TaskPriority _priority = TaskPriority.normal;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  UnscheduledAttachment _attachment = UnscheduledAttachment.quarterly;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final goalChoices = _empId != null
        ? vm.goalsForEmployee(_empId!)
        : <QuarterlyGoalModel>[];
    final isQuarterly = _attachment == UnscheduledAttachment.quarterly;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSlateBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kSlate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: formDec('Employee *'),
                  items: vm.employees
                      .map(
                        (e) => DropdownMenuItem(
                          value: e['id'] as String,
                          child: Text(
                            e['name'] ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _empId = v;
                    _goalId = null;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<UnscheduledAttachment>(
                  isExpanded: true,
                  decoration: formDec('Attach To *'),
                  initialValue: _attachment,
                  items: UnscheduledAttachment.values
                      .map(
                        (a) => DropdownMenuItem(
                          value: a,
                          child: Row(
                            children: [
                              Icon(a.icon, size: 15, color: a.color),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  a.label,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _attachment = v!;
                    _goalId = null;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AttachmentInfoBanner(attachment: _attachment),
          if (isQuarterly) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: formDec('Quarterly Goal *'),
              initialValue: _goalId,
              items: goalChoices
                  .map(
                    (g) => DropdownMenuItem(
                      value: g.id,
                      child: Text(g.title, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _goalId = v),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<TaskPriority>(
                  isExpanded: true,
                  decoration: formDec('Priority'),
                  initialValue: _priority,
                  items: TaskPriority.values
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            p == TaskPriority.prioritized
                                ? 'Prioritized (Urgent)'
                                : 'Normal',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _priority = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DatePickerField(
                  label: 'Due Date',
                  value: _dueDate,
                  onPick: (d) => setState(() => _dueDate = d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _titleCtrl,
            decoration: formDec('Task Title *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: formDec('Description'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => vm.showUnscheduledFormValue = false,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (_empId == null) return;
                  if (isQuarterly && _goalId == null) return;
                  if (_titleCtrl.text.trim().isEmpty) return;
                  vm.assignUnscheduledTask(
                    goalId: isQuarterly ? _goalId! : '',
                    employeeId: _empId!,
                    title: _titleCtrl.text.trim(),
                    description: _descCtrl.text.trim(),
                    dueDate: _dueDate,
                    priority: _priority,
                    attachmentType: _attachment.value,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kOrange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Assign Task'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ATTACHMENT INFO BANNER
// ─────────────────────────────────────────────────────────────

class _AttachmentInfoBanner extends StatelessWidget {
  final UnscheduledAttachment attachment;
  const _AttachmentInfoBanner({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final (msg, bg, border, fg) = switch (attachment) {
      UnscheduledAttachment.quarterly => (
        'Task will be nested inside the selected quarterly goal\'s weekly breakdown.',
        kBlueSoft,
        kBlueBorder,
        kBlue,
      ),
      UnscheduledAttachment.currentWeek => (
        'Task will appear as a standalone card in the employee\'s "This Week" section.',
        const Color(0xFFFFF7ED),
        const Color(0xFFFED7AA),
        kOrange,
      ),
      UnscheduledAttachment.upcomingWeek => (
        'Task will appear as a standalone card in the employee\'s "Upcoming" section.',
        const Color(0xFFF5F3FF),
        const Color(0xFFDDD6FE),
        const Color(0xFF7C3AED),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline_rounded, size: 14, color: fg),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg, style: TextStyle(fontSize: 12, color: fg)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// UNSCHEDULED CARD
// ─────────────────────────────────────────────────────────────

class _UnscheduledCard extends StatelessWidget {
  final UnscheduledEntry entry;
  const _UnscheduledCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final task = entry.task;
    final attachmentType = task.attachmentType ?? 'quarterly';
    final (attachLabel, attachColor) = switch (attachmentType) {
      'currentWeek' => ('This Week — Standalone', kOrange),
      'upcomingWeek' => ('Upcoming Week — Standalone', const Color(0xFF7C3AED)),
      _ => ('Quarterly: ${entry.goalTitle}', kBlue),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          left: BorderSide(color: Color(0xFFFB923C), width: 4),
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PriorityBadge(priority: task.priority),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description,
                    style: const TextStyle(fontSize: 13, color: kSlate),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      entry.empName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(
                          attachColor.red,
                          attachColor.green,
                          attachColor.blue,
                          0.10,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        attachLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: attachColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Due: ${task.dueDate.toString().substring(0, 10)}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB — EMPLOYEE GOALS (`goals` collection)
// ─────────────────────────────────────────────────────────────

class _EmployeeGoalsTab extends StatelessWidget {
  final HRPerformanceViewModel vm;
  const _EmployeeGoalsTab({required this.vm});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Employee Goals',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Daily, weekly, bi-weekly, or monthly — separate from quarterly',
                    style: TextStyle(fontSize: 12, color: kSlate),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    vm.showEmployeeGoalFormValue = !vm.showEmployeeGoalForm,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Assign Goal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (vm.showEmployeeGoalForm) ...[
            _EmployeeGoalAssignForm(vm: vm),
            const SizedBox(height: 16),
          ],
          if (vm.allEmployeeGoals.isEmpty)
            const EmptyState(message: 'No employee goals yet.')
          else
            ...vm.allEmployeeGoals.map(
              (g) => _HREmployeeGoalCard(
                goal: g,
                onDelete: () => vm.deleteEmployeeGoalDoc(g.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmployeeGoalAssignForm extends StatefulWidget {
  final HRPerformanceViewModel vm;
  const _EmployeeGoalAssignForm({required this.vm});

  @override
  State<_EmployeeGoalAssignForm> createState() =>
      _EmployeeGoalAssignFormState();
}

class _EmployeeGoalAssignFormState extends State<_EmployeeGoalAssignForm> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _empId;
  DateTime? _due;
  GoalCadence _cadence = GoalCadence.monthly;
  TaskPriority _priority = TaskPriority.normal;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String _cadenceLabel(GoalCadence c) {
    switch (c) {
      case GoalCadence.daily:
        return 'Daily';
      case GoalCadence.weekly:
        return 'Weekly';
      case GoalCadence.biWeekly:
        return 'Bi-weekly';
      case GoalCadence.monthly:
        return 'Monthly';
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBlueBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New goal',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: formDec('Employee *'),
                  items: vm.employees
                      .map(
                        (e) => DropdownMenuItem(
                          value: e['id'] as String,
                          child: Text(
                            e['name'] ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _empId = v),
                ),
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _titleCtrl,
                  decoration: formDec('Title *'),
                ),
              ),
              SizedBox(
                width: 580,
                child: TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: formDec('Description'),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<GoalCadence>(
                  isExpanded: true,
                  initialValue: _cadence,
                  decoration: formDec('Cadence'),
                  items: GoalCadence.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(_cadenceLabel(c)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _cadence = v!),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<TaskPriority>(
                  isExpanded: true,
                  initialValue: _priority,
                  decoration: formDec('Priority'),
                  items: const [
                    DropdownMenuItem(
                      value: TaskPriority.normal,
                      child: Text('Normal'),
                    ),
                    DropdownMenuItem(
                      value: TaskPriority.prioritized,
                      child: Text('Prioritized'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _priority = v!),
                ),
              ),
              SizedBox(
                width: 200,
                child: DatePickerField(
                  label: 'Target date *',
                  value: _due,
                  onPick: (d) => setState(() => _due = d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => vm.showEmployeeGoalFormValue = false,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (_empId == null || _due == null) return;
                  vm.assignEmployeeGoal(
                    employeeId: _empId!,
                    title: _titleCtrl.text,
                    description: _descCtrl.text,
                    cadence: _cadence,
                    priority: _priority,
                    dueDate: _due!,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HREmployeeGoalCard extends StatelessWidget {
  final EmployeeGoalModel goal;
  final VoidCallback onDelete;

  const _HREmployeeGoalCard({required this.goal, required this.onDelete});

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _cadenceLabel(GoalCadence c) {
    switch (c) {
      case GoalCadence.daily:
        return 'Daily';
      case GoalCadence.weekly:
        return 'Weekly';
      case GoalCadence.biWeekly:
        return 'Bi-weekly';
      case GoalCadence.monthly:
        return 'Monthly';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pri = goal.priority == TaskPriority.prioritized;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pri ? const Color(0xFFF59E0B) : kSlate200,
          width: pri ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: pri ? const Color(0xFFFEF3C7) : const Color(0xFFCCFBF1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                pri ? Icons.priority_high_rounded : Icons.flag_outlined,
                color: pri ? const Color(0xFFB45309) : const Color(0xFF0D9488),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    goal.employeeName,
                    style: const TextStyle(fontSize: 12, color: kSlate),
                  ),
                  if (goal.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      goal.description,
                      style: const TextStyle(fontSize: 12, color: kSlateDark),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chip(_cadenceLabel(goal.cadence), kBlueSoft, kBlue),
                      _chip(
                        pri ? 'Prioritized' : 'Normal',
                        pri ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                        pri ? const Color(0xFFB45309) : kSlate,
                      ),
                      _chip(
                        'Due ${_fmt(goal.dueDate)}',
                        const Color(0xFFEFF6FF),
                        kBlue,
                      ),
                      _chip(
                        goal.status.name,
                        const Color(0xFFF8FAFC),
                        kSlateDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, color: kRed),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String t, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        t,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 3 — QUARTERLY TASKS
// ─────────────────────────────────────────────────────────────

class _QuarterlyTab extends StatelessWidget {
  final HRPerformanceViewModel vm;
  const _QuarterlyTab({required this.vm});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quarterly Task Assignment',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Assign long-term tasks with weekly breakdowns',
                    style: TextStyle(fontSize: 12, color: kSlate),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    vm.showQuarterlyFormValue = !vm.showQuarterlyForm,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Assign Quarterly Task'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (vm.showQuarterlyForm) ...[
            _QuarterlyForm(vm: vm),
            const SizedBox(height: 16),
          ],
          if (vm.allGoals.isEmpty)
            const EmptyState(message: 'No quarterly tasks assigned yet.')
          else
            ...vm.allGoals.map(
              (goal) => _QuarterlyGoalCard(
                goal: goal,
                onViewPlan: () {
                  vm.openWeeklyBreakdown(goal);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ChangeNotifierProvider.value(
                      value: vm,
                      child: const _HRWeeklySheet(),
                    ),
                  );
                },
                onDelete: () => vm.deleteGoal(goal.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuarterlyForm extends StatefulWidget {
  final HRPerformanceViewModel vm;
  const _QuarterlyForm({required this.vm});

  @override
  State<_QuarterlyForm> createState() => _QuarterlyFormState();
}

class _QuarterlyFormState extends State<_QuarterlyForm> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _weightCtrl = TextEditingController(text: '20');
  String? _empId;
  DateTime? _start;
  DateTime? _end;
  GoalCategory _category = GoalCategory.project;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBlueBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assign New Quarterly Task',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: formDec('Employee *'),
                  items: vm.employees
                      .map(
                        (e) => DropdownMenuItem(
                          value: e['id'] as String,
                          child: Text(
                            e['name'] ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _empId = v),
                ),
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _titleCtrl,
                  decoration: formDec('Task Title *'),
                ),
              ),
              SizedBox(
                width: 580,
                child: TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: formDec('Description'),
                ),
              ),
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<GoalCategory>(
                  isExpanded: true,
                  initialValue: _category,
                  decoration: formDec('Category'),
                  items: GoalCategory.values
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c.name.capitalize(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: formDec('Weight (%)'),
                ),
              ),
              SizedBox(
                width: 200,
                child: DatePickerField(
                  label: 'Start Date',
                  value: _start,
                  onPick: (d) => setState(() => _start = d),
                ),
              ),
              SizedBox(
                width: 200,
                child: DatePickerField(
                  label: 'End Date',
                  value: _end,
                  onPick: (d) => setState(() => _end = d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => vm.showQuarterlyFormValue = false,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (_empId == null || _start == null || _end == null) {
                    return;
                  }
                  vm.assignQuarterlyGoal(
                    employeeId: _empId!,
                    title: _titleCtrl.text,
                    description: _descCtrl.text,
                    category: _category,
                    startDate: _start!,
                    endDate: _end!,
                    weight: double.tryParse(_weightCtrl.text) ?? 20,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Assign Task'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuarterlyGoalCard extends StatelessWidget {
  final QuarterlyGoalModel goal;
  final VoidCallback onViewPlan;
  final VoidCallback onDelete;

  const _QuarterlyGoalCard({
    required this.goal,
    required this.onViewPlan,
    required this.onDelete,
  });

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final weeks = goal.endDate.difference(goal.startDate).inDays ~/ 7;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kBlueSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.work_outline_rounded,
                    color: kBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Assigned to: ${goal.employeeName}',
                        style: const TextStyle(fontSize: 12, color: kSlate),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        children: [
                          _chip(
                            Icons.calendar_today_rounded,
                            '${_fmt(goal.startDate)} – ${_fmt(goal.endDate)}',
                          ),
                          _chip(Icons.access_time_rounded, '$weeks Weeks'),
                          _chip(
                            Icons.star_outline_rounded,
                            'Weight: ${goal.weight.toInt()}%',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Progress',
                            style: TextStyle(fontSize: 12, color: kSlate),
                          ),
                          Text(
                            '${goal.currentProgress.toInt()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      PerformanceProgressBar(
                        current: goal.currentProgress,
                        target: 100,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GoalStatusBadge(status: goal.status),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: kSlateBg,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onViewPlan,
                  icon: const Icon(Icons.list_alt_rounded, size: 15),
                  label: const Text('View / Edit Weekly Plan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kBlue,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 15,
                    color: kRed,
                  ),
                  label: const Text('Delete', style: TextStyle(color: kRed)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 11, color: kSlate)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────
// HR WEEKLY BREAKDOWN SHEET  (full add/edit parity with employee)
// ─────────────────────────────────────────────────────────────

class _HRWeeklySheet extends StatefulWidget {
  const _HRWeeklySheet();

  @override
  State<_HRWeeklySheet> createState() => _HRWeeklySheetState();
}

class _HRWeeklySheetState extends State<_HRWeeklySheet> {
  // ── Helpers (mirror employee sheet logic) ─────────────────

  int _maxWeeks(HRPerformanceViewModel vm) {
    final goal = vm.selectedGoal;
    if (goal == null) return 13;
    final natural = goal.endDate.difference(goal.startDate).inDays ~/ 7;
    return natural.clamp(1, 13);
  }

  List<WeeklyTaskModel> _scheduled(HRPerformanceViewModel vm) =>
      vm.weeklyTasksTemp.where((t) => !t.isUnscheduled).toList();

  List<WeeklyTaskModel> _unscheduled(HRPerformanceViewModel vm) =>
      vm.weeklyTasksTemp.where((t) => t.isUnscheduled).toList();

  bool _canAdd(HRPerformanceViewModel vm) {
    final goal = vm.selectedGoal;
    if (goal == null) return false;
    final sched = _scheduled(vm);
    if (sched.length >= _maxWeeks(vm)) return false;
    final nextDue = goal.startDate.add(Duration(days: (_nextWeekNum(vm)) * 7));
    return !nextDue.isAfter(goal.endDate);
  }

  int _nextWeekNum(HRPerformanceViewModel vm) {
    final sched = _scheduled(vm);
    if (sched.isEmpty) return 1;
    return sched.map((t) => t.weekNumber).reduce((a, b) => a > b ? a : b) + 1;
  }

  int _remaining(HRPerformanceViewModel vm) =>
      (_maxWeeks(vm) - _scheduled(vm).length).clamp(0, 13);

  void _addWeek(HRPerformanceViewModel vm) {
    final goal = vm.selectedGoal;
    if (goal == null) return;
    final nextWeek = _nextWeekNum(vm);
    final dueDate = goal.startDate.add(Duration(days: nextWeek * 7));
    vm.weeklyTasksTemp.add(
      WeeklyTaskModel(
        id: '',
        goalId: goal.id,
        employeeId: goal.employeeId,
        weekNumber: nextWeek,
        title: '',
        description: '',
        dueDate: dueDate,
        status: TaskStatus.pending,
        isUnscheduled: false,
        priority: TaskPriority.normal,
      ),
    );
    setState(() {});
    vm.notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HRPerformanceViewModel>();
    final scheduled = _scheduled(vm);
    final unscheduled = _unscheduled(vm);
    final maxWeeks = _maxWeeks(vm);
    final canAdd = _canAdd(vm);
    final remaining = _remaining(vm);

    final completed = vm.weeklyTasksTemp
        .where((t) => t.status == TaskStatus.completed)
        .length;
    final missed = vm.weeklyTasksTemp
        .where((t) => t.status == TaskStatus.missed)
        .length;
    final pending = vm.weeklyTasksTemp
        .where((t) => t.status == TaskStatus.pending)
        .length;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.96,
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
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kSlate200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kBlueSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.list_alt_outlined,
                      color: kBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Weekly Task Plan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (vm.selectedGoal != null)
                          Text(
                            vm.selectedGoal!.title,
                            style: const TextStyle(fontSize: 11, color: kSlate),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),

            // ── Mini stats bar ──────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kBlueSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBlueBorder),
              ),
              child: Row(
                children: [
                  _miniStat('Pending', '$pending'),
                  _miniStat('Done', '$completed'),
                  _miniStat('Missed', '$missed'),
                  _miniStat('Max', '$maxWeeks wks'),
                  _miniStat('Planned', '${scheduled.length}/$maxWeeks'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Legend dots ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _dot(kBlue, 'Pending: $pending'),
                  const SizedBox(width: 14),
                  _dot(kGreen, 'Done: $completed'),
                  const SizedBox(width: 14),
                  _dot(kRed, 'Missed: $missed'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kBlueSoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kBlueBorder),
                    ),
                    child: Text(
                      '${scheduled.length} / $maxWeeks weeks',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: kBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Divider(height: 8),

            // ── Task list ───────────────────────────────────
            Expanded(
              child: vm.weeklyTasksTemp.isEmpty
                  ? _emptyState(vm)
                  : ListView(
                      controller: ctrl,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Unscheduled section
                        if (unscheduled.isNotEmpty) ...[
                          _sectionHeader(
                            icon: Icons.bolt_rounded,
                            color: kOrange,
                            label: 'Unscheduled Tasks',
                            count: unscheduled.length,
                          ),
                          ...unscheduled.map((t) {
                            final idx = vm.weeklyTasksTemp.indexOf(t);
                            return _HRTaskItem(
                              key: ValueKey(t.id.isEmpty ? 'u_$idx' : t.id),
                              task: t,
                              index: idx,
                              vm: vm,
                              showUnscheduledBadge: true,
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        // Scheduled section
                        if (scheduled.isNotEmpty) ...[
                          _sectionHeader(
                            icon: Icons.calendar_today_rounded,
                            color: kBlue,
                            label: 'Scheduled Weekly Tasks',
                            count: scheduled.length,
                          ),
                          ...scheduled.map((t) {
                            final idx = vm.weeklyTasksTemp.indexOf(t);
                            return _HRTaskItem(
                              key: ValueKey(t.id.isEmpty ? 'w_$idx' : t.id),
                              task: t,
                              index: idx,
                              vm: vm,
                              showUnscheduledBadge: false,
                            );
                          }),
                        ],

                        // Add week tile
                        if (canAdd)
                          _AddWeekTile(
                            onTap: () => _addWeek(vm),
                            remaining: remaining,
                            nextWeekNumber: _nextWeekNum(vm),
                            nextDueDate: vm.selectedGoal!.startDate.add(
                              Duration(days: _nextWeekNum(vm) * 7),
                            ),
                          )
                        else if (vm.weeklyTasksTemp.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kSlate100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: kSlate,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'All $maxWeeks weeks planned. Max reached.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: kSlate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),

            // ── Footer: Save ────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kSlate200)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await vm.saveWeeklyBreakdown();
                    if (vm.errorMessage == null && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text(
                    'Save Weekly Plan',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

  Widget _emptyState(HRPerformanceViewModel vm) => Center(
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
              borderRadius: BorderRadius.circular(36),
            ),
            child: const Icon(Icons.add_task_rounded, color: kBlue, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'No weekly tasks yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: kSlateDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap "Add Week 1" to start planning.',
            style: TextStyle(fontSize: 12, color: kSlate),
            textAlign: TextAlign.center,
          ),
          if (_canAdd(vm)) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _addWeek(vm),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Week 1'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _sectionHeader({
    required IconData icon,
    required Color color,
    required String label,
    required int count,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _miniStat(String label, String value) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: kSlateDark,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
        ),
      ],
    ),
  );

  Widget _dot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: kSlate)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────
// ADD WEEK TILE
// ─────────────────────────────────────────────────────────────

class _AddWeekTile extends StatelessWidget {
  final VoidCallback onTap;
  final int remaining;
  final int nextWeekNumber;
  final DateTime nextDueDate;

  const _AddWeekTile({
    required this.onTap,
    required this.remaining,
    required this.nextWeekNumber,
    required this.nextDueDate,
  });

  @override
  Widget build(BuildContext context) {
    final dueFmt = DateFormats.short(nextDueDate); // reuse helper below
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
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: kBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Week $nextWeekNumber',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: kSlateDark,
                    ),
                  ),
                  Text(
                    'Due $dueFmt  ·  $remaining week'
                    '${remaining == 1 ? '' : 's'} remaining',
                    style: const TextStyle(fontSize: 11, color: kSlate),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kBlue),
          ],
        ),
      ),
    );
  }
}

// tiny date helper so we don't import intl just for this
class DateFormats {
  static String short(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} '
      '${_months[d.month - 1]} ${d.year}';
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}

// ─────────────────────────────────────────────────────────────
// HR TASK ITEM  (editable for pending, read-only + remarks for done)
// ─────────────────────────────────────────────────────────────

class _HRTaskItem extends StatelessWidget {
  final WeeklyTaskModel task;
  final int index;
  final HRPerformanceViewModel vm;
  final bool showUnscheduledBadge;

  const _HRTaskItem({
    super.key,
    required this.task,
    required this.index,
    required this.vm,
    this.showUnscheduledBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == TaskStatus.completed;
    final isMissed = task.status == TaskStatus.missed;
    final isPending = task.status == TaskStatus.pending;

    Color bg, border;
    if (isCompleted) {
      bg = kGreenSoft;
      border = const Color(0xFFBBF7D0);
    } else if (isMissed) {
      bg = kRedSoft;
      border = const Color(0xFFFECACA);
    } else {
      bg = Colors.white;
      border = kSlate200;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? kGreen
                      : isMissed
                      ? kRed
                      : const Color(0xFF475569),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${task.weekNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Week ${task.weekNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (showUnscheduledBadge || task.isUnscheduled) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: kOrangeSoft,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: const Color(0xFFFBD38D),
                              ),
                            ),
                            child: const Text(
                              'Unscheduled',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: kOrange,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'Due: ${task.dueDate.toString().substring(0, 10)}',
                      style: const TextStyle(fontSize: 11, color: kSlate),
                    ),
                  ],
                ),
              ),
              TaskStatusBadge(status: task.status),
            ],
          ),

          // ── Pending: fully editable ──────────────────────
          if (isPending) ...[
            const SizedBox(height: 10),
            TextField(
              decoration: formDec('Week ${task.weekNumber} title'),
              controller: TextEditingController(text: task.title),
              onChanged: (v) =>
                  vm.updateTempTask(index, task.copyWith(title: v)),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: formDec('Description (optional)'),
              maxLines: 2,
              controller: TextEditingController(text: task.description),
              onChanged: (v) =>
                  vm.updateTempTask(index, task.copyWith(description: v)),
            ),
          ]
          // ── Completed / missed: read-only ────────────────
          else ...[
            const SizedBox(height: 8),
            Text(
              task.title.isNotEmpty ? task.title : 'Week ${task.weekNumber}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                task.description,
                style: const TextStyle(fontSize: 12, color: kSlate),
              ),
            ],
            if (isCompleted && task.completedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Completed ${task.completedAt!.toString().substring(0, 10)}',
                style: const TextStyle(fontSize: 11, color: kGreen),
              ),
            ],

            // ── Team remarks ──────────────────────────────
            if (isCompleted &&
                task.teamRemarks != null &&
                task.teamRemarks!.isNotEmpty) ...[
              const SizedBox(height: 10),
              _HRTeamRemarksView(remarks: task.teamRemarks!),
            ],
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TEAM REMARKS — HR read-only view
// ─────────────────────────────────────────────────────────────

class _HRTeamRemarksView extends StatelessWidget {
  final List<Map<String, String>> remarks;
  const _HRTeamRemarksView({required this.remarks});

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
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 13, color: kGreen),
              const SizedBox(width: 6),
              Text(
                'Team Remarks  •  ${remarks.length} '
                'member${remarks.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF065F46),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...remarks.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: kGreen,
                      shape: BoxShape.circle,
                    ),
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
                              color: Color(0xFF065F46),
                            ),
                          ),
                          TextSpan(
                            text: r['remark']?.isNotEmpty == true
                                ? r['remark']
                                : '(no remark)',
                            style: const TextStyle(color: Color(0xFF047857)),
                          ),
                        ],
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
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 4 — RULES
// ─────────────────────────────────────────────────────────────

class _RulesTab extends StatefulWidget {
  final HRPerformanceViewModel vm;
  const _RulesTab({required this.vm});

  @override
  State<_RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<_RulesTab> {
  late double _deductPct;
  late double _progressPct;
  late double _bonusThreshold;
  late DeductionFrequency _frequency;

  @override
  void initState() {
    super.initState();
    final r = widget.vm.rules ?? PerformanceRulesModel.defaults();
    _deductPct = r.missedTaskDeductionPercent;
    _progressPct = r.completedTaskProgressPercent;
    _bonusThreshold = r.bonusThresholdScore;
    _frequency = r.deductionFrequency;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: PCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Auto-Scoring Rules',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'These rules apply automatically when calculating '
              'deductions and quarterly scores.',
              style: TextStyle(fontSize: 13, color: kSlate),
            ),
            const SizedBox(height: 24),
            const Text(
              'Deduction Frequency',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'How often deductions are calculated based on missed tasks',
              style: TextStyle(fontSize: 12, color: kSlate),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: DeductionFrequency.values.map((f) {
                final selected = f == _frequency;
                return GestureDetector(
                  onTap: () => setState(() => _frequency = f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? kBlue : kBlueSoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? kBlue : kBlueBorder),
                    ),
                    child: Text(
                      frequencyLabel(f),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : kBlue,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 20),
            _RuleSlider(
              label: 'Missed Task Deduction',
              subtitle: 'Each missed task deducts this % from salary',
              value: _deductPct,
              min: 1,
              max: 20,
              color: kRed,
              onChanged: (v) => setState(() => _deductPct = v),
            ),
            const SizedBox(height: 20),
            _RuleSlider(
              label: 'Completed Task Progress Increase',
              subtitle: 'Each completed task adds this % to quarterly score',
              value: _progressPct,
              min: 1,
              max: 20,
              color: kGreen,
              onChanged: (v) => setState(() => _progressPct = v),
            ),
            const SizedBox(height: 20),
            _RuleSlider(
              label: 'Bonus Threshold Score',
              subtitle: 'Score above this % earns the performance bonus',
              value: _bonusThreshold,
              min: 50,
              max: 100,
              color: const Color(0xFFF59E0B),
              onChanged: (v) => setState(() => _bonusThreshold = v),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kBlueSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBlueBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rules Summary',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: kBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _summaryRow('📅 Frequency', frequencyLabel(_frequency)),
                  _summaryRow(
                    '❌ Missed task',
                    '-${_deductPct.toInt()}% of salary per task',
                  ),
                  _summaryRow(
                    '✅ Completed task',
                    '+${_progressPct.toInt()}% quarterly progress',
                  ),
                  _summaryRow(
                    '🏆 Bonus threshold',
                    'Score ≥ ${_bonusThreshold.toInt()}%',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  final updated =
                      (widget.vm.rules ?? PerformanceRulesModel.defaults())
                          .copyWith(
                            missedTaskDeductionPercent: _deductPct,
                            completedTaskProgressPercent: _progressPct,
                            bonusThresholdScore: _bonusThreshold,
                            deductionFrequency: _frequency,
                            updatedBy: 'hr_001',
                          );
                  widget.vm.saveRules(updated);
                },
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save Rules'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: kSlate)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: kSlateDark,
          ),
        ),
      ],
    ),
  );
}

class _RuleSlider extends StatelessWidget {
  final String label;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final Color color;
  final ValueChanged<double> onChanged;

  const _RuleSlider({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${value.toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: kSlate)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: color.withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
