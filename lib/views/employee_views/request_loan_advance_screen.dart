import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/loan_advance_request.dart';
import '../../services/loan_advance_service.dart';
import '../../viewmodels/auth_viewmodel.dart';

class RequestLoanAdvanceScreen extends StatefulWidget {
  const RequestLoanAdvanceScreen({super.key});

  @override
  State<RequestLoanAdvanceScreen> createState() =>
      _RequestLoanAdvanceScreenState();
}

class _RequestLoanAdvanceScreenState extends State<RequestLoanAdvanceScreen> {
  static const double _loanCap = 70000;

  final _service = LoanAdvanceService();
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  LoanAdvanceKind _kind = LoanAdvanceKind.loan;
  bool _submitting = false;
  bool _loadingProfile = true;
  double _monthlySalary = 0;
  String _empId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) {
      if (mounted) setState(() => _loadingProfile = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};
      if (!mounted) return;
      setState(() {
        _monthlySalary = (data['salary'] as num?)?.toDouble() ?? 0;
        _empId = (data['emp_id'] ?? '').toString();
        _loadingProfile = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  /// Active cap for the current kind. Loan = fixed Rs. 70,000;
  /// Advance = the employee's monthly salary read from `users.salary`.
  double get _activeCap =>
      _kind == LoanAdvanceKind.loan ? _loanCap : _monthlySalary;

  String? _validateAmount(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return 'Enter an amount';
    final n = double.tryParse(raw);
    if (n == null || n <= 0) return 'Enter a valid amount';
    if (_kind == LoanAdvanceKind.advance && _monthlySalary <= 0) {
      return 'Monthly salary not set on your profile — contact HR';
    }
    if (n > _activeCap) {
      return _kind == LoanAdvanceKind.loan
          ? 'Loan cannot exceed Rs. ${_loanCap.toStringAsFixed(0)}'
          : 'Advance cannot exceed your monthly salary (Rs. ${_monthlySalary.toStringAsFixed(0)})';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      await _service.createRequest(
        employeeUid: user.uid,
        employeeEmpId: _empId,
        employeeName: user.name,
        kind: _kind,
        amount: double.parse(_amountCtrl.text.trim()),
        message: _messageCtrl.text.trim(),
      );
      if (!mounted) return;
      _amountCtrl.clear();
      _messageCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request submitted to HR'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Request Loan / Advance',
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
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFormCard(),
                      const SizedBox(height: 24),
                      const Text(
                        'My Requests',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (user != null)
                        _MyRequestsList(uid: user.uid, service: _service),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Request',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            // Kind selector
            Row(
              children: [
                Expanded(child: _kindChip(LoanAdvanceKind.loan)),
                const SizedBox(width: 8),
                Expanded(child: _kindChip(LoanAdvanceKind.advance)),
              ],
            ),
            const SizedBox(height: 14),
            _label('Amount (Rs.)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText:
                    'Up to Rs. ${_activeCap.toStringAsFixed(0)} (${_kind.label})',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFCBD5E1),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              validator: _validateAmount,
            ),
            const SizedBox(height: 6),
            Text(
              _kind == LoanAdvanceKind.loan
                  ? 'Max loan: Rs. ${_loanCap.toStringAsFixed(0)}'
                  : (_monthlySalary > 0
                        ? 'Max advance (your monthly salary): Rs. ${_monthlySalary.toStringAsFixed(0)}'
                        : 'Your monthly salary is not set yet — contact HR'),
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            _label('Reason / Message'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _messageCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Briefly describe why you need this...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFCBD5E1),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Please add a short reason' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                label: Text(
                  _submitting ? 'Submitting...' : 'Submit Request',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kindChip(LoanAdvanceKind kind) {
    final selected = _kind == kind;
    return InkWell(
      onTap: () => setState(() => _kind = kind),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF2563EB)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Center(
          child: Text(
            kind.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Color(0xFF475569),
    ),
  );
}

/// Reusable list of an employee's own loan/advance requests.
/// Also used inside the My Profile screen's Loans tab.
class _MyRequestsList extends StatelessWidget {
  final String uid;
  final LoanAdvanceService service;
  const _MyRequestsList({required this.uid, required this.service});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LoanAdvanceRequest>>(
      stream: service.streamForEmployee(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final list = snap.data ?? const <LoanAdvanceRequest>[];
        if (list.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'No requests yet.',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          );
        }
        return Column(
          children: list.map((r) => LoanAdvanceRequestCard(req: r)).toList(),
        );
      },
    );
  }
}

/// Shared display card — used in the employee list, the profile Loans tab,
/// and the HR management list.
class LoanAdvanceRequestCard extends StatelessWidget {
  final LoanAdvanceRequest req;
  final Widget? trailing;
  const LoanAdvanceRequestCard({super.key, required this.req, this.trailing});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (req.status) {
      LoanAdvanceStatus.pending => (
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
        'Pending',
      ),
      LoanAdvanceStatus.accepted => (
        const Color(0xFFD1FAE5),
        const Color(0xFF065F46),
        'Accepted',
      ),
      LoanAdvanceStatus.rejected => (
        const Color(0xFFFEE2E2),
        const Color(0xFF991B1B),
        'Rejected',
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: req.status == LoanAdvanceStatus.accepted
              ? const Color(0xFFA7F3D0)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  req.kind.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('d MMM yyyy').format(req.createdAt),
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Rs. ${(req.amount ?? 0).toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          if (req.employeeName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${req.employeeName} · ${req.employeeEmpId}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
          if (req.initialMessage.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                req.initialMessage,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF334155),
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (req.responseReason != null &&
              req.responseReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
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
                  const Text(
                    'HR Note',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    req.responseReason!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (trailing != null) ...[const SizedBox(height: 10), trailing!],
        ],
      ),
    );
  }
}

/// Tab body for the My Profile screen showing the employee's accepted
/// loans/advances (the user's spec: visible on the profile once HR accepts).
class MyProfileLoansTab extends StatelessWidget {
  final String userId;
  const MyProfileLoansTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final service = LoanAdvanceService();
    return StreamBuilder<List<LoanAdvanceRequest>>(
      stream: service.streamForEmployee(userId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final accepted = (snap.data ?? const <LoanAdvanceRequest>[])
            .where((r) => r.status == LoanAdvanceStatus.accepted)
            .toList();
        if (accepted.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No accepted loans or advances yet.',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: accepted
              .map((r) => LoanAdvanceRequestCard(req: r))
              .toList(),
        );
      },
    );
  }
}
