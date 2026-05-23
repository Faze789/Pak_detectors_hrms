// lib/screens/attendance/leave_approvals_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../viewmodels/attendance_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';

class LeaveApprovalsScreen extends StatefulWidget {
  const LeaveApprovalsScreen({super.key});

  @override
  State<LeaveApprovalsScreen> createState() => _LeaveApprovalsScreenState();
}

class _LeaveApprovalsScreenState extends State<LeaveApprovalsScreen> {
  String? _myEmpId;

  @override
  void initState() {
    super.initState();
    // Ensure the UI is built before trying to access Providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLeadPortal();
    });
  }

  Future<void> _initLeadPortal() async {
    final authVm = context.read<AuthViewModel>();
    final attendanceVm = context.read<AttendanceViewModel>();
    final uid = authVm.currentUser?.uid;

    if (uid == null) return;

    try {
      // 1. Fetch your user document to get your EMP_ID (EMP_009)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final empId = userDoc.data()?['emp_id']?.toString();

        if (empId != null) {
          // 2. SAVE the ID to state so _handleReview knows who you are
          setState(() {
            _myEmpId = empId;
          });

          // 3. FETCH the requests where leadsNotified contains "EMP_009"
          await attendanceVm.fetchLeaveRequestsForLead(empId);
        }
      }
    } catch (e) {
      debugPrint('Error loading lead portal: $e');
    }
  }

  void _handleReview(
    BuildContext context,
    Map<String, dynamic> request,
    String status,
  ) async {
    if (status == 'declined') {
      final reason = await _showDeclineDialog(context);
      if (reason == null || reason.isEmpty) return; // Cancelled or empty
      _submitReview(context, request, status, reason: reason);
    } else {
      _submitReview(context, request, status);
    }
  }

  Future<void> _submitReview(
    BuildContext context,
    Map<String, dynamic> request,
    String status, {
    String? reason,
  }) async {
    if (_myEmpId == null) return; // Ensure we have the ID

    final vm = context.read<AttendanceViewModel>();

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await vm.reviewLeaveRequest(
      requestId: request['id'],
      employeeUid: request['uid'],
      employeeName: request['name'],
      leadEmpId: _myEmpId!, // Use the cached ID
      newStatus: status,
      rejectionReason: reason,
    );

    if (!context.mounted) return;
    Navigator.pop(context); // close loading

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Request $status successfully' : 'Failed to update request',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<String?> _showDeclineDialog(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Leave'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Enter reason for declining...',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Decline', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    List<Map<String, dynamic>> requests, {
    required bool isPending,
    required String emptyMessage,
  }) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_rounded, size: 64, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final startDate = (req['startDate'] as Timestamp).toDate();
        final endDate = (req['endDate'] as Timestamp).toDate();
        final totalWorkingDays = req['totalDays'] ?? 1;
        final note = req['note'] as String? ?? '';
        final name = req['name'] ?? 'Employee';
        final empId = req['emp_id'] ?? 'Unknown ID';
        final status = req['status'] ?? 'pending';

        return LeaveApprovalCard(
          employeeName: name,
          role: 'Emp ID: $empId',
          startDate: startDate,
          endDate: endDate,
          totalWorkingDays: totalWorkingDays,
          note: note,
          status: status, // Pass status
          isPending: isPending, // Pass flag
          onApprove: () => _handleReview(context, req, 'approved'),
          onDecline: () => _handleReview(context, req, 'declined'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(
          0xFFF1F5F9,
        ), // Light background to make cards pop
        appBar: AppBar(
          title: const Text(
            'Leave Management',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Declined'),
            ],
          ),
        ),
        body: Consumer<AttendanceViewModel>(
          builder: (context, vm, child) {
            if (vm.state == ViewState.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            // Split records by status for filtering
            final pending = vm.pendingLeaveRequests
                .where((req) => req['status'] == 'pending')
                .toList();
            final approved = vm.pendingLeaveRequests
                .where((req) => req['status'] == 'approved')
                .toList();
            final declined = vm.pendingLeaveRequests
                .where((req) => req['status'] == 'declined')
                .toList();

            return TabBarView(
              children: [
                _buildList(
                  pending,
                  isPending: true,
                  emptyMessage: 'No pending leave requests.',
                ),
                _buildList(
                  approved,
                  isPending: false,
                  emptyMessage: 'No approved leaves.',
                ),
                _buildList(
                  declined,
                  isPending: false,
                  emptyMessage: 'No declined leaves.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Leave Approval Card UI
// ══════════════════════════════════════════════════════════════════════════════

class LeaveApprovalCard extends StatelessWidget {
  final String employeeName;
  final String role;
  final DateTime startDate;
  final DateTime endDate;
  final int totalWorkingDays;
  final String note;
  final String status;
  final bool isPending;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  const LeaveApprovalCard({
    super.key,
    required this.employeeName,
    required this.role,
    required this.startDate,
    required this.endDate,
    required this.totalWorkingDays,
    required this.note,
    required this.status,
    required this.isPending,
    required this.onApprove,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy');
    final dateString = startDate.isAtSameMomentAs(endDate)
        ? dateFmt.format(startDate)
        : '${DateFormat('MMM d').format(startDate)} – ${dateFmt.format(endDate)}';

    Color statusColor = status == 'approved'
        ? Colors.green
        : status == 'declined'
        ? Colors.red
        : Colors.orange;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header: Employee Info ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  child: Text(
                    employeeName.isNotEmpty
                        ? employeeName.substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employeeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        role,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                // Dynamic Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Body: Leave Details ────────────────────────────────────────
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.date_range_rounded,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Requested Dates',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateString,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Highlight the calculated working days
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.work_history_rounded,
                                  size: 12,
                                  color: Color(0xFF1D4ED8),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$totalWorkingDays Working Day${totalWorkingDays > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
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
                              size: 14,
                              color: Color(0xFF64748B),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Reason / Note',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          note,
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
              ],
            ),
          ),

          // ─── Footer: Actions ────────────────────────────────────────────
          if (isPending)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDecline,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text(
                        'Decline',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text(
                        'Approve',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
