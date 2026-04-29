import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/employee_report_service.dart';

class EmployeeReportViewModel extends ChangeNotifier {
  final EmployeeReportService _service;

  EmployeeReportViewModel({EmployeeReportService? service})
      : _service = service ?? EmployeeReportService();

  // ─── State ──────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> get reports => _reports;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _filterType = ''; // '', 'daily', 'weekly', 'monthly'
  String get filterType => _filterType;

  // ─── Employee: Submit Report ────────────────────────────────────────────────

  Future<bool> submitReport({
    required String employeeId,
    required String employeeName,
    required String employeeRole,
    required String department,
    required String reportType,
    required String reportText,
    String? pdfUrl,
    String? pdfName,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      await _service.submitReport(
        employeeId: employeeId,
        employeeName: employeeName,
        employeeRole: employeeRole,
        department: department,
        reportType: reportType,
        reportText: reportText,
        pdfUrl: pdfUrl,
        pdfName: pdfName,
      );

      // Always notify HR when any employee submits a report
      final typeLabel = '${reportType[0].toUpperCase()}${reportType.substring(1)}';
      final isLead = employeeRole.toLowerCase().contains('project lead');
      final roleTag = isLead ? ' (Lead)' : '';

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
          'title': '$typeLabel Report Submitted',
          'body': '$employeeName$roleTag has submitted a $reportType report',
          'type': 'report',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      // Also notify lead when a team member submits
      if (!isLead) {
        final leads = await FirebaseFirestore.instance
            .collection('users')
            .where('department', isEqualTo: department)
            .where('role', isEqualTo: 'project lead')
            .get();

        for (final doc in leads.docs) {
          final leadEmpId = doc.data()['emp_id'] ?? doc.id;
          await FirebaseFirestore.instance
              .collection('task_notifications')
              .add({
            'lead_id': leadEmpId,
            'title': '$typeLabel Report Submitted',
            'body': '$employeeName has submitted a $reportType report',
            'type': 'report',
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
        }
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

  // ─── Employee: Load Own Reports ─────────────────────────────────────────────

  Future<void> loadReportsForEmployee(String employeeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _reports = await _service.getReportsForEmployee(employeeId);
    } catch (e) {
      _errorMessage = 'Failed to load reports: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Lead: Load Team Member Reports ──────────────────────────────────────────

  Future<void> loadReportsForLead({
    required String leadId,
    required String department,
    String? filterType,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _filterType = filterType ?? '';
    notifyListeners();

    try {
      _reports = await _service.getReportsForLead(
        leadId: leadId,
        department: department,
        filterType: (filterType != null && filterType.isNotEmpty)
            ? filterType
            : null,
      );
    } catch (e) {
      _errorMessage = 'Failed to load team reports: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Lead: Assess Member Report ─────────────────────────────────────────────

  Future<bool> leadAssessReport({
    required String reportId,
    required String leadId,
    required String leadName,
    required String remarks,
    required int rating,
    required String employeeName,
    required String reportType,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      await _service.leadAssessReport(
        reportId: reportId,
        leadId: leadId,
        leadName: leadName,
        remarks: remarks,
        rating: rating,
      );

      // Update local state
      final idx = _reports.indexWhere((r) => r['id'] == reportId);
      if (idx != -1) {
        _reports[idx]['status'] = 'lead_assessed';
        _reports[idx]['leadRemarks'] = remarks;
        _reports[idx]['leadRating'] = rating;
        _reports[idx]['assessedByLeadName'] = leadName;
      }

      // Notify HR about lead's assessment
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
          'title': 'Report Assessed by Lead',
          'body':
              '$leadName assessed $employeeName\'s $reportType report',
          'type': 'report',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

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

  // ─── HR: Load All Reports (with filter) ─────────────────────────────────────

  Future<void> loadAllReports({String? filterType}) async {
    _isLoading = true;
    _errorMessage = null;
    _filterType = filterType ?? '';
    notifyListeners();

    try {
      _reports = await _service.getAllReports(
        filterType: (filterType != null && filterType.isNotEmpty)
            ? filterType
            : null,
      );
    } catch (e) {
      _errorMessage = 'Failed to load reports: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── HR: Assess Report ──────────────────────────────────────────────────────

  Future<bool> assessReport({
    required String reportId,
    required String assessedBy,
    required String assessedByName,
    required String remarks,
    required int rating,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      await _service.assessReport(
        reportId: reportId,
        assessedBy: assessedBy,
        assessedByName: assessedByName,
        remarks: remarks,
        rating: rating,
      );

      // Update local state
      final idx = _reports.indexWhere((r) => r['id'] == reportId);
      if (idx != -1) {
        _reports[idx]['status'] = 'assessed';
        _reports[idx]['hrRemarks'] = remarks;
        _reports[idx]['hrRating'] = rating;
        _reports[idx]['assessedByName'] = assessedByName;
      }

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
