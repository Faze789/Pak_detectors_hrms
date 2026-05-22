// lib/screens/attendance/hr_leave_approvals_screen.dart
//
// Full-featured HR leave management screen.
// • Streams live from Firestore — no manual refresh needed.
// • Tabs: Pending / Approved / Declined
// • HR can approve or decline with a required reason for decline.
// • On review, writes a notification doc for the employee.
// • Pending count badge is shown in the tab label.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/leave_request_model.dart';
import '../../viewmodels/attendance_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/leave_policy.dart';

class HRLeaveApprovalsScreen extends StatefulWidget {
  const HRLeaveApprovalsScreen({super.key});

  @override
  State<HRLeaveApprovalsScreen> createState() => _HRLeaveApprovalsScreenState();
}

class _HRLeaveApprovalsScreenState extends State<HRLeaveApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // HR identity — loaded once from Firestore
  String? _hrEmpId;
  String? _hrName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHRIdentity());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHRIdentity() async {
    final uid = context.read<AuthViewModel>().currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _hrEmpId = doc.data()?['emp_id']?.toString();
          _hrName = doc.data()?['name']?.toString() ?? 'HR';
        });
      }
    } catch (e) {
      debugPrint('_loadHRIdentity error: $e');
    }
  }

  // ── Review handler ──────────────────────────────────────────────────────
  Future<void> _handleReview(LeaveRequestModel req, String newStatus) async {
    if (_hrEmpId == null) {
      _showSnack('HR identity not loaded yet. Please wait.', isError: true);
      return;
    }

    String? reason;
    if (newStatus == 'declined') {
      reason = await _showDeclineDialog();
      if (reason == null) return; // user cancelled
    }

    // Show loading overlay
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      ),
    );

    final vm = context.read<AttendanceViewModel>();
    final success = await vm.hrReviewLeaveRequest(
      requestId: req.id,
      employeeUid: req.uid,
      employeeName: req.name,
      hrEmpId: _hrEmpId!,
      hrName: _hrName ?? 'HR',
      newStatus: newStatus,
      rejectionReason: reason,
    );

    if (!mounted) return;
    Navigator.pop(context); // close loading

    _showSnack(
      success
          ? 'Leave request ${newStatus == 'approved' ? 'approved ✓' : 'declined ✗'} — employee notified.'
          : 'Failed to update. Please try again.',
      isError: !success,
    );
  }

  Future<String?> _showDeclineDialog() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.close_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text(
              'Decline Leave Request',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Provide a reason for declining (required):',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. Insufficient leave balance...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 1.5,
                  ),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? const Color(0xFFDC2626)
            : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final vm = context.read<AttendanceViewModel>();

    return StreamBuilder<List<LeaveRequestModel>>(
      stream: vm.streamAllLeaveRequests(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final pending = all.where((r) => r.status == 'pending').toList();
        final approved = all.where((r) => r.status == 'approved').toList();
        final declined = all.where((r) => r.status == 'declined').toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            title: const Text(
              'Leave Management',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (pending.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${pending.length} pending',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Pending'),
                      if (pending.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _TabBadge(count: pending.length),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Approved'),
                      if (approved.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _TabBadge(
                          count: approved.length,
                          color: const Color(0xFF059669),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Declined'),
                      if (declined.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _TabBadge(count: declined.length, color: Colors.orange),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          body:
              snapshot.connectionState == ConnectionState.waiting &&
                  snapshot.data == null
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _LeaveList(
                      requests: pending,
                      isPending: true,
                      emptyMessage: 'No pending requests',
                      emptyIcon: Icons.inbox_rounded,
                      onApprove: (r) => _handleReview(r, 'approved'),
                      onDecline: (r) => _handleReview(r, 'declined'),
                    ),
                    _LeaveList(
                      requests: approved,
                      isPending: false,
                      emptyMessage: 'No approved leaves',
                      emptyIcon: Icons.check_circle_outline_rounded,
                    ),
                    _LeaveList(
                      requests: declined,
                      isPending: false,
                      emptyMessage: 'No declined requests',
                      emptyIcon: Icons.cancel_outlined,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// ── Tab badge ─────────────────────────────────────────────────────────────────
class _TabBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _TabBadge({required this.count, this.color = Colors.red});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$count',
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  );
}

// ── Leave list ────────────────────────────────────────────────────────────────
class _LeaveList extends StatelessWidget {
  final List<LeaveRequestModel> requests;
  final bool isPending;
  final String emptyMessage;
  final IconData emptyIcon;
  final void Function(LeaveRequestModel)? onApprove;
  final void Function(LeaveRequestModel)? onDecline;

  const _LeaveList({
    required this.requests,
    required this.isPending,
    required this.emptyMessage,
    required this.emptyIcon,
    this.onApprove,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 72, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      itemCount: requests.length,
      itemBuilder: (context, i) {
        final req = requests[i];
        return _HRLeaveCard(
          request: req,
          isPending: isPending,
          onApprove: onApprove != null ? () => onApprove!(req) : null,
          onDecline: onDecline != null ? () => onDecline!(req) : null,
        );
      },
    );
  }
}

// ── HR Leave Card ─────────────────────────────────────────────────────────────
class _HRLeaveCard extends StatelessWidget {
  final LeaveRequestModel request;
  final bool isPending;
  final VoidCallback? onApprove;
  final VoidCallback? onDecline;

  const _HRLeaveCard({
    required this.request,
    required this.isPending,
    this.onApprove,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final r = request;
    final dateFmt = DateFormat('MMM d, yyyy');
    final dateStr =
        r.startDate.day == r.endDate.day &&
            r.startDate.month == r.endDate.month &&
            r.startDate.year == r.endDate.year
        ? dateFmt.format(r.startDate)
        : '${DateFormat('MMM d').format(r.startDate)} – ${dateFmt.format(r.endDate)}';

    final Color statusColor;
    final Color statusBg;
    final IconData statusIcon;
    switch (r.status) {
      case 'approved':
        statusColor = const Color(0xFF059669);
        statusBg = const Color(0xFFD1FAE5);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'declined':
        statusColor = const Color(0xFFDC2626);
        statusBg = const Color(0xFFFEE2E2);
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFEF3C7);
        statusIcon = Icons.schedule_rounded;
    }

    // Parse leave type label
    final leaveTypeLabel = RequestLeaveTypeX.parse(r.leaveType).label;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFDBEAFE),
                  child: Text(
                    r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${r.role}  ·  ${r.empId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        r.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Details ──────────────────────────────────────────────────────
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leave type pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF93C5FD)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.label_rounded,
                        size: 12,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        leaveTypeLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Date row
                Row(
                  children: [
                    const Icon(
                      Icons.date_range_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    // Working days chip
                    Container(
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
                            Icons.work_history_rounded,
                            size: 11,
                            color: Color(0xFF1D4ED8),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${r.totalDays} day${r.totalDays > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Note
                if (r.note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.notes_rounded,
                              size: 13,
                              color: Color(0xFF64748B),
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Reason',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          r.note,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Decline reason (if declined)
                if (r.status == 'declined' &&
                    r.rejectionReason != null &&
                    r.rejectionReason!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 13,
                              color: Color(0xFFDC2626),
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Decline Reason',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          r.rejectionReason!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF991B1B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Reviewed by
                if (!isPending && r.reviewedByName != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        size: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reviewed by ${r.reviewedByName}'
                        '${r.reviewedAt != null ? '  ·  ${DateFormat('MMM d, HH:mm').format(r.reviewedAt!)}' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],

                // Submitted at
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: Color(0xFFCBD5E1),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      r.createdAt != null
                          ? 'Submitted ${DateFormat('MMM d, yyyy · HH:mm').format(r.createdAt!)}'
                          : 'Submitted —',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Actions (pending only) ────────────────────────────────────────
          if (isPending)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDecline,
                      icon: const Icon(Icons.close_rounded, size: 17),
                      label: const Text(
                        'Decline',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: const Text(
                        'Approve',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
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
