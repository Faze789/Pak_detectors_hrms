import 'package:cloud_firestore/cloud_firestore.dart';

class TaskService {
  final FirebaseFirestore _db;

  TaskService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _db.collection('tasks');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Fetch all tasks assigned to a specific lead by emp_id
  Future<List<Map<String, dynamic>>> getTasksByEmpId(String empId) async {
    final snap = await _tasks.where('emp_id', isEqualTo: empId).get();

    final docs = snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();

    docs.sort((a, b) {
      final aTime = a['createdAt'] as Timestamp?;
      final bTime = b['createdAt'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return docs;
  }

  /// Fetch team members whose lead_id matches the lead's emp_id
  Future<List<Map<String, dynamic>>> getMembersByLeadId(String leadEmpId) async {
    final snapshot = await _users
        .where('lead_id', isEqualTo: leadEmpId)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['uid'] = doc.id;
      return data;
    }).toList();
  }

  /// Save a new task to Firestore
  Future<void> createTask({
    required String empId,
    required String leadName,
    required String department,
    required String title,
    required String description,
    required String duration,
  }) async {
    await _tasks.add({
      'emp_id': empId,
      'leadName': leadName,
      'department': department,
      'title': title,
      'description': description,
      'duration': duration,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
