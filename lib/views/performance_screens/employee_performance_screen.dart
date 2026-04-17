// ============================================================
// EMPLOYEE PERFORMANCE SCREEN
// Tabs: My Goals (`goals`) | Quarterly tasks & weekly work
//
// CHANGE: Before marking any task "completed", the employee
// must fill in team member names + remarks via TeamRemarksDialog.
// Data is stored as `teamRemarks` field in the existing task doc.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/performance_models.dart';
import '../../viewmodels/performance_viewmodel.dart';
import 'performance_widgets.dart';

// ─────────────────────────────────────────────────────────────
// TEAM REMARKS DIALOG
// Public — also imported by weekly_breakdown_sheet.dart
// ─────────────────────────────────────────────────────────────

/// Shows the team-remarks dialog and returns the list of
/// {name, remark} entries on confirm, or null on cancel.
///
/// Call this from any "Complete" trigger point.
Future<List<Map<String, String>>?> showTeamRemarksDialog(BuildContext context) {
  return showDialog<List<Map<String, String>>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const TeamRemarksDialog(),
  );
}

class TeamRemarksDialog extends StatefulWidget {
  const TeamRemarksDialog({super.key});

  @override
  State<TeamRemarksDialog> createState() => _TeamRemarksDialogState();
}

class _TeamRemarksDialogState extends State<TeamRemarksDialog> {
  // Each entry: {nameCtrl, remarkCtrl}
  final List<_MemberEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _addEntry(); // start with one blank row
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.nameCtrl.dispose();
      e.remarkCtrl.dispose();
    }
    super.dispose();
  }

  void _addEntry() {
    setState(() => _entries.add(_MemberEntry()));
  }

  void _removeEntry(int index) {
    final e = _entries.removeAt(index);
    e.nameCtrl.dispose();
    e.remarkCtrl.dispose();
    setState(() {});
  }

  void _submit() {
    // Require at least one member with a non-empty name
    final filled = _entries
        .where((e) => e.nameCtrl.text.trim().isNotEmpty)
        .toList();
    if (filled.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one team member name.'),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final result = filled
        .map(
          (e) => {
            'name': e.nameCtrl.text.trim(),
            'remark': e.remarkCtrl.text.trim(),
          },
        )
        .toList();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            decoration: BoxDecoration(
              color: kGreenSoft,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFBBF7D0)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete Task',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46),
                        ),
                      ),
                      Text(
                        'Add team members & remarks',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable body ───────────────────────────────
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kBlueSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBlueBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: kBlue,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Enter the team members who contributed to '
                            'this task along with a short remark for each.',
                            style: TextStyle(fontSize: 12, color: kBlue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Member rows
                  ...List.generate(_entries.length, (i) {
                    return _MemberRow(
                      index: i,
                      entry: _entries[i],
                      canRemove: _entries.length > 1,
                      onRemove: () => _removeEntry(i),
                    );
                  }),

                  // Add member button
                  GestureDetector(
                    onTap: _addEntry,
                    child: Container(
                      margin: const EdgeInsets.only(top: 6, bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: kBlueBorder,
                          style: BorderStyle.solid,
                          width: 1.5,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 16,
                            color: kBlue,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Add Another Member',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Footer buttons ────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: kSlate, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text(
                      'Confirm & Complete',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.white,
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
        ],
      ),
    );
  }
}

// ── Single member row ─────────────────────────────────────────

class _MemberEntry {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController remarkCtrl = TextEditingController();
}

class _MemberRow extends StatelessWidget {
  final int index;
  final _MemberEntry entry;
  final bool canRemove;
  final VoidCallback onRemove;

