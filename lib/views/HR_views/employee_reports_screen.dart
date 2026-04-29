import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../viewmodels/employee_report_viewmodel.dart';

class EmployeeReportsScreen extends StatefulWidget {
  const EmployeeReportsScreen({super.key});

  @override
  State<EmployeeReportsScreen> createState() => _EmployeeReportsScreenState();
}

class _EmployeeReportsScreenState extends State<EmployeeReportsScreen> {
  String _activeFilter = ''; // '' = All
  String _roleFilter = ''; // '' = All, 'lead', 'member'
  String _hrName = '';
  String _hrId = '';

  @override
  void initState() {
    super.initState();
    _loadHrInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeReportViewModel>().loadAllReports();
    });
  }

  Future<void> _loadHrInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!mounted) return;
    setState(() {
      _hrId = user.uid;
      _hrName = doc.data()?['name'] ?? 'HR';
    });
  }

  void _applyFilter(String filter) {
    setState(() => _activeFilter = filter);
    context
        .read<EmployeeReportViewModel>()
        .loadAllReports(filterType: filter.isEmpty ? null : filter);
  }

  void _openPdf(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Employee Reports'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Type Filter Bar ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.filter_list, color: Color(0xFF64748B), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Type:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),
                _buildFilterChip('', 'All'),
                const SizedBox(width: 6),
                _buildFilterChip('daily', 'Daily'),
                const SizedBox(width: 6),
                _buildFilterChip('weekly', 'Weekly'),
                const SizedBox(width: 6),
                _buildFilterChip('monthly', 'Monthly'),
              ],
            ),
          ),

          // ── Role Filter Bar ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.people_outline, color: Color(0xFF64748B), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Role:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),
                _buildRoleChip('', 'All Employees'),
                const SizedBox(width: 6),
                _buildRoleChip('lead', 'Project Leads'),
                const SizedBox(width: 6),
                _buildRoleChip('member', 'Team Members'),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Reports List ──────────────────────────────────────────────
          Expanded(
            child: Consumer<EmployeeReportViewModel>(
              builder: (context, vm, _) {
                if (vm.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Apply role filter client-side
                final filtered = _roleFilter.isEmpty
                    ? vm.reports
                    : vm.reports.where((r) {
                        final role = (r['employeeRole'] ?? '').toString().toLowerCase();
                        if (_roleFilter == 'lead') {
                          return role.contains('project lead');
                        } else {
                          return !role.contains('project lead');
                        }
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No reports found',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _buildReportCard(filtered[index]),
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
      onTap: () => _applyFilter(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String value, String label) {
    final isActive = _roleFilter == value;
    final color = value == 'lead'
        ? const Color(0xFFF59E0B)
        : value == 'member'
            ? const Color(0xFF10B981)
            : const Color(0xFF64748B);
    final activeColor = value.isEmpty ? const Color(0xFF2563EB) : color;

    return GestureDetector(
      onTap: () => setState(() => _roleFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final reportId = (report['id'] ?? '').toString();
    final employeeName = (report['employeeName'] ?? '').toString();
    final employeeRole = (report['employeeRole'] ?? '').toString();
    final department = (report['department'] ?? '').toString();
    final type = (report['reportType'] ?? '').toString();
    final text = (report['reportText'] ?? '').toString();
    final status = (report['status'] ?? '').toString();
    final pdfUrl = (report['pdfUrl'] ?? '').toString();
    final pdfName = (report['pdfName'] ?? '').toString();
    final hrRemarks = (report['hrRemarks'] ?? '').toString();
    final hrRating = (report['hrRating'] ?? 0) as num;
    final assessedByName = (report['assessedByName'] ?? '').toString();
    final leadRemarks = (report['leadRemarks'] ?? '').toString();
    final leadRating = (report['leadRating'] ?? 0) as num;
    final assessedByLeadName = (report['assessedByLeadName'] ?? '').toString();
    final submittedAt = report['submittedAt'] as Timestamp?;
    final isLeadAssessed = status == 'lead_assessed' || status == 'assessed';
    final isAssessed = status == 'assessed';

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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: typeColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: employee name + type + status
            Row(
              children: [
                // Avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    employeeName.isNotEmpty ? employeeName[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: typeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              employeeName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (employeeRole.toLowerCase().contains('project lead')) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Lead',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (department.isNotEmpty)
                        Text(
                          department,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                    ],
                  ),
                ),
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, size: 13, color: typeColor),
                      const SizedBox(width: 4),
                      Text(
                        '${type[0].toUpperCase()}${type.substring(1)}',
                        style: TextStyle(
                          fontSize: 11,
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAssessed
                        ? const Color(0xFFD1FAE5)
                        : isLeadAssessed
                            ? const Color(0xFFDBEAFE)
                            : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAssessed
                        ? 'Assessed'
                        : isLeadAssessed
                            ? 'Lead Assessed'
                            : 'Pending',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isAssessed
                          ? const Color(0xFF059669)
                          : isLeadAssessed
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Submitted date
            if (submittedAt != null)
              Text(
                'Submitted: ${DateFormat.yMMMd().add_jm().format(submittedAt.toDate())}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            const SizedBox(height: 8),

            // Report text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                text,
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.5),
              ),
            ),

            // PDF
            if (pdfUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _openPdf(pdfUrl),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Color(0xFFEA580C), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        pdfName.isNotEmpty ? pdfName : 'View PDF',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFEA580C)),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Lead Assessment display
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
                        const Icon(Icons.rate_review, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Text(
                          'Lead Assessment by $assessedByLeadName',
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
                          i < leadRating.toInt() ? Icons.star : Icons.star_border,
                          color: const Color(0xFFF59E0B),
                          size: 18,
                        );
                      }),
                    ),
                    if (leadRemarks.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        leadRemarks,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // HR Assessment display (if already assessed)
            if (isAssessed) ...[
              const SizedBox(height: 12),
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
                        const Icon(Icons.check_circle, size: 16, color: Color(0xFF059669)),
                        const SizedBox(width: 6),
                        Text(
                          'Assessed by $assessedByName',
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
                          i < hrRating.toInt() ? Icons.star : Icons.star_border,
                          color: const Color(0xFFF59E0B),
                          size: 18,
                        );
                      }),
                    ),
                    if (hrRemarks.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        hrRemarks,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Assess Button (if not yet assessed)
            if (!isAssessed) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAssessDialog(reportId, employeeName),
                  icon: const Icon(Icons.rate_review, size: 18),
                  label: const Text('Assess & Provide Remarks'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Assess Dialog ──────────────────────────────────────────────────────────

  void _showAssessDialog(String reportId, String employeeName) {
    int selectedRating = 0;
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.rate_review, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Assess Report - $employeeName',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rating
                const Text(
                  'Rating',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final starNum = i + 1;
                    return GestureDetector(
                      onTap: () => setSt(() => selectedRating = starNum),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          starNum <= selectedRating ? Icons.star : Icons.star_border,
                          color: const Color(0xFFF59E0B),
                          size: 36,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // Remarks
                const Text(
                  'Remarks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: remarksController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Enter your feedback...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedRating == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a rating')),
                  );
                  return;
                }
                if (remarksController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter remarks')),
                  );
                  return;
                }

                Navigator.pop(ctx);

                final vm = context.read<EmployeeReportViewModel>();
                final success = await vm.assessReport(
                  reportId: reportId,
                  assessedBy: _hrId,
                  assessedByName: _hrName,
                  remarks: remarksController.text.trim(),
                  rating: selectedRating,
                );

                if (success && mounted) {
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
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Submit Assessment'),
            ),
          ],
        ),
      ),
    );
  }
}
