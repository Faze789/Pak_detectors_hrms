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
          final docLeadId = (d.data()['lead_id'] ?? '')
              .toString()
              .toLowerCase();
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

  /// Fetch tasks where the given emp_id appears in the members map
  Future<List<Map<String, dynamic>>> getTasksByMemberEmpId(String empId) async {
    final snap = await _tasks.get();
    final lowerEmpId = empId.toLowerCase();

    final docs = snap.docs
        .where((d) {
          final data = d.data();
          final members = data['members'] as Map<String, dynamic>? ?? {};
          return members.values.any((m) {
            if (m is Map<String, dynamic>) {
              return (m['emp_id'] ?? '').toString().toLowerCase() == lowerEmpId;
            }
            return false;
          });
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

  /// Fetch tasks where the user is either the lead OR a member
  Future<List<Map<String, dynamic>>> getTasksForUser(String empId) async {
    final snap = await _tasks.get();
    final lowerEmpId = empId.toLowerCase();
    final Set<String> seenIds = {};

    final docs = <Map<String, dynamic>>[];

    for (final d in snap.docs) {
      final data = d.data();
      final docId = d.id;

      // Check if user is the lead
      final docLeadId = (data['lead_id'] ?? '').toString().toLowerCase();
      final isLead = docLeadId == lowerEmpId;

      // Check if user is a member
      final members = data['members'] as Map<String, dynamic>? ?? {};
      final isMember = members.values.any((m) {
        if (m is Map<String, dynamic>) {
          return (m['emp_id'] ?? '').toString().toLowerCase() == lowerEmpId;
        }
        return false;
      });

      // Lead sees all their tasks (pending + approved)
      // Members only see approved tasks
      final status = (data['status'] ?? '').toString();
      if (isLead || (isMember && status != 'pending')) {
        if (!seenIds.contains(docId)) {
          seenIds.add(docId);
          data['id'] = docId;
          docs.add(data);
        }
      }
    }

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
  /// Attachments are saved as: [{type: "pdf"/"doc", url: "...", name: "..."}, ...]
  Future<void> createTask({
    List<Map<String, dynamic>>? members,
    required String lead_id,
    required String leadName,
    required String department,
    required String title,
    required String description,
    required String duration,
    required String taskType,
    List<Map<String, dynamic>>? attachments,
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

    // Calculate deadline from duration
    final durationDays = _durationToDays(duration);
    final deadline = DateTime.now().add(Duration(days: durationDays));

    final taskData = <String, dynamic>{
      'members': membersMap,
      'lead_id': lead_id,
      'leadName': leadName,
      'department': department,
      'title': title,
      'description': description,
      'duration': duration,
      'status': 'pending',
      'taskType': taskType,
      'createdAt': FieldValue.serverTimestamp(),
      'deadline': Timestamp.fromDate(deadline),
      'version': 1,
    };

    if (attachments != null && attachments.isNotEmpty) {
      taskData['attachments'] = attachments;
    }

    await _tasks.add(taskData);
  }

  /// Submit a task — saves summary, submission text, optional PDF URL
  Future<void> submitTask({
    required String taskId,
    required String summary,
    required String submissionText,
    required String submittedBy,
    required String submittedByRole,
    String? pdfUrl,
  }) async {
    await _tasks.doc(taskId).update({
      'status': 'submitted',
      'projectSummary': summary,
      'submissionText': submissionText,
      'submissionPdfUrl': pdfUrl ?? '',
      'submittedBy': submittedBy,
      'submittedByRole': submittedByRole,
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Member submits their individual work — stored per-member, does NOT change task status
  Future<void> submitMemberWork({
    required String taskId,
    required String empId,
    required String memberName,
    required String submissionText,
    String? pdfUrl,
  }) async {
    await _tasks.doc(taskId).update({
      'member_submissions.$empId': {
        'memberName': memberName,
        'submissionText': submissionText,
        'pdfUrl': pdfUrl ?? '',
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'submitted',
      },
    });
  }

  /// Lead accepts a member's submitted work
  Future<void> acceptMemberWork({
    required String taskId,
    required String empId,
  }) async {
    await _tasks.doc(taskId).update({
      'member_submissions.$empId.status': 'accepted',
      'member_submissions.$empId.reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Lead rejects a member's submitted work with a reason
  Future<void> rejectMemberWork({
    required String taskId,
    required String empId,
    required String reason,
  }) async {
    await _tasks.doc(taskId).update({
      'member_submissions.$empId.status': 'rejected',
      'member_submissions.$empId.rejectionReason': reason,
      'member_submissions.$empId.reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Lead pushes back all member submissions for corrections
  Future<void> pushBackToMembers(String taskId) async {
    final doc = await _tasks.doc(taskId).get();
    final data = doc.data();
    if (data == null) return;

    final submissions =
        data['member_submissions'] as Map<String, dynamic>? ?? {};
    final updates = <String, dynamic>{};
    for (final empId in submissions.keys) {
      updates['member_submissions.$empId.status'] = 'rejected';
      updates['member_submissions.$empId.rejectionReason'] =
          'Lead requested corrections after HR review';
      updates['member_submissions.$empId.reviewedAt'] =
          FieldValue.serverTimestamp();
    }

    if (updates.isNotEmpty) {
      await _tasks.doc(taskId).update(updates);
    }
  }

  /// Update an employee's department
  Future<void> updateEmployeeDepartment(String uid, String department) async {
    await _users.doc(uid).update({'department': department});
  }

  /// HR accepts a submitted task
  Future<void> acceptSubmission(String taskId) async {
    await _tasks.doc(taskId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// HR rejects a submitted task — sends back to approved
  Future<void> rejectSubmission(String taskId, String reason) async {
    await _tasks.doc(taskId).update({
      'status': 'approved',
      'rejectionReason': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Convert duration string to number of days
  static int _durationToDays(String duration) {
    switch (duration.toLowerCase()) {
      case 'weekly':
        return 7;
      case 'bi-weekly':
        return 14;
      case 'monthly':
        return 30;
      case 'bi-monthly':
        return 60;
      case 'quarterly':
        return 90;
      default:
        return 30;
    }
  }

  /// Update a task: saves the current version to history subcollection,
  /// then updates the main document with new values.
  Future<void> updateTask({
    required String taskId,
    required Map<String, dynamic> currentData,
    required String project_status_from_employeer,
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

    // Save previous description so both screens can show old vs new
    updateData['previousDescription'] = currentData['description'] ?? '';

    // Save approval timestamp and set employee status when task is approved
    if (newStatus == 'approved') {
      updateData['approvedAt'] = FieldValue.serverTimestamp();
      updateData['project_status_from_employee'] = 'pending';
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

  /// Update members map on a task document
  Future<void> updateTaskMembers({
    required String taskId,
    required Map<String, dynamic> membersMap,
  }) async {
    await _tasks.doc(taskId).update({'members': membersMap});
  }

  /// Fetch all users excluding HR (for lead + member selection)
  Future<List<Map<String, dynamic>>> getAllNonHRUsers() async {
    final snapshot = await _users.get();
    return snapshot.docs
        .where((doc) {
          final role = (doc.data()['role'] ?? '').toString().toLowerCase();
          return !role.contains('hr');
        })
        .map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return data;
        })
        .toList();
  }

  /// Fetch employees that have no lead_id (unassigned to any lead)
  /// Excludes HR users since they manage, not participate
  Future<List<Map<String, dynamic>>> getUnassignedEmployees() async {
    final snapshot = await _users.get();

    return snapshot.docs
        .where((doc) {
          final data = doc.data();

          final role = (data['role'] ?? '').toString().toLowerCase();
          final leadId = (data['lead_id'] ?? '').toString().trim();

          return leadId.isEmpty &&
              !role.contains('hr') &&
              !role.contains('project lead');
        })
        .map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return data;
        })
        .toList();
  }

  /// Assign a lead_id to an employee — requires lead approval
  Future<void> assignLeadToEmployee(
    String employeeUid,
    String leadEmpId,
  ) async {
    await _users.doc(employeeUid).update({
      'lead_id': leadEmpId,
      'team_status': 'pending_lead_approval',
    });
  }

  /// Remove lead_id from an employee's user document
  Future<void> removeLeadFromEmployee(String employeeUid) async {
    await _users.doc(employeeUid).update({
      'lead_id': '',
      'team_status': FieldValue.delete(),
    });
  }

  /// Lead accepts a pending team member
  Future<void> acceptTeamMember(String employeeUid) async {
    await _users.doc(employeeUid).update({'team_status': 'active_team_member'});
  }

  /// Lead rejects a pending team member
  Future<void> rejectTeamMember(String employeeUid) async {
    await _users.doc(employeeUid).update({
      'lead_id': '',
      'team_status': FieldValue.delete(),
    });
  }

  /// Fetch pending team members for a lead (awaiting approval)
  Future<List<Map<String, dynamic>>> getPendingTeamMembers(
    String leadEmpId,
  ) async {
    final snapshot = await _users.get();
    final lower = leadEmpId.toLowerCase();
    return snapshot.docs
        .where((doc) {
          final data = doc.data();
          final docLeadId = (data['lead_id'] ?? '').toString().toLowerCase();
          final status = (data['team_status'] ?? '').toString();
          return docLeadId == lower && status == 'pending_lead_approval';
        })
        .map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return data;
        })
        .toList();
  }

  /// Lead forwards a task to a specific member with additional instructions + attachments
  /// Stored in task document as member_tasks.$empId
  Future<void> forwardTaskToMember({
    required String taskId,
    required String empId,
    required String memberName,
    required String instructions,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final data = <String, dynamic>{
      'memberName': memberName,
      'instructions': instructions,
      'forwardedAt': FieldValue.serverTimestamp(),
      'status': 'assigned',
    };
    if (attachments != null && attachments.isNotEmpty) {
      data['attachments'] = attachments;
    }
    await _tasks.doc(taskId).update({'member_tasks.$empId': data});
  }

  /// Fetch active team members for a lead (accepted members only)
  Future<List<Map<String, dynamic>>> getActiveTeamMembers(
    String leadEmpId,
  ) async {
    final snapshot = await _users.get();
    final lower = leadEmpId.toLowerCase();
    return snapshot.docs
        .where((doc) {
          final data = doc.data();
          final docLeadId = (data['lead_id'] ?? '').toString().toLowerCase();
          final status = (data['team_status'] ?? '').toString();
          return docLeadId == lower && status == 'active_team_member';
        })
        .map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return data;
        })
        .toList();
  }

  // ── Task Notifications ─────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('task_notifications');

  /// Stream unread task notification count for a specific user (by emp_id or uid)
  Stream<int> streamUnreadTaskNotificationCount(String recipientId) {
    final lower = recipientId.toLowerCase();
    return _notifications
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.where((d) {
              final leadId = (d.data()['lead_id'] ?? '').toString().toLowerCase();
              return leadId == lower;
            }).length);
  }

  /// Stream all task notifications for a specific user
  Stream<List<Map<String, dynamic>>> streamTaskNotifications(String recipientId) {
    final lower = recipientId.toLowerCase();
    return _notifications
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .where((d) {
              final leadId = (d.data()['lead_id'] ?? '').toString().toLowerCase();
              return leadId == lower;
            })
            .map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            })
            .toList());
  }

  /// Mark a single task notification as read
  Future<void> markTaskNotificationRead(String notifId) async {
    await _notifications.doc(notifId).update({'read': true});
  }

  /// Clear (delete) all task notifications for a user
  Future<void> clearAllTaskNotifications(String recipientId) async {
    final lower = recipientId.toLowerCase();
    final snap = await _notifications.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      final leadId = (doc.data()['lead_id'] ?? '').toString().toLowerCase();
      if (leadId == lower) {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();
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
