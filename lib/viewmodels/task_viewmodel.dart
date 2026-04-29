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

  /// Submit a new task and refresh the list
  Future<bool> assignTask({
    List<Map<String, dynamic>>? members,
    required String lead_id,
    required String leadName,
    required String department,
    required String title,
    required String description,
    required String duration,
    String taskType = 'primary',
    List<Map<String, dynamic>>? attachments,
  }) async {
    _submitting = true;
    notifyListeners();

    try {
      await _service.createTask(
        members: members,
        lead_id: lead_id,
        leadName: leadName,
        department: department,
        title: title,
        description: description,
        duration: duration,
        taskType: taskType,
        attachments: attachments,
      );

      // Notify the lead about the new task assignment
      if (lead_id.isNotEmpty) {
        await FirebaseFirestore.instance.collection('task_notifications').add({
          'lead_id': lead_id,
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
          await FirebaseFirestore.instance
              .collection('task_notifications')
              .add({
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
      debugPrint('[submitMemberWork] empId=$empId, pdfUrl=${pdfUrl != null ? "present (${pdfUrl.length} chars)" : "null"}');
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

  /// HR accepts a submitted task
  Future<bool> acceptSubmission(String taskId) async {
    try {
      await _service.acceptSubmission(taskId);
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Failed to accept submission: $e';
      notifyListeners();
      return false;
    }
  }

  /// HR rejects a submitted task — notifies the lead
  Future<bool> rejectSubmission(
    String taskId,
    String reason, {
    String? leadEmpId,
  }) async {
    try {
      await _service.rejectSubmission(taskId, reason);

      // Notify lead about rejection
      if (leadEmpId != null && leadEmpId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('task_notifications').add({
          'lead_id': leadEmpId,
          'title': 'Task Rejected by HR',
          'body': 'Your submission was rejected. Reason: $reason',
          'type': 'task',
          'taskId': taskId,
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
    final submissions = taskData['member_submissions'] as Map<String, dynamic>? ?? {};
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
          await FirebaseFirestore.instance
              .collection('task_notifications')
              .add({
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
            await FirebaseFirestore.instance
                .collection('task_notifications')
                .add({
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
