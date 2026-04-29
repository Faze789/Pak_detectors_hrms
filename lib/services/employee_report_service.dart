import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeReportService {
  final FirebaseFirestore _db;

  EmployeeReportService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('employee_reports');

  /// Submit a report (daily / weekly / monthly)
  Future<void> submitReport({
    required String employeeId,
    required String employeeName,
    required String employeeRole,
    required String department,
    required String reportType, // 'daily', 'weekly', 'monthly'
    required String reportText,
    String? pdfUrl,
    String? pdfName,
  }) async {
    await _reports.add({
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeeRole': employeeRole,
      'department': department,
      'reportType': reportType,
      'reportText': reportText,
      'pdfUrl': pdfUrl ?? '',
      'pdfName': pdfName ?? '',
      'status': 'submitted', // submitted | assessed
      'hrRemarks': '',
      'hrRating': 0,
      'assessedBy': '',
      'assessedByName': '',
      'submittedAt': FieldValue.serverTimestamp(),
      'assessedAt': null,
    });
  }

  /// Fetch reports for a specific employee (employee views own history)
  Future<List<Map<String, dynamic>>> getReportsForEmployee(
    String employeeId,
  ) async {
    final snap =
        await _reports.where('employeeId', isEqualTo: employeeId).get();

    final docs = snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();

    docs.sort((a, b) {
      final aTime = a['submittedAt'] as Timestamp?;
      final bTime = b['submittedAt'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return docs;
  }

  /// Fetch all reports (HR overview) — optional filter by reportType
  Future<List<Map<String, dynamic>>> getAllReports({
    String? filterType, // 'daily', 'weekly', 'monthly', or null for all
  }) async {
    Query<Map<String, dynamic>> query = _reports;

    if (filterType != null && filterType.isNotEmpty) {
      query = query.where('reportType', isEqualTo: filterType);
    }

    final snap = await query.get();

    final docs = snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();

    docs.sort((a, b) {
      final aTime = a['submittedAt'] as Timestamp?;
      final bTime = b['submittedAt'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return docs;
  }

  /// Fetch reports from members in the same department (for lead view)
  /// Excludes the lead's own reports.
  Future<List<Map<String, dynamic>>> getReportsForLead({
    required String leadId,
    required String department,
    String? filterType,
  }) async {
    Query<Map<String, dynamic>> query =
        _reports.where('department', isEqualTo: department);

    if (filterType != null && filterType.isNotEmpty) {
      query = query.where('reportType', isEqualTo: filterType);
    }

    final snap = await query.get();

    final docs = snap.docs
        .map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        })
        .where((d) => d['employeeId'] != leadId) // exclude lead's own
        .toList();

    docs.sort((a, b) {
      final aTime = a['submittedAt'] as Timestamp?;
      final bTime = b['submittedAt'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return docs;
  }

  /// Lead assesses a member report — adds lead rating + remarks
  Future<void> leadAssessReport({
    required String reportId,
    required String leadId,
    required String leadName,
    required String remarks,
    required int rating, // 1–5
  }) async {
    await _reports.doc(reportId).update({
      'status': 'lead_assessed',
      'leadRemarks': remarks,
      'leadRating': rating,
      'assessedByLead': leadId,
      'assessedByLeadName': leadName,
      'leadAssessedAt': FieldValue.serverTimestamp(),
    });
  }

  /// HR assesses a report — adds rating + remarks
  Future<void> assessReport({
    required String reportId,
    required String assessedBy,
    required String assessedByName,
    required String remarks,
    required int rating, // 1–5
  }) async {
    await _reports.doc(reportId).update({
      'status': 'assessed',
      'hrRemarks': remarks,
      'hrRating': rating,
      'assessedBy': assessedBy,
      'assessedByName': assessedByName,
      'assessedAt': FieldValue.serverTimestamp(),
    });
  }
}