  const _MemberRow({
    required this.index,
    required this.entry,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row header
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: kBlueSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: kBlueBorder),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: kBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Team Member',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kSlateDark,
                ),
              ),
              const Spacer(),
              if (canRemove)
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: kRedSoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: kRed,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Name field
          TextField(
            controller: entry.nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: formDec('Member name *'),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),

          // Remark field
          TextField(
            controller: entry.remarkCtrl,
            decoration: formDec('Remark / contribution (optional)'),
            style: const TextStyle(fontSize: 13),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────

class EmployeePerformanceScreen extends StatelessWidget {
  final String employeeId;
  final String employeeName;
  final String employeeRole;

  const EmployeePerformanceScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.employeeRole,
  });

  @override
  Widget build(BuildContext context) {
    if (employeeId.trim().isEmpty) {
      return Scaffold(
        backgroundColor: kSlateBg,
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.white,
          foregroundColor: kSlateDark,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: kRed, size: 48),
              SizedBox(height: 16),
              Text(
                'Employee ID is required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Please log in again or contact support.',
                style: TextStyle(color: kSlate),
              ),
            ],
          ),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => EmployeePerformanceViewModel(
        service: context.read(),
        employeeId: employeeId.trim(),
        employeeName: employeeName.trim(),
        employeeRole: employeeRole.trim(),
      ),
      child: const _EmployeeBody(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BODY
// ─────────────────────────────────────────────────────────────

class _EmployeeBody extends StatelessWidget {
  const _EmployeeBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EmployeePerformanceViewModel>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
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

    if (!vm.quarterlyStreamReady) {
      return const Scaffold(
        backgroundColor: kSlateBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: kBlue),
              SizedBox(height: 16),
              Text('Loading...', style: TextStyle(color: kSlate)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kSlateBg,
      body: Stack(
        children: [
          DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: _EmpProfileHeader(vm: vm),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PayrollImpactCard(vm: vm),
                        const SizedBox(height: 12),
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          child: TabBar(
                            labelColor: kBlue,
                            unselectedLabelColor: kSlate,
                            indicatorColor: kBlue,
                            dividerColor: Colors.transparent,
                            labelStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            tabs: const [
                              Tab(text: 'My Goals'),
                              Tab(text: 'Quarterly'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _PersonalGoalsTab(vm: vm),
                              SingleChildScrollView(
                                child: _QuarterlyGoalsSection(vm: vm),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (vm.showWeeklyReminder && vm.reminderTask != null)
            _WeeklyReminderOverlay(vm: vm),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PROFILE HEADER (above tabs)
// ─────────────────────────────────────────────────────────────

class _EmpProfileHeader extends StatelessWidget {
  final EmployeePerformanceViewModel vm;
  const _EmpProfileHeader({required this.vm});

  String _initials(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t
        .split(RegExp(r'\s+'))
        .where((n) => n.isNotEmpty)
        .map((n) => n[0].toUpperCase())
        .take(2)
        .join();
  }

  @override
  Widget build(BuildContext context) {
    final nameLoaded = vm.employeeName.trim().isNotEmpty;

    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(23),
              ),
              alignment: Alignment.center,
              child: nameLoaded
                  ? Text(
                      _initials(vm.employeeName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    )
                  : const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  nameLoaded
                      ? Text(
                          'Welcome, ${vm.employeeName}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: kSlateDark,
                          ),
                        )
                      : Container(
                          height: 14,
                          width: 160,
                          decoration: BoxDecoration(
                            color: kSlate200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                  const SizedBox(height: 4),
                  vm.employeeRole.trim().isNotEmpty
                      ? Text(
                          vm.employeeRole,
                          style: const TextStyle(fontSize: 12, color: kSlate),
                        )
                      : Container(
                          height: 10,
                          width: 100,
                          decoration: BoxDecoration(
                            color: kSlate200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => ChangeNotifierProvider.value(
                  value: vm,
                  child: const _BarrierDialog(),
                ),
              ),
              icon: const Icon(
                Icons.warning_amber_rounded,
                size: 15,
                color: kRed,
              ),
              label: const Text(
                'Report Barrier',
                style: TextStyle(fontSize: 12, color: kRed),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                backgroundColor: kRedSoft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PAYROLL IMPACT CARD
// ─────────────────────────────────────────────────────────────

class _PayrollImpactCard extends StatelessWidget {
  final EmployeePerformanceViewModel vm;
  const _PayrollImpactCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kBlueSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: kBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "This Month's Payroll Impact",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Based on tasks due this month',
                    style: TextStyle(fontSize: 11, color: kSlate),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _ratingBg(vm.performanceRating),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  vm.performanceRating,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _ratingFg(vm.performanceRating),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PayrollRow(
                  label: 'Performance Bonus',
                  amount: vm.projectedBonus,
                  isBonus: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PayrollRow(
                  label: 'Deductions',
                  amount: vm.projectedDeduction,
                  isBonus: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _ratingBg(String r) {
    if (r == 'Excellent') return const Color(0xFFD1FAE5);
    if (r == 'Good') return const Color(0xFFDBEAFE);
    return const Color(0xFFFEF3C7);
  }

  Color _ratingFg(String r) {
    if (r == 'Excellent') return const Color(0xFF065F46);
    if (r == 'Good') return const Color(0xFF1E40AF);
    return const Color(0xFF92400E);
  }
}

class _PayrollRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBonus;
  const _PayrollRow({
    required this.label,
    required this.amount,
    required this.isBonus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBonus ? kGreenSoft : kRedSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBonus ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  isBonus
                      ? Icons.trending_up_rounded
                      : Icons.warning_amber_rounded,
                  color: isBonus ? const Color(0xFF16A34A) : kRed,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isBonus
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            amount > 0
                ? '${isBonus ? '+' : '-'}PKR ${amount.toStringAsFixed(0)}'
                : 'PKR 0',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isBonus ? const Color(0xFF16A34A) : kRed,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PERSONAL GOALS TAB (`goals` collection)
// ─────────────────────────────────────────────────────────────

class _PersonalGoalsTab extends StatelessWidget {
  final EmployeePerformanceViewModel vm;
  const _PersonalGoalsTab({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.employeeGoals.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 24),
          EmptyState(
            message:
                'No personal goals yet. HR can assign daily, weekly, bi-weekly, or monthly goals here.',
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: vm.employeeGoals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) =>
          _EmployeePersonalGoalCard(goal: vm.employeeGoals[i], vm: vm),
    );
  }
}

class _EmployeePersonalGoalCard extends StatelessWidget {
  final EmployeeGoalModel goal;
  final EmployeePerformanceViewModel vm;

  const _EmployeePersonalGoalCard({required this.goal, required this.vm});

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
    final done = goal.status == GoalStatus.completed;

    return PCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: pri
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  pri ? Icons.priority_high_rounded : Icons.flag_outlined,
                  color: pri
                      ? const Color(0xFFB45309)
                      : const Color(0xFF0D9488),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
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
                    if (goal.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        goal.description,
                        style: const TextStyle(fontSize: 12, color: kSlateDark),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _miniChip(_cadenceLabel(goal.cadence), kBlueSoft, kBlue),
              _miniChip(
                pri ? 'Prioritized' : 'Normal',
                pri ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                pri ? const Color(0xFFB45309) : kSlate,
              ),
              _miniChip(
                'Due ${_fmt(goal.dueDate)}',
                const Color(0xFFEFF6FF),
                kBlue,
              ),
              _miniChip(
                done ? 'Completed' : goal.status.name,
                done ? kGreenSoft : const Color(0xFFF8FAFC),
                done ? const Color(0xFF15803D) : kSlateDark,
              ),
            ],
          ),
          if (done && goal.completedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Completed ${_fmt(goal.completedAt!)}',
              style: const TextStyle(fontSize: 11, color: kSlate),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (!done)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: vm.isLoading
                        ? null
                        : () => vm.updateEmployeeGoalStatus(
                            goalId: goal.id,
                            status: GoalStatus.completed,
                          ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Mark complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              if (done) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: vm.isLoading
                        ? null
                        : () => vm.updateEmployeeGoalStatus(
                            goalId: goal.id,
                            status: GoalStatus.inProgress,
                          ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reopen'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String t, Color bg, Color fg) {
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
// QUARTERLY SECTION (tab)
// ─────────────────────────────────────────────────────────────

class _QuarterlyGoalsSection extends StatelessWidget {
  final EmployeePerformanceViewModel vm;
  const _QuarterlyGoalsSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    final allPendingUnscheduled = vm.currentWeekTasks
        .where((t) => t.isUnscheduled && t.status == TaskStatus.pending)
        .toList();

    final thisWeekStandalone = allPendingUnscheduled
        .where((t) => t.attachmentType == 'currentWeek')
        .toList();

    final upcomingStandalone = allPendingUnscheduled
        .where((t) => t.attachmentType == 'upcomingWeek')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (thisWeekStandalone.isNotEmpty) ...[
          _StandaloneUnscheduledSection(
            tasks: thisWeekStandalone,
            label: 'This Week — Unscheduled',
            subtitle: 'Standalone tasks assigned for this week',
            accentColor: kOrange,
            bgColor: const Color(0xFFFFF7ED),
            borderColor: const Color(0xFFFED7AA),
            icon: Icons.today_rounded,
            vm: vm,
          ),
          const SizedBox(height: 14),
        ],
        if (upcomingStandalone.isNotEmpty) ...[
          _StandaloneUnscheduledSection(
            tasks: upcomingStandalone,
            label: 'Upcoming Week — Unscheduled',
            subtitle: 'Standalone tasks assigned for next week',
            accentColor: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF5F3FF),
            borderColor: const Color(0xFFDDD6FE),
            icon: Icons.event_rounded,
            vm: vm,
          ),
          const SizedBox(height: 14),
        ],
        const Row(
          children: [
            Icon(Icons.track_changes_rounded, size: 18),
            SizedBox(width: 6),
            Text(
              'My Quarterly Tasks',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CurrentWeekUnscheduledCard(vm: vm),
        if (vm.goals.isEmpty)
          const EmptyState(message: 'No quarterly tasks assigned yet.')
        else
          ...vm.goals.map((g) => _QuarterlyTaskCard(goal: g, vm: vm)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STANDALONE UNSCHEDULED SECTION
// ─────────────────────────────────────────────────────────────

class _StandaloneUnscheduledSection extends StatelessWidget {
  final List<WeeklyTaskModel> tasks;
  final String label;
  final String subtitle;
  final Color accentColor;
  final Color bgColor;
  final Color borderColor;
  final IconData icon;
  final EmployeePerformanceViewModel vm;

  const _StandaloneUnscheduledSection({
    required this.tasks,
    required this.label,
    required this.subtitle,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
    required this.icon,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color.fromRGBO(
                          accentColor.red,
                          accentColor.green,
                          accentColor.blue,
                          0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(
                    accentColor.red,
                    accentColor.green,
                    accentColor.blue,
                    0.12,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${tasks.length} task${tasks.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tasks.map(
            (t) => _StandaloneTaskRow(
              task: t,
              accentColor: accentColor,
              // Show dialog → then mark complete
              onComplete: t.id.trim().isEmpty
                  ? null
                  : () async {
                      final remarks = await showTeamRemarksDialog(context);
                      if (remarks == null) return;
                      await vm.markTaskStatus(
                        goalId: t.goalId,
                        taskId: t.id,
                        status: TaskStatus.completed,
                        teamRemarks: remarks,
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _StandaloneTaskRow extends StatelessWidget {
  final WeeklyTaskModel task;
  final Color accentColor;
  final VoidCallback? onComplete;

  const _StandaloneTaskRow({
    required this.task,
    required this.accentColor,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent = task.priority == TaskPriority.prioritized;
    final canComplete = onComplete != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUrgent ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color.fromRGBO(
                accentColor.red,
                accentColor.green,
                accentColor.blue,
                0.1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              isUrgent ? Icons.priority_high_rounded : Icons.bolt_rounded,
              color: accentColor,
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
                    if (isUrgent) ...[
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'URGENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: kRed,
                          ),
                        ),
                      ),
                    ],
                    Flexible(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (task.description.isNotEmpty)
                  Text(
                    task.description,
                    style: const TextStyle(fontSize: 12, color: kSlate),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Due: ${task.dueDate.toString().substring(0, 10)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          canComplete
              ? TextButton(
                  onPressed: onComplete,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 14),
                      SizedBox(width: 4),
                      Text('Done', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                )
              : Tooltip(
                  message: 'Task is not yet saved',
                  child: TextButton(
                    onPressed: null,
                    style: TextButton.styleFrom(
                      foregroundColor: kSlate,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_empty_rounded, size: 14),
                        SizedBox(width: 4),
                        Text('Pending', style: TextStyle(fontSize: 12)),
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
// CURRENT WEEK UNSCHEDULED CARD (quarterly-attached)
// ─────────────────────────────────────────────────────────────

class _CurrentWeekUnscheduledCard extends StatelessWidget {
  final EmployeePerformanceViewModel vm;
  const _CurrentWeekUnscheduledCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final urgent = vm.currentWeekTasks
        .where(
          (t) =>
              t.isUnscheduled &&
              t.status == TaskStatus.pending &&
              (t.attachmentType == null || t.attachmentType == 'quarterly') &&
              t.goalId.isNotEmpty,
        )
        .toList();

    if (urgent.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: kOrangeSoft,
        border: const Border(left: BorderSide(color: kOrange, width: 4)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: kOrange, size: 20),
              SizedBox(width: 8),
              Text(
                'Current Week — Quarterly Unscheduled',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Urgent tasks assigned inside quarterly goals',
            style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
          ),
          const SizedBox(height: 12),
          ...urgent.map(
            (t) => _UrgentTaskRow(
              task: t,
              onComplete: t.id.trim().isEmpty
                  ? null
                  : () async {
                      final remarks = await showTeamRemarksDialog(context);
                      if (remarks == null) return;
                      await vm.markTaskStatus(
                        goalId: t.goalId,
                        taskId: t.id,
                        status: TaskStatus.completed,
                        teamRemarks: remarks,
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgentTaskRow extends StatelessWidget {
  final WeeklyTaskModel task;
  final VoidCallback? onComplete;
  const _UrgentTaskRow({required this.task, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final isUrgent = task.priority == TaskPriority.prioritized;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUrgent ? const Color(0xFFFCA5A5) : const Color(0xFFFBD38D),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isUrgent) ...[
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'URGENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: kRed,
                          ),
                        ),
                      ),
                    ],
                    Flexible(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (task.description.isNotEmpty)
                  Text(
                    task.description,
                    style: const TextStyle(fontSize: 12, color: kSlate),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onComplete,
            style: TextButton.styleFrom(
              foregroundColor: onComplete != null
                  ? const Color(0xFF16A34A)
                  : kSlate,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 14),
                SizedBox(width: 4),
                Text('Complete', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// QUARTERLY TASK CARD
// ─────────────────────────────────────────────────────────────

class _QuarterlyTaskCard extends StatelessWidget {
  final QuarterlyGoalModel goal;
  final EmployeePerformanceViewModel vm;

  const _QuarterlyTaskCard({super.key, required this.goal, required this.vm});

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final weeks = goal.endDate.difference(goal.startDate).inDays ~/ 7;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(left: BorderSide(color: kBlue, width: 4)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      goal.description,
                      style: const TextStyle(fontSize: 12, color: kSlate),
                    ),
                  ],
                ),
              ),
              GoalStatusBadge(status: goal.status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            children: [
              _chip(
                Icons.calendar_today_rounded,
                '${_fmt(goal.startDate)} → ${_fmt(goal.endDate)}',
              ),
              _chip(Icons.access_time_rounded, '$weeks weeks'),
              _chip(
                Icons.star_outline_rounded,
                'Weight: ${goal.weight.toInt()}%',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Overall Progress',
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
          PerformanceProgressBar(current: goal.currentProgress, target: 100),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              vm.openWeeklyBreakdown(goal);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ChangeNotifierProvider.value(
                  value: vm,
                  child: _WeeklyBreakdownSheet(key: UniqueKey()),
                ),
              );
            },
            icon: const Icon(Icons.list_alt_rounded, size: 14),
            label: const Text(
              'View / Create Weekly Plan',
              style: TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(foregroundColor: kBlue),
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
// WEEKLY BREAKDOWN BOTTOM SHEET
// ─────────────────────────────────────────────────────────────

class _WeeklyBreakdownSheet extends StatefulWidget {
  const _WeeklyBreakdownSheet({super.key});

  @override
  State<_WeeklyBreakdownSheet> createState() => _WeeklyBreakdownSheetState();
}

class _WeeklyBreakdownSheetState extends State<_WeeklyBreakdownSheet> {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EmployeePerformanceViewModel>();
    final canAdd = vm.canAddWeek;
    final remaining = vm.remainingWeeks;
    final maxWeeks = vm.selectedGoal != null
        ? vm.maxWeeksForGoal(vm.selectedGoal!)
        : 13;

    final scheduled = vm.weeklyTasksTemp
        .where((t) => !t.isUnscheduled)
        .toList();
    final unscheduled = vm.weeklyTasksTemp
        .where((t) => t.isUnscheduled)
        .toList();

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
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kSlate200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.list_alt_rounded, color: kBlue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Weekly Plan',
                          style: TextStyle(
                            fontSize: 17,
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
                    icon: const Icon(Icons.close_rounded, color: kSlate),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _dot(
                    kBlue,
                    'Pending',
                    vm.weeklyTasksTemp
                        .where((t) => t.status == TaskStatus.pending)
                        .length,
                  ),
                  const SizedBox(width: 14),
                  _dot(
                    kGreen,
                    'Done',
                    vm.weeklyTasksTemp
                        .where((t) => t.status == TaskStatus.completed)
                        .length,
                  ),
                  const SizedBox(width: 14),
                  _dot(
                    kRed,
                    'Missed',
                    vm.weeklyTasksTemp
                        .where((t) => t.status == TaskStatus.missed)
                        .length,
                  ),
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
            const Divider(height: 16),
            Expanded(
              child: vm.weeklyTasksTemp.isEmpty
                  ? _emptyState(context, vm)
                  : ListView(
                      controller: ctrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        if (unscheduled.isNotEmpty) ...[
                          _sectionHeader(
                            icon: Icons.bolt_rounded,
                            color: kOrange,
                            label: 'Unscheduled Tasks (HR Assigned)',
                            count: unscheduled.length,
                          ),
                          ...unscheduled.map((t) {
                            final idx = vm.weeklyTasksTemp.indexOf(t);
                            return _EmpTaskItem(
                              key: ValueKey(t.id.isEmpty ? 'u_$idx' : t.id),
                              task: t,
                              index: idx,
                              vm: vm,
                              showUnscheduledBadge: true,
                            );
                          }),
                          const SizedBox(height: 16),
                        ],
                        if (scheduled.isNotEmpty) ...[
                          _sectionHeader(
                            icon: Icons.calendar_today_rounded,
                            color: kBlue,
                            label: 'Scheduled Weekly Tasks',
                            count: scheduled.length,
                          ),
                          ...scheduled.map((t) {
                            final idx = vm.weeklyTasksTemp.indexOf(t);
                            return _EmpTaskItem(
                              key: ValueKey(t.id.isEmpty ? 'w_$idx' : t.id),
                              task: t,
                              index: idx,
                              vm: vm,
                              showUnscheduledBadge: false,
                            );
                          }),
                        ],
                        if (canAdd)
                          _AddWeekButton(
                            onTap: vm.addWeekTask,
                            remaining: remaining,
                            nextWeekNumber: scheduled.isEmpty
                                ? 1
                                : scheduled
                                          .map((t) => t.weekNumber)
                                          .reduce((a, b) => a > b ? a : b) +
                                      1,
                            nextDueDate: vm.selectedGoal!.startDate.add(
                              Duration(
                                days:
                                    (scheduled.isEmpty
                                        ? 1
                                        : scheduled
                                                  .map((t) => t.weekNumber)
                                                  .reduce(
                                                    (a, b) => a > b ? a : b,
                                                  ) +
                                              1) *
                                    7,
                              ),
                            ),
                          )
                        else if (vm.weeklyTasksTemp.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    vm.saveWeeklyBreakdown();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Weekly Plan',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, EmployeePerformanceViewModel vm) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kSlateDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first week task.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: kSlate),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: vm.canAddWeek ? vm.addWeekTask : null,
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
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required Color color,
    required String label,
    required int count,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
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
              color: Color.fromRGBO(color.red, color.green, color.blue, 0.1),
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
  }

  Widget _dot(Color color, String label, int value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text('$label: ', style: const TextStyle(fontSize: 12, color: kSlate)),
      Text(
        '$value',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────
// TASK ITEM  (inside the bottom sheet)
// ─────────────────────────────────────────────────────────────

class _EmpTaskItem extends StatelessWidget {
  final WeeklyTaskModel task;
  final int index;
  final EmployeePerformanceViewModel vm;
  final bool showUnscheduledBadge;

  const _EmpTaskItem({
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
    final isWeekend = task.status == TaskStatus.weekend;

    Color borderColor = kSlate200;
    Color bgColor = Colors.white;
    if (isCompleted) {
      borderColor = const Color(0xFF6EE7B7);
      bgColor = kGreenSoft;
    } else if (isMissed) {
      borderColor = const Color(0xFFFCA5A5);
      bgColor = kRedSoft;
    } else if (isWeekend) {
      borderColor = const Color(0xFFFBD38D);
      bgColor = const Color(0xFFFFFBEB);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? kGreen
                      : isMissed
                      ? kRed
                      : isWeekend
                      ? const Color(0xFFF59E0B)
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
              // Complete button → shows TeamRemarksDialog first
              if (task.status == TaskStatus.pending)
                task.id.trim().isNotEmpty
                    ? TextButton(
                        onPressed: () async {
                          final remarks = await showTeamRemarksDialog(context);
                          if (remarks == null) return;
                          await vm.markTaskStatus(
                            goalId: task.goalId,
                            taskId: task.id,
                            status: TaskStatus.completed,
                            teamRemarks: remarks,
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF16A34A),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          'Complete',
                          style: TextStyle(fontSize: 12),
                        ),
                      )
                    : const Tooltip(
                        message: 'Save the plan first',
                        child: Icon(
                          Icons.hourglass_empty_rounded,
                          size: 18,
                          color: kSlate,
                        ),
                      )
              else
                TaskStatusBadge(status: task.status),
            ],
          ),

          // ── Team remarks (read-only once completed) ────────
          if (isCompleted &&
              task.teamRemarks != null &&
              task.teamRemarks!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _TeamRemarksReadView(remarks: task.teamRemarks!),
          ],

          const SizedBox(height: 10),
          if (task.status == TaskStatus.pending) ...[
            TextFormField(
              initialValue: task.title,
              decoration: formDec('Task title for week ${task.weekNumber}...'),
              onChanged: (v) =>
                  vm.updateTempTask(index, task.copyWith(title: v)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: task.description,
              decoration: formDec('Describe what you\'ll accomplish...'),
              maxLines: 2,
              onChanged: (v) =>
                  vm.updateTempTask(index, task.copyWith(description: v)),
            ),
          ] else ...[
            Text(
              task.title.isNotEmpty ? task.title : 'Week ${task.weekNumber}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            if (task.description.isNotEmpty)
              Text(
                task.description,
                style: const TextStyle(fontSize: 12, color: kSlate),
              ),
            if (isCompleted && task.completedAt != null)
              Text(
                'Completed on ${task.completedAt!.toString().substring(0, 10)}',
                style: const TextStyle(fontSize: 11, color: kGreen),
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TEAM REMARKS — Read-only display (shown on completed task)
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
          const Row(
            children: [
              Icon(Icons.groups_rounded, size: 13, color: kGreen),
              SizedBox(width: 6),
              Text(
                'Team Remarks',
                style: TextStyle(
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
                    margin: const EdgeInsets.only(top: 2),
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
// BARRIER DIALOG
// ─────────────────────────────────────────────────────────────

class _BarrierDialog extends StatefulWidget {
  const _BarrierDialog();
  @override
  State<_BarrierDialog> createState() => _BarrierDialogState();
}

class _BarrierDialogState extends State<_BarrierDialog> {
  EmployeeContact? _selectedRecipient;
  final Set<String> _ccIds = {};
  final _descCtrl = TextEditingController();
  bool _isSending = false;
  bool _loadingEmp = true;
  List<EmployeeContact> _employees = [];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    final vm = context.read<EmployeePerformanceViewModel>();
    try {
      final list = await vm.fetchAllEmployeeContacts();
      if (mounted) {
        setState(() {
          _employees = list;
          _loadingEmp = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingEmp = false);
    }
  }

  List<EmployeeContact> get _ccOptions =>
      _employees.where((e) => e.uid != _selectedRecipient?.uid).toList();

  Future<void> _send() async {
    if (_selectedRecipient == null) {
      _snack('Please select a recipient.', isError: true);
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      _snack('Please describe the barrier.', isError: true);
      return;
    }
    setState(() => _isSending = true);
    final vm = context.read<EmployeePerformanceViewModel>();
    final ccList = _employees.where((e) => _ccIds.contains(e.uid)).toList();
    try {
      await vm.reportBarrierWithNotifications(
        recipient: _selectedRecipient!,
        ccList: ccList,
        description: _descCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _snack('Failed to send: $e', isError: true);
      }
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? kRed : kGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: kRed, size: 22),
                SizedBox(width: 8),
                Text(
                  'Report a Barrier',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: kRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Select a recipient — they will receive a notification. '
              'CC\'d employees get a foreground notification only.',
              style: TextStyle(fontSize: 12, color: kSlate),
            ),
            const SizedBox(height: 20),
            const _FieldLabel('To (Recipient) *', Icons.person_rounded),
            const SizedBox(height: 6),
            if (_loadingEmp)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kBlue,
                  ),
                ),
              )
            else
              _EmployeeDropdown(
                label: 'Select recipient',
                employees: _employees,
                selected: _selectedRecipient,
                onChanged: (emp) => setState(() {
                  _selectedRecipient = emp;
                  _ccIds.remove(emp?.uid);
                }),
              ),
            if (_selectedRecipient != null) ...[
              const SizedBox(height: 8),
              _NotificationBadge(
                label:
                    '${_selectedRecipient!.name} will receive a foreground + background notification',
                icon: Icons.notifications_active_rounded,
                color: kBlue,
              ),
            ],
            const SizedBox(height: 20),
            const _FieldLabel('CC (optional)', Icons.alternate_email_rounded),
            const SizedBox(height: 6),
            if (_ccOptions.isEmpty && !_loadingEmp)
              const Text(
                'No other employees available.',
                style: TextStyle(fontSize: 12, color: kSlate),
              )
            else
              _CcMultiSelect(
                options: _ccOptions,
                selectedIds: _ccIds,
                onToggle: (uid) => setState(
                  () => _ccIds.contains(uid)
                      ? _ccIds.remove(uid)
                      : _ccIds.add(uid),
                ),
              ),
            if (_ccIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              _NotificationBadge(
                label:
                    '${_ccIds.length} CC\'d employee${_ccIds.length == 1 ? '' : 's'} will receive a foreground notification only',
                icon: Icons.notifications_rounded,
                color: kOrange,
              ),
            ],
            const SizedBox(height: 20),
            const _FieldLabel('Barrier Description *', Icons.notes_rounded),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: formDec('Describe the barrier you\'re facing...'),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSending ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isSending ? null : _send,
                  icon: _isSending
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 15),
                  label: Text(_isSending ? 'Sending…' : 'Send Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kRed,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Employee dropdown ─────────────────────────────────────────

class _EmployeeDropdown extends StatelessWidget {
  final String label;
  final List<EmployeeContact> employees;
  final EmployeeContact? selected;
  final ValueChanged<EmployeeContact?> onChanged;

  const _EmployeeDropdown({
    required this.label,
    required this.employees,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: kSlate200),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<EmployeeContact>(
          value: selected,
          isExpanded: true,
          hint: Text(
            label,
            style: const TextStyle(fontSize: 13, color: kSlate),
          ),
          items: employees.map((emp) {
            return DropdownMenuItem<EmployeeContact>(
              value: emp,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emp.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kSlateDark,
                    ),
                  ),
                  Text(
                    emp.email,
                    style: const TextStyle(fontSize: 11, color: kSlate),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
          selectedItemBuilder: (ctx) => employees.map((emp) {
            return Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    emp.name
                        .split(' ')
                        .map((n) => n.isNotEmpty ? n[0] : '')
                        .take(2)
                        .join(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        emp.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        emp.email,
                        style: const TextStyle(fontSize: 10, color: kSlate),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── CC multi-select ───────────────────────────────────────────

class _CcMultiSelect extends StatelessWidget {
  final List<EmployeeContact> options;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  const _CcMultiSelect({
    required this.options,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: kSlate200),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Column(
        children: options.asMap().entries.map((entry) {
          final i = entry.key;
          final emp = entry.value;
          final isSelected = selectedIds.contains(emp.uid);
          final isLast = i == options.length - 1;

          return InkWell(
            onTap: () => onToggle(emp.uid),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? kBlueSoft : Colors.transparent,
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(color: Color(0xFFF1F5F9)),
                      ),
                borderRadius: isLast
                    ? const BorderRadius.vertical(bottom: Radius.circular(8))
                    : i == 0
                    ? const BorderRadius.vertical(top: Radius.circular(8))
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          isSelected ? kBlue : const Color(0xFF64748B),
                          isSelected
                              ? const Color(0xFF8B5CF6)
                              : const Color(0xFF94A3B8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emp.name
                          .split(' ')
                          .map((n) => n.isNotEmpty ? n[0] : '')
                          .take(2)
                          .join(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? kBlue : kSlateDark,
                          ),
                        ),
                        Text(
                          emp.email,
                          style: const TextStyle(fontSize: 11, color: kSlate),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isSelected ? kBlue : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? kBlue : kSlate200,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  const _FieldLabel(this.text, this.icon);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14, color: kSlate),
      const SizedBox(width: 6),
      Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: kSlateDark,
        ),
      ),
    ],
  );
}

class _NotificationBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _NotificationBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Color.fromRGBO(color.red, color.green, color.blue, 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: Color.fromRGBO(color.red, color.green, color.blue, 0.3),
      ),
    ),
    child: Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 11, color: color)),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// WEEKLY REMINDER OVERLAY
// ─────────────────────────────────────────────────────────────

class _WeeklyReminderOverlay extends StatelessWidget {
  final EmployeePerformanceViewModel vm;
  const _WeeklyReminderOverlay({required this.vm});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      color: kBlue,
                      size: 26,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Weekly Task Check-in',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Did you complete this week\'s task?',
                            style: TextStyle(fontSize: 13, color: kSlate),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kBlueSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBlueBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vm.reminderTask?.title ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                      if (vm.reminderTask?.description.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text(
                          vm.reminderTask!.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 13,
                            color: Color(0xFF60A5FA),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Due: ${vm.reminderTask?.dueDate.toString().substring(0, 10) ?? ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kOrangeSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFBD38D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: kOrange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Missed = ${vm.rules?.missedTaskDeductionPercent.toInt() ?? 5}% salary deduction  •  Weekend = No deduction',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    // Missed — no dialog needed
                    Expanded(
                      child: _ReminderBtn(
                        label: 'Missed',
                        icon: Icons.cancel_rounded,
                        fg: kRed,
                        bg: kRedSoft,
                        onTap: () =>
                            vm.handleReminderResponse(TaskStatus.missed),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Weekend — no dialog needed
                    Expanded(
                      child: _ReminderBtn(
                        label: 'Weekend',
                        icon: Icons.access_time_rounded,
                        fg: kOrange,
                        bg: kOrangeSoft,
                        onTap: () =>
                            vm.handleReminderResponse(TaskStatus.weekend),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Completed — show TeamRemarksDialog first
                    Expanded(
                      child: _ReminderBtn(
                        label: 'Completed',
                        icon: Icons.check_circle_rounded,
                        fg: Colors.white,
                        bg: kGreen,
                        onTap: () async {
                          final remarks = await showTeamRemarksDialog(context);
                          if (remarks == null) return;
                          await vm.handleReminderResponse(
                            TaskStatus.completed,
                            teamRemarks: remarks,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color fg, bg;
  final VoidCallback onTap;
  const _ReminderBtn({
    required this.label,
    required this.icon,
    required this.fg,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ADD WEEK BUTTON
// ─────────────────────────────────────────────────────────────

class _AddWeekButton extends StatelessWidget {
  final VoidCallback onTap;
  final int remaining;
  final int nextWeekNumber;
  final DateTime nextDueDate;
  const _AddWeekButton({
    required this.onTap,
    required this.remaining,
    required this.nextWeekNumber,
    required this.nextDueDate,
  });

  @override
  Widget build(BuildContext context) {
    final dueFmt =
        '${nextDueDate.year}-${nextDueDate.month.toString().padLeft(2, '0')}-${nextDueDate.day.toString().padLeft(2, '0')}';

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
              decoration: BoxDecoration(color: kBlue, shape: BoxShape.circle),
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
                    'Due $dueFmt  ·  $remaining week${remaining == 1 ? '' : 's'} remaining',
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
