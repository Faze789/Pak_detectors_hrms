import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/monthly_goal_viewmodel.dart';

class LeaderMonthlyReportScreen extends StatefulWidget {
  const LeaderMonthlyReportScreen({super.key});

  @override
  State<LeaderMonthlyReportScreen> createState() =>
      _LeaderMonthlyReportScreenState();
}

class _LeaderMonthlyReportScreenState extends State<LeaderMonthlyReportScreen> {
  String? _empId;
  String? _empName;
  bool _loadingUser = true;
  String _selectedMonth = '';

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  // Controllers for each goal's progress text
  final Map<String, TextEditingController> _progressControllers = {};
  // Picked PDFs per goal
  final Map<String, PlatformFile> _pickedPdfs = {};
  // Uploaded PDF URLs per goal (after upload)
  final Map<String, String> _uploadedPdfUrls = {};
  final Map<String, String> _uploadedPdfNames = {};
  bool _isUploadingPdfs = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = '${_months[now.month - 1]} ${now.year}';

    Future.microtask(() async {
      if (!mounted) return;
      final user = context.read<AuthViewModel>().currentUser;
      if (user == null) {
        setState(() => _loadingUser = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final empId = doc.data()?['emp_id'] ?? '';
      final empName = doc.data()?['name'] ?? user.name;

      if (!mounted) return;
      setState(() {
        _empId = empId;
        _empName = empName;
        _loadingUser = false;
      });

      if (empId.isNotEmpty) {
        _loadData(empId);
      }
    });
  }

  void _loadData(String empId) {
    final vm = context.read<MonthlyGoalViewModel>();
    vm.loadGoalsForLeader(empId, _selectedMonth);
    vm.loadReport(empId, _selectedMonth);
    vm.loadReportsForLeader(empId);
  }

  @override
  void dispose() {
    for (final c in _progressControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _getMonthOptions() {
    final now = DateTime.now();
    final options = <String>[];
    for (int i = -3; i <= 1; i++) {
      final date = DateTime(now.year, now.month + i, 1);
      options.add('${_months[date.month - 1]} ${date.year}');
    }
    return options;
  }

  bool _allFieldsFilled(List<Map<String, dynamic>> goals) {
    for (final goal in goals) {
      final id = goal['id'] as String? ?? '';
      final ctrl = _progressControllers[id];
      if (ctrl == null || ctrl.text.trim().isEmpty) return false;
    }
    return true;
  }

  Future<void> _openPdf(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _pickPdfForGoal(String goalId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedPdfs[goalId] = result.files.first);
    }
  }

  Future<void> _uploadAllPdfs() async {
    for (final entry in _pickedPdfs.entries) {
      final goalId = entry.key;
      final file = entry.value;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = FirebaseStorage.instance.ref('monthly_report_pdfs/$fileName');

      if (file.bytes != null) {
        await ref.putData(file.bytes!);
      } else if (!kIsWeb && file.path != null) {
        await ref.putFile(File(file.path!));
      } else {
        continue;
      }

      final url = await ref.getDownloadURL();
      _uploadedPdfUrls[goalId] = url;
      _uploadedPdfNames[goalId] = file.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUser) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }

    if (_empId == null || _empId!.isEmpty) {
      return const Center(
        child: Text(
          'Could not load user data',
          style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Consumer<MonthlyGoalViewModel>(
        builder: (context, vm, _) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isDesktop = screenWidth >= 768;
          final hasExistingReport = vm.currentReport != null;
          final reportStatus = (vm.currentReport?['status'] ?? '').toString();

          return Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Report',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Report your progress on assigned goals',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFBFDBFE),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 48 : 16,
                    vertical: 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Month selector
                          _buildLabel('Select Month'),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedMonth,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.calendar_month,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              items: _getMonthOptions()
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() {
                                  _selectedMonth = v;
                                  _progressControllers.clear();
                                  _pickedPdfs.clear();
                                  _uploadedPdfUrls.clear();
                                  _uploadedPdfNames.clear();
                                });
                                _loadData(_empId!);
                              },
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Status banner for existing report
                          if (hasExistingReport)
                            _buildReportStatusBanner(
                              reportStatus,
                              vm.currentReport!,
                            ),

                          // Goals section
                          if (vm.isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            )
                          else if (vm.goals.isEmpty)
                            _buildNoGoalsBanner()
                          else if (hasExistingReport)
                            _buildSubmittedReport(vm)
                          else
                            _buildReportForm(vm),

                          // History section
                          const SizedBox(height: 32),
                          if (vm.reports.isNotEmpty) ...[
                            const Text(
                              'Report History',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...vm.reports.map((r) => _buildHistoryCard(r)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportStatusBanner(String status, Map<String, dynamic> report) {
    final isAssessed = status == 'assessed';
    final assessment = report['assessment'] as Map<String, dynamic>?;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAssessed ? const Color(0xFFD1FAE5) : const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAssessed ? const Color(0xFFA7F3D0) : const Color(0xFFDDD6FE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAssessed ? Icons.check_circle : Icons.schedule,
                size: 20,
                color: isAssessed
                    ? const Color(0xFF065F46)
                    : const Color(0xFF6D28D9),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAssessed
                      ? 'Report Assessed by HR'
                      : 'Report Submitted — Awaiting HR Assessment',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isAssessed
                        ? const Color(0xFF065F46)
                        : const Color(0xFF6D28D9),
                  ),
                ),
              ),
            ],
          ),
          if (isAssessed && assessment != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Overall Rating: ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF065F46),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF065F46),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    assessment['overallRating'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if ((assessment['remarks'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'HR Remarks: ${assessment['remarks']}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF065F46),
                  height: 1.4,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildNoGoalsBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.flag_outlined, size: 48, color: Color(0xFFCBD5E1)),
          SizedBox(height: 12),
          Text(
            'No goals assigned for this month',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Contact HR to get your monthly goals assigned',
            style: TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedReport(MonthlyGoalViewModel vm) {
    final entries = (vm.currentReport?['goalEntries'] as List<dynamic>?) ?? [];
    final assessment = vm.currentReport?['assessment'] as Map<String, dynamic>?;
    final goalRatings = (assessment?['goalRatings'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Submitted Report',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        ...entries.asMap().entries.map((e) {
          final idx = e.key;
          final entry = e.value as Map<String, dynamic>;
          final goalId = entry['goalId'] ?? '';
          final entryPdfUrl = (entry['pdfUrl'] ?? '').toString();
          final entryPdfName = (entry['pdfName'] ?? '').toString();

          // Find per-goal rating if assessed
          Map<String, dynamic>? goalRating;
          for (final gr in goalRatings) {
            if (gr is Map<String, dynamic> && gr['goalId'] == goalId) {
              goalRating = gr;
              break;
            }
          }

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
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
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFFDBEAFE),
                      child: Text(
                        '${idx + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry['goalTitle'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Goal:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry['goalDescription'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Progress Update:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry['progressText'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                // Show attached PDF from report submission
                if (entryPdfUrl.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildPdfViewRow(
                    entryPdfName.isNotEmpty ? entryPdfName : 'Your Attachment',
                    entryPdfUrl,
                  ),
                ],
                if (goalRating != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'HR Rating: ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF065F46),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF065F46),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                goalRating['rating'] ?? '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if ((goalRating['feedback'] ?? '')
                            .toString()
                            .isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            goalRating['feedback'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReportForm(MonthlyGoalViewModel vm) {
    // Initialize controllers for each goal
    for (final goal in vm.goals) {
      final id = goal['id'] as String? ?? '';
      _progressControllers.putIfAbsent(id, () => TextEditingController());
    }

    return StatefulBuilder(
      builder: (context, setFormState) {
        final allFilled = _allFieldsFilled(vm.goals);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report on Your Assigned Goals',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${vm.goals.length} goal${vm.goals.length == 1 ? '' : 's'} assigned — fill in progress for each',
              style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),

            // Goal fields
            ...vm.goals.asMap().entries.map((e) {
              final idx = e.key;
              final goal = e.value;
              final goalId = goal['id'] as String? ?? '';
              final ctrl = _progressControllers[goalId]!;
              final hrPdfUrl = (goal['pdfUrl'] ?? '').toString();
              final hrPdfName = (goal['pdfName'] ?? '').toString();
              final assignedByName = (goal['assignedByName'] ?? '').toString();
              final pickedPdf = _pickedPdfs[goalId];

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Goal header with "Given by HR" ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFFDBEAFE),
                                child: Text(
                                  '${idx + 1}',
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
                                      goal['goalTitle'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      goal['goalDescription'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // "Given by HR" chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.admin_panel_settings_outlined,
                                  size: 13,
                                  color: Color(0xFF7C3AED),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  assignedByName.isNotEmpty
                                      ? 'Goal given by HR: $assignedByName'
                                      : 'Goal given by HR',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // HR-attached PDF
                          if (hrPdfUrl.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildPdfViewRow(
                              hrPdfName.isNotEmpty
                                  ? 'HR Attachment: $hrPdfName'
                                  : 'HR Attachment',
                              hrPdfUrl,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── Progress input section ──
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Progress Update *',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: ctrl,
                            maxLines: 4,
                            onChanged: (_) => setFormState(() {}),
                            decoration: InputDecoration(
                              hintText:
                                  'Describe your progress on this goal...',
                              hintStyle: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFCBD5E1),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // PDF upload for this goal
                          const Text(
                            'Attach PDF (optional)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (pickedPdf != null)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFECACA),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.picture_as_pdf,
                                    size: 18,
                                    color: Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      pickedPdf.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setFormState(() {
                                        _pickedPdfs.remove(goalId);
                                      });
                                    },
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: () async {
                                await _pickPdfForGoal(goalId);
                                setFormState(() {});
                              },
                              icon: const Icon(Icons.upload_file, size: 16),
                              label: const Text(
                                'Choose PDF',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (!allFilled || vm.isSubmitting || _isUploadingPdfs)
                    ? null
                    : () async {
                        // Upload picked PDFs first
                        if (_pickedPdfs.isNotEmpty) {
                          setState(() => _isUploadingPdfs = true);
                          await _uploadAllPdfs();
                          setState(() => _isUploadingPdfs = false);
                        }

                        final goalEntries = vm.goals.map((goal) {
                          final goalId = goal['id'] as String? ?? '';
                          return {
                            'goalId': goalId,
                            'goalTitle': goal['goalTitle'] ?? '',
                            'goalDescription': goal['goalDescription'] ?? '',
                            'progressText':
                                _progressControllers[goalId]?.text.trim() ?? '',
                            'pdfUrl': _uploadedPdfUrls[goalId] ?? '',
                            'pdfName': _uploadedPdfNames[goalId] ?? '',
                          };
                        }).toList();

                        final success = await vm.submitReport(
                          leaderId: _empId!,
                          leaderName: _empName ?? '',
                          assignedMonth: _selectedMonth,
                          goalEntries: goalEntries,
                        );

                        if (!mounted) return;
                        if (success) {
                          _progressControllers.clear();
                          _pickedPdfs.clear();
                          _uploadedPdfUrls.clear();
                          _uploadedPdfNames.clear();
                          _loadData(_empId!);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Monthly report submitted successfully',
                              ),
                              backgroundColor: Color(0xFF16A34A),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                vm.errorMessage ?? 'Failed to submit report',
                              ),
                              backgroundColor: const Color(0xFFEF4444),
                            ),
                          );
                        }
                      },
                icon: (vm.isSubmitting || _isUploadingPdfs)
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isUploadingPdfs
                      ? 'Uploading PDFs...'
                      : vm.isSubmitting
                      ? 'Submitting...'
                      : 'Submit Monthly Report',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF93C5FD),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            if (!allFilled)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '* All goal progress fields must be filled to submit',
                  style: TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPdfViewRow(String label, String url) {
    return InkWell(
      onTap: () => _openPdf(url),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.picture_as_pdf,
              size: 15,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFDC2626),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.open_in_new, size: 12, color: Color(0xFFDC2626)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> report) {
    final status = (report['status'] ?? 'submitted').toString();
    final isAssessed = status == 'assessed';
    final month = report['assignedMonth'] ?? '';
    final submittedAt = report['submittedAt'] as Timestamp?;
    final dateStr = submittedAt != null
        ? '${submittedAt.toDate().day}/${submittedAt.toDate().month}/${submittedAt.toDate().year}'
        : '';

    final assessment = report['assessment'] as Map<String, dynamic>?;
    final rating = assessment?['overallRating'] ?? '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAssessed ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 20,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  month,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Submitted $dateStr',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          if (isAssessed && rating.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF065F46),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                rating,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Pending',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6D28D9),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF475569),
        letterSpacing: 0.2,
      ),
    );
  }
}
