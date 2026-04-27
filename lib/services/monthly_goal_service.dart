import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyGoalService {
  final FirebaseFirestore _db;

  MonthlyGoalService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _goals =>
      _db.collection('monthly_goals');

  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('monthly_reports');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  // ─── Monthly Goals (HR assigns to leaders) ──────────────────────────────────

  /// Create a monthly goal for a specific leader
  Future<void> createGoal({
    required String leaderId,
    required String leaderName,
    required String assignedMonth, // e.g. "May 2026"
    required String goalTitle,
    required String goalDescription,
    required String assignedBy, // HR emp_id
    required String assignedByName, // HR name
    String? pdfUrl,
    String? pdfName,
  }) async {
    await _goals.add({
      'leaderId': leaderId,
      'leaderName': leaderName,
      'assignedMonth': assignedMonth,
      'goalTitle': goalTitle,
      'goalDescription': goalDescription,
      'assignedBy': assignedBy,
      'assignedByName': assignedByName,
      'pdfUrl': pdfUrl ?? '',
      'pdfName': pdfName ?? '',
      'status': 'active', // active | reported | assessed
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetch all goals assigned to a leader for a specific month
  Future<List<Map<String, dynamic>>> getGoalsForLeader(
    String leaderId,
    String assignedMonth,
  ) async {
    // Single where clause to avoid needing a Firestore composite index
    final snap = await _goals
        .where('leaderId', isEqualTo: leaderId)
        .get();

    return snap.docs
        .where((d) => d.data()['assignedMonth'] == assignedMonth)
        .map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();
  }

  /// Fetch all goals assigned to a leader across all months
  Future<List<Map<String, dynamic>>> getAllGoalsForLeader(
    String leaderId,
  ) async {
    final snap = await _goals
        .where('leaderId', isEqualTo: leaderId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();
  }

  /// Fetch all goals for a given month (HR sees all leaders)
  Future<List<Map<String, dynamic>>> getAllGoalsForMonth(
    String assignedMonth,
  ) async {
    final snap =
        await _goals.where('assignedMonth', isEqualTo: assignedMonth).get();

    return snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();
  }

  /// Delete a goal (HR only, before report is submitted)
  Future<void> deleteGoal(String goalId) async {
    await _goals.doc(goalId).delete();
  }

  // ─── Monthly Reports (Leader submits, HR assesses) ──────────────────────────

  /// Submit a monthly report — leader reports progress on each assigned goal
  Future<void> submitMonthlyReport({
    required String leaderId,
    required String leaderName,
    required String assignedMonth,
    required List<Map<String, dynamic>> goalEntries,
    // Each entry: { goalId, goalTitle, goalDescription, progressText, pdfUrl?, pdfName? }
  }) async {
    // Create the report
    await _reports.add({
      'leaderId': leaderId,
      'leaderName': leaderName,
      'assignedMonth': assignedMonth,
      'goalEntries': goalEntries,
      'status': 'submitted', // submitted | assessed
      'submittedAt': FieldValue.serverTimestamp(),
      'assessment': null,
    });

    // Mark each goal as reported
    for (final entry in goalEntries) {
      final goalId = entry['goalId'] as String?;
      if (goalId != null && goalId.isNotEmpty) {
        await _goals.doc(goalId).update({'status': 'reported'});
      }
    }
  }

  /// Fetch submitted report for a leader/month
  Future<Map<String, dynamic>?> getReport(
    String leaderId,
    String assignedMonth,
  ) async {
    // Single where clause to avoid needing a Firestore composite index
    final snap = await _reports
        .where('leaderId', isEqualTo: leaderId)
        .get();

    final match = snap.docs
        .where((d) => d.data()['assignedMonth'] == assignedMonth)
        .toList();

    if (match.isEmpty) return null;
    final data = match.first.data();
    data['id'] = match.first.id;
    return data;
  }

  /// Fetch all submitted reports (for HR to review)
  Future<List<Map<String, dynamic>>> getAllSubmittedReports() async {
    final snap = await _reports
        .where('status', isEqualTo: 'submitted')
        .get();

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

  /// Fetch all reports (submitted + assessed) for HR overview
  Future<List<Map<String, dynamic>>> getAllReports() async {
    final snap = await _reports.get();

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

  /// HR assesses a report — adds rating + feedback, closes the cycle
  Future<void> assessReport({
    required String reportId,
    required String assessedBy,
    required String overallRating,
    required String remarks,
    required List<Map<String, dynamic>> goalRatings,
    // Each: { goalId, rating, feedback }
  }) async {
    await _reports.doc(reportId).update({
      'status': 'assessed',
      'assessment': {
        'assessedBy': assessedBy,
        'overallRating': overallRating,
        'remarks': remarks,
        'goalRatings': goalRatings,
        'assessedAt': FieldValue.serverTimestamp(),
      },
    });

    // Also mark each goal as assessed
    for (final entry in goalRatings) {
      final goalId = entry['goalId'] as String?;
      if (goalId != null && goalId.isNotEmpty) {
        await _goals.doc(goalId).update({'status': 'assessed'});
      }
    }
  }

  /// Fetch users with 'project lead' role for goal assignment
  Future<List<Map<String, dynamic>>> getAllLeaders() async {
    final snap = await _users.get();
    return snap.docs
        .where((doc) {
          final data = doc.data();
          final role = (data['role'] ?? '').toString().toLowerCase();
          return role.contains('project lead');
        })
        .map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return data;
        })
        .toList();
  }

  /// Fetch reports for a specific leader (leader views their own history)
  Future<List<Map<String, dynamic>>> getReportsForLeader(
    String leaderId,
  ) async {
    final snap =
        await _reports.where('leaderId', isEqualTo: leaderId).get();

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
}
