import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../viewmodels/monthly_goal_viewmodel.dart';
import 'hr_assessment_screen.dart';

class HRMonthlyGoalsScreen extends StatefulWidget {
  const HRMonthlyGoalsScreen({super.key});

  @override
  State<HRMonthlyGoalsScreen> createState() => _HRMonthlyGoalsScreenState();
}

class _HRMonthlyGoalsScreenState extends State<HRMonthlyGoalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _hrEmpId = '';
  String _hrName = '';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final now = DateTime.now();
    _selectedMonth = '${_months[now.month - 1]} ${now.year}';

    Future.microtask(() async {
      if (!mounted) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        _hrEmpId = doc.data()?['emp_id'] ?? '';
        _hrName = doc.data()?['name'] ?? '';
      }
      if (!mounted) return;
      final vm = context.read<MonthlyGoalViewModel>();
      vm.loadLeaders();
      vm.loadGoalsForMonth(_selectedMonth);
      vm.loadAllReports();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<String> _getMonthOptions() {
    final now = DateTime.now();
    final options = <String>[];
    for (int i = -2; i <= 3; i++) {
      final date = DateTime(now.year, now.month + i, 1);
      options.add('${_months[date.month - 1]} ${date.year}');
    }
    return options;
  }

  Future<void> _openPdf(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Monthly Goals & Reports',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
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
          unselectedLabelColor: const Color(0xFFBFDBFE),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Assign Goals'),
            Tab(text: 'Review Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildAssignGoalsTab(), _buildReviewReportsTab()],
      ),
    );
  }

  // ─── Tab 1: Assign Goals ──────────────────────────────────────────────────

  Widget _buildAssignGoalsTab() {
    return Consumer<MonthlyGoalViewModel>(
      builder: (context, vm, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktop = screenWidth >= 768;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 48 : 16,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
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
                      border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _selectedMonth = v);
                        vm.loadGoalsForMonth(v);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Header row
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Goals for this Month',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddGoalDialog(context, vm),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Goal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (vm.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    )
                  else if (vm.goals.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.flag_outlined,
                            size: 48,
                            color: Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No goals assigned for this month',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => _showAddGoalDialog(context, vm),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Assign First Goal'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...vm.goals.map((goal) => _buildGoalCard(goal, vm)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal, MonthlyGoalViewModel vm) {
    final status = (goal['status'] ?? 'active').toString();
    final isActive = status == 'active';
    final assignedByName = (goal['assignedByName'] ?? '').toString();
    final leaderName = (goal['leaderName'] ?? '').toString();
    final pdfUrl = (goal['pdfUrl'] ?? '').toString();
    final pdfName = (goal['pdfName'] ?? '').toString();

    Color statusBg;
    Color statusFg;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'reported':
        statusBg = const Color(0xFFEDE9FE);
        statusFg = const Color(0xFF6D28D9);
        statusLabel = 'Reported';
        statusIcon = Icons.assignment_turned_in_outlined;
        break;
      case 'assessed':
        statusBg = const Color(0xFFD1FAE5);
        statusFg = const Color(0xFF065F46);
        statusLabel = 'Assessed';
        statusIcon = Icons.check_circle_outline;
        break;
      default:
        statusBg = const Color(0xFFFEF3C7);
        statusFg = const Color(0xFF92400E);
        statusLabel = 'Active';
        statusIcon = Icons.flag_outlined;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header with status ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusBg.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, size: 16, color: statusFg),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    goal['goalTitle'] ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
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
                      color: statusFg,
                    ),
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Goal'),
                          content: const Text(
                            'Are you sure you want to delete this goal?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await vm.deleteGoal(goal['id']);
                      }
                    },
                    child: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Body ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Text(
                  goal['goalDescription'] ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Info chips row ──
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    // Assigned to lead
                    _buildInfoChip(
                      Icons.person_outline,
                      'Assigned to: $leaderName',
                      const Color(0xFF2563EB),
                      const Color(0xFFEFF6FF),
                    ),
                    // Assigned by HR
                    _buildInfoChip(
                      Icons.admin_panel_settings_outlined,
                      assignedByName.isNotEmpty
                          ? 'Given by HR: $assignedByName'
                          : 'Given by HR',
                      const Color(0xFF7C3AED),
                      const Color(0xFFF5F3FF),
                    ),
                    // Reported by lead
                    if (status == 'reported' || status == 'assessed')
                      _buildInfoChip(
                        Icons.assignment_turned_in_outlined,
                        'Submitted by Lead: $leaderName',
                        const Color(0xFF059669),
                        const Color(0xFFF0FDF4),
                      ),
                  ],
                ),

                // ── PDF attachment ──
                if (pdfUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _openPdf(pdfUrl),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                            size: 16,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              pdfName.isNotEmpty ? pdfName : 'View Attachment',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFDC2626),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.open_in_new,
                            size: 13,
                            color: Color(0xFFDC2626),
                          ),
                        ],
                      ),
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

  Widget _buildInfoChip(IconData icon, String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Add Goal Dialog ──────────────────────────────────────────────────────

  void _showAddGoalDialog(BuildContext context, MonthlyGoalViewModel vm) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedLeaderId;
    String? selectedLeaderName;
    PlatformFile? pickedPdf;
    bool isUploading = false;

    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Future<void> pickPdf() async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['pdf'],
                withData: true,
              );
              if (result != null && result.files.isNotEmpty) {
                setDialogState(() => pickedPdf = result.files.first);
              }
            }

            Future<String?> uploadPdf() async {
              if (pickedPdf == null) return null;
              final fileName =
                  '${DateTime.now().millisecondsSinceEpoch}_${pickedPdf!.name}';
              final ref = FirebaseStorage.instance.ref(
                'monthly_goal_pdfs/$fileName',
              );

              if (pickedPdf!.bytes != null) {
                await ref.putData(pickedPdf!.bytes!);
              } else if (!kIsWeb && pickedPdf!.path != null) {
                await ref.putFile(File(pickedPdf!.path!));
              } else {
                return null;
              }
              return await ref.getDownloadURL();
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Assign Monthly Goal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              content: SizedBox(
                width: screenWidth >= 768 ? 500 : double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Month display
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month,
                              size: 16,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedMonth,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Select Leader
                      _buildLabel('Select Project Lead'),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: vm.leaders.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No project leads found',
                                  style: TextStyle(color: Color(0xFF94A3B8)),
                                ),
                              )
                            : Scrollbar(
                                child: ListView(
                                  shrinkWrap: true,
                                  children: vm.leaders.map((leader) {
                                    final empId = (leader['emp_id'] ?? '')
                                        .toString();
                                    final name = (leader['name'] ?? 'Unknown')
                                        .toString();
                                    return RadioListTile<String>(
                                      value: empId,
                                      groupValue: selectedLeaderId,
                                      activeColor: const Color(0xFF2563EB),
                                      title: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        empId,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                      onChanged: (v) {
                                        setDialogState(() {
                                          selectedLeaderId = v;
                                          selectedLeaderName = name;
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // Goal Title
                      _buildLabel('Goal Title'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. Complete Q2 sprint targets',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
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
                      const SizedBox(height: 16),

                      // Goal Description
                      _buildLabel('Goal Description'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText:
                              'Describe the expected outcome in detail...',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
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
                      const SizedBox(height: 16),

                      // PDF attachment
                      _buildLabel('Attach PDF (optional)'),
                      const SizedBox(height: 8),
                      if (pickedPdf != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.picture_as_pdf,
                                size: 20,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  pickedPdf!.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setDialogState(() => pickedPdf = null);
                                },
                                child: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: pickPdf,
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text('Choose PDF'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
                ElevatedButton(
                  onPressed: (vm.isSubmitting || isUploading)
                      ? null
                      : () async {
                          if (selectedLeaderId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a project lead'),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                            return;
                          }
                          if (titleCtrl.text.trim().isEmpty ||
                              descCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill in all fields'),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                            return;
                          }

                          String? pdfUrl;
                          String? pdfFileName;
                          if (pickedPdf != null) {
                            setDialogState(() => isUploading = true);
                            pdfUrl = await uploadPdf();
                            pdfFileName = pickedPdf?.name;
                            setDialogState(() => isUploading = false);
                          }

                          final success = await vm.createGoal(
                            leaderId: selectedLeaderId!,
                            leaderName: selectedLeaderName ?? '',
                            assignedMonth: _selectedMonth,
                            goalTitle: titleCtrl.text.trim(),
                            goalDescription: descCtrl.text.trim(),
                            assignedBy: _hrEmpId,
                            assignedByName: _hrName,
                            pdfUrl: pdfUrl,
                            pdfName: pdfFileName,
                          );

                          if (!context.mounted) return;
                          Navigator.pop(dialogCtx);

                          if (success) {
                            vm.loadGoalsForMonth(_selectedMonth);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Goal assigned successfully'),
                                backgroundColor: Color(0xFF16A34A),
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
                  child: (vm.isSubmitting || isUploading)
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Assign Goal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Tab 2: Review Reports ────────────────────────────────────────────────

  Widget _buildReviewReportsTab() {
    return Consumer<MonthlyGoalViewModel>(
      builder: (context, vm, _) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktop = screenWidth >= 768;

        if (vm.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2563EB)),
          );
        }

        if (vm.reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 56,
                  color: Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No reports submitted yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => vm.loadAllReports(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 48 : 16,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Submitted Reports',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => vm.loadAllReports(),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...vm.reports.map(
                    (report) => _buildReportCard(context, report),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportCard(BuildContext context, Map<String, dynamic> report) {
    final status = (report['status'] ?? 'submitted').toString();
    final isAssessed = status == 'assessed';
    final submittedAt = report['submittedAt'] as Timestamp?;
    final dateStr = submittedAt != null
        ? '${submittedAt.toDate().day}/${submittedAt.toDate().month}/${submittedAt.toDate().year}'
        : '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAssessed ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HRAssessmentScreen(report: report),
            ),
          ).then((_) {
            context.read<MonthlyGoalViewModel>().loadAllReports();
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFDBEAFE),
                child: Text(
                  (report['leaderName'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report['leaderName'] ?? 'Unknown Leader',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${report['assignedMonth'] ?? ''} · Submitted $dateStr',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isAssessed
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isAssessed ? 'Assessed' : 'Pending Review',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isAssessed
                        ? const Color(0xFF065F46)
                        : const Color(0xFF6D28D9),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
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
