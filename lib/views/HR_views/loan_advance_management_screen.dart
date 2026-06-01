import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/loan_advance_request.dart';
import '../../services/loan_advance_service.dart';
import '../employee_views/request_loan_advance_screen.dart' show LoanAdvanceRequestCard;

class LoanAdvanceManagementScreen extends StatefulWidget {
  const LoanAdvanceManagementScreen({super.key});

  @override
  State<LoanAdvanceManagementScreen> createState() =>
      _LoanAdvanceManagementScreenState();
}

class _LoanAdvanceManagementScreenState
    extends State<LoanAdvanceManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = LoanAdvanceService();
  String _hrEmpId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHrId());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHrId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!mounted) return;
    setState(() {
      _hrEmpId = (doc.data()?['emp_id'] ?? user.uid).toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Loan & Advance Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Accepted'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(LoanAdvanceStatus.pending),
          _buildList(LoanAdvanceStatus.accepted),
          _buildList(LoanAdvanceStatus.rejected),
        ],
      ),
    );
  }

  Widget _buildList(LoanAdvanceStatus status) {
    return StreamBuilder<List<LoanAdvanceRequest>>(
      stream: _service.streamAll(status: status),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? const <LoanAdvanceRequest>[];
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No ${status.label.toLowerCase()} requests.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: list
              .map(
                (r) => LoanAdvanceRequestCard(
                  req: r,
                  trailing: status == LoanAdvanceStatus.pending
                      ? _pendingActions(r)
                      : null,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _pendingActions(LoanAdvanceRequest r) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _decide(r, accept: true),
            icon: const Icon(
              Icons.check_circle_outline,
              size: 16,
              color: Colors.white,
            ),
            label: const Text(
              'Accept',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _decide(r, accept: false),
            icon: const Icon(
              Icons.cancel_outlined,
              size: 16,
              color: Colors.white,
            ),
            label: const Text(
              'Reject',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _decide(LoanAdvanceRequest r, {required bool accept}) async {
    String? reason;
    if (!accept) {
      reason = await _promptRejectReason();
      if (reason == null) return;
    }
    try {
      await _service.updateStatus(
        requestId: r.id,
        status: accept
            ? LoanAdvanceStatus.accepted
            : LoanAdvanceStatus.rejected,
        hrEmpId: _hrEmpId,
        employeeEmpId: r.employeeEmpId,
        kind: r.kind,
        amount: r.amount ?? 0,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'Request accepted' : 'Request rejected',
          ),
          backgroundColor: accept
              ? const Color(0xFF16A34A)
              : const Color(0xFFDC2626),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<String?> _promptRejectReason() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject request'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Reason for rejecting this request...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isEmpty) return;
              Navigator.of(ctx).pop(v);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    return reason;
  }
}
