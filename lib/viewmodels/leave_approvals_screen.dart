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

  // Inside _LeaveApprovalsScreenState

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Approvals'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: Consumer<AttendanceViewModel>(
        builder: (context, vm, child) {
          // If you updated isLoading to viewState as discussed earlier,
          // change this to: if (vm.state == ViewState.loading)
          if (vm.state == ViewState.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final pending = vm.pendingLeaveRequests
              .where((req) => req['status'] == 'pending')
              .toList();

          if (pending.isEmpty) {
            return const Center(
              child: Text(
                'No pending leave requests.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pending.length,
            itemBuilder: (context, index) {
              final req = pending[index];
              final startDate = (req['startDate'] as Timestamp).toDate();
              final endDate = (req['endDate'] as Timestamp).toDate();
              final dateStr =
                  '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            req['name'] ?? 'Employee',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Pending',
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Employee ID: ${req['emp_id']}'),
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month,
                            size: 20,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(dateStr, style: const TextStyle(fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.timer, size: 20, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            '${req['totalDays']} Day(s) requested',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _handleReview(context, req, 'declined'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  _handleReview(context, req, 'approved'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
