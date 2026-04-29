import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../viewmodels/employee_report_viewmodel.dart';

class TeamReportsScreen extends StatefulWidget {
  const TeamReportsScreen({super.key});

  @override
  State<TeamReportsScreen> createState() => _TeamReportsScreenState();
}

class _TeamReportsScreenState extends State<TeamReportsScreen> {
  String _leadId = '';
  String _leadName = '';
  String _leadDept = '';
  bool _loadingUser = true;

  String _activeFilter = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;
    setState(() {
      _leadId = user.uid;
      _leadName = doc.data()?['name'] ?? '';
      _leadDept = doc.data()?['department'] ?? '';
      _loadingUser = false;
    });

    _loadReports();
  }

  void _loadReports() {
    context.read<EmployeeReportViewModel>().loadReportsForLead(
          leadId: _leadId,
          department: _leadDept,
          filterType: _activeFilter.isNotEmpty ? _activeFilter : null,
        );
  }

  void _setFilter(String filter) {
    setState(() => _activeFilter = filter);
    _loadReports();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUser) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Team Reports'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                _buildFilterChip('', 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('daily', 'Daily'),
                const SizedBox(width: 8),
                _buildFilterChip('weekly', 'Weekly'),
                const SizedBox(width: 8),
                _buildFilterChip('monthly', 'Monthly'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Reports list
          Expanded(
            child: Consumer<EmployeeReportViewModel>(
              builder: (context, vm, _) {
                if (vm.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (vm.errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Color(0xFFEF4444)),
                        const SizedBox(height: 12),
                        Text(vm.errorMessage!,
                            style: const TextStyle(color: Color(0xFFEF4444))),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadReports,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (vm.reports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No team reports found',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadReports(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: vm.reports.length,
                    itemBuilder: (context, index) =>
                        _buildReportCard(vm.reports[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isActive = _activeFilter == value;
    return GestureDetector(
      onTap: () => _setFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFF2563EB)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final type = (report['reportType'] ?? '').toString();
    final text = (report['reportText'] ?? '').toString();
    final status = (report['status'] ?? '').toString();
    final pdfUrl = (report['pdfUrl'] ?? '').toString();
    final pdfName = (report['pdfName'] ?? '').toString();
    final employeeName = (report['employeeName'] ?? '').toString();
    final submittedAt = report['submittedAt'] as Timestamp?;

    // Lead assessment fields
    final leadRemarks = (report['leadRemarks'] ?? '').toString();
    final leadRating = (report['leadRating'] ?? 0) as num;
    final assessedByLeadName =
        (report['assessedByLeadName'] ?? '').toString();

    // HR assessment fields
    final hrRemarks = (report['hrRemarks'] ?? '').toString();
    final hrRating = (report['hrRating'] ?? 0) as num;
    final assessedByName = (report['assessedByName'] ?? '').toString();

    final isLeadAssessed =
        status == 'lead_assessed' || status == 'assessed';
    final isHrAssessed = status == 'assessed';

    Color typeColor;
    IconData typeIcon;
    switch (type) {
      case 'daily':
        typeColor = const Color(0xFF2563EB);
        typeIcon = Icons.today;
        break;
      case 'weekly':
        typeColor = const Color(0xFF7C3AED);
        typeIcon = Icons.date_range;
        break;
      case 'monthly':
        typeColor = const Color(0xFFEA580C);
        typeIcon = Icons.calendar_month;
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.description;
    }

    Color statusColor;
    String statusLabel;
    if (isHrAssessed) {
      statusColor = const Color(0xFF059669);
      statusLabel = 'HR Assessed';
    } else if (isLeadAssessed) {
      statusColor = const Color(0xFF2563EB);
      statusLabel = 'Assessed';
    } else {
      statusColor = const Color(0xFFD97706);
      statusLabel = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: typeColor, width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 6),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Employee name
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_outline,
                      size: 16, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employeeName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (submittedAt != null)
                        Text(
                          DateFormat.yMMMd()
                              .add_jm()
                              .format(submittedAt.toDate()),
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                    ],
                  ),
                ),
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, size: 14, color: typeColor),
                      const SizedBox(width: 4),
                      Text(
                        '${type[0].toUpperCase()}${type.substring(1)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Report text
            Text(
              text,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF334155), height: 1.5),
            ),

            // PDF
            if (pdfUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => launchUrl(Uri.parse(pdfUrl),
                    mode: LaunchMode.externalApplication),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.picture_as_pdf,
                          color: Color(0xFFEA580C), size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          pdfName.isNotEmpty ? pdfName : 'View PDF',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFFEA580C)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Lead assessment section (already assessed)
            if (isLeadAssessed && leadRemarks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.rate_review,
                            size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Text(
                          'Your Assessment${assessedByLeadName.isNotEmpty ? ' ($assessedByLeadName)' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < leadRating.toInt()
                              ? Icons.star
                              : Icons.star_border,
                          color: const Color(0xFFF59E0B),
                          size: 18,
                        );
                      }),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      leadRemarks,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                          height: 1.4),
                    ),
                  ],
                ),
              ),
            ],

            // HR assessment section
            if (isHrAssessed && hrRemarks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified,
                            size: 16, color: Color(0xFF059669)),
                        const SizedBox(width: 6),
                        Text(
                          'HR Assessment${assessedByName.isNotEmpty ? ' by $assessedByName' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < hrRating.toInt()
                              ? Icons.star
                              : Icons.star_border,
                          color: const Color(0xFFF59E0B),
                          size: 18,
                        );
                      }),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hrRemarks,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                          height: 1.4),
                    ),
                  ],
                ),
              ),
            ],

            // Assess button (only if not yet assessed by lead)
            if (!isLeadAssessed) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAssessDialog(report),
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: const Text('Assess & Provide Feedback'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAssessDialog(Map<String, dynamic> report) {
    int rating = 3;
    final remarksCtrl = TextEditingController();
    final reportId = report['id'] as String;
    final employeeName = (report['employeeName'] ?? '').toString();
    final reportType = (report['reportType'] ?? '').toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.rate_review,
                  color: Color(0xFF2563EB), size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Assess Report',
                    style: TextStyle(fontSize: 17)),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Employee: $employeeName',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                const Text('Rating',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return IconButton(
                      icon: Icon(
                        i < rating ? Icons.star : Icons.star_border,
                        color: const Color(0xFFF59E0B),
                        size: 32,
                      ),
                      onPressed: () =>
                          setDlgState(() => rating = i + 1),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                const Text('Remarks / Feedback',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: remarksCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Enter your feedback...',
                    hintStyle:
                        const TextStyle(color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (remarksCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter remarks')),
                  );
                  return;
                }
                Navigator.pop(ctx);

                final vm =
                    context.read<EmployeeReportViewModel>();
                final ok = await vm.leadAssessReport(
                  reportId: reportId,
                  leadId: _leadId,
                  leadName: _leadName,
                  remarks: remarksCtrl.text.trim(),
                  rating: rating,
                  employeeName: employeeName,
                  reportType: reportType,
                );

                if (ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report assessed successfully!'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Submit Assessment'),
            ),
          ],
        ),
      ),
    );
  }
}
