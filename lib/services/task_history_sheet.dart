import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TaskHistorySheet extends StatefulWidget {
  final Map<String, dynamic> task;
  final String currentEmpId;
  final bool isLead;

  const TaskHistorySheet({
    super.key,
    required this.task,
    required this.currentEmpId,
    required this.isLead,
  });

  @override
  State<TaskHistorySheet> createState() => _TaskHistorySheetState();
}

class _TaskHistorySheetState extends State<TaskHistorySheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _weeklyDocs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final taskId = widget.task['id'] as String;
      final snap = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .collection('weekly_assignments')
          .get();

      final docs = snap.docs.map((d) {
        final data = d.data();
        data['docId'] = d.id;
        return data;
      }).toList();

      // Sort by weekNumber then empId
      docs.sort((a, b) {
        final wA = (a['weekNumber'] ?? 0) as int;
        final wB = (b['weekNumber'] ?? 0) as int;
        if (wA != wB) return wA.compareTo(wB);
        return (a['empId'] ?? '').toString().compareTo(
          (b['empId'] ?? '').toString(),
        );
      });

      // If member, filter to only their docs
      if (!widget.isLead) {
        final lowerEmpId = widget.currentEmpId.toLowerCase();
        _weeklyDocs = docs.where((d) {
          return (d['empId'] ?? '').toString().toLowerCase() == lowerEmpId;
        }).toList();
      } else {
        _weeklyDocs = docs;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
        maxWidth: sw >= 768 ? 720 : double.infinity,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Task History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      widget.task['title'] ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error: $_error',
            style: const TextStyle(color: Colors.red, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_weeklyDocs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFCBD5E1)),
              SizedBox(height: 12),
              Text(
                'No history available yet',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Week assignments will appear here once the lead assigns work',
                style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Group by weekNumber for cleaner display
    final Map<int, List<Map<String, dynamic>>> grouped = {};
    for (final doc in _weeklyDocs) {
      final week = (doc['weekNumber'] ?? 0) as int;
      grouped.putIfAbsent(week, () => []).add(doc);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        return _buildWeekSection(entry.key, entry.value);
      }).toList(),
    );
  }

  Widget _buildWeekSection(int weekNumber, List<Map<String, dynamic>> docs) {
    final totalWeeks = (widget.task['totalWeeks'] ?? 0) as int;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Week header
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Week $weekNumber of $totalWeeks',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        ...docs.map((doc) => _buildMemberWeekCard(doc)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMemberWeekCard(Map<String, dynamic> doc) {
    final memberName = (doc['memberName'] ?? 'Unknown').toString();
    final empId = (doc['empId'] ?? '').toString();
    final instruction = (doc['instruction'] ?? '').toString();
    final docStatus = (doc['status'] ?? 'pending').toString();
    final attempts = (doc['attempts'] as List?) ?? [];
    final startDate = doc['startDate'] as Timestamp?;
    final endDate = doc['endDate'] as Timestamp?;

    Color statusColor;
    Color statusBg;
    String statusLabel;
    switch (docStatus) {
      case 'accepted':
        statusColor = const Color(0xFF065F46);
        statusBg = const Color(0xFFD1FAE5);
        statusLabel = 'Accepted';
        break;
      case 'submitted':
        statusColor = const Color(0xFF1E40AF);
        statusBg = const Color(0xFFDBEAFE);
        statusLabel = 'Submitted';
        break;
      case 'rejected':
        statusColor = const Color(0xFF991B1B);
        statusBg = const Color(0xFFFEE2E2);
        statusLabel = 'Rejected';
        break;
      case 'barrier':
        statusColor = const Color(0xFF92400E);
        statusBg = const Color(0xFFFEF3C7);
        statusLabel = 'Barrier';
        break;
      default:
        statusColor = const Color(0xFF64748B);
        statusBg = const Color(0xFFF1F5F9);
        statusLabel = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFDBEAFE),
                  child: Text(
                    memberName.isNotEmpty ? memberName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memberName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        empId.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date range
                if (startDate != null || endDate != null) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.date_range_outlined,
                        size: 13,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_fmtDate(startDate)} → ${_fmtDate(endDate)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Instruction block
                if (instruction.isNotEmpty) ...[
                  const Text(
                    'ASSIGNED INSTRUCTION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      instruction,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E3A5F),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Attempts
                if (attempts.isNotEmpty) ...[
                  Text(
                    'SUBMISSIONS (${attempts.length})',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...attempts.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final attempt = entry.value as Map<String, dynamic>;
                    return _buildAttemptTile(idx + 1, attempt);
                  }),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.hourglass_empty,
                          size: 14,
                          color: Color(0xFF92400E),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'No submissions yet',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttemptTile(int number, Map<String, dynamic> attempt) {
    final text = (attempt['text'] ?? '').toString();
    final status = (attempt['status'] ?? '').toString();
    final submittedAt = attempt['submittedAt'] as Timestamp?;
    final reviewedAt = attempt['reviewedAt'] as Timestamp?;
    final rejectReason = (attempt['rejectReason'] ?? '').toString();
    final attachments = (attempt['attachments'] as List?) ?? [];

    Color attemptBorder;
    Color attemptBg;
    IconData attemptIcon;
    Color attemptIconColor;

    switch (status) {
      case 'accepted':
        attemptBorder = const Color(0xFFA7F3D0);
        attemptBg = const Color(0xFFF0FDF4);
        attemptIcon = Icons.check_circle_outline;
        attemptIconColor = const Color(0xFF059669);
        break;
      case 'rejected':
        attemptBorder = const Color(0xFFFECACA);
        attemptBg = const Color(0xFFFEF2F2);
        attemptIcon = Icons.cancel_outlined;
        attemptIconColor = const Color(0xFFDC2626);
        break;
      default:
        attemptBorder = const Color(0xFFBFDBFE);
        attemptBg = const Color(0xFFEFF6FF);
        attemptIcon = Icons.upload_file_outlined;
        attemptIconColor = const Color(0xFF2563EB);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: attemptBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: attemptBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(attemptIcon, size: 14, color: attemptIconColor),
              const SizedBox(width: 6),
              Text(
                'Attempt $number',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: attemptIconColor,
                ),
              ),
              const Spacer(),
              if (submittedAt != null)
                Text(
                  _fmtDateTime(submittedAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF334155),
                height: 1.4,
              ),
            ),
          ],
          // PDF attachments
          for (final att in attachments) ...[
            const SizedBox(height: 6),
            if (att is Map && (att['url'] ?? '').toString().isNotEmpty)
              GestureDetector(
                onTap: () async {
                  final url = att['url'].toString();
                  try {
                    await launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (_) {}
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.picture_as_pdf,
                        size: 14,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        (att['name'] ?? 'View PDF').toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          // Review info
          if (reviewedAt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  status == 'accepted'
                      ? Icons.verified_outlined
                      : Icons.rate_review_outlined,
                  size: 12,
                  color: const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 4),
                Text(
                  'Reviewed ${_fmtDateTime(reviewedAt)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
          if (rejectReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                'Rejection reason: $rejectReason',
                style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDate(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    return '${d.day}/${d.month}/${d.year}';
  }

  String _fmtDateTime(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $h:$m';
  }
}
