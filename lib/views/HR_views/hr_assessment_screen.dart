import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/monthly_goal_viewmodel.dart';

class HRAssessmentScreen extends StatefulWidget {
  final Map<String, dynamic> report;

  const HRAssessmentScreen({super.key, required this.report});

  @override
  State<HRAssessmentScreen> createState() => _HRAssessmentScreenState();
}

class _HRAssessmentScreenState extends State<HRAssessmentScreen> {
  String _hrEmpId = '';
  final _remarksCtrl = TextEditingController();
  String? _overallRating;
  bool _submitting = false;

  // Per-goal ratings and feedback
  final Map<String, String?> _goalRatings = {};
  final Map<String, TextEditingController> _goalFeedbackCtrls = {};

  static const _ratingOptions = [
    'Exceeds Expectations',
    'Meets Expectations',
    'Needs Improvement',
    'Below Expectations',
    'Not Rated',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        setState(() {
          _hrEmpId = doc.data()?['emp_id'] ?? '';
        });
      }
    });

    // Initialize feedback controllers for each goal
    final entries =
        (widget.report['goalEntries'] as List<dynamic>?) ?? [];
    for (final entry in entries) {
      if (entry is Map<String, dynamic>) {
        final goalId = (entry['goalId'] ?? '').toString();
        _goalFeedbackCtrls[goalId] = TextEditingController();
      }
    }

    // Pre-fill if already assessed
    final assessment =
        widget.report['assessment'] as Map<String, dynamic>?;
    if (assessment != null) {
      _overallRating = assessment['overallRating'] as String?;
      _remarksCtrl.text = (assessment['remarks'] ?? '').toString();

      final goalRatings =
          (assessment['goalRatings'] as List<dynamic>?) ?? [];
      for (final gr in goalRatings) {
        if (gr is Map<String, dynamic>) {
          final goalId = (gr['goalId'] ?? '').toString();
          _goalRatings[goalId] = gr['rating'] as String?;
          _goalFeedbackCtrls[goalId]?.text =
              (gr['feedback'] ?? '').toString();
        }
      }
    }
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    for (final c in _goalFeedbackCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isAlreadyAssessed =>
      (widget.report['status'] ?? '') == 'assessed';

  @override
  Widget build(BuildContext context) {
    final entries =
        (widget.report['goalEntries'] as List<dynamic>?) ?? [];
    final leaderName = widget.report['leaderName'] ?? 'Unknown';
    final assignedMonth = widget.report['assignedMonth'] ?? '';
    final submittedAt = widget.report['submittedAt'] as Timestamp?;
    final dateStr = submittedAt != null
        ? '${submittedAt.toDate().day}/${submittedAt.toDate().month}/${submittedAt.toDate().year}'
        : '';

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Performance Assessment',
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
      ),
      body: SingleChildScrollView(
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
                // Leader info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFDBEAFE),
                        child: Text(
                          leaderName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              leaderName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$assignedMonth · Submitted $dateStr',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _isAlreadyAssessed
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _isAlreadyAssessed
                              ? 'Assessed'
                              : 'Pending Review',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isAlreadyAssessed
                                ? const Color(0xFF065F46)
                                : const Color(0xFF6D28D9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Section: Goals & Progress
                const Text(
                  'Goals & Leader\'s Progress',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entries.length} goal${entries.length == 1 ? '' : 's'} reported',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 16),

                // Goal entries with per-goal ratings
                ...entries.asMap().entries.map((e) {
                  final idx = e.key;
                  final entry = e.value as Map<String, dynamic>;
                  final goalId =
                      (entry['goalId'] ?? '').toString();

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // Goal title
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  const Color(0xFFDBEAFE),
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
                        const SizedBox(height: 10),

                        // Goal description
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Assigned Goal:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                entry['goalDescription'] ??
                                    '',
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

                        // Leader's progress
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Leader\'s Progress Update:',
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
                        const SizedBox(height: 12),

                        // Per-goal rating (HR input)
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        const Text(
                          'Rate this Goal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius:
                                BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  const Color(0xFFE2E8F0),
                            ),
                          ),
                          child:
                              DropdownButtonFormField<String>(
                            value: _goalRatings[goalId],
                            isExpanded: true,
                            decoration:
                                const InputDecoration(
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              hintText: 'Select rating',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            items: _ratingOptions
                                .map(
                                  (r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(
                                      r,
                                      style:
                                          const TextStyle(
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _isAlreadyAssessed
                                ? null
                                : (v) {
                                    setState(() =>
                                        _goalRatings[
                                            goalId] = v);
                                  },
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller:
                              _goalFeedbackCtrls[goalId],
                          maxLines: 2,
                          readOnly: _isAlreadyAssessed,
                          decoration: InputDecoration(
                            hintText:
                                'Feedback for this goal (optional)',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFCBD5E1),
                            ),
                            filled: true,
                            fillColor:
                                const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color:
                                    Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 8),

                // Overall Assessment Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2563EB),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 20,
                            color: Color(0xFF2563EB),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Overall Assessment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Overall rating dropdown
                      const Text(
                        'Performance Rating *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                          ),
                        ),
                        child:
                            DropdownButtonFormField<String>(
                          value: _overallRating,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            hintText:
                                'Select overall performance rating',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            prefixIcon: Icon(
                              Icons.assessment_outlined,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          items: _ratingOptions
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r),
                                ),
                              )
                              .toList(),
                          onChanged: _isAlreadyAssessed
                              ? null
                              : (v) {
                                  setState(
                                    () =>
                                        _overallRating = v,
                                  );
                                },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Remarks
                      const Text(
                        'HR Remarks *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _remarksCtrl,
                        maxLines: 4,
                        readOnly: _isAlreadyAssessed,
                        decoration: InputDecoration(
                          hintText:
                              'Write your assessment remarks...',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFCBD5E1),
                          ),
                          filled: true,
                          fillColor:
                              const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Assessment button
                if (!_isAlreadyAssessed)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => _submitAssessment(),
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.check_circle_outline,
                              size: 20,
                            ),
                      label: Text(
                        _submitting
                            ? 'Submitting...'
                            : 'Submit Assessment',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFF86EFAC),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                if (_isAlreadyAssessed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFA7F3D0),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 20,
                          color: Color(0xFF065F46),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'This report has been assessed and closed',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitAssessment() async {
    if (_overallRating == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an overall performance rating'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (_remarksCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add HR remarks'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    // Build per-goal ratings
    final entries =
        (widget.report['goalEntries'] as List<dynamic>?) ?? [];
    final goalRatingsList = entries.map((entry) {
      if (entry is Map<String, dynamic>) {
        final goalId = (entry['goalId'] ?? '').toString();
        return {
          'goalId': goalId,
          'rating': _goalRatings[goalId] ?? 'Not Rated',
          'feedback':
              _goalFeedbackCtrls[goalId]?.text.trim() ?? '',
        };
      }
      return <String, dynamic>{};
    }).toList();

    final vm = context.read<MonthlyGoalViewModel>();
    final success = await vm.assessReport(
      reportId: widget.report['id'],
      assessedBy: _hrEmpId,
      overallRating: _overallRating!,
      remarks: _remarksCtrl.text.trim(),
      goalRatings: goalRatingsList,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assessment submitted successfully'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(vm.errorMessage ?? 'Failed to submit assessment'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }
}
