// lib/views/HR_views/hr_leave_screen.dart
// Matches the React LeaveScreen: stats cards + filter bar + scrollable table

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/leave_model.dart';
import '../../viewmodels/leave_viewmodel.dart';

class HRLeaveScreen extends StatefulWidget {
  const HRLeaveScreen({super.key});

  @override
  State<HRLeaveScreen> createState() => _HRLeaveScreenState();
}

class _HRLeaveScreenState extends State<HRLeaveScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _typeFilter = 'all';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaveViewModel>().initForHR();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<LeaveModel> _filtered(List<LeaveModel> all) {
    return all.where((l) {
      final matchSearch =
          _search.isEmpty ||
          l.employeeName.toLowerCase().contains(_search.toLowerCase());
      final matchType = _typeFilter == 'all' || l.type.value == _typeFilter;
      final matchStatus =
          _statusFilter == 'all' || l.status.value == _statusFilter;
      return matchSearch && matchType && matchStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaveViewModel>(
      builder: (context, vm, _) {
        final leaves = _filtered(vm.allLeaves);
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildStats(vm),
                const SizedBox(height: 20),
                _buildFilterBar(),
                const SizedBox(height: 20),
                _buildTable(leaves, vm),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'LEAVES',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 1.4,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Leave Management',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Review, filter and approve employee leave requests.',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
      ),
    ],
  );

  // ── Stats cards (4 across like React) ────────────────────────────────────

  Widget _buildStats(LeaveViewModel vm) {
    final cards = [
      _StatData(
        'Total Leaves',
        vm.totalLeaves,
        Icons.calendar_month_outlined,
        const Color(0xFF1E293B),
        Colors.white,
      ),
      _StatData(
        'Approved',
        vm.approvedLeaves,
        Icons.check_circle_outline,
        const Color(0xFFD1FAE5),
        const Color(0xFF059669),
      ),
      _StatData(
        'Pending',
        vm.pendingLeaves,
        Icons.access_time_outlined,
        const Color(0xFFFEF3C7),
        const Color(0xFFD97706),
      ),
      _StatData(
        'Rejected',
        vm.rejectedLeaves,
        Icons.cancel_outlined,
        const Color(0xFFFEE2E2),
        const Color(0xFFDC2626),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // 2 columns on narrow, 4 on wide
        final crossCount = constraints.maxWidth > 700 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 20,
          childAspectRatio: 1.5,
          children: cards.map((c) => _StatCard(data: c)).toList(),
        );
      },
    );
  }

  // ── Filter bar ────────────────────────────────────────────────────────────

