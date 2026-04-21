import 'package:flutter/foundation.dart';
import '../services/task_service.dart';

class TaskViewModel extends ChangeNotifier {
  final TaskService _service;

  TaskViewModel({TaskService? service}) : _service = service ?? TaskService();

  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _members = [];
  bool isLoading = false;
  String? errorMessage;

  List<Map<String, dynamic>> get tasks => _tasks;
  List<Map<String, dynamic>> get members => _members;

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

  /// Load team members whose lead_id matches the lead's emp_id
  Future<void> loadMembersByLeadId(String leadEmpId) async {
    try {
      _members = await _service.getMembersByLeadId(leadEmpId);
    } catch (e) {
      _members = [];
    }
    notifyListeners();
  }

  /// Submit a new task and refresh the list
  Future<bool> assignTask({
    required String empId,
    required String leadName,
    required String department,
    required String title,
    required String description,
    required String duration,
  }) async {
    try {
      await _service.createTask(
        empId: empId,
        leadName: leadName,
        department: department,
        title: title,
        description: description,
        duration: duration,
      );
      await loadTasksForLead(empId);
      return true;
    } catch (e) {
      errorMessage = 'Failed to assign task: $e';
      notifyListeners();
      return false;
    }
  }
}
