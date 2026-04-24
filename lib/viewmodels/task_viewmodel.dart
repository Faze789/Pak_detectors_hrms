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
      );

      // Notify the lead about the new task assignment
      if (lead_id.isNotEmpty) {
        await FirebaseFirestore.instance.collection('task_notifications').add({
          'lead_id': lead_id,
          'title': 'New Task Assigned',
          'body': '"$title" has been assigned to you by HR',
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
          'modifiedBy': modifiedBy,
          'modifiedByRole': modifiedByRole,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      // If approved, notify all task members
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
                    'modifiedBy': modifiedBy,
                    'modifiedByRole': modifiedByRole,
                    'createdAt': FieldValue.serverTimestamp(),
                    'read': false,
                  });
            }
          }
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
}
