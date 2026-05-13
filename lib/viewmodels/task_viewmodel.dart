import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/task_service.dart';

class TaskViewModel extends ChangeNotifier {
  final TaskService _service;

  TaskViewModel({TaskService? service}) : _service = service ?? TaskService();

  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _unassignedEmployees = [];
  List<Map<String, dynamic>> _taskHistory = [];
  String project_status_from_employeer = 'pending';
  bool isLoading = false;
  String? errorMessage;

  bool _submitting = false;

  bool get isSubmitting => _submitting;

  List<Map<String, dynamic>> _allUsers = [];

  List<Map<String, dynamic>> get tasks => _tasks;
  List<Map<String, dynamic>> get members => _members;
  List<Map<String, dynamic>> get unassignedEmployees => _unassignedEmployees;
  List<Map<String, dynamic>> get allUsers => _allUsers;
  List<Map<String, dynamic>> get taskHistory => _taskHistory;

  /// Load all tasks for a specific lead by emp_id
  Future<void> loadTasksForLead(String empId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _tasks = await _service.getTasksByEmpId(empId);
    } catch (e) {
      errorMessage = 'Failed to load tasks: $e';
      _tasks = [];
    }

    isLoading = false;
    notifyListeners();
  }

  // Fetch all tasks

  Future<void> loadAllTasks() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _tasks = await _service.getAllTasks();
    } catch (e) {
      errorMessage = 'Failed to load tasks: $e';
      _tasks = [];
    }

    isLoading = false;
    notifyListeners();
  }

  /// Load tasks where lead_id matches the logged-in lead's emp_id
  Future<void> loadTasksByLeadId(String leadEmpId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _tasks = await _service.getTasksByLeadId(leadEmpId);
    } catch (e) {
      errorMessage = 'Failed to load tasks: $e';
      _tasks = [];
    }

    isLoading = false;
    notifyListeners();
  }

  /// Load team members whose lead_id matches the lead's emp_id
  Future<void> loadMembersByLeadId(String leadEmpId) async {
    debugPrint('[TaskVM] loadMembersByLeadId called with: "$leadEmpId"');
    try {
      _members = await _service.getMembersByLeadId(leadEmpId);
      debugPrint('[TaskVM] Members found: ${_members.length}');
      for (final m in _members) {
        debugPrint('[TaskVM]   - ${m['name']} (lead_id: ${m['lead_id']})');
      }
    } catch (e) {
      debugPrint('[TaskVM] ERROR loading members: $e');
      _members = [];
    }
    notifyListeners();
  }

  /// Load tasks where the employee is listed as a member
  Future<void> loadTasksForEmployee(String empId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _tasks = await _service.getTasksByMemberEmpId(empId);
    } catch (e) {
      errorMessage = 'Failed to load tasks: $e';
      _tasks = [];
    }

    isLoading = false;
    notifyListeners();
  }

  /// Load tasks where the user is either the lead OR a member
  Future<void> loadTasksForUser(String empId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      _tasks = await _service.getTasksForUser(empId);
    } catch (e) {
      errorMessage = 'Failed to load tasks: $e';
      _tasks = [];
    }

    isLoading = false;
    notifyListeners();
  }

  /// Load all users excluding HR (for lead + member selection by HR)
  Future<void> loadAllNonHRUsers() async {
    try {
      _allUsers = await _service.getAllNonHRUsers();
    } catch (e) {
      debugPrint('[TaskVM] ERROR loading all users: $e');
      _allUsers = [];
    }
    notifyListeners();
  }

  /// Load employees that have no lead_id (available to assign)
  Future<void> loadUnassignedEmployees() async {
    try {
      _unassignedEmployees = await _service.getUnassignedEmployees();
    } catch (e) {
      debugPrint('[TaskVM] ERROR loading unassigned employees: $e');
      _unassignedEmployees = [];
    }
    notifyListeners();
  }

  /// Assign lead_id to an employee's document and refresh both lists
  Future<bool> assignEmployeeToLead(
    String employeeUid,
    String leadEmpId,
  ) async {
    try {
      await _service.assignLeadToEmployee(employeeUid, leadEmpId);
      return true;
    } catch (e) {
      errorMessage = 'Failed to assign employee to lead: $e';
      return false;
    }
  }

  /// Remove lead_id from an employee's document
  Future<bool> removeEmployeeFromLead(String employeeUid) async {
    try {
      await _service.removeLeadFromEmployee(employeeUid);
      return true;
    } catch (e) {
      errorMessage = 'Failed to remove employee from lead: $e';
      return false;
    }
  }

  /// Submit a new task and refresh the list.
  ///
  /// `createdBy*` are forwarded to [TaskService.createTask] so the hr_create
  /// audit event can be written. They're optional only for backward compat
  /// with any pre-v2 callers; the HR form now always passes them.
  Future<bool> assignTask({
    List<Map<String, dynamic>>? members,
    required String lead_id,
    required String leadName,
    required String department,
    required String title,
    required String description,
    required bool unscheduled_task,
    required String duration,
    int? customDurationDays,
    // String taskType = 'primary',
    List<Map<String, dynamic>>? attachments,
    String? secondaryDescription,
    List<Map<String, dynamic>>? secondaryAttachments,
    String? createdBy,
    String? createdByName,
    String? createdByRole,
  }) async {
    _submitting = true;
    notifyListeners();

    try {
      final newTaskId = await _service.createTask(
        members: members,
        lead_id: lead_id,
        leadName: leadName,
        department: department,
        title: title,
        description: description,
        unscheduled_task: unscheduled_task,
        duration: duration,
        customDurationDays: customDurationDays,
        attachments: attachments,
        secondaryDescription: secondaryDescription,
        secondaryAttachments: secondaryAttachments,
        createdBy: createdBy,
        createdByName: createdByName,
        createdByRole: createdByRole,
      );

      // Notify the lead about the new task assignment
      if (lead_id.isNotEmpty) {
        await FirebaseFirestore.instance.collection('task_notifications').add({
          'lead_id': lead_id,
          'taskId': newTaskId,
          'title': 'New Task Assigned',
          'body': '"$title" has been assigned to you by HR',
          'type': 'task',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      await loadTasksForLead(lead_id);
      _submitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to assign task: $e';
      _submitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Edit an existing task: saves old version to history, updates document
  /// Edit an existing task: saves old version to history, updates document
  Future<bool> editTask({
    required String taskId,
    required Map<String, dynamic> currentData,
    required String project_status_from_employeer,
    required String newTitle,
    required String newDescription,
    required String newDuration,
    required String newStatus,
    required String modifiedBy,
    required String modifiedByRole,
    String? newPrimaryGoal, // ← NEW: primary goal text (priority tasks only)
    String? newNormalGoal, // ← NEW: normal/secondary goal text
  }) async {
    _submitting = true;
    notifyListeners();

    try {
      await _service.updateTask(
        taskId: taskId,
        currentData: currentData,
        project_status_from_employeer: project_status_from_employeer,
        newTitle: newTitle,
        newDescription: newDescription,
        newDuration: newDuration,
        newStatus: newStatus,
        modifiedBy: modifiedBy,
        modifiedByRole: modifiedByRole,
        newPrimaryGoal: newPrimaryGoal,
        newNormalGoal: newNormalGoal,
      );

      // Create notification for the lead in Firestore
      final leadEmpId = currentData['lead_id'] ?? '';
      if (leadEmpId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('task_notifications').add({
          'lead_id': leadEmpId,
          'taskId': taskId,
          'title': 'Task Modified',
          'body': '"$newTitle" was updated by $modifiedBy ($modifiedByRole)',
          'type': 'task',
          'modifiedBy': modifiedBy,
          'modifiedByRole': modifiedByRole,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      // If approved, notify all task members + HR
      if (newStatus == 'approved') {
        final members = currentData['members'] as Map<String, dynamic>? ?? {};
        for (final entry in members.values) {
          if (entry is Map<String, dynamic>) {
            final memberEmpId = entry['emp_id'] ?? '';
            if (memberEmpId.isNotEmpty) {
              await FirebaseFirestore.instance
                  .collection('task_notifications')
                  .add({
                    'lead_id': memberEmpId,
                    'taskId': taskId,
                    'title': 'Task Approved',
                    'body':
                        '"$newTitle" has been approved by $modifiedBy ($modifiedByRole)',
                    'type': 'task',
                    'modifiedBy': modifiedBy,
                    'modifiedByRole': modifiedByRole,
                    'createdAt': FieldValue.serverTimestamp(),
                    'read': false,
                  });
            }
          }
        }

        // Auto-forward Week 1 to all members
        final totalWeeks = (currentData['totalWeeks'] ?? 0) as int;
        if (members.isNotEmpty && totalWeeks > 0) {
          await _service.forwardTaskToAllMembers(
            taskId: taskId,
            members: members,
            instructions: newDescription,
            weekNumber: 1,
          );
        }

        // Notify HR about the approval
        final oldDescription = (currentData['description'] ?? '').toString();
        final wasModified = newDescription != oldDescription;

        final hrUsers = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'hr')
            .get();

        for (final hrDoc in hrUsers.docs) {
          final hrEmpId = hrDoc.data()['emp_id'] ?? hrDoc.id;
          await FirebaseFirestore.instance.collection('task_notifications').add({
            'lead_id': hrEmpId,
            'taskId': taskId,
            'title': wasModified
                ? 'Task Edited & Approved'
                : 'Task Approved by Lead',
            'body': wasModified
                ? '"$newTitle" was edited and approved by $modifiedBy. Description was modified.'
                : '"$newTitle" has been approved by $modifiedBy without changes.',
            'type': 'task',
            'modifiedBy': modifiedBy,
            'modifiedByRole': modifiedByRole,
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
        }
      }

      _submitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to update task: $e';
      _submitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Submit a task with summary, text and optional PDF
  Future<bool> submitTask({
    required String taskId,
    required String summary,
    required String submissionText,
    required String submittedBy,
    required String submittedByRole,
    String? pdfUrl,
  }) async {
    _submitting = true;
    notifyListeners();

    try {
      await _service.submitTask(
        taskId: taskId,
        summary: summary,
        submissionText: submissionText,
        submittedBy: submittedBy,
        submittedByRole: submittedByRole,
        pdfUrl: pdfUrl,
      );

      // Notify HR about the submission
      final hrUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'hr')
          .get();

      for (final doc in hrUsers.docs) {
        final hrEmpId = doc.data()['emp_id'] ?? doc.id;
        await FirebaseFirestore.instance.collection('task_notifications').add({
          'lead_id': hrEmpId,
          'title': 'Task Submitted',
          'body': '"$submittedBy" has submitted a task for review',
          'type': 'task',
          'taskId': taskId,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      _submitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to submit task: $e';
      _submitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Member submits their work to the lead (per-member, no task status change)
  Future<bool> submitMemberWork({
    required String taskId,
    required String empId,
    required String memberName,
    required String submissionText,
    required String leadEmpId,
    required String taskTitle,
    String? pdfUrl,
  }) async {
    _submitting = true;
    notifyListeners();

    try {
      debugPrint(
        '[submitMemberWork] empId=$empId, pdfUrl=${pdfUrl != null ? "present (${pdfUrl.length} chars)" : "null"}',
      );
      await _service.submitMemberWork(
        taskId: taskId,
        empId: empId,
        memberName: memberName,
        submissionText: submissionText,
        pdfUrl: pdfUrl,
      );

      // Notify lead about the member submission
      if (leadEmpId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('task_notifications').add({
          'lead_id': leadEmpId,
          'title': 'Member Submission',
          'body': '$memberName has submitted work for "$taskTitle"',
          'type': 'task',
          'taskId': taskId,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
      // Audit fan-out to all HR users so HR is notified of every
      // member submission, regardless of which UI path (v1 or v2) ran.
      await _notifyAllHr(
        taskId: taskId,
        title: 'Member Submission (audit)',
        body: '$memberName submitted work on "$taskTitle"',
        memberEmpId: empId,
      );

      _submitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to submit work: $e';
      _submitting = false;
      notifyListeners();
      return false;
    }
  }

  /// HR accepts a submitted task. Optional `hr*` / `leadEmpId` params fire
  /// the v2 `hr_accept` audit event and notify the lead — both new params
  /// are optional to keep legacy call sites working.
  Future<bool> acceptSubmission(
    String taskId, {
    String? hrEmpId,
    String? hrName,
    String? leadEmpId,
    String? taskTitle,
  }) async {
    try {
      await _service.acceptSubmission(taskId);

      // v2 audit event so the HR audit timeline shows the HR sign-off.
      String? eventId;
      if (hrEmpId != null && hrEmpId.isNotEmpty) {
        eventId = await _service.logEvent(
          taskId: taskId,
          type: 'hr_accept',
          actorId: hrEmpId,
          actorName: hrName ?? 'HR',
          actorRole: 'hr',
          payload: {if (taskTitle != null) 'taskTitle': taskTitle},
        );
      }

      // Notify the lead.
      if (leadEmpId != null && leadEmpId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('task_notifications').add({
          'lead_id': leadEmpId,
          'taskId': taskId,
          if (eventId != null) 'eventId': eventId,
          'title': 'Task Accepted by HR',
          'body': taskTitle == null
              ? 'HR has accepted your task.'
              : 'HR has accepted "$taskTitle".',
          'type': 'task',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to accept submission: $e';
      notifyListeners();
      return false;
    }
  }

  /// HR rejects a submitted task — notifies the lead and logs an audit event.
  Future<bool> rejectSubmission(
    String taskId,
    String reason, {
    String? leadEmpId,
    String? hrEmpId,
    String? hrName,
    String? taskTitle,
  }) async {
    try {
      await _service.rejectSubmission(taskId, reason);

      String? eventId;
      if (hrEmpId != null && hrEmpId.isNotEmpty) {
        eventId = await _service.logEvent(
          taskId: taskId,
          type: 'hr_reject',
          actorId: hrEmpId,
          actorName: hrName ?? 'HR',
          actorRole: 'hr',
          payload: {
            'rejectReason': reason,
            if (taskTitle != null) 'taskTitle': taskTitle,
          },
        );
      }

      // Notify lead about rejection
      if (leadEmpId != null && leadEmpId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('task_notifications').add({
          'lead_id': leadEmpId,
          'taskId': taskId,
          if (eventId != null) 'eventId': eventId,
          'title': 'Task Rejected by HR',
          'body': 'Your submission was rejected. Reason: $reason',
          'type': 'task',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to reject submission: $e';
      notifyListeners();
      return false;
    }
  }

  /// Lead accepts a member's submitted work.
  /// If all members are now accepted, auto-assigns the next week.
  Future<bool> acceptMemberWork({
    required String taskId,
    required String empId,
    required String memberName,
  }) async {
    try {
      await _service.acceptMemberWork(taskId: taskId, empId: empId);

      await FirebaseFirestore.instance.collection('task_notifications').add({
        'lead_id': empId,
        'title': 'Work Accepted',
        'body': 'Your submission has been accepted by the lead',
        'type': 'task',
        'taskId': taskId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Check if ALL members are now accepted → auto-assign next week
      await _autoAssignNextWeekIfAllAccepted(taskId);

      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to accept member work: $e';
      notifyListeners();
      return false;
    }
  }

  /// Checks if all members have accepted submissions for the current week.
  /// If yes, auto-forwards the next week to all members.
  Future<void> _autoAssignNextWeekIfAllAccepted(String taskId) async {
    final taskDoc = await FirebaseFirestore.instance
        .collection('tasks')
        .doc(taskId)
        .get();
    final taskData = taskDoc.data();
    if (taskData == null) return;

    final members = taskData['members'] as Map<String, dynamic>? ?? {};
    final submissions =
        taskData['member_submissions'] as Map<String, dynamic>? ?? {};
    final totalWeeks = (taskData['totalWeeks'] ?? 0) as int;
    if (members.isEmpty || totalWeeks <= 1) return;

    // Check if every member's submission is 'accepted'
    for (final memberEntry in members.values) {
      if (memberEntry is Map<String, dynamic>) {
        final memberEmpId = (memberEntry['emp_id'] ?? '').toString();
        if (memberEmpId.isEmpty) continue;
        final sub = submissions[memberEmpId];
        if (sub is! Map<String, dynamic> || sub['status'] != 'accepted') {
          return; // Not all accepted yet
        }
      }
    }

    // All accepted — find next unassigned week
    final deadlines = taskData['weeklyDeadlines'] as List? ?? [];
    int nextWeek = 0;
    for (final d in deadlines) {
      final w = Map<String, dynamic>.from(d as Map);
      if (w['assigned'] != true) {
        nextWeek = (w['week'] as int?) ?? 0;
        break;
      }
    }

    if (nextWeek == 0 || nextWeek > totalWeeks) return; // All weeks done

    // Auto-forward next week
    await _service.forwardTaskToAllMembers(
      taskId: taskId,
      members: members,
      instructions: taskData['description'] ?? '',
      weekNumber: nextWeek,
    );

    // Notify all members about next week
    final taskTitle = taskData['title'] ?? '';
    for (final entry in members.values) {
      if (entry is Map<String, dynamic>) {
        final memberEmpId = (entry['emp_id'] ?? '').toString();
        if (memberEmpId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('task_notifications').add({
            'lead_id': memberEmpId,
            'title': 'Week $nextWeek Assigned',
            'body':
                'All submissions accepted! Week $nextWeek of "$taskTitle" is now assigned.',
            'type': 'task',
            'taskId': taskId,
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
        }
      }
    }
  }

  /// Lead rejects a member's submitted work
  Future<bool> rejectMemberWork({
    required String taskId,
    required String empId,
    required String memberName,
    required String reason,
  }) async {
    try {
      await _service.rejectMemberWork(
        taskId: taskId,
        empId: empId,
        reason: reason,
      );

      await FirebaseFirestore.instance.collection('task_notifications').add({
        'lead_id': empId,
        'title': 'Work Rejected',
        'body': 'Your submission was rejected. Reason: $reason',
        'type': 'task',
        'taskId': taskId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to reject member work: $e';
      notifyListeners();
      return false;
    }
  }

  /// Lead pushes back all member submissions for corrections
  Future<bool> pushBackToMembers({
    required String taskId,
    required Map<String, dynamic> members,
  }) async {
    try {
      await _service.pushBackToMembers(taskId);

      for (final entry in members.values) {
        if (entry is Map<String, dynamic>) {
          final memberEmpId = entry['emp_id'] ?? '';
          if (memberEmpId.isNotEmpty) {
            await FirebaseFirestore.instance.collection('task_notifications').add({
              'lead_id': memberEmpId,
              'title': 'Task Pushed Back',
              'body':
                  'The lead has requested corrections. Please resubmit your work.',
              'type': 'task',
              'taskId': taskId,
              'createdAt': FieldValue.serverTimestamp(),
              'read': false,
            });
          }
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to push back to members: $e';
      notifyListeners();
      return false;
    }
  }

  /// Lead assigns an ad-hoc task to a member. Deadline must be < 6 days.
  /// Notifies the member; HR can also see it via the `isAdHoc:true` flag.
  Future<bool> assignAdHocTask({
    required String leadEmpId,
    required String leadName,
    required String memberEmpId,
    required String memberName,
    required String department,
    required String title,
    required String description,
    required DateTime deadline,
  }) async {
    _submitting = true;
    notifyListeners();
    try {
      final taskId = await _service.assignAdHocTask(
        leadEmpId: leadEmpId,
        leadName: leadName,
        memberEmpId: memberEmpId,
        memberName: memberName,
        department: department,
        title: title,
        description: description,
        deadline: deadline,
      );

      // Notify the member
      await FirebaseFirestore.instance.collection('task_notifications').add({
        'lead_id': memberEmpId,
        'taskId': taskId,
        'title': 'Ad-hoc Task Assigned',
        'body':
            '$leadName assigned you a quick task: "$title". '
            'Due ${deadline.day}/${deadline.month}/${deadline.year}.',
        'type': 'task',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Refresh lead's view
      await loadTasksForUser(leadEmpId);

      _submitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to assign ad-hoc task: $e';
      _submitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Submit a "reason for not submitting" entry. Saved on the task doc and
  /// notification is sent to the lead (if member submitting) or all HR
  /// (if lead submitting). Visible in task history.
  Future<bool> submitNoSubmissionReason({
    required String taskId,
    required String empId,
    required String empName,
    required String role, // 'member' or 'lead'
    required String reason,
    required String taskTitle,
    String? leadEmpId,
    int? forWeek,
  }) async {
    try {
      await _service.submitNoSubmissionReason(
        taskId: taskId,
        empId: empId,
        empName: empName,
        role: role,
        reason: reason,
        forWeek: forWeek,
      );

      final weekTag = forWeek != null ? ' (Week $forWeek)' : '';

      if (role == 'member' && leadEmpId != null && leadEmpId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('task_notifications').add({
          'lead_id': leadEmpId,
          'taskId': taskId,
          'title': 'Non-Submission Reason from $empName',
          'body': '"$taskTitle"$weekTag — $reason',
          'type': 'task',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      } else if (role == 'lead') {
        final hrUsers = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'hr')
            .get();
        for (final hrDoc in hrUsers.docs) {
          final hrEmpId = hrDoc.data()['emp_id'] ?? hrDoc.id;
          await FirebaseFirestore.instance
              .collection('task_notifications')
              .add({
                'lead_id': hrEmpId,
                'taskId': taskId,
                'title': 'Non-Submission Reason from $empName (Lead)',
                'body': '"$taskTitle"$weekTag — $reason',
                'type': 'task',
                'createdAt': FieldValue.serverTimestamp(),
                'read': false,
              });
        }
      }

      await loadTasksForUser(empId);
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to submit reason: $e';
      notifyListeners();
      return false;
    }
  }

  /// HR updates an employee's department
  Future<bool> updateEmployeeDepartment(String uid, String department) async {
    try {
      await _service.updateEmployeeDepartment(uid, department);
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to update department: $e';
      notifyListeners();
      return false;
    }
  }

  /// Update the members map on a task (for lead add/remove members)
  Future<bool> updateTaskMembers({
    required String taskId,
    required Map<String, dynamic> membersMap,
  }) async {
    try {
      await _service.updateTaskMembers(taskId: taskId, membersMap: membersMap);
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to update members: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Team member management ───────────────────────────────────────

  List<Map<String, dynamic>> _pendingMembers = [];
  List<Map<String, dynamic>> get pendingMembers => _pendingMembers;

  /// Load pending team members awaiting lead approval
  Future<void> loadPendingMembers(String leadEmpId) async {
    try {
      _pendingMembers = await _service.getPendingTeamMembers(leadEmpId);
    } catch (e) {
      debugPrint('[TaskVM] ERROR loading pending members: $e');
      _pendingMembers = [];
    }
    notifyListeners();
  }

  /// Lead accepts a pending team member
  Future<bool> acceptTeamMember({
    required String employeeUid,
    required String employeeName,
    required String leadEmpId,
  }) async {
    try {
      await _service.acceptTeamMember(employeeUid);

      await FirebaseFirestore.instance.collection('task_notifications').add({
        'lead_id': employeeUid,
        'title': 'Team Request Accepted',
        'body': 'You have been accepted into the team',
        'type': 'team',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      await loadPendingMembers(leadEmpId);
      await loadMembersByLeadId(leadEmpId);
      return true;
    } catch (e) {
      errorMessage = 'Failed to accept team member: $e';
      notifyListeners();
      return false;
    }
  }

  /// Lead rejects a pending team member
  Future<bool> rejectTeamMember({
    required String employeeUid,
    required String employeeName,
    required String leadEmpId,
  }) async {
    try {
      await _service.rejectTeamMember(employeeUid);

      await FirebaseFirestore.instance.collection('task_notifications').add({
        'lead_id': employeeUid,
        'title': 'Team Request Declined',
        'body': 'Your team assignment was declined by the lead',
        'type': 'team',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      await loadPendingMembers(leadEmpId);
      return true;
    } catch (e) {
      errorMessage = 'Failed to reject team member: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Task forwarding (Lead → Member) ────────────────────────────

  /// Forward a task to ALL members for a specific week
  Future<bool> forwardTaskToAllMembers({
    required String taskId,
    required Map<String, dynamic> members,
    required String instructions,
    required int weekNumber,
    required String leadEmpId,
    required String taskTitle,
    List<Map<String, dynamic>>? attachments,
  }) async {
    _submitting = true;
    notifyListeners();

    try {
      await _service.forwardTaskToAllMembers(
        taskId: taskId,
        members: members,
        instructions: instructions,
        weekNumber: weekNumber,
        attachments: attachments,
      );

      // Notify each member
      for (final entry in members.values) {
        if (entry is Map<String, dynamic>) {
          final memberEmpId = (entry['emp_id'] ?? '').toString();
          if (memberEmpId.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('task_notifications')
                .add({
                  'lead_id': memberEmpId,
                  'title': 'Week $weekNumber Assigned',
                  'body':
                      'You have been assigned Week $weekNumber of "$taskTitle"',
                  'type': 'task',
                  'taskId': taskId,
                  'createdAt': FieldValue.serverTimestamp(),
                  'read': false,
                });
          }
        }
      }

      _submitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to forward task: $e';
      _submitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Lead forwards a task to a specific member with instructions + optional attachments
  Future<bool> forwardTaskToMember({
    required String taskId,
    required String empId,
    required String memberName,
    required String instructions,
    required String leadEmpId,
    required String taskTitle,
    int? weekNumber,
    List<Map<String, dynamic>>? attachments,
  }) async {
    _submitting = true;
    notifyListeners();

    try {
      await _service.forwardTaskToMember(
        taskId: taskId,
        empId: empId,
        memberName: memberName,
        instructions: instructions,
        weekNumber: weekNumber,
        attachments: attachments,
      );

      // Notify the member
      await FirebaseFirestore.instance.collection('task_notifications').add({
        'lead_id': empId,
        'title': 'Task Forwarded to You',
        'body': 'Lead has assigned you work on "$taskTitle"',
        'type': 'task',
        'taskId': taskId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      _submitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to forward task: $e';
      _submitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Load version history for a specific task
  Future<void> loadTaskHistory(String taskId) async {
    try {
      _taskHistory = await _service.getTaskHistory(taskId);
    } catch (e) {
      debugPrint('[TaskVM] Error loading history: $e');
      _taskHistory = [];
    }
    notifyListeners();
  }

  // ── v2 Hierarchical Task Workflow ─────────────────────────────────
  // These methods drive the schemaVersion=2 flow. They wrap [TaskService]
  // calls, emit audit events via [TaskService.logEvent], and write to
  // `task_notifications` so FCM/in-app notifications fire.

  /// Lead acceptance — variant is one of:
  ///   'accepted_as_is'      : single-tap accept of HR's original task
  ///   'accepted_with_edits' : lead modified title/desc/attachments before accepting
  ///   'team_changed'        : lead changed the member list before/with accepting
  Future<bool> leadAcceptTask({
    required String taskId,
    required String variant,
    required String leadEmpId,
    required String leadName,
    required String taskTitle,
    Map<String, dynamic>? editsPayload,
    Map<String, dynamic>? membersPayload,
  }) async {
    try {
      final state = variant == 'team_changed' ? 'accepted_with_edits' : variant;
      await _service.setLeadAcceptanceState(
        taskId: taskId,
        state: state,
        leadEmpId: leadEmpId,
      );

      final eventType = switch (variant) {
        'accepted_as_is' => 'lead_accept_as_is',
        'accepted_with_edits' => 'lead_edit_and_accept',
        'team_changed' => 'lead_team_change',
        _ => 'lead_accept_as_is',
      };

      final eventId = await _service.logEvent(
        taskId: taskId,
        type: eventType,
        actorId: leadEmpId,
        actorName: leadName,
        actorRole: 'lead',
        payload: {
          if (editsPayload != null) ...editsPayload,
          if (membersPayload != null) 'members': membersPayload,
        },
      );

      // Notify HR that the lead has accepted
      await _notifyAllHr(
        taskId: taskId,
        title: switch (variant) {
          'accepted_as_is' => 'Task Accepted by Lead',
          'accepted_with_edits' => 'Task Edited & Accepted by Lead',
          'team_changed' => 'Lead Modified Team & Accepted',
          _ => 'Task Accepted by Lead',
        },
        body: '$leadName accepted "$taskTitle"',
        eventId: eventId,
      );

      return true;
    } catch (e) {
      errorMessage = 'Failed to accept task: $e';
      notifyListeners();
      return false;
    }
  }

  // Add this method inside TaskViewModel class
  // ----- Notification Helpers -----

  /// Lead applies edits (title/description/attachments) to the task without
  /// accepting yet. Used by the "Edit & Accept" flow before the explicit
  /// acceptance step.
  Future<bool> leadApplyEdits({
    required String taskId,
    String? title,
    String? description,
    String? secondaryDescription,
    List<Map<String, dynamic>>? attachments,
    List<Map<String, dynamic>>? secondaryAttachments,
  }) async {
    try {
      await _service.applyLeadEdits(
        taskId: taskId,
        title: title,
        description: description,
        secondaryDescription: secondaryDescription,
        attachments: attachments,
        secondaryAttachments: secondaryAttachments,
      );
      return true;
    } catch (e) {
      errorMessage = 'Failed to apply edits: $e';
      notifyListeners();
      return false;
    }
  }

  /// Submits the member's work for a specific task
  Future<bool> submitTaskWork({
    required String taskId,
    required String empId,
    required String submissionText,
    String? pdfUrl,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({
        'member_submissions.$empId': {
          'status': 'submitted',
          'submissionText': submissionText,
          'pdfUrl': pdfUrl ?? '',
          'submittedAt': FieldValue.serverTimestamp(),
        },
      });
      return true;
    } catch (e) {
      print('Error submitting task work: $e');
      return false;
    }
  }

  /// Lead updates the member list with min-1 validation. Logs a
  /// `lead_team_change` event when members actually changed.
  Future<bool> leadUpdateMembers({
    required String taskId,
    required Map<String, dynamic> previousMembers,
    required Map<String, dynamic> newMembers,
    required String leadEmpId,
    required String leadName,
  }) async {
    if (newMembers.isEmpty) {
      errorMessage = 'A task must have at least one member.';
      notifyListeners();
      return false;
    }
    try {
      await _service.updateTaskMembers(taskId: taskId, membersMap: newMembers);
      await _service.logEvent(
        taskId: taskId,
        type: 'lead_team_change',
        actorId: leadEmpId,
        actorName: leadName,
        actorRole: 'lead',
        payload: {
          'previousCount': previousMembers.length,
          'newCount': newMembers.length,
          'newMembers': newMembers,
        },
      );
      return true;
    } catch (e) {
      errorMessage = 'Failed to update members: $e';
      notifyListeners();
      return false;
    }
  }

  /// Lead writes/updates the per-(week, member) instruction during breakdown.
  /// Persists to `weekly_assignments` and logs `lead_breakdown`. Notifies the
  /// member that their week is assigned.
  ///
  /// Dates are derived inside [TaskService.upsertWeeklyAssignment] — when the
  /// lead saves a week beyond `currentWeek`, that call implicitly activates
  /// the new phase (sets startDate=NOW, endDate=NOW+cycle, bumps currentWeek,
  /// closes prior).
  Future<bool> leadSetWeekInstruction({
    required String taskId,
    required int weekNumber,
    required String empId,
    required String memberName,
    required String instruction,
    required String leadEmpId,
    required String leadName,
    required String taskTitle,
    List<Map<String, dynamic>>? attachments,
    bool notify = true,
  }) async {
    try {
      await _service.upsertWeeklyAssignment(
        taskId: taskId,
        weekNumber: weekNumber,
        empId: empId,
        memberName: memberName,
        instruction: instruction,
        attachments: attachments,
      );
      final eventId = await _service.logEvent(
        taskId: taskId,
        type: 'lead_breakdown',
        actorId: leadEmpId,
        actorName: leadName,
        actorRole: 'lead',
        weekNumber: weekNumber,
        memberEmpId: empId,
        payload: {'instruction': instruction, 'memberName': memberName},
        attachments: attachments,
      );
      if (notify) {
        await FirebaseFirestore.instance.collection('task_notifications').add({
          'lead_id': empId,
          'taskId': taskId,
          'weekNumber': weekNumber,
          'eventId': eventId,
          'title': 'Week $weekNumber Assigned',
          'body': 'You have a Week $weekNumber breakdown for "$taskTitle"',
          'type': 'task',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
      return true;
    } catch (e) {
      errorMessage = 'Failed to set week instruction: $e';
      notifyListeners();
      return false;
    }
  }

  /// Mark the parent task as breakdown-complete (or not). The lead
  /// breakdown UI calls this after saving all (week, member) cells.
  Future<bool> leadSetBreakdownComplete({
    required String taskId,
    required bool complete,
  }) async {
    try {
      await _service.markBreakdownComplete(taskId, complete);
      return true;
    } catch (e) {
      errorMessage = 'Failed to update breakdown state: $e';
      notifyListeners();
      return false;
    }
  }

  /// Member submits work for a single (week, member) pair. Records the
  /// attempt, logs `member_submit` (or `member_resubmit` for attempts > 1),
  /// notifies the lead.
  Future<bool> memberSubmitWeeklyWork({
    required String taskId,
    required int weekNumber,
    required String empId,
    required String memberName,
    required String text,
    required String leadEmpId,
    required String taskTitle,
    List<Map<String, dynamic>>? attachments,
  }) async {
    _submitting = true;
    notifyListeners();
    try {
      final attemptNumber = await _service.appendSubmissionAttempt(
        taskId: taskId,
        weekNumber: weekNumber,
        empId: empId,
        text: text,
        attachments: attachments,
      );
      final eventId = await _service.logEvent(
        taskId: taskId,
        type: attemptNumber == 1 ? 'member_submit' : 'member_resubmit',
        actorId: empId,
        actorName: memberName,
        actorRole: 'member',
        weekNumber: weekNumber,
        memberEmpId: empId,
        payload: {'attemptNumber': attemptNumber, 'text': text},
        attachments: attachments,
      );
      if (leadEmpId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('task_notifications').add({
          'lead_id': leadEmpId,
          'taskId': taskId,
          'weekNumber': weekNumber,
          'memberEmpId': empId,
          'eventId': eventId,
          'title': attemptNumber == 1
              ? 'Member Submission'
              : 'Member Resubmitted',
          'body':
              '$memberName submitted Week $weekNumber work for "$taskTitle"',
          'type': 'task',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
      // HR summary notification on every member submission (spec §7)
      await _notifyAllHr(
        taskId: taskId,
        title: 'Member Submission (audit)',
        body: '$memberName submitted Week $weekNumber on "$taskTitle"',
        weekNumber: weekNumber,
        memberEmpId: empId,
        eventId: eventId,
      );

      _submitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to submit work: $e';
      _submitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Lead accepts or rejects the most recent attempt on a (week, member).
  /// Logs `lead_accept_member` / `lead_reject_member`, notifies the member.
  Future<bool> leadReviewWeeklyWork({
    required String taskId,
    required int weekNumber,
    required String empId,
    required String memberName,
    required bool accept,
    required String leadEmpId,
    required String leadName,
    required String taskTitle,
    String? rejectReason,
  }) async {
    try {
      await _service.reviewLastAttempt(
        taskId: taskId,
        weekNumber: weekNumber,
        empId: empId,
        accept: accept,
        rejectReason: rejectReason,
        reviewerId: leadEmpId,
      );
      final eventId = await _service.logEvent(
        taskId: taskId,
        type: accept ? 'lead_accept_member' : 'lead_reject_member',
        actorId: leadEmpId,
        actorName: leadName,
        actorRole: 'lead',
        weekNumber: weekNumber,
        memberEmpId: empId,
        payload: {
          if (!accept && rejectReason != null) 'rejectReason': rejectReason,
        },
      );
      await FirebaseFirestore.instance.collection('task_notifications').add({
        'lead_id': empId,
        'taskId': taskId,
        'weekNumber': weekNumber,
        'eventId': eventId,
        'title': accept ? 'Work Accepted' : 'Work Rejected',
        'body': accept
            ? 'Your Week $weekNumber work on "$taskTitle" was accepted'
            : 'Week $weekNumber rejected. Reason: ${rejectReason ?? 'no reason'}',
        'type': 'task',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
      if (!accept) {
        // Spec §7: HR summary notification on rejections too.
        await _notifyAllHr(
          taskId: taskId,
          title: 'Lead Rejection (audit)',
          body:
              '$leadName rejected $memberName\'s Week $weekNumber on "$taskTitle"',
          weekNumber: weekNumber,
          memberEmpId: empId,
          eventId: eventId,
        );
      }
      return true;
    } catch (e) {
      errorMessage = 'Failed to review work: $e';
      notifyListeners();
      return false;
    }
  }

  /// Member raises a barrier — only available once the week's deadline has
  /// passed without an accepted submission.
  Future<bool> memberRaiseBarrier({
    required String taskId,
    required int weekNumber,
    required String empId,
    required String memberName,
    required String reason,
    required String leadEmpId,
    required String taskTitle,
  }) async {
    try {
      await _service.setBarrier(
        taskId: taskId,
        weekNumber: weekNumber,
        empId: empId,
        reason: reason,
      );
      final eventId = await _service.logEvent(
        taskId: taskId,
        type: 'member_barrier',
        actorId: empId,
        actorName: memberName,
        actorRole: 'member',
        weekNumber: weekNumber,
        memberEmpId: empId,
        payload: {'reason': reason},
      );
      if (leadEmpId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('task_notifications').add({
          'lead_id': leadEmpId,
          'taskId': taskId,
          'weekNumber': weekNumber,
          'memberEmpId': empId,
          'eventId': eventId,
          'title': 'Barrier Raised',
          'body':
              '$memberName raised a barrier for Week $weekNumber of "$taskTitle"',
          'type': 'task',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
      return true;
    } catch (e) {
      errorMessage = 'Failed to raise barrier: $e';
      notifyListeners();
      return false;
    }
  }

  /// Lead's final submission of the whole task back to HR. Sets task status
  /// to 'submitted' and notifies all HR users.
  Future<bool> leadSubmitTaskToHr({
    required String taskId,
    required String leadEmpId,
    required String leadName,
    required String taskTitle,
    String? summary,
  }) async {
    _submitting = true;
    notifyListeners();
    try {
      await _service.submitV2TaskToHr(taskId: taskId, summary: summary);
      final eventId = await _service.logEvent(
        taskId: taskId,
        type: 'lead_submit_to_hr',
        actorId: leadEmpId,
        actorName: leadName,
        actorRole: 'lead',
        payload: {if (summary != null) 'summary': summary},
      );
      await _notifyAllHr(
        taskId: taskId,
        title: 'Task Submitted by Lead',
        body: '$leadName submitted "$taskTitle" for HR review',
        eventId: eventId,
      );
      _submitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to submit task: $e';
      _submitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Lead activates the next week immediately (or after the current week
  /// expired). Shifts dates via [TaskService.activateNextWeek], logs the
  /// `lead_activate_week` event and notifies every member of the new active
  /// week.
  Future<bool> leadActivateNextWeek({
    required String taskId,
    required int currentWeekNumber,
    required String leadEmpId,
    required String leadName,
    required String taskTitle,
    required Map<String, dynamic> members,
  }) async {
    try {
      await _service.activateNextWeek(
        taskId: taskId,
        currentWeekNumber: currentWeekNumber,
      );
      final nextWeek = currentWeekNumber + 1;
      final eventId = await _service.logEvent(
        taskId: taskId,
        type: 'lead_activate_week',
        actorId: leadEmpId,
        actorName: leadName,
        actorRole: 'lead',
        weekNumber: nextWeek,
        payload: {'previousWeek': currentWeekNumber},
      );

      // Notify each member that the new week is active.
      for (final m in members.values) {
        if (m is Map<String, dynamic>) {
          final empId = (m['emp_id'] ?? '').toString();
          if (empId.isEmpty) continue;
          await FirebaseFirestore.instance.collection('task_notifications').add({
            'lead_id': empId,
            'taskId': taskId,
            'weekNumber': nextWeek,
            'eventId': eventId,
            'title': 'Week $nextWeek Activated',
            'body':
                'Week $nextWeek of "$taskTitle" is now active. Submit your work before the deadline.',
            'type': 'task',
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to activate next week: $e';
      notifyListeners();
      return false;
    }
  }

  /// Internal helper — fan-out a notification to every HR user.
  Future<void> _notifyAllHr({
    required String taskId,
    required String title,
    required String body,
    int? weekNumber,
    String? memberEmpId,
    String? eventId,
  }) async {
    final hrUsers = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'hr')
        .get();
    for (final hrDoc in hrUsers.docs) {
      final hrEmpId = hrDoc.data()['emp_id'] ?? hrDoc.id;
      await FirebaseFirestore.instance.collection('task_notifications').add({
        'lead_id': hrEmpId,
        'taskId': taskId,
        if (weekNumber != null) 'weekNumber': weekNumber,
        if (memberEmpId != null) 'memberEmpId': memberEmpId,
        if (eventId != null) 'eventId': eventId,
        'title': title,
        'body': body,
        'type': 'task',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    }
  }

  /// Check all approved multi-week tasks for this lead.
  /// If the current week's deadline has passed and the next week
  /// hasn't been assigned yet, auto-assign it and notify members.
  Future<void> checkWeeklyReminders(String leadEmpId) async {
    try {
      final now = DateTime.now();

      for (final task in _tasks) {
        final taskLeadId = (task['lead_id'] ?? '').toString().toLowerCase();
        if (taskLeadId != leadEmpId.toLowerCase()) continue;

        final status = (task['status'] ?? '').toString();
        if (status != 'approved') continue;

        final totalWeeks = (task['totalWeeks'] ?? 0) as int;
        if (totalWeeks <= 1) continue;

        final deadlines = task['weeklyDeadlines'] as List? ?? [];
        if (deadlines.isEmpty) continue;

        final members = task['members'] as Map<String, dynamic>? ?? {};
        if (members.isEmpty) continue;

        for (int i = 0; i < deadlines.length; i++) {
          final week = Map<String, dynamic>.from(deadlines[i] as Map);
          final weekNum = week['week'] as int? ?? 0;
          final assigned = week['assigned'] as bool? ?? false;
          final deadlineTs = week['deadline'] as Timestamp?;

          if (assigned || deadlineTs == null) continue;

          final deadlineDate = deadlineTs.toDate();

          // If this week's deadline has passed and it's not assigned yet,
          // auto-assign it to all members
          if (now.isAfter(deadlineDate)) {
            await _service.forwardTaskToAllMembers(
              taskId: task['id'],
              members: members,
              instructions: task['description'] ?? '',
              weekNumber: weekNum,
            );

            // Notify lead
            await FirebaseFirestore.instance.collection('task_notifications').add({
              'lead_id': leadEmpId,
              'taskId': task['id'],
              'title': 'Week $weekNum Auto-Assigned',
              'body':
                  'Week $weekNum of "${task['title']}" has been auto-assigned '
                  'to all members (deadline passed).',
              'weekNumber': weekNum,
              'createdAt': FieldValue.serverTimestamp(),
              'read': false,
            });

            // Notify all members
            for (final entry in members.values) {
              if (entry is Map<String, dynamic>) {
                final memberEmpId = (entry['emp_id'] ?? '').toString();
                if (memberEmpId.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('task_notifications')
                      .add({
                        'lead_id': memberEmpId,
                        'title': 'Week $weekNum Assigned',
                        'body':
                            'Week $weekNum of "${task['title']}" has been assigned to you.',
                        'taskId': task['id'],
                        'createdAt': FieldValue.serverTimestamp(),
                        'read': false,
                      });
                }
              }
            }
          }
          // Only handle the first unassigned week
          break;
        }
      }
    } catch (e) {
      debugPrint('[TaskVM] Error checking weekly reminders: $e');
    }
  }
}
