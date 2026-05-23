// ============================================================
// HR PAYROLL SCREEN
// Basic pulled from users.salary | HR can override
// Deductions: Loan + Performance + Attendance
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/payroll_model.dart';
import '../../services/payroll_service.dart';
import '../../viewmodels/payroll_viewmodel.dart';
import '../performance_screens/performance_widgets.dart';

class HRPayrollScreen extends StatelessWidget {
  const HRPayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HRPayrollViewModel(
        service: context.read<PayrollService>(),
        hrUserId: 'hr_001',
      ),
      child: const _HRPayrollBody(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BODY
// ─────────────────────────────────────────────────────────────

class _HRPayrollBody extends StatelessWidget {
  const _HRPayrollBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HRPayrollViewModel>();

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

    return Scaffold(
      backgroundColor: kSlateBg,
      body: Column(
        children: [
          _Header(vm: vm),
          Expanded(
            child: switch (vm.activeTab) {
              HRPayrollTab.overview => _OverviewTab(vm: vm),
              HRPayrollTab.runPayroll => _RunPayrollTab(vm: vm),
              HRPayrollTab.configure => _ConfigureTab(vm: vm),
              HRPayrollTab.history => _HistoryTab(vm: vm),
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final HRPayrollViewModel vm;
  const _Header({required this.vm});

  static const _tabs = [
    (HRPayrollTab.overview, Icons.account_balance_wallet_rounded, 'Overview'),
    (HRPayrollTab.runPayroll, Icons.play_circle_rounded, 'Run Payroll'),
    (HRPayrollTab.configure, Icons.tune_rounded, 'Configure'),
    (HRPayrollTab.history, Icons.history_rounded, 'History'),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kBlueSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: kBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payroll Management',
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
              const Spacer(),
              _MonthPicker(vm: vm),
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

class _MonthPicker extends StatelessWidget {
  final HRPayrollViewModel vm;
  const _MonthPicker({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: kSlate200),
        borderRadius: BorderRadius.circular(8),
        color: kSlateBg,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: vm.selectedMonth,
          style: const TextStyle(
            fontSize: 13,
            color: kSlateDark,
            fontWeight: FontWeight.w500,
          ),
          items: HRPayrollViewModel.availableMonths()
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (v) {
            if (v != null) vm.setMonth(v);
          },
          icon: const Icon(Icons.expand_more_rounded, size: 18, color: kSlate),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 1 — OVERVIEW
// ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final HRPayrollViewModel vm;
  const _OverviewTab({required this.vm});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stats grid ──────────────────────────────────────
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.0,
            children: [
              StatCard(
                title: 'Total Gross',
                value: _pkr(vm.totalGrossForMonth),
                icon: Icons.trending_up_rounded,
                color: kBlue,
              ),
              StatCard(
                title: 'Total Net Pay',
                value: _pkr(vm.totalNetForMonth),
                icon: Icons.payments_rounded,
                color: kGreen,
              ),
              StatCard(
                title: 'Perf Deductions',
                value: _pkr(vm.totalPerfDeductionsForMonth),
                icon: Icons.remove_circle_rounded,
                color: kRed,
              ),
              StatCard(
                title: 'Attendance Deductions',
                value: _pkr(vm.totalAttendanceDeductionsForMonth),
                icon: Icons.access_time_rounded,
                color: const Color(0xFFEA580C),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Status pills ─────────────────────────────────────
          if (vm.payslipsForMonth.isNotEmpty)
            Row(
              children: [
                _StatusPill(
                  label: 'Draft',
                  count: vm.payslipsForMonth
                      .where((p) => p.status == PayslipStatus.draft)
                      .length,
                  color: kSlate,
                ),
                const SizedBox(width: 8),
                _StatusPill(
                  label: 'Approved',
                  count: vm.approvedCount,
                  color: kBlue,
                ),
                const SizedBox(width: 8),
                _StatusPill(label: 'Paid', count: vm.paidCount, color: kGreen),
              ],
            ),
          const SizedBox(height: 16),

          if (vm.payslipsForMonth.isEmpty)
            _EmptyPayroll(month: vm.selectedMonth)
          else
            PCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${vm.selectedMonth} Payslips',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${vm.payslipsForMonth.length} employees',
                        style: const TextStyle(fontSize: 12, color: kSlate),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...vm.payslipsForMonth.map(
                    (p) => _PayslipRow(payslip: p, vm: vm),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _pkr(double v) =>
      'PKR ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
}

class _StatusPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatusPill({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayslipRow extends StatelessWidget {
  final PayslipModel payslip;
  final HRPayrollViewModel vm;
  const _PayslipRow({required this.payslip, required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSlateBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kSlate200),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              payslip.employeeName
                  .split(' ')
                  .map((n) => n.isNotEmpty ? n[0] : '')
                  .take(2)
                  .join(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payslip.employeeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  payslip.employeeRole,
                  style: const TextStyle(fontSize: 11, color: kSlate),
                ),
              ],
            ),
          ),

          // Attendance deduction badge
          if (payslip.attendanceDeduction > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 10,
                    color: Color(0xFFEA580C),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '-PKR ${payslip.attendanceDeduction.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ],
              ),
            ),

          // Performance deduction badge
          if (payslip.performanceDeduction > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '-PKR ${payslip.performanceDeduction.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: kRed,
                ),
              ),
            ),

          // Net pay
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PKR ${payslip.netPay.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: kSlateDark,
                ),
              ),
              const Text(
                'Net Pay',
                style: TextStyle(fontSize: 10, color: kSlate),
              ),
            ],
          ),
          const SizedBox(width: 12),

          _PayslipStatusMenu(payslip: payslip, vm: vm),
        ],
      ),
    );
  }
}

class _PayslipStatusMenu extends StatelessWidget {
  final PayslipModel payslip;
  final HRPayrollViewModel vm;
  const _PayslipStatusMenu({required this.payslip, required this.vm});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'approve') vm.approvePayslip(payslip.id);
        if (v == 'paid') vm.markAsPaid(payslip.id);
        if (v == 'delete') vm.deletePayslip(payslip.id);
        if (v == 'view') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PayslipDetailScreen(payslip: payslip),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _statusColor(payslip.status).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _statusColor(payslip.status).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              payslip.status.name.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _statusColor(payslip.status),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: _statusColor(payslip.status),
            ),
          ],
        ),
      ),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(Icons.visibility_rounded, size: 16),
              SizedBox(width: 8),
              Text('View Payslip'),
            ],
          ),
        ),
        if (payslip.status == PayslipStatus.draft)
          const PopupMenuItem(
            value: 'approve',
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: kBlue),
                SizedBox(width: 8),
                Text('Approve'),
              ],
            ),
          ),
        if (payslip.status == PayslipStatus.approved)
          const PopupMenuItem(
            value: 'paid',
            child: Row(
              children: [
                Icon(Icons.payments_rounded, size: 16, color: kGreen),
                SizedBox(width: 8),
                Text('Mark as Paid'),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 16, color: kRed),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: kRed)),
            ],
          ),
        ),
      ],
    );
  }

  Color _statusColor(PayslipStatus s) => switch (s) {
    PayslipStatus.draft => kSlate,
    PayslipStatus.approved => kBlue,
    PayslipStatus.paid => kGreen,
  };
}