  Widget _buildFilterBar() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6),
      ],
    ),
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Search
        SizedBox(
          width: 240,
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search employee...',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFFCBD5E1),
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Color(0xFF94A3B8),
                size: 16,
              ),
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
                borderSide: const BorderSide(color: Color(0xFF2563EB)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
          ),
        ),

        // Leave type dropdown
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<String>(
            initialValue: _typeFilter,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
            decoration: _dropDeco(),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Types')),
              DropdownMenuItem(value: 'sick', child: Text('Sick Leave')),
              DropdownMenuItem(value: 'annual', child: Text('Annual Leave')),
              DropdownMenuItem(value: 'casual', child: Text('Casual Leave')),
              DropdownMenuItem(value: 'unpaid', child: Text('Unpaid Leave')),
            ],
            onChanged: (v) => setState(() => _typeFilter = v ?? 'all'),
          ),
        ),

        // Status dropdown
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<String>(
            initialValue: _statusFilter,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
            decoration: _dropDeco(),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Status')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'approved', child: Text('Approved')),
              DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
          ),
        ),
      ],
    ),
  );

  InputDecoration _dropDeco() => InputDecoration(
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
      borderSide: const BorderSide(color: Color(0xFF2563EB)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    isDense: true,
  );

  // ── Table ─────────────────────────────────────────────────────────────────

  Widget _buildTable(List<LeaveModel> leaves, LeaveViewModel vm) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: const Text(
              'Leave Requests',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),

          // Scrollable table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 48,
              ),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF8FAFC),
                ),
                headingTextStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.6,
                ),
                dataTextStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                ),
                columnSpacing: 20,
                horizontalMargin: 16,
                dividerThickness: 1,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 52,
                columns: const [
                  DataColumn(label: Text('EMPLOYEE')),
                  DataColumn(label: Text('ROLE')),
                  DataColumn(label: Text('EMP ID')),
                  DataColumn(label: Text('TYPE')),
                  DataColumn(label: Text('FROM')),
                  DataColumn(label: Text('TO')),
                  DataColumn(label: Text('DAYS'), numeric: true),
                  DataColumn(label: Text('REASON')),
                  DataColumn(label: Text('STATUS / ACTIONS')),
                ],
                rows: leaves.isEmpty
                    ? [
                        DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: MediaQuery.of(context).size.width - 80,
                                child: const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Text(
                                      'No leave requests match your filters.',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                          ],
                        ),
                      ]
                    : leaves.map((l) => _buildRow(l, vm)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(LeaveModel l, LeaveViewModel vm) {
    final fmt = DateFormat('dd MMM yyyy');
    return DataRow(
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFFF8FAFC);
        }
        return Colors.white;
      }),
      cells: [
        // Employee
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEFF6FF),
                ),
                alignment: Alignment.center,
                child: Text(
                  l.employeeName.isNotEmpty
                      ? l.employeeName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l.employeeName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),

        // Role
        DataCell(
          Text(
            l.employeeRole,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
        ),

        DataCell(
          Text(l.emp_id, style: const TextStyle(color: Color(0xFF64748B))),
        ),

        // Type
        DataCell(Text(l.type.label)),

        // From
        DataCell(Text(fmt.format(l.fromDate))),

        // To
        DataCell(Text(fmt.format(l.toDate))),

        // Days
        DataCell(
          Text(
            '${l.days}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),

        // Reason
        DataCell(
          SizedBox(
            width: 140,
            child: Text(l.reason, overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
        ),

        // Status + actions
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusBadge(status: l.status),
              if (l.status == LeaveStatus.pending) ...[
                const SizedBox(width: 8),
                _ActionButton(
                  label: 'Approve',
                  color: const Color(0xFF065F46),
                  bg: const Color(0xFF059669),
                  onTap: () => _confirmApprove(l, vm),
                ),
                const SizedBox(width: 6),
                _ActionButton(
                  label: 'Reject',
                  color: Colors.white,
                  bg: const Color(0xFFDC2626),
                  onTap: () => _showRejectDialog(l, vm),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _confirmApprove(LeaveModel leave, LeaveViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Approve Leave',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Approve ${leave.employeeName}\'s ${leave.type.label}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              vm.approveLeave(leave);
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(LeaveModel leave, LeaveViewModel vm) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Reject Leave',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reject ${leave.employeeName}\'s ${leave.type.label}?',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Reason for rejection (optional)',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFCBD5E1),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(10),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              vm.rejectLeave(leave, note: noteCtrl.text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _StatData {
  final String label;
  final int value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  const _StatData(
    this.label,
    this.value,
    this.icon,
    this.iconBg,
    this.iconColor,
  );
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: data.iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(data.icon, color: data.iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              data.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '${data.value}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  final LeaveStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg, border;
    IconData icon;
    String label;

    switch (status) {
      case LeaveStatus.approved:
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF065F46);
        border = const Color(0xFFA7F3D0);
        icon = Icons.check_circle_outline;
        label = 'Approved';
        break;
      case LeaveStatus.rejected:
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        border = const Color(0xFFFCA5A5);
        icon = Icons.cancel_outlined;
        label = 'Rejected';
        break;
      default:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFF92400E);
        border = const Color(0xFFFCD34D);
        icon = Icons.access_time_outlined;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
