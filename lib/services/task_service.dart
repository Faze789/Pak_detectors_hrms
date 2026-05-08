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

  /// Fetch tasks where the user is either the lead OR a member.
  ///
  /// FIX: Members now also see tasks where they appear in [member_tasks]
  /// (i.e. the lead has directly forwarded/assigned work to them), even if
  /// they were added to the members map but the task was still pending when
  /// the lead first forwarded. The auto-approve in [forwardTaskToAllMembers] /
  /// [forwardTaskToMember] makes these visible here immediately.
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

      // Check if user is in the members map (added by HR at task creation)
      final members = data['members'] as Map<String, dynamic>? ?? {};
      final isMember = members.values.any((m) {
        if (m is Map<String, dynamic>) {
          return (m['emp_id'] ?? '').toString().toLowerCase() == lowerEmpId;
        }
        return false;
      });

      // Check if the lead has already forwarded/assigned work directly to
      // this member (member_tasks.$empId exists). This is set by
      // forwardTaskToMember / forwardTaskToAllMembers / upsertWeeklyAssignment.
      final memberTasks = data['member_tasks'] as Map<String, dynamic>? ?? {};
      final hasDirectAssignment = memberTasks.keys.any(
        (k) => k.toLowerCase() == lowerEmpId,
      );

      final status = (data['status'] ?? '').toString();

      // Visibility rules:
      //  - Lead sees ALL their tasks regardless of status.
      //  - Member sees task once it is approved (status != 'pending').
      //  - Member ALSO sees task if the lead has already forwarded work
      //    directly to them (hasDirectAssignment) — this handles the case
      //    where the lead assigns before explicitly marking approved.
      //  - v2 fallback: for schemaVersion=2 tasks, members can see the task
      //    as soon as the lead has accepted (leadAcceptanceState != 'awaiting'),
      //    even if `status` is briefly stale. This guards the race where the
      //    lead saves a breakdown cell before the acceptance flip lands.
      final isV2 = data['schemaVersion'] == 2;
      final leadAccState = (data['leadAcceptanceState'] ?? 'awaiting')
          .toString();
      final shouldInclude =
          isLead ||
          (isMember && status != 'pending') ||
          hasDirectAssignment ||
          (isV2 && isMember && leadAccState != 'awaiting');

      if (shouldInclude && !seenIds.contains(docId)) {
        seenIds.add(docId);
        data['id'] = docId;
        docs.add(data);
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
  Future<String> createTask({
    List<Map<String, dynamic>>? members,
    required String lead_id,
    required String leadName,
    required String department,
    required String title,
    required String description,
    required bool unscheduled_task,
    required String duration,
    List<Map<String, dynamic>>? attachments,
    String? secondaryDescription,
    List<Map<String, dynamic>>? secondaryAttachments,
    String? createdBy,
    String? createdByName,
    String? createdByRole,
  }) async {
    final Map<String, dynamic> membersMap = {};
    if (members != null) {
      for (int i = 0; i < members.length; i++) {
        membersMap['${i + 1}'] = {
          'name': members[i]['name'] ?? '',
          'emp_id': members[i]['emp_id'] ?? '',
        };
      }
    }

    final durationDays = _durationToDays(duration);
    final cycleDays = _durationToCycleDays(duration);
    final now = DateTime.now();
    final deadline = now.add(Duration(days: durationDays));

    final totalWeeks = (durationDays / cycleDays).ceil();
    final List<Map<String, dynamic>> weeklyDeadlines = [];
    final List<Timestamp> weekStartDates = [];
    for (int w = 1; w <= totalWeeks; w++) {
      final cycleStart = now.add(Duration(days: cycleDays * (w - 1)));
      final cycleEnd = now.add(Duration(days: cycleDays * w));
      weekStartDates.add(Timestamp.fromDate(cycleStart));
      weeklyDeadlines.add({
        'week': w,
        'deadline': Timestamp.fromDate(
          cycleEnd.isAfter(deadline) ? deadline : cycleEnd,
        ),
        'assigned': false,
      });
    }

    final taskData = <String, dynamic>{
      'members': membersMap,
      'lead_id': lead_id,
      'leadName': leadName,
      'department': department,
      'title': title,
      'description': description,
      'unscheduled_task': unscheduled_task,
      'duration': duration,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'deadline': Timestamp.fromDate(deadline),
      'version': 1,
      'totalWeeks': totalWeeks,
      'weeklyDeadlines': weeklyDeadlines,
      'schemaVersion': 2,
      'weekStartDates': weekStartDates,
      'leadAcceptanceState': 'awaiting',
      'breakdownComplete': false,
      // Phase pointer: 1 by default. Bumped by upsertWeeklyAssignment when
      // the lead assigns a later week. The lead must actively assign each
      // phase — weeks > currentWeek do not have weekly_assignments docs yet.
      'currentWeek': 1,
    };

    if (attachments != null && attachments.isNotEmpty) {
      taskData['attachments'] = attachments;
    }

    if (secondaryDescription != null &&
        secondaryDescription.trim().isNotEmpty) {
      taskData['secondaryDescription'] = secondaryDescription.trim();
    }
    if (secondaryAttachments != null && secondaryAttachments.isNotEmpty) {
      taskData['secondaryAttachments'] = secondaryAttachments;
    }

    final ref = await _tasks.add(taskData);

    if (createdBy != null && createdBy.isNotEmpty) {
      final eventAttachments = <Map<String, dynamic>>[
        ...?attachments,
        ...?secondaryAttachments,
      ];
      await logEvent(
        taskId: ref.id,
        type: 'hr_create',
        actorId: createdBy,
        actorName: createdByName ?? '',
        actorRole: createdByRole ?? 'hr',
        payload: {
          'title': title,
          'description': description,
          'duration': duration,
          'totalWeeks': totalWeeks,
          'lead_id': lead_id,
          'leadName': leadName,
          'memberCount': membersMap.length,
          if (secondaryDescription != null &&
              secondaryDescription.trim().isNotEmpty)
            'secondaryDescription': secondaryDescription.trim(),
        },
        attachments: eventAttachments.isEmpty ? null : eventAttachments,
      );
    }

    return ref.id;
  }

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

  Future<void> submitMemberWork({
    required String taskId,
    required String empId,
    required String memberName,
    required String submissionText,
    String? pdfUrl,
    int? weekNumber, // ← add this parameter
  }) async {
    final taskDoc = await _tasks.doc(taskId).get();
    final resolvedWeek =
        weekNumber ?? (taskDoc.data()?['currentWeek'] as int?) ?? 1;

    await _tasks.doc(taskId).update({
      'member_submissions.$empId': {
        'memberName': memberName,
        'submissionText': submissionText,
        'pdfUrl': pdfUrl ?? '',
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'submitted',
        'weekNumber': resolvedWeek, // ← always stamp weekNumber
      },
    });
    // v2 bridge: append an attempt to the active week so the v2 review flow
    // (LeadReviewScreen, Assign-Week-N+1 visibility) sees the submission.
    await _bridgeV2Submit(
      taskId: taskId,
      empId: empId,
      submissionText: submissionText,
      pdfUrl: pdfUrl,
    );
  }

  Future<void> acceptMemberWork({
    required String taskId,
    required String empId,
  }) async {
    await _tasks.doc(taskId).update({
      'member_submissions.$empId.status': 'accepted',
      'member_submissions.$empId.reviewedAt': FieldValue.serverTimestamp(),
    });
    // v2 bridge: also flip the active week's last attempt to accepted so the
    // "Assign Week N+1 Tasks" CTA on the v2 review screen unlocks.
    await _bridgeV2Review(taskId: taskId, empId: empId, accept: true);
  }

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
    await _bridgeV2Review(
      taskId: taskId,
      empId: empId,
      accept: false,
      rejectReason: reason,
    );
  }

  // ── v2 bridges from legacy v1 entry points ────────────────────────
  // The legacy task card on EmployeeGoalsScreen uses `submitMemberWork` /
  // `acceptMemberWork` / `rejectMemberWork`. v2 tasks now also live inside
  // `weekly_assignments`, so these helpers mirror the same action there
  // when the task is `schemaVersion: 2`. Best-effort: missing docs / empty
  // attempts are silently skipped so we never break the legacy write.

  Future<void> _bridgeV2Submit({
    required String taskId,
    required String empId,
    required String submissionText,
    String? pdfUrl,
  }) async {
    try {
      final taskDoc = await _tasks.doc(taskId).get();
      final taskData = taskDoc.data();
      if (taskData == null) return;
      if (taskData['schemaVersion'] != 2) return;
      final currentWeek = (taskData['currentWeek'] ?? 1) as int;
      final docId = _weeklyAssignmentDocId(currentWeek, empId);
      final ref = _weeklyAssignments(taskId).doc(docId);
      final snap = await ref.get();
      // No active assignment for this member this week — nothing to bridge.
      if (!snap.exists) return;
      final attachments = (pdfUrl != null && pdfUrl.isNotEmpty)
          ? <Map<String, dynamic>>[
              {'url': pdfUrl, 'name': 'submission.pdf', 'type': 'pdf'},
            ]
          : null;
      await appendSubmissionAttempt(
        taskId: taskId,
        weekNumber: currentWeek,
        empId: empId,
        text: submissionText,
        attachments: attachments,
      );
    } catch (_) {
      // Best-effort — ignore.
    }
  }

  Future<void> _bridgeV2Review({
    required String taskId,
    required String empId,
    required bool accept,
    String? rejectReason,
  }) async {
    try {
      final taskDoc = await _tasks.doc(taskId).get();
      final taskData = taskDoc.data();
      if (taskData == null) return;
      if (taskData['schemaVersion'] != 2) return;
      final currentWeek = (taskData['currentWeek'] ?? 1) as int;
      final docId = _weeklyAssignmentDocId(currentWeek, empId);
      final ref = _weeklyAssignments(taskId).doc(docId);
      final snap = await ref.get();
      if (!snap.exists) return;
      final attempts = (snap.data()?['attempts'] as List?) ?? const <dynamic>[];
      // If the legacy submit flow ran but the v2 bridge missed (e.g. doc was
      // created later), seed a synthetic attempt so we have something to
      // accept/reject. Otherwise reviewLastAttempt is a no-op.
      if (attempts.isEmpty) {
        await appendSubmissionAttempt(
          taskId: taskId,
          weekNumber: currentWeek,
          empId: empId,
          text: '(Submitted via legacy flow)',
        );
      }
      await reviewLastAttempt(
        taskId: taskId,
        weekNumber: currentWeek,
        empId: empId,
        accept: accept,
        rejectReason: rejectReason,
        reviewerId: '',
      );
    } catch (_) {
      // Best-effort — ignore.
    }
  }

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

  Future<void> updateEmployeeDepartment(String uid, String department) async {
    await _users.doc(uid).update({'department': department});
  }

  Future<void> acceptSubmission(String taskId) async {
    await _tasks.doc(taskId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectSubmission(String taskId, String reason) async {
    await _tasks.doc(taskId).update({
      'status': 'approved',
      'rejectionReason': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  static int _durationToDays(String duration) {
    switch (duration.toLowerCase()) {
      case 'weekly':
        return 7;
      case 'bi-weekly':
        return 14;
      case 'monthly':
        return 28;
      case 'bi-monthly':
        return 56;
      case 'quarterly':
        return 84;
      default:
        return 28;
    }
  }

  static int _durationToCycleDays(String duration) {
    switch (duration.toLowerCase()) {
      case 'quarterly':
      case 'bi-monthly':
        return 14;
      default:
        return 7;
    }
  }

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
    String? newPrimaryGoal,
    String? newNormalGoal,
  }) async {
    final taskRef = _tasks.doc(taskId);
    final currentVersion = (currentData['version'] ?? 1) as int;

    await taskRef.collection('history').add({
      'title': currentData['title'] ?? '',
      'description': currentData['description'] ?? '',
      'secondaryDescription': currentData['secondaryDescription'] ?? '',
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

    final updateData = <String, dynamic>{
      'title': newTitle,
      'description': newDescription,
      'duration': newDuration,
      'status': newStatus,
      'version': currentVersion + 1,
      'lastModifiedAt': FieldValue.serverTimestamp(),
      'lastModifiedBy': modifiedBy,
      'lastModifiedByRole': modifiedByRole,
      'previousDescription': currentData['description'] ?? '',
    };

    if (newPrimaryGoal != null) {
      updateData['description'] = newPrimaryGoal;
    }
    if (newNormalGoal != null) {
      updateData['secondaryDescription'] = newNormalGoal;
    }

    if (newStatus == 'approved') {
      updateData['approvedAt'] = FieldValue.serverTimestamp();
      updateData['project_status_from_employee'] = 'pending';
    }

    await taskRef.update(updateData);
  }

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

  Future<void> updateTaskMembers({
    required String taskId,
    required Map<String, dynamic> membersMap,
  }) async {
    await _tasks.doc(taskId).update({'members': membersMap});
  }

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

  Future<void> assignLeadToEmployee(
    String employeeUid,
    String leadEmpId,
  ) async {
    await _users.doc(employeeUid).update({
      'lead_id': leadEmpId,
      'team_status': 'pending_lead_approval',
    });
  }

  Future<void> removeLeadFromEmployee(String employeeUid) async {
    await _users.doc(employeeUid).update({
      'lead_id': '',
      'team_status': FieldValue.delete(),
    });
  }

  Future<void> acceptTeamMember(String employeeUid) async {
    await _users.doc(employeeUid).update({'team_status': 'active_team_member'});
  }

  Future<void> rejectTeamMember(String employeeUid) async {
    await _users.doc(employeeUid).update({
      'lead_id': '',
      'team_status': FieldValue.delete(),
    });
  }

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

  /// Forward a task to a specific member.
  ///
  /// FIX: Auto-approves the task when it is still 'pending' so the member
  /// can immediately see it in their goals screen.
  Future<void> forwardTaskToMember({
    required String taskId,
    required String empId,
    required String memberName,
    required String instructions,
    int? weekNumber,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final data = <String, dynamic>{
      'memberName': memberName,
      'instructions': instructions,
      'forwardedAt': FieldValue.serverTimestamp(),
      'status': 'assigned',
    };
    if (weekNumber != null) {
      data['weekNumber'] = weekNumber;
    }
    if (attachments != null && attachments.isNotEmpty) {
      data['attachments'] = attachments;
    }

    final updateData = <String, dynamic>{'member_tasks.$empId': data};

    // ── Mark the week as assigned ─────────────────────────────────
    if (weekNumber != null) {
      final taskDoc = await _tasks.doc(taskId).get();
      final taskData = taskDoc.data();
      if (taskData != null) {
        final deadlines = List<Map<String, dynamic>>.from(
          (taskData['weeklyDeadlines'] as List? ?? []).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        );
        for (int i = 0; i < deadlines.length; i++) {
          if (deadlines[i]['week'] == weekNumber) {
            deadlines[i]['assigned'] = true;
            break;
          }
        }
        updateData['weeklyDeadlines'] = deadlines;

        // ── FIX: auto-approve so member sees task immediately ─────
        final currentStatus = (taskData['status'] ?? '').toString();
        if (currentStatus == 'pending') {
          updateData['status'] = 'approved';
          updateData['approvedAt'] = FieldValue.serverTimestamp();
        }
      }
    }

    await _tasks.doc(taskId).update(updateData);
  }

  /// Forward a task to ALL members for a specific week.
  ///
  /// FIX: Auto-approves the task when it is still 'pending' so all members
  /// can immediately see it in their goals screen.
  Future<void> forwardTaskToAllMembers({
    required String taskId,
    required Map<String, dynamic> members,
    required String instructions,
    required int weekNumber,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final updateData = <String, dynamic>{};

    for (final entry in members.entries) {
      final m = entry.value as Map<String, dynamic>;
      final empId = (m['emp_id'] ?? '').toString();
      if (empId.isEmpty) continue;

      final data = <String, dynamic>{
        'memberName': m['name'] ?? '',
        'instructions': instructions,
        'forwardedAt': FieldValue.serverTimestamp(),
        'status': 'assigned',
        'weekNumber': weekNumber,
      };
      if (attachments != null && attachments.isNotEmpty) {
        data['attachments'] = attachments;
      }
      updateData['member_tasks.$empId'] = data;

      if (weekNumber > 1) {
        updateData['member_submissions.$empId'] = FieldValue.delete();
      }
    }

    // ── Mark the week as assigned ─────────────────────────────────
    final taskDoc = await _tasks.doc(taskId).get();
    final taskData = taskDoc.data();
    if (taskData != null) {
      final deadlines = List<Map<String, dynamic>>.from(
        (taskData['weeklyDeadlines'] as List? ?? []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      for (int i = 0; i < deadlines.length; i++) {
        if (deadlines[i]['week'] == weekNumber) {
          deadlines[i]['assigned'] = true;
          break;
        }
      }
      updateData['weeklyDeadlines'] = deadlines;

      // ── FIX: auto-approve so members see task immediately ─────────
      final currentStatus = (taskData['status'] ?? '').toString();
      if (currentStatus == 'pending') {
        updateData['status'] = 'approved';
        updateData['approvedAt'] = FieldValue.serverTimestamp();
      }
    }

    await _tasks.doc(taskId).update(updateData);
  }

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

  Future<String> assignAdHocTask({
    required String leadEmpId,
    required String leadName,
    required String memberEmpId,
    required String memberName,
    required String department,
    required String title,
    required String description,
    required DateTime deadline,
  }) async {
    final now = DateTime.now();
    final maxDeadline = now.add(const Duration(days: 6));
    if (!deadline.isAfter(now)) {
      throw Exception('Deadline must be in the future.');
    }
    if (deadline.isAfter(maxDeadline)) {
      throw Exception('Ad-hoc deadline must be less than 6 days from now.');
    }

    final taskData = <String, dynamic>{
      'isAdHoc': true,
      'taskType': 'ad-hoc',
      'lead_id': leadEmpId,
      'leadName': leadName,
      'department': department,
      'title': title,
      'description': description,
      'duration': 'ad-hoc',
      'status': 'approved',
      'createdAt': FieldValue.serverTimestamp(),
      'deadline': Timestamp.fromDate(deadline),
      'version': 1,
      'totalWeeks': 1,
      'weeklyDeadlines': [
        {'week': 1, 'deadline': Timestamp.fromDate(deadline), 'assigned': true},
      ],
      'members': {
        '1': {'name': memberName, 'emp_id': memberEmpId},
      },
      'member_tasks': {
        memberEmpId: {
          'memberName': memberName,
          'instructions': description,
          'forwardedAt': FieldValue.serverTimestamp(),
          'status': 'assigned',
          'weekNumber': 1,
        },
      },
    };

    final ref = await _tasks.add(taskData);
    return ref.id;
  }

  Future<void> submitNoSubmissionReason({
    required String taskId,
    required String empId,
    required String empName,
    required String role,
    required String reason,
    int? forWeek,
  }) async {
    final entry = <String, dynamic>{
      'empId': empId,
      'empName': empName,
      'role': role,
      'reason': reason,
      'submittedAt': Timestamp.now(),
      'sentTo': role == 'member' ? 'lead' : 'hr',
    };
    if (forWeek != null) entry['forWeek'] = forWeek;

    await _tasks.doc(taskId).update({
      'no_submission_reasons': FieldValue.arrayUnion([entry]),
    });
  }

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('task_notifications');

  Stream<int> streamUnreadTaskNotificationCount(String recipientId) {
    final lower = recipientId.toLowerCase();
    return _notifications
        .where('read', isEqualTo: false)
        .snapshots()
        .map(
          (snap) => snap.docs.where((d) {
            final leadId = (d.data()['lead_id'] ?? '').toString().toLowerCase();
            return leadId == lower;
          }).length,
        );
  }

  Stream<List<Map<String, dynamic>>> streamTaskNotifications(
    String recipientId,
  ) {
    final lower = recipientId.toLowerCase();
    return _notifications
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .where((d) {
                final leadId = (d.data()['lead_id'] ?? '')
                    .toString()
                    .toLowerCase();
                return leadId == lower;
              })
              .map((d) {
                final data = d.data();
                data['id'] = d.id;
                return data;
              })
              .toList(),
        );
  }

  Future<void> markTaskNotificationRead(String notifId) async {
    await _notifications.doc(notifId).update({'read': true});
  }

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

  // ── v2 Audit Events ────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _events(String taskId) =>
      _tasks.doc(taskId).collection('events');

  Future<String> logEvent({
    required String taskId,
    required String type,
    required String actorId,
    required String actorName,
    required String actorRole,
    int? weekNumber,
    String? memberEmpId,
    Map<String, dynamic>? payload,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final data = <String, dynamic>{
      'type': type,
      'actorId': actorId,
      'actorName': actorName,
      'actorRole': actorRole,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (weekNumber != null) data['weekNumber'] = weekNumber;
    if (memberEmpId != null && memberEmpId.isNotEmpty) {
      data['memberEmpId'] = memberEmpId.toLowerCase();
    }
    if (payload != null && payload.isNotEmpty) data['payload'] = payload;
    if (attachments != null && attachments.isNotEmpty) {
      data['attachments'] = attachments;
    }
    final ref = await _events(taskId).add(data);
    return ref.id;
  }

  Stream<List<Map<String, dynamic>>> streamEvents(String taskId) {
    return _events(taskId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final m = d.data();
            m['id'] = d.id;
            return m;
          }).toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> streamEventsForMember(
    String taskId,
    String empId,
  ) {
    final lower = empId.toLowerCase();
    const taskLevelTypes = <String>{
      'hr_create',
      'hr_edit',
      'hr_attach',
      'hr_accept',
      'hr_reject',
      'lead_accept_as_is',
      'lead_edit_and_accept',
      'lead_team_change',
      'lead_submit_to_hr',
    };
    return streamEvents(taskId).map((events) {
      return events.where((e) {
        final type = (e['type'] ?? '').toString();
        if (taskLevelTypes.contains(type)) return true;
        final mid = (e['memberEmpId'] ?? '').toString().toLowerCase();
        return mid == lower;
      }).toList();
    });
  }

  // ── v2 Weekly Assignments ─────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _weeklyAssignments(String taskId) =>
      _tasks.doc(taskId).collection('weekly_assignments');

  String _weeklyAssignmentDocId(int weekNumber, String empId) =>
      '${weekNumber}_${empId.toLowerCase()}';

  /// Create or update a weekly assignment for one (week, member) pair.
  /// Idempotent — safe to call again to edit the instruction/attachments.
  ///
  /// **Phase activation is implicit.** When `weekNumber > task.currentWeek`,
  /// the call atomically:
  ///   * stamps `startDate = NOW`, `endDate = NOW + cycleLength` on the new
  ///     (week, member) doc
  ///   * bumps `task.currentWeek` to `weekNumber` and updates the parent's
  ///     `weekStartDates[weekNumber-1]` and `weeklyDeadlines[weekNumber-1]`
  ///   * closes the prior week's docs (`endDate = startDate of new week`)
  ///     so the previous phase falls into read-only history
  ///
  /// When `weekNumber == task.currentWeek`, the call edits in place: dates
  /// are taken from the existing schedule and preserved across attempts.
  Future<void> upsertWeeklyAssignment({
    required String taskId,
    required int weekNumber,
    required String empId,
    required String memberName,
    required String instruction,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final taskRef = _tasks.doc(taskId);
    final taskDoc = await taskRef.get();
    final taskData = taskDoc.data() ?? <String, dynamic>{};

    final taskCurrentWeek = (taskData['currentWeek'] ?? 1) as int;
    final isActivation = weekNumber > taskCurrentWeek;

    // Resolve start/end for THIS week.
    Timestamp startDate;
    Timestamp endDate;
    if (isActivation) {
      final cycleDays = _durationToCycleDays(
        (taskData['duration'] ?? 'monthly').toString(),
      );
      final now = Timestamp.now();
      startDate = now;
      endDate = Timestamp.fromDate(now.toDate().add(Duration(days: cycleDays)));
    } else {
      final starts = ((taskData['weekStartDates'] as List?) ?? <dynamic>[])
          .whereType<Timestamp>()
          .toList();
      final deadlines = ((taskData['weeklyDeadlines'] as List?) ?? <dynamic>[])
          .whereType<Map>()
          .toList();
      startDate = (weekNumber - 1) < starts.length
          ? starts[weekNumber - 1]
          : Timestamp.now();
      Timestamp? end;
      for (final d in deadlines) {
        if (d['week'] == weekNumber) {
          final t = d['deadline'];
          if (t is Timestamp) end = t;
          break;
        }
      }
      endDate = end ?? startDate;
    }

    final docId = _weeklyAssignmentDocId(weekNumber, empId);
    final ref = _weeklyAssignments(taskId).doc(docId);
    final snap = await ref.get();

    final base = <String, dynamic>{
      'taskId': taskId,
      'weekNumber': weekNumber,
      'empId': empId.toLowerCase(),
      'memberName': memberName,
      'instruction': instruction,
      'attachments': attachments ?? <Map<String, dynamic>>[],
      'startDate': startDate,
      'endDate': endDate,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isActivation || !snap.exists) {
      base['status'] = 'pending';
      base['attempts'] = <Map<String, dynamic>>[];
      base['barrier'] = null;
      base['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(base, SetOptions(merge: true));

    // Auto-approve parent task so the member sees it.
    final currentStatus = (taskData['status'] ?? '').toString();
    if (currentStatus == 'pending') {
      await taskRef.update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });
    }

    // Implicit activation of a later week: sync parent metadata + close prior.
    if (isActivation) {
      final starts = ((taskData['weekStartDates'] as List?) ?? <dynamic>[])
          .whereType<Timestamp>()
          .toList();
      final deadlines = List<Map<String, dynamic>>.from(
        ((taskData['weeklyDeadlines'] as List?) ?? <dynamic>[]).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      while (starts.length < weekNumber) {
        starts.add(startDate);
      }
      starts[weekNumber - 1] = startDate;
      bool foundEntry = false;
      for (int i = 0; i < deadlines.length; i++) {
        if (deadlines[i]['week'] == weekNumber) {
          deadlines[i]['deadline'] = endDate;
          foundEntry = true;
        }
      }
      if (!foundEntry) {
        deadlines.add({
          'week': weekNumber,
          'deadline': endDate,
          'assigned': true,
        });
      }
      // Close prior week (endDate = NOW) and set its deadline accordingly.
      final priorWeek = weekNumber - 1;
      if (priorWeek >= 1) {
        for (int i = 0; i < deadlines.length; i++) {
          if (deadlines[i]['week'] == priorWeek) {
            deadlines[i]['deadline'] = startDate;
          }
        }
        final priorSnap = await _weeklyAssignments(
          taskId,
        ).where('weekNumber', isEqualTo: priorWeek).get();
        for (final d in priorSnap.docs) {
          await d.reference.update({
            'endDate': startDate,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      await taskRef.update({
        'currentWeek': weekNumber,
        'weekStartDates': starts,
        'weeklyDeadlines': deadlines,
      });
    }

    // ── Reset the legacy member_submissions entry for THIS member ──
    // The legacy member task card (in EmployeeGoalsScreen) reads
    // `member_submissions.{empId}` to decide whether to show "Submit Now"
    // or "Submitted to Lead". After the lead activates a new (week, member)
    // pair, the member's UI must reset to the fresh-week state.
    //
    // The reset is gated on `!snap.exists` (this is a brand-new (week,
    // member) doc) instead of `isActivation` because in a multi-member save
    // only the first call sees `isActivation == true` — by the time the
    // second member's call lands, `task.currentWeek` is already bumped.
    // Using `!snap.exists` runs this clear once per fresh weekly assignment,
    // covering every member of the new week.
    if (!snap.exists) {
      try {
        await taskRef.update({
          'member_submissions.$empId': FieldValue.delete(),
          'member_submissions.${empId.toLowerCase()}': FieldValue.delete(),
          'member_submissions.${empId.toUpperCase()}': FieldValue.delete(),
        });
      } on FirebaseException {
        // Best-effort — ignore.
      }
    }

    // Mirror a lightweight flag into the parent task's `member_tasks` map so
    // [getTasksForUser]'s `hasDirectAssignment` check picks this member up
    // even on pre-v2-aware UI surfaces.
    await taskRef.set({
      'member_tasks': {
        empId.toLowerCase(): {
          'memberName': memberName,
          'instructions': instruction,
          'forwardedAt': FieldValue.serverTimestamp(),
          'status': 'assigned',
          'weekNumber': weekNumber,
        },
      },
    }, SetOptions(merge: true));
    // At the end of upsertWeeklyAssignment, after the member_tasks mirror write:
    // Mark this week as assigned in weeklyDeadlines
    final latestTaskDoc = await taskRef.get();
    final latestData = latestTaskDoc.data() ?? <String, dynamic>{};
    final latestDeadlines = List<Map<String, dynamic>>.from(
      ((latestData['weeklyDeadlines'] as List?) ?? <dynamic>[]).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    bool changed = false;
    for (int i = 0; i < latestDeadlines.length; i++) {
      if (latestDeadlines[i]['week'] == weekNumber &&
          latestDeadlines[i]['assigned'] != true) {
        latestDeadlines[i]['assigned'] = true;
        changed = true;
      }
    }
    if (changed) {
      await taskRef.update({'weeklyDeadlines': latestDeadlines});
    }
  }

  Stream<Map<String, dynamic>?> streamWeeklyAssignment({
    required String taskId,
    required int weekNumber,
    required String empId,
  }) {
    final docId = _weeklyAssignmentDocId(weekNumber, empId);
    return _weeklyAssignments(taskId).doc(docId).snapshots().map((d) {
      if (!d.exists) return null;
      final m = d.data() ?? <String, dynamic>{};
      m['id'] = d.id;
      return m;
    });
  }

  Stream<List<Map<String, dynamic>>> streamWeeklyAssignmentsForWeek({
    required String taskId,
    required int weekNumber,
  }) {
    return _weeklyAssignments(taskId)
        .where('weekNumber', isEqualTo: weekNumber)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final m = d.data();
            m['id'] = d.id;
            return m;
          }).toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> streamWeeklyAssignmentsForMember({
    required String taskId,
    required String empId,
  }) {
    return _weeklyAssignments(taskId)
        .where('empId', isEqualTo: empId.toLowerCase())
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final m = d.data();
            m['id'] = d.id;
            return m;
          }).toList(),
        );
  }

  Future<List<Map<String, dynamic>>> getAllWeeklyAssignments(
    String taskId,
  ) async {
    final snap = await _weeklyAssignments(taskId).get();
    return snap.docs.map((d) {
      final m = d.data();
      m['id'] = d.id;
      return m;
    }).toList();
  }

  Future<void> markBreakdownComplete(String taskId, bool complete) async {
    await _tasks.doc(taskId).update({'breakdownComplete': complete});
  }

  Future<void> setLeadAcceptanceState({
    required String taskId,
    required String state,
    required String leadEmpId,
  }) async {
    await _tasks.doc(taskId).update({
      'leadAcceptanceState': state,
      'leadAcceptedAt': FieldValue.serverTimestamp(),
      'leadAcceptedBy': leadEmpId,
      if (state != 'awaiting') 'status': 'approved',
    });
  }

  Future<void> applyLeadEdits({
    required String taskId,
    String? title,
    String? description,
    String? secondaryDescription,
    List<Map<String, dynamic>>? attachments,
    List<Map<String, dynamic>>? secondaryAttachments,
  }) async {
    final update = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (title != null) update['title'] = title;
    if (description != null) update['description'] = description;
    if (secondaryDescription != null) {
      update['secondaryDescription'] = secondaryDescription;
    }
    if (attachments != null) update['attachments'] = attachments;
    if (secondaryAttachments != null) {
      update['secondaryAttachments'] = secondaryAttachments;
    }
    await _tasks.doc(taskId).update(update);
  }

  // ── v2 Submission attempts ─────────────────────────────────────────

  Future<int> appendSubmissionAttempt({
    required String taskId,
    required int weekNumber,
    required String empId,
    required String text,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final docRef = _weeklyAssignments(
      taskId,
    ).doc(_weeklyAssignmentDocId(weekNumber, empId));
    final snap = await docRef.get();
    final data = snap.data() ?? <String, dynamic>{};
    final existing = List<Map<String, dynamic>>.from(
      ((data['attempts'] as List?) ?? <dynamic>[]).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final newAttempt = <String, dynamic>{
      'attemptNumber': existing.length + 1,
      'text': text,
      'attachments': attachments ?? <Map<String, dynamic>>[],
      'submittedAt': Timestamp.now(),
      'status': 'submitted',
    };
    existing.add(newAttempt);
    await docRef.update({
      'attempts': existing,
      'status': 'submitted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return existing.length;
  }

  Future<void> reviewLastAttempt({
    required String taskId,
    required int weekNumber,
    required String empId,
    required bool accept,
    String? rejectReason,
    required String reviewerId,
  }) async {
    final docRef = _weeklyAssignments(
      taskId,
    ).doc(_weeklyAssignmentDocId(weekNumber, empId));
    final snap = await docRef.get();
    final data = snap.data();
    if (data == null) return;
    final attempts = List<Map<String, dynamic>>.from(
      ((data['attempts'] as List?) ?? <dynamic>[]).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    if (attempts.isEmpty) return;
    final last = Map<String, dynamic>.from(attempts.last);
    last['status'] = accept ? 'accepted' : 'rejected';
    last['reviewedBy'] = reviewerId;
    last['reviewedAt'] = Timestamp.now();
    if (!accept && rejectReason != null && rejectReason.trim().isNotEmpty) {
      last['rejectReason'] = rejectReason.trim();
    }
    attempts[attempts.length - 1] = last;
    await docRef.update({
      'attempts': attempts,
      'status': accept ? 'accepted' : 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setBarrier({
    required String taskId,
    required int weekNumber,
    required String empId,
    required String reason,
  }) async {
    final docRef = _weeklyAssignments(
      taskId,
    ).doc(_weeklyAssignmentDocId(weekNumber, empId));
    await docRef.update({
      'status': 'barrier',
      'barrier': {
        'reason': reason,
        'raisedAt': Timestamp.now(),
        'role': 'member',
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitV2TaskToHr({
    required String taskId,
    String? summary,
  }) async {
    await _tasks.doc(taskId).update({
      'status': 'submitted',
      'submittedAt': FieldValue.serverTimestamp(),
      if (summary != null && summary.trim().isNotEmpty)
        'projectSummary': summary.trim(),
    });
  }

  /// Activate the next week immediately.
  ///
  /// Closes the current week (its `endDate` is set to NOW so it falls into
  /// the read-only / barrier state) and shifts week N+1..totalWeeks so each
  /// gets a fresh `cycleLength` window starting at NOW. Both the parent
  /// task's `weekStartDates` / `weeklyDeadlines` and every affected
  /// `weekly_assignments` doc are kept in sync.
  ///
  /// Used by the lead in two scenarios per spec:
  ///   * all members of the current week are accepted before the deadline
  ///   * the current week's deadline has passed and the lead wants to move on
  Future<void> activateNextWeek({
    required String taskId,
    required int currentWeekNumber,
  }) async {
    final taskRef = _tasks.doc(taskId);
    final taskDoc = await taskRef.get();
    final taskData = taskDoc.data();
    if (taskData == null) return;

    final totalWeeks = (taskData['totalWeeks'] ?? 0) as int;
    final nextWeek = currentWeekNumber + 1;
    if (nextWeek > totalWeeks) return;

    final now = Timestamp.now();
    final nowDt = now.toDate();

    final starts = List<Timestamp>.from(
      ((taskData['weekStartDates'] as List?) ?? const <dynamic>[])
          .whereType<Timestamp>(),
    );
    while (starts.length < totalWeeks) {
      starts.add(now);
    }

    final deadlines = List<Map<String, dynamic>>.from(
      ((taskData['weeklyDeadlines'] as List?) ?? const <dynamic>[]).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );

    // Compute cycle length from next week's original schedule (fallback 7d).
    Duration cycle = const Duration(days: 7);
    if ((nextWeek - 1) < starts.length) {
      final origNextStart = starts[nextWeek - 1].toDate();
      Timestamp? origNextEnd;
      for (final d in deadlines) {
        if (d['week'] == nextWeek) {
          final t = d['deadline'];
          if (t is Timestamp) origNextEnd = t;
          break;
        }
      }
      if (origNextEnd != null) {
        cycle = origNextEnd.toDate().difference(origNextStart);
        if (cycle.inSeconds <= 0) cycle = const Duration(days: 7);
      }
    }

    // Close current week (its deadline becomes NOW).
    for (int i = 0; i < deadlines.length; i++) {
      if (deadlines[i]['week'] == currentWeekNumber) {
        deadlines[i]['deadline'] = now;
      }
    }

    // Shift week N+1..total: each starts cycle apart from NOW.
    for (int w = nextWeek; w <= totalWeeks; w++) {
      final newStart = nowDt.add(cycle * (w - nextWeek));
      final newEnd = nowDt.add(cycle * (w - nextWeek + 1));
      starts[w - 1] = Timestamp.fromDate(newStart);
      for (int i = 0; i < deadlines.length; i++) {
        if (deadlines[i]['week'] == w) {
          deadlines[i]['deadline'] = Timestamp.fromDate(newEnd);
        }
      }
    }

    await taskRef.update({
      'weekStartDates': starts,
      'weeklyDeadlines': deadlines,
    });

    // Close out current week's weekly_assignments docs (endDate = NOW).
    final curSnap = await _weeklyAssignments(
      taskId,
    ).where('weekNumber', isEqualTo: currentWeekNumber).get();
    for (final doc in curSnap.docs) {
      await doc.reference.update({
        'endDate': now,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Update weekly_assignments for shifted weeks.
    for (int w = nextWeek; w <= totalWeeks; w++) {
      final newStart = Timestamp.fromDate(nowDt.add(cycle * (w - nextWeek)));
      final newEnd = Timestamp.fromDate(nowDt.add(cycle * (w - nextWeek + 1)));
      final wkSnap = await _weeklyAssignments(
        taskId,
      ).where('weekNumber', isEqualTo: w).get();
      for (final doc in wkSnap.docs) {
        await doc.reference.update({
          'startDate': newStart,
          'endDate': newEnd,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }
}
