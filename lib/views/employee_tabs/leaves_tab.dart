import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/leave_model.dart';
import '../../viewmodels/leave_viewmodel.dart';
import '../employee_views/leave_request_dialog.dart';

class LeavesTab extends StatelessWidget {
  final String userId;
  final String employeeName;
  final String employeeRole;
  final bool isHR;

  // ── Leave quotas from employee model ──────────────────────────
  final int annualLeaveQuota;
  final int sickLeaveQuota;
  final int casualLeaveQuota;
  final int unpaidLeaveQuota;

  const LeavesTab({
    super.key,
    required this.userId,
    required this.employeeName,
    required this.employeeRole,
    this.isHR = false,
    this.annualLeaveQuota = 4,
    this.sickLeaveQuota = 3,
    this.casualLeaveQuota = 6,
    this.unpaidLeaveQuota = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaveViewModel>(
      builder: (context, vm, _) {
        final leaves = (isHR ? vm.allLeaves : vm.myLeaves)
            .where((l) => l.userId == userId)
            .toList();

        final usedSick = leaves
            .where(
              (l) =>
                  l.type == LeaveType.sick && l.status == LeaveStatus.approved,
            )
            .fold(0, (s, l) => s + l.days);
        final usedAnnual = leaves
            .where(
              (l) =>
                  l.type == LeaveType.annual &&
                  l.status == LeaveStatus.approved,
            )
            .fold(0, (s, l) => s + l.days);
        final usedCasual = leaves
            .where(
              (l) =>
                  l.type == LeaveType.casual &&
                  l.status == LeaveStatus.approved,
            )
            .fold(0, (s, l) => s + l.days);
        final usedUnpaid = leaves
            .where(
              (l) =>
                  l.type == LeaveType.unpaid &&
                  l.status == LeaveStatus.approved,
            )
            .fold(0, (s, l) => s + l.days);

        final pendingSick = leaves
            .where(
              (l) =>
                  l.type == LeaveType.sick && l.status == LeaveStatus.pending,
            )
            .fold(0, (s, l) => s + l.days);
        final pendingAnnual = leaves
            .where(
              (l) =>
                  l.type == LeaveType.annual && l.status == LeaveStatus.pending,
            )
            .fold(0, (s, l) => s + l.days);
        final pendingCasual = leaves
            .where(
              (l) =>
                  l.type == LeaveType.casual && l.status == LeaveStatus.pending,
            )
            .fold(0, (s, l) => s + l.days);
        final pendingUnpaid = leaves
            .where(
              (l) =>
                  l.type == LeaveType.unpaid && l.status == LeaveStatus.pending,
            )
            .fold(0, (s, l) => s + l.days);

        // ── Use quotas from employee model, not hardcoded ──────────
        final balances = [
          _BalanceData(
            type: 'Annual Leave',
            total: annualLeaveQuota,
            used: usedAnnual,
            pending: pendingAnnual,
            color: const Color(0xFF3B82F6),
          ),
          _BalanceData(
            type: 'Sick Leave',
            total: sickLeaveQuota,
            used: usedSick,
            pending: pendingSick,
            color: const Color(0xFF10B981),
          ),
          _BalanceData(
            type: 'Casual Leave',
            total: casualLeaveQuota,
            used: usedCasual,
            pending: pendingCasual,
            color: const Color(0xFFF59E0B),
          ),
          _BalanceData(
            type: 'Unpaid Leave',
            total: unpaidLeaveQuota,
            used: usedUnpaid,
            pending: pendingUnpaid,
            color: const Color(0xFF8B5CF6),
          ),
        ];

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            if (!isHR) ...[
              ...balances.map((b) => _LeaveBalanceCard(data: b)),
              const SizedBox(height: 4),
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 40,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Need Time Off?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submit a request and get notified when HR responds',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => showLeaveRequestDialog(
                          context,
                          userId: userId,
                          employeeName: employeeName,
                          employeeRole: employeeRole,
                        ),
                        icon: const Icon(Icons.send_outlined, size: 15),
                        label: const Text('Request Leave'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.history_outlined,
                          color: Color(0xFF2563EB),
                          size: 17,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'Leave Request History',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (leaves.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 44,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No leave requests yet',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: leaves
                            .map((l) => _LeaveHistoryTile(leave: l))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        );
      },
    );
  }
}

// ── Balance card ──────────────────────────────────────────────────────────────

class _BalanceData {
  final String type;
  final int total, used, pending;
  final Color color;
  const _BalanceData({
    required this.type,
    required this.total,
    required this.used,
    required this.pending,
    required this.color,
  });
  int get remaining => (total - used - pending).clamp(0, total);
}

class _LeaveBalanceCard extends StatelessWidget {
  final _BalanceData data;
  const _LeaveBalanceCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final pct = data.total > 0 ? (data.used / data.total).clamp(0.0, 1.0) : 0.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: data.color, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.type,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LStat(label: 'Total', value: data.total, color: Colors.black87),
              _LStat(label: 'Used', value: data.used, color: Colors.redAccent),
              _LStat(
                label: 'Pending',
                value: data.pending,
                color: Colors.orange,
              ),
              _LStat(
                label: 'Left',
                value: data.remaining,
                color: data.remaining > 5
                    ? Colors.green
                    : data.remaining > 0
                    ? Colors.orange
                    : Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(data.color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _LStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
      ),
      const SizedBox(height: 3),
      Text(
        '$value',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: color,
        ),
      ),
    ],
  );
}

// ── History tile ──────────────────────────────────────────────────────────────

class _LeaveHistoryTile extends StatelessWidget {
  final LeaveModel leave;
  const _LeaveHistoryTile({required this.leave});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');

    Color statusColor;
    IconData statusIcon;
    switch (leave.status) {
      case LeaveStatus.approved:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case LeaveStatus.rejected:
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.access_time_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leave.type.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${fmt.format(leave.fromDate)}  →  ${fmt.format(leave.toDate)}  (${leave.days}d)',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  'Reason: ${leave.reason}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (leave.hrNote != null && leave.hrNote!.isNotEmpty)
                  Text(
                    'HR: ${leave.hrNote}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  'Submitted: ${fmt.format(leave.submittedAt)}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 11),
                const SizedBox(width: 3),
                Text(
                  leave.status.label,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
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
