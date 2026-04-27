import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/monthly_goal_service.dart';

class MonthlyGoalViewModel extends ChangeNotifier {
  final MonthlyGoalService _service;

  MonthlyGoalViewModel({MonthlyGoalService? service})
      : _service = service ?? MonthlyGoalService();

  // ─── State ──────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _goals = [];
  List<Map<String, dynamic>> get goals => _goals;

  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> get reports => _reports;

  List<Map<String, dynamic>> _leaders = [];
  List<Map<String, dynamic>> get leaders => _leaders;

  Map<String, dynamic>? _currentReport;
  Map<String, dynamic>? get currentReport => _currentReport;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ─── Goal Management (HR) ──────────────────────────────────────────────────

  /// Load all leaders for HR to assign goals to
  Future<void> loadLeaders() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _leaders = await _service.getAllLeaders();
    } catch (e) {
      _errorMessage = 'Failed to load leaders: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load goals for a specific month (HR overview)
  Future<void> loadGoalsForMonth(String assignedMonth) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _goals = await _service.getAllGoalsForMonth(assignedMonth);
    } catch (e) {
      _errorMessage = 'Failed to load goals: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load goals for a specific leader and month
  Future<void> loadGoalsForLeader(
    String leaderId,
    String assignedMonth,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _goals = await _service.getGoalsForLeader(leaderId, assignedMonth);
    } catch (e) {
      _errorMessage = 'Failed to load goals: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// HR creates a new goal for a leader
  Future<bool> createGoal({
    required String leaderId,
    required String leaderName,
    required String assignedMonth,
    required String goalTitle,
    required String goalDescription,
    required String assignedBy,
    required String assignedByName,
    String? pdfUrl,
    String? pdfName,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      await _service.createGoal(
        leaderId: leaderId,
        leaderName: leaderName,
        assignedMonth: assignedMonth,
        goalTitle: goalTitle,
        goalDescription: goalDescription,
        assignedBy: assignedBy,
        assignedByName: assignedByName,
        pdfUrl: pdfUrl,
        pdfName: pdfName,
      );
      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to create goal: $e';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// HR deletes a goal
  Future<bool> deleteGoal(String goalId) async {
    try {
      await _service.deleteGoal(goalId);
      _goals.removeWhere((g) => g['id'] == goalId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete goal: $e';
      notifyListeners();
      return false;
    }
  }

  // ─── Monthly Reports (Leader) ──────────────────────────────────────────────

  /// Leader submits their monthly report
  Future<bool> submitReport({
    required String leaderId,
    required String leaderName,
    required String assignedMonth,
    required List<Map<String, dynamic>> goalEntries,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      await _service.submitMonthlyReport(
        leaderId: leaderId,
        leaderName: leaderName,
        assignedMonth: assignedMonth,
        goalEntries: goalEntries,
      );

      // Notify HR about the submission
      final hrUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'hr')
          .get();

      for (final doc in hrUsers.docs) {
        final hrEmpId = doc.data()['emp_id'] ?? doc.id;
        await FirebaseFirestore.instance
            .collection('task_notifications')
            .add({
          'lead_id': hrEmpId,
          'title': 'Monthly Report Submitted',
          'body':
              '$leaderName has submitted their monthly report for $assignedMonth',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to submit report: $e';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Load the current report for a leader/month
  Future<void> loadReport(String leaderId, String assignedMonth) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentReport = await _service.getReport(leaderId, assignedMonth);
    } catch (e) {
      _errorMessage = 'Failed to load report: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load all submitted reports for HR review
  Future<void> loadAllSubmittedReports() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _reports = await _service.getAllSubmittedReports();
    } catch (e) {
      _errorMessage = 'Failed to load reports: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load all reports (both submitted and assessed) for HR overview
  Future<void> loadAllReports() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _reports = await _service.getAllReports();
    } catch (e) {
      _errorMessage = 'Failed to load reports: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load reports for a specific leader (leader views own history)
  Future<void> loadReportsForLeader(String leaderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _reports = await _service.getReportsForLeader(leaderId);
    } catch (e) {
      _errorMessage = 'Failed to load reports: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── HR Assessment ─────────────────────────────────────────────────────────

  /// HR submits assessment for a monthly report
  Future<bool> assessReport({
    required String reportId,
    required String assessedBy,
    required String overallRating,
    required String remarks,
    required List<Map<String, dynamic>> goalRatings,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      await _service.assessReport(
        reportId: reportId,
        assessedBy: assessedBy,
        overallRating: overallRating,
        remarks: remarks,
        goalRatings: goalRatings,
      );

      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to assess report: $e';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }
}
