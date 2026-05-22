// lib/views/employee_views/my_leave_requests_screen.dart
//
// Employee-facing list of their OWN leave requests from the
// `request_for_leave` collection (the new HR-approval flow).
//
// Streams live so any HR decision shows up the moment it lands. Status
// badge colors match the project palette:
//   • Pending   → yellow / amber
//   • Approved  → green
//   • Declined  → red

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/request_leave_sheet.dart';

class MyLeaveRequestsScreen extends StatelessWidget {
  const MyLeaveRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final uid = auth.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'My Leave Requests',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => showLeavePolicyInstructions(context),
            icon: const Icon(Icons.menu_book_rounded, size: 16),
            label: const Text('Policy'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: uid.isEmpty
          ? const _EmptyMessage(text: 'Sign in to see your leave requests.')
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('request_for_leave')
                  .where('uid', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _EmptyMessage(
                    text: 'Failed to load: ${snap.error}',
                  );
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const _EmptyMessage(
                    text:
                        'No leave requests yet.\nTap "Request Leave" on the attendance screen to send one.',
                  );
                }
                // Sort newest-first by createdAt (in-memory — avoids the
                // composite index the orderBy version would need).
                final sorted = docs.toList()
                  ..sort((a, b) {
                    final at = a.data()['createdAt'];
                    final bt = b.data()['createdAt'];
                    if (at is Timestamp && bt is Timestamp) {
                      return bt.compareTo(at);
                    }
                    return 0;
                  });
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _RequestRow(
                    data: sorted[i].data(),
                    id: sorted[i].id,
                  ),
                );
              },
            ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final String id;
  const _RequestRow({required this.data, required this.id});

  @override
  Widget build(BuildContext context) {
    final start = (data['startDate'] as Timestamp?)?.toDate();
    final end = (data['endDate'] as Timestamp?)?.toDate();
    final status = (data['status'] ?? 'pending').toString();
    final totalDays = (data['totalDays'] as num?)?.toInt() ?? 0;
    final type = (data['leaveTypeLabel'] ?? data['leaveType'] ?? 'Leave').toString();
    final reason = (data['note'] ?? data['reason'] ?? '').toString();
    final rejectionReason = (data['rejectionReason'] ?? '').toString();
    final reviewedBy = (data['reviewedByName'] ?? data['reviewedBy'] ?? '').toString();

    final dateLabel = (start != null && end != null)
        ? (start.year == end.year && start.month == end.month && start.day == end.day
            ? DateFormat('EEE, d MMM yyyy').format(start)
            : '${DateFormat('d MMM').format(start)} → ${DateFormat('d MMM yyyy').format(end)}')
        : '—';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  type,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 12, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                '$dateLabel  ·  $totalDays day${totalDays == 1 ? "" : "s"}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                reason,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (status == 'declined' && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: Color(0xFFB91C1C)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Declined: $rejectionReason',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (reviewedBy.isNotEmpty && status != 'pending') ...[
            const SizedBox(height: 6),
            Text(
              status == 'approved'
                  ? 'Approved by $reviewedBy'
                  : 'Reviewed by $reviewedBy',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label, IconData icon) =
        switch (status.toLowerCase()) {
      'approved' => (
        const Color(0xFFDCFCE7),
        const Color(0xFF15803D),
        'Approved',
        Icons.check_circle_rounded,
      ),
      'declined' || 'rejected' => (
        const Color(0xFFFEE2E2),
        const Color(0xFFB91C1C),
        'Declined',
        Icons.cancel_rounded,
      ),
      _ => (
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
        'Pending',
        Icons.hourglass_top_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  final String text;
  const _EmptyMessage({required this.text});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
      ),
    );
  }
}
