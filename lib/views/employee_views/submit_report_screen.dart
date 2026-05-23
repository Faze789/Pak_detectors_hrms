import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../viewmodels/employee_report_viewmodel.dart';

class SubmitReportScreen extends StatefulWidget {
  const SubmitReportScreen({super.key});

  @override
  State<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends State<SubmitReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Employee info
  String _empName = '';
  String _empRole = '';
  String _empDept = '';
  String _empId = '';
  bool _loadingUser = true;

  // Submit form state
  String _selectedType = 'daily';
  final _reportTextController = TextEditingController();
  PlatformFile? _pickedPdf;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      _empId = user.uid;
      _empName = doc.data()?['name'] ?? user.displayName ?? '';
      _empRole = doc.data()?['role'] ?? '';
      _empDept = doc.data()?['department'] ?? '';
      _loadingUser = false;
    });

    // Load employee's submitted reports
    context.read<EmployeeReportViewModel>().loadReportsForEmployee(_empId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reportTextController.dispose();
    super.dispose();
  }

  // ─── PDF Picker ─────────────────────────────────────────────────────────────

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedPdf = result.files.first);
    }
  }

  Future<String?> _uploadPdf(PlatformFile file) async {
    final ref = FirebaseStorage.instance.ref(
      'employee_report_pdfs/${DateTime.now().millisecondsSinceEpoch}_${file.name}',
    );

    if (file.bytes != null) {
      await ref.putData(file.bytes!);
    } else if (!kIsWeb && file.path != null) {
      await ref.putFile(File(file.path!));
    } else {
      return null;
    }

    return await ref.getDownloadURL();
  }

  // ─── Submit Report ──────────────────────────────────────────────────────────

  Future<void> _submitReport() async {
    final text = _reportTextController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter report details')),
      );
      return;
    }

    setState(() => _isUploading = true);

    String? pdfUrl;
    String? pdfName;

    if (_pickedPdf != null) {
      pdfUrl = await _uploadPdf(_pickedPdf!);
      pdfName = _pickedPdf!.name;
    }

    final vm = context.read<EmployeeReportViewModel>();
    final success = await vm.submitReport(
      employeeId: _empId,
      employeeName: _empName,
      employeeRole: _empRole,
      department: _empDept,
      reportType: _selectedType,
      reportText: text,
      pdfUrl: pdfUrl,
      pdfName: pdfName,
    );

    setState(() => _isUploading = false);

    if (success && mounted) {
      _reportTextController.clear();
      setState(() => _pickedPdf = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      // Refresh history and switch to history tab
      vm.loadReportsForEmployee(_empId);
      _tabController.animateTo(1);
    }
  }

  // ─── Open PDF ───────────────────────────────────────────────────────────────

  void _openPdf(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Submit Report'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: Icon(Icons.add_circle_outline, size: 18),
              text: 'New Report',
            ),
            Tab(icon: Icon(Icons.history, size: 18), text: 'My Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSubmitTab(), _buildHistoryTab()],
      ),
    );
  }

  // ─── Submit Tab ─────────────────────────────────────────────────────────────

  Widget _buildSubmitTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Report Type Selection
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.category_outlined,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Report Type',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildTypeChip('daily', 'Daily', Icons.today),
                  const SizedBox(width: 8),
                  _buildTypeChip('weekly', 'Weekly', Icons.date_range),
                  const SizedBox(width: 8),
                  _buildTypeChip('monthly', 'Monthly', Icons.calendar_month),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Report Text
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.edit_note, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Report Details',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reportTextController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: 'Write your $_selectedType report here...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF2563EB),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // PDF Attachment (Optional)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.attach_file, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Attachment (Optional)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_pickedPdf != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.picture_as_pdf,
                        color: Color(0xFFEA580C),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _pickedPdf!.name,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Color(0xFFEF4444),
                        ),
                        onPressed: () => setState(() => _pickedPdf = null),
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _pickPdf,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Upload PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Submit Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isUploading ? null : _submitReport,
            icon: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send),
            label: Text(_isUploading ? 'Submitting...' : 'Submit Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String value, String label, IconData icon) {
    final isSelected = _selectedType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2563EB)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── History Tab ────────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    return Consumer<EmployeeReportViewModel>(
      builder: (context, vm, _) {
        if (vm.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (vm.reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'No reports submitted yet',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vm.reports.length,
          itemBuilder: (context, index) => _buildReportCard(vm.reports[index]),
        );
      },
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final type = (report['reportType'] ?? '').toString();
    final text = (report['reportText'] ?? '').toString();
    final status = (report['status'] ?? '').toString();
    final pdfUrl = (report['pdfUrl'] ?? '').toString();
    final pdfName = (report['pdfName'] ?? '').toString();
    final hrRemarks = (report['hrRemarks'] ?? '').toString();
    final hrRating = (report['hrRating'] ?? 0) as num;
    final assessedByName = (report['assessedByName'] ?? '').toString();
    final submittedAt = report['submittedAt'] as Timestamp?;
    final leadRemarks = (report['leadRemarks'] ?? '').toString();
    final leadRating = (report['leadRating'] ?? 0) as num;
    final assessedByLeadName = (report['assessedByLeadName'] ?? '').toString();
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: typeColor, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
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
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isAssessed
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isAssessed ? 'Assessed' : 'Submitted',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isAssessed
                          ? const Color(0xFF059669)
                          : const Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Date
            if (submittedAt != null)
              Text(
                DateFormat.yMMMd().add_jm().format(submittedAt.toDate()),
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            const SizedBox(height: 8),

            // Report text
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF334155),
                height: 1.5,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),

            // PDF
            if (pdfUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _openPdf(pdfUrl),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.picture_as_pdf,
                        color: Color(0xFFEA580C),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          pdfName.isNotEmpty ? pdfName : 'View PDF',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFEA580C),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Lead Assessment
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
                        const Icon(
                          Icons.rate_review,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Lead Assessment${assessedByLeadName.isNotEmpty ? ' by $assessedByLeadName' : ''}',
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
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // HR Assessment
            if (isAssessed && hrRemarks.isNotEmpty) ...[
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
                        const Icon(
                          Icons.rate_review,
                          size: 16,
                          color: Color(0xFF059669),
                        ),
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
                    // Rating stars
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < hrRating.toInt() ? Icons.star : Icons.star_border,
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
    );
  }
}
