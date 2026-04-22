import 'package:cloud_firestore/cloud_firestore.dart';

class TaskService {
  final FirebaseFirestore _db;

  TaskService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _db.collection('tasks');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Fetch all tasks from Firestore
  Future<List<Map<String, dynamic>>> getAllTasks() async {
    final snap = await _tasks.get();

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

  /// Fetch tasks where lead_id matches the given emp_id (case-insensitive)
  Future<List<Map<String, dynamic>>> getTasksByLeadId(String leadEmpId) async {
    final snap = await _tasks.get();
    final lowerLeadId = leadEmpId.toLowerCase();

    final docs = snap.docs
        .where((d) {
          final docLeadId = (d.data()['lead_id'] ?? '').toString().toLowerCase();
          return docLeadId == lowerLeadId;
        })
        .map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        })
        .toList();

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
  /// Uses case-insensitive comparison since Firestore values may differ in casing
  Future<List<Map<String, dynamic>>> getMembersByLeadId(
    String leadEmpId,
  ) async {
    final snapshot = await _users.get();
    final lowerLeadId = leadEmpId.toLowerCase();
    return snapshot.docs
        .where((doc) {
          final data = doc.data();
          final docLeadId = (data['lead_id'] ?? '').toString().toLowerCase();
          return docLeadId == lowerLeadId;
        })
        .map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return data;
        })
        .toList();
  }

  /// Save a new task to Firestore
  /// Members are saved as: {1: {name: "...", emp_id: "..."}, 2: {...}}
  Future<void> createTask({
    List<Map<String, dynamic>>? members,
    required String lead_id,
    required String leadName,
    required String department,
    required String title,
    required String description,
    required String duration,
  }) async {
    // Format members as numbered map: {1: {name, emp_id}, 2: {name, emp_id}}
    final Map<String, dynamic> membersMap = {};
    if (members != null) {
      for (int i = 0; i < members.length; i++) {
        membersMap['${i + 1}'] = {
          'name': members[i]['name'] ?? '',
          'emp_id': members[i]['emp_id'] ?? '',
        };
      }
    }

    await _tasks.add({
      'members': membersMap,
      'lead_id': lead_id,
      'leadName': leadName,
      'department': department,
      'title': title,
      'description': description,
      'duration': duration,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'version': 1,
    });
  }

  /// Update a task: saves the current version to history subcollection,
  /// then updates the main document with new values.
  Future<void> updateTask({
    required String taskId,
    required Map<String, dynamic> currentData,
    required String newTitle,
    required String newDescription,
    required String newDuration,
    required String newStatus,
    required String modifiedBy,
    required String modifiedByRole,
  }) async {
    final taskRef = _tasks.doc(taskId);
    final currentVersion = (currentData['version'] ?? 1) as int;

    // Save current version to history subcollection
    await taskRef.collection('history').add({
      'title': currentData['title'] ?? '',
      'description': currentData['description'] ?? '',
      'duration': currentData['duration'] ?? '',
      'status': currentData['status'] ?? '',
      'lead_id': currentData['lead_id'] ?? '',
      'leadName': currentData['leadName'] ?? '',
      'department': currentData['department'] ?? '',
      'members': currentData['members'] ?? {},
      'version': currentVersion,
      'savedAt': FieldValue.serverTimestamp(),
      'savedBy': modifiedBy,
    });

    // Update the main task document with new values
    final updateData = <String, dynamic>{
      'title': newTitle,
      'description': newDescription,
      'duration': newDuration,
      'status': newStatus,
      'version': currentVersion + 1,
      'lastModifiedAt': FieldValue.serverTimestamp(),
      'lastModifiedBy': modifiedBy,
      'lastModifiedByRole': modifiedByRole,
    };

    // Save approval timestamp when task is approved
    if (newStatus == 'approved') {
      updateData['approvedAt'] = FieldValue.serverTimestamp();
    }

    await taskRef.update(updateData);
  }

  /// Fetch version history for a task (sorted oldest first)
  Future<List<Map<String, dynamic>>> getTaskHistory(String taskId) async {
    final snap = await _tasks
        .doc(taskId)
        .collection('history')
        .orderBy('version', descending: false)
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();
  }

  /// Fetch the FCM token for a user by their emp_id (case-insensitive)
  Future<String?> getFcmTokenByEmpId(String empId) async {
    final snap = await _users.get();
    final lowerEmpId = empId.toLowerCase();
    for (final doc in snap.docs) {
      final data = doc.data();
      if ((data['emp_id'] ?? '').toString().toLowerCase() == lowerEmpId) {
        return data['fcmToken'] as String?;
      }
    }
    return null;
  }
}