class _EmptyPayroll extends StatelessWidget {
  final String month;
  const _EmptyPayroll({required this.month});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSlate200),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: kBlueSoft,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: kBlue,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No payslips for $month',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Go to "Run Payroll" to generate payslips for this month.',
            style: TextStyle(fontSize: 13, color: kSlate),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 2 — RUN PAYROLL
// ─────────────────────────────────────────────────────────────

class _RunPayrollTab extends StatelessWidget {
  final HRPayrollViewModel vm;
  const _RunPayrollTab({required this.vm});

  @override
  Widget build(BuildContext context) {
    final alreadyRun = vm.payslipsForMonth.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: const Border(left: BorderSide(color: kBlue, width: 4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.play_circle_rounded, color: kBlue, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Run Monthly Payroll',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Generates payslips for all configured employees for ${vm.selectedMonth}.\n'
                  'Attendance deductions (late arrivals, absences, early departures) '
                  'are calculated automatically from the attendance archive.',
                  style: const TextStyle(fontSize: 13, color: kSlate),
                ),
                const SizedBox(height: 16),

                // Policy reference box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        children: [
                          Icon(
                            Icons.gavel_rounded,
                            size: 14,
                            color: Color(0xFFEA580C),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Attendance Penalty Rules',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      _PolicyLine('Absent (no leave)', 'Salary ÷ 22 × 100%'),
                      _PolicyLine('Late 9–10 AM', 'Salary ÷ 22 × 25%'),
                      _PolicyLine('Late after 10 AM', 'Salary ÷ 22 × 50%'),
                      _PolicyLine('Left after 5 PM', 'Salary ÷ 22 × 25%'),
                      _PolicyLine('Left before 5 PM', 'Salary ÷ 22 × 50%'),
                      _PolicyLine('Worked < 4 h', 'Salary ÷ 22 × 50%'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Before running:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _req(
                  'Employees have salary set in their profiles',
                  vm.employees.isNotEmpty,
                ),
                _req('Attendance archive exists for ${vm.selectedMonth}', true),
                _req(
                  'Performance deductions calculated for ${vm.selectedMonth}',
                  true,
                ),

                const SizedBox(height: 20),

                if (vm.isRunning)
                  Column(
                    children: [
                      const LinearProgressIndicator(color: kBlue),
                      const SizedBox(height: 12),
                      Text(
                        vm.runProgressMessage,
                        style: const TextStyle(fontSize: 13, color: kSlate),
                      ),
                    ],
                  )
                else if (alreadyRun)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kGreenSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: kGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payroll already run for ${vm.selectedMonth}. '
                            '${vm.payslipsForMonth.length} payslips generated. '
                            'You can re-run to overwrite.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox.shrink(),

                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: vm.isRunning ? null : vm.runPayroll,
                  icon: vm.isRunning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(
                    vm.isRunning
                        ? 'Running…'
                        : alreadyRun
                        ? 'Re-run Payroll'
                        : 'Run Payroll for ${vm.selectedMonth}',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (vm.employees.isNotEmpty) ...[
            Text(
              'Employees (${vm.employees.length}) — basic salary auto-pulled from profile',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...vm.employees.map((emp) {
              final existing = vm.payslipsForMonth
                  .where((p) => p.employeeId == emp['id'])
                  .firstOrNull;
              final salary = emp['salary'] as double? ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kSlate200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (emp['name'] as String? ?? 'E')
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
                            emp['name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            emp['role'] ?? emp['designation'] ?? '',
                            style: const TextStyle(fontSize: 11, color: kSlate),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'PKR ${salary.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kBlue,
                          ),
                        ),
                        const Text(
                          'from profile',
                          style: TextStyle(fontSize: 10, color: kSlate),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    if (existing != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: kGreenSoft,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFBBF7D0),
                              ),
                            ),
                            child: Text(
                              'Net PKR ${existing.netPay.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: kGreen,
                              ),
                            ),
                          ),
                          if (existing.attendanceDeduction > 0) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Att. -PKR ${existing.attendanceDeduction.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                          ],
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: kSlate100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Pending',
                          style: TextStyle(fontSize: 11, color: kSlate),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _req(String label, bool done) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(
          done
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: done ? kGreen : kSlate,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: done ? kGreen : kSlate),
        ),
      ],
    ),
  );
}

/// Small two-column policy line used in the penalty reference box.
class _PolicyLine extends StatelessWidget {
  final String rule;
  final String formula;
  const _PolicyLine(this.rule, this.formula);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        const Icon(
          Icons.arrow_right_rounded,
          size: 14,
          color: Color(0xFFEA580C),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            rule,
            style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
          ),
        ),
        Text(
          formula,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFFEA580C),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// TAB 3 — CONFIGURE
// ─────────────────────────────────────────────────────────────

class _ConfigureTab extends StatelessWidget {
  final HRPayrollViewModel vm;
  const _ConfigureTab({required this.vm});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Employee Payroll Configuration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Add allowances or override basic salary. Loan deductions set here.',
            style: TextStyle(fontSize: 12, color: kSlate),
          ),
          const SizedBox(height: 16),

