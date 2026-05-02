import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/leave_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/leave_viewmodel.dart';

/// Screen the project lead opens to review leave requests where they are
/// listed as a required approver. Leads can Approve or Reject — any
/// rejection cancels the entire request.
class LeadLeaveApprovalsScreen extends StatefulWidget {
  const LeadLeaveApprovalsScreen({super.key});

  @override
  State<LeadLeaveApprovalsScreen> createState() =>
      _LeadLeaveApprovalsScreenState();
}

class _LeadLeaveApprovalsScreenState extends State<LeadLeaveApprovalsScreen> {
  String? _empId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = context.read<AuthViewModel>().currentUser;
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      setState(() {
        _empId = (doc.data()?['emp_id'] ?? '').toString();
        _loading = false;
      });
    });
  }

  Future<void> _approve(LeaveModel leave) async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null || _empId == null) return;
    final ok = await context.read<LeaveViewModel>().leadApproveLeave(
          leave: leave,
          leadEmpId: _empId!,
          leadName: user.name,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Approved' : 'Failed'),
      backgroundColor: ok
          ? const Color(0xFF16A34A)
          : const Color(0xFFDC2626),
    ));
  }

  Future<void> _reject(LeaveModel leave) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Leave?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rejecting ${leave.employeeName}\'s ${leave.type.label}. '
              'This cancels the request even if other leads approve.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final reason = ctrl.text.trim();
    if (reason.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reason is required'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null || _empId == null) return;
    final ok = await context.read<LeaveViewModel>().leadRejectLeave(
          leave: leave,
          leadEmpId: _empId!,
          leadName: user.name,
          reason: reason,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Rejected' : 'Failed'),
      backgroundColor: ok
          ? const Color(0xFF16A34A)
          : const Color(0xFFDC2626),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_empId == null || _empId!.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Sign in required')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Leave Approvals',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: StreamBuilder<List<LeaveModel>>(
        stream: context.read<LeaveViewModel>().streamLeavesPendingForLead(_empId!),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_rounded,
                      size: 56, color: Color(0xFFCBD5E1)),
                  SizedBox(height: 12),
                  Text(
                    'No pending leave approvals',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final l = list[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            l.type.label.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l.duration.label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${l.fromDate.day}/${l.fromDate.month} → '
                          '${l.toDate.day}/${l.toDate.month}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${l.employeeName} (${l.emp_id})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.reason,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                    if (l.requiredApproverEmpIds.length > 1) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Requires ${l.requiredApproverEmpIds.length} leads — '
                        '${l.approvals.length} decided',
                        style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _reject(l),
                            icon: const Icon(Icons.close_rounded,
                                size: 14, color: Color(0xFFDC2626)),
                            label: const Text(
                              'Reject',
                              style: TextStyle(
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFDC2626)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approve(l),
                            icon: const Icon(Icons.check_rounded, size: 14),
                            label: const Text(
                              'Approve',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