          if (vm.showConfigForm && vm.editingConfig != null)
            _PayrollConfigForm(vm: vm)
          else ...[
            if (vm.employees.isEmpty)
              const EmptyState(message: 'No employees found.')
            else
              ...vm.employees.map((emp) {
                final empId = emp['id'] as String;
                final salary = emp['salary'] as double? ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kSlate200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (emp['name'] as String? ?? 'E')
                              .split(' ')
                              .map((n) => n.isNotEmpty ? n[0] : '')
                              .take(2)
                              .join(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              emp['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Profile salary: PKR ${salary.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: kBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => vm.openConfigForEmployee(empId),
                        icon: const Icon(Icons.tune_rounded, size: 14),
                        label: const Text('Configure'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kBlue,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }
}

class _PayrollConfigForm extends StatefulWidget {
  final HRPayrollViewModel vm;
  const _PayrollConfigForm({required this.vm});

  @override
  State<_PayrollConfigForm> createState() => _PayrollConfigFormState();
}

class _PayrollConfigFormState extends State<_PayrollConfigForm> {
  late TextEditingController _overrideCtrl;
  late TextEditingController _loanCtrl;
  late List<AllowanceItem> _allowances;
  bool _overrideBasic = false;

  @override
  void initState() {
    super.initState();
    final c = widget.vm.editingConfig!;
    _overrideBasic = c.basicSalaryOverride != null;
    _overrideCtrl = TextEditingController(
      text: c.basicSalaryOverride?.toStringAsFixed(0) ?? '',
    );
    _loanCtrl = TextEditingController(
      text: c.loanDeductionPerMonth.toStringAsFixed(0),
    );
    _allowances = List.from(c.allowances);
  }

  @override
  void dispose() {
    _overrideCtrl.dispose();
    _loanCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final loan = double.tryParse(_loanCtrl.text) ?? 0;
    final override = _overrideBasic
        ? double.tryParse(_overrideCtrl.text)
        : null;

    widget.vm.updateEditingConfig(
      widget.vm.editingConfig!.copyWith(
        basicSalaryOverride: override,
        allowances: _allowances,
        loanDeductionPerMonth: loan,
        updatedBy: 'hr_001',
      ),
    );
    widget.vm.saveConfig();
  }

  double get _effectiveBasic {
    if (_overrideBasic) return double.tryParse(_overrideCtrl.text) ?? 0;
    return widget.vm.editingEmployeeSalary;
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.vm.editingConfig!;

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
          Row(
            children: [
              Text(
                'Configuring: ${config.employeeName.isNotEmpty ? config.employeeName : config.employeeId}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.vm.cancelConfig,
                child: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kSlateBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kSlate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 16,
                      color: kBlue,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Basic Salary',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: _overrideBasic,
                      activeThumbColor: kBlue,
                      onChanged: (v) => setState(() {
                        _overrideBasic = v;
                        if (!v) _overrideCtrl.clear();
                      }),
                    ),
                    Text(
                      _overrideBasic ? 'Override' : 'Auto',
                      style: TextStyle(
                        fontSize: 12,
                        color: _overrideBasic ? kBlue : kSlate,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_overrideBasic)
                  TextField(
                    controller: _overrideCtrl,
                    keyboardType: TextInputType.number,
                    decoration: formDec('Override Basic Salary (PKR)'),
                    onChanged: (_) => setState(() {}),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kBlueSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: kBlue,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Auto: PKR ${widget.vm.editingEmployeeSalary.toStringAsFixed(0)} (from employee profile)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: kBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _loanCtrl,
            keyboardType: TextInputType.number,
            decoration: formDec('Loan Deduction (PKR/month)'),
          ),
          const SizedBox(height: 20),

          const Text(
            'Allowances',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ..._allowances.asMap().entries.map((e) {
            final i = e.key;
            final a = e.value;
            final resolvedLabel =
                a.type == AllowanceType.percentOfBasic && _overrideBasic
                ? '= PKR ${a.resolve(_effectiveBasic).toStringAsFixed(0)}'
                : '';
            return _AllowanceRow(
              allowance: a,
              resolvedLabel: resolvedLabel,
              onUpdate: (u) => setState(() => _allowances[i] = u),
              onDelete: () => setState(() => _allowances.removeAt(i)),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(
              () => _allowances.add(
                const AllowanceItem(
                  name: '',
                  amount: 0,
                  type: AllowanceType.fixed,
                ),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Allowance'),
            style: TextButton.styleFrom(foregroundColor: kBlue),
          ),
          const SizedBox(height: 20),

          if (_effectiveBasic > 0) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kBlueSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBlueBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Estimated Gross Pay',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'PKR ${(_effectiveBasic + _allowances.fold(0.0, (s, a) => s + a.resolve(_effectiveBasic))).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save Configuration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AllowanceRow extends StatelessWidget {
  final AllowanceItem allowance;
  final String resolvedLabel;
  final ValueChanged<AllowanceItem> onUpdate;
  final VoidCallback onDelete;
  const _AllowanceRow({
    required this.allowance,
    required this.resolvedLabel,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kSlateBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kSlate200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              initialValue: allowance.name,
              decoration: formDec('Name'),
              onChanged: (v) => onUpdate(allowance.copyWith(name: v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: allowance.amount.toStringAsFixed(0),
              decoration: formDec(
                allowance.type == AllowanceType.percentOfBasic ? '%' : 'PKR',
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) =>
                  onUpdate(allowance.copyWith(amount: double.tryParse(v) ?? 0)),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<AllowanceType>(
            value: allowance.type,
            underline: const SizedBox(),
            style: const TextStyle(fontSize: 12, color: kSlateDark),
            items: const [
              DropdownMenuItem(
                value: AllowanceType.fixed,
                child: Text('Fixed'),
              ),
              DropdownMenuItem(
                value: AllowanceType.percentOfBasic,
                child: Text('% of Basic'),
              ),
            ],
            onChanged: (v) {
              if (v != null) onUpdate(allowance.copyWith(type: v));
            },
          ),
          if (resolvedLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                resolvedLabel,
                style: const TextStyle(fontSize: 11, color: kBlue),
              ),
            ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded, size: 16, color: kSlate),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB 4 — HISTORY
// ─────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  final HRPayrollViewModel vm;
  const _HistoryTab({required this.vm});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payroll Run History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (vm.runHistory.isEmpty)
            const EmptyState(message: 'No payroll runs yet.')
          else
            ...vm.runHistory.map((run) => _RunCard(run: run)),
        ],
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  final PayrollRunModel run;
  const _RunCard({required this.run});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSlate200),
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
                  color: kBlueSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  run.month,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: kBlue,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kGreenSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  run.status.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: kGreen,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Run by ${run.runBy} · ${run.runAt.toString().substring(0, 10)}',
                style: const TextStyle(fontSize: 11, color: kSlate),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _RunStat('Employees', '${run.totalEmployees}'),
              _RunStat(
                'Gross',
                'PKR ${(run.totalGross / 1000).toStringAsFixed(0)}k',
              ),
              _RunStat(
                'Deductions',
                'PKR ${(run.totalDeductions / 1000).toStringAsFixed(0)}k',
              ),
              _RunStat(
                'Net Pay',
                'PKR ${(run.totalNetPay / 1000).toStringAsFixed(0)}k',
              ),
            ],
          ),
          if (run.totalAttendanceDeductions > 0 ||
              run.totalPerformanceDeductions > 0 ||
              run.totalPerformanceBonuses > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                if (run.totalAttendanceDeductions > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Color(0xFFEA580C),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Attendance: PKR ${run.totalAttendanceDeductions.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                if (run.totalPerformanceDeductions > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.trending_down_rounded,
                        size: 14,
                        color: kRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Perf: PKR ${run.totalPerformanceDeductions.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: kRed),
                      ),
                    ],
                  ),
                if (run.totalPerformanceBonuses > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Bonus: PKR ${run.totalPerformanceBonuses.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RunStat extends StatelessWidget {
  final String label;
  final String value;
  const _RunStat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: kSlate)),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// PAYSLIP DETAIL SCREEN
// ─────────────────────────────────────────────────────────────

class PayslipDetailScreen extends StatelessWidget {
  final PayslipModel payslip;
  const PayslipDetailScreen({super.key, required this.payslip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSlateBg,
      appBar: AppBar(
        title: Text('Payslip — ${payslip.month}'),
        backgroundColor: Colors.white,
        foregroundColor: kSlateDark,
        elevation: 1,
        actions: [
          IconButton(
            onPressed: () {
              /* TODO: share/print */
            },
            icon: const Icon(Icons.share_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _PayslipCard(payslip: payslip),
      ),
    );
  }
}

class _PayslipCard extends StatelessWidget {
  final PayslipModel payslip;
  const _PayslipCard({required this.payslip});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Dark header ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        payslip.employeeName
                            .split(' ')
                            .map((n) => n.isNotEmpty ? n[0] : '')
                            .take(2)
                            .join(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payslip.employeeName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            payslip.employeeRole,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _PayslipStatusBadge(status: payslip.status),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pay Period',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          payslip.month,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Net Pay',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'PKR ${payslip.netPay.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Earnings ──────────────────────────────────
                _SectionTitle('Earnings', Icons.trending_up_rounded, kGreen),
                const SizedBox(height: 10),
                _LineItem('Basic Salary', payslip.basicSalary),
                ...payslip.allowances.map((a) => _LineItem(a.name, a.amount)),
                if (payslip.performanceBonus > 0)
                  _LineItem(
                    'Performance Bonus',
                    payslip.performanceBonus,
                    color: kGreen,
                    isBold: true,
                  ),
                const Divider(height: 20),
                _LineItem('Gross Pay', payslip.grossPay, isBold: true),
                const SizedBox(height: 20),

                // ── Deductions ────────────────────────────────
                _SectionTitle('Deductions', Icons.trending_down_rounded, kRed),
                const SizedBox(height: 10),
                if (payslip.loanDeduction > 0)
                  _LineItem(
                    'Loan Repayment',
                    payslip.loanDeduction,
                    isDeduction: true,
                  ),
                if (payslip.performanceDeduction > 0)
                  _PerformanceDeductionLine(payslip: payslip),
                if (payslip.attendanceDeduction > 0)
                  _AttendanceDeductionLine(payslip: payslip),
                const Divider(height: 20),
                _LineItem(
                  'Total Deductions',
                  payslip.totalDeductions,
                  isBold: true,
                  isDeduction: true,
                ),
                const SizedBox(height: 20),

                // ── Net pay ───────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Net Pay',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'PKR ${payslip.netPay.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Attendance deduction breakdown ────────────
                if (payslip.attendanceDeduction > 0)
                  _AttendanceDeductionSection(payslip: payslip),

                // ── Performance section ───────────────────────
                if (payslip.totalTasksInMonth > 0) ...[
                  if (payslip.attendanceDeduction > 0)
                    const SizedBox(height: 16),
                  _PerformanceSection(payslip: payslip),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ATTENDANCE DEDUCTION LINE (summary row in deductions section)
// ─────────────────────────────────────────────────────────────

class _AttendanceDeductionLine extends StatelessWidget {
  final PayslipModel payslip;
  const _AttendanceDeductionLine({required this.payslip});

  @override
  Widget build(BuildContext context) {
    final s = payslip.attendanceSummary;
    final parts = <String>[];
    if (s.absentDays > 0) parts.add('${s.absentDays} absent');
    if (s.lateMildDays > 0) parts.add('${s.lateMildDays} late (mild)');
    if (s.lateSevereDays > 0) parts.add('${s.lateSevereDays} late (severe)');
    if (s.earlyMildDays > 0) parts.add('${s.earlyMildDays} early (mild)');
    if (s.earlySevereDays > 0) parts.add('${s.earlySevereDays} early (severe)');
    if (s.underworkedDays > 0) parts.add('${s.underworkedDays} < 4 h');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 14,
                color: Color(0xFFEA580C),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Attendance Deduction',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                  Text(
                    parts.join(' · '),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            '-PKR ${payslip.attendanceDeduction.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFEA580C),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ATTENDANCE DEDUCTION SECTION (full breakdown in detail)
// ─────────────────────────────────────────────────────────────

class _AttendanceDeductionSection extends StatefulWidget {
  final PayslipModel payslip;
  const _AttendanceDeductionSection({required this.payslip});

  @override
  State<_AttendanceDeductionSection> createState() =>
      _AttendanceDeductionSectionState();
}

class _AttendanceDeductionSectionState
    extends State<_AttendanceDeductionSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.payslip.attendanceSummary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 16,
                color: Color(0xFFEA580C),
              ),
              const SizedBox(width: 6),
              const Text(
                'Attendance Deductions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEA580C),
                ),
              ),
              const Spacer(),
              Text(
                '-PKR ${widget.payslip.attendanceDeduction.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEA580C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Summary chips ───────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (s.absentDays > 0)
                _AttChip('${s.absentDays}× Absent', const Color(0xFFDC2626)),
              if (s.lateSevereDays > 0)
                _AttChip(
                  '${s.lateSevereDays}× Late >10AM',
                  const Color(0xFFEA580C),
                ),
              if (s.lateMildDays > 0)
                _AttChip(
                  '${s.lateMildDays}× Late 9–10AM',
                  const Color(0xFFD97706),
                ),
              if (s.earlySevereDays > 0)
                _AttChip(
                  '${s.earlySevereDays}× Early <5PM',
                  const Color(0xFFEA580C),
                ),
              if (s.earlyMildDays > 0)
                _AttChip(
                  '${s.earlyMildDays}× Early 5–6PM',
                  const Color(0xFFD97706),
                ),
              if (s.underworkedDays > 0)
                _AttChip(
                  '${s.underworkedDays}× <4h work',
                  const Color(0xFF7C3AED),
                ),
            ],
          ),

          // ── Expandable day-by-day breakdown ─────────────────
          if (s.breakdown.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Text(
                    _expanded
                        ? 'Hide day-by-day breakdown'
                        : 'Show day-by-day breakdown',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFEA580C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: const Color(0xFFEA580C),
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              const Divider(color: Color(0xFFFED7AA), height: 1),
              const SizedBox(height: 10),
              ...s.breakdown.map((d) => _BreakdownRow(entry: d)),
            ],
          ],
        ],
      ),
    );
  }
}

class _AttChip extends StatelessWidget {
  final String label;
  final Color color;
  const _AttChip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

class _BreakdownRow extends StatelessWidget {
  final AttendanceDayDeduction entry;
  const _BreakdownRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.type) {
      AttendanceInfractionType.absent => const Color(0xFFDC2626),
      AttendanceInfractionType.lateSevere => const Color(0xFFEA580C),
      AttendanceInfractionType.lateMild => const Color(0xFFD97706),
      AttendanceInfractionType.earlySevere => const Color(0xFFEA580C),
      AttendanceInfractionType.earlyMild => const Color(0xFFD97706),
      AttendanceInfractionType.underworked => const Color(0xFF7C3AED),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            entry.date,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.type.label,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
          Text(
            '-PKR ${entry.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// EXISTING PAYSLIP WIDGETS (unchanged)
// ─────────────────────────────────────────────────────────────

class _PayslipStatusBadge extends StatelessWidget {
  final PayslipStatus status;
  const _PayslipStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      PayslipStatus.draft => (
        'DRAFT',
        const Color(0xFF334155),
        const Color(0xFF94A3B8),
      ),
      PayslipStatus.approved => (
        'APPROVED',
        const Color(0xFF1D4ED8).withValues(alpha: 0.2),
        const Color(0xFF60A5FA),
      ),
      PayslipStatus.paid => (
        'PAID',
        const Color(0xFF065F46).withValues(alpha: 0.3),
        const Color(0xFF34D399),
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
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _SectionTitle(this.text, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    ],
  );
}

class _LineItem extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;
  final bool isDeduction;
  final Color? color;
  const _LineItem(
    this.label,
    this.amount, {
    this.isBold = false,
    this.isDeduction = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? (isDeduction ? kRed : (isBold ? kSlateDark : kSlate));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? kSlateDark : kSlate,
            ),
          ),
          Text(
            '${isDeduction ? '-' : ''}PKR ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceDeductionLine extends StatelessWidget {
  final PayslipModel payslip;
  const _PerformanceDeductionLine({required this.payslip});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kRedSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 14, color: kRed),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Performance Deduction',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kRed,
                    ),
                  ),
                  Text(
                    '${payslip.missedTasks} missed task${payslip.missedTasks == 1 ? '' : 's'} this month',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            '-PKR ${payslip.performanceDeduction.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: kRed,
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceSection extends StatelessWidget {
  final PayslipModel payslip;
  const _PerformanceSection({required this.payslip});

  @override
  Widget build(BuildContext context) {
    final score = payslip.performanceScore;
    Color scoreColor = kRed;
    if (score >= 80) {
      scoreColor = kGreen;
    } else if (score >= 60)
      scoreColor = const Color(0xFFD97706);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBlueSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBlueBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.track_changes_rounded, size: 16, color: kBlue),
              SizedBox(width: 6),
              Text(
                'Performance This Month',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: kBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: scoreColor, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${score.toInt()}%',
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PerfRow('Total tasks', '${payslip.totalTasksInMonth}'),
                    _PerfRow('Completed', '${payslip.completedTasks}', kGreen),
                    _PerfRow(
                      'Missed',
                      '${payslip.missedTasks}',
                      payslip.missedTasks > 0 ? kRed : kSlate,
                    ),
                    _PerfRow('Weekend', '${payslip.weekendTasks}'),
                  ],
                ),
              ),
            ],
          ),
          if (payslip.performanceDeduction > 0 ||
              payslip.performanceBonus > 0) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            if (payslip.performanceDeduction > 0)
              Row(
                children: [
                  const Icon(
                    Icons.remove_circle_rounded,
                    size: 14,
                    color: kRed,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Performance deduction applied',
                    style: TextStyle(fontSize: 12, color: kRed),
                  ),
                  const Spacer(),
                  Text(
                    '-PKR ${payslip.performanceDeduction.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: kRed,
                    ),
                  ),
                ],
              ),
            if (payslip.performanceBonus > 0)
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 14, color: kGreen),
                  const SizedBox(width: 6),
                  const Text(
                    'Performance bonus added',
                    style: TextStyle(fontSize: 12, color: kGreen),
                  ),
                  const Spacer(),
                  Text(
                    '+PKR ${payslip.performanceBonus.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: kGreen,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _PerfRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _PerfRow(this.label, this.value, [this.color]);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 12, color: kSlate)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color ?? kSlateDark,
          ),
        ),
      ],
    ),
  );
}
