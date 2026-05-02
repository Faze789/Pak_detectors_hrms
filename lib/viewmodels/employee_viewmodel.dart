import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/employee_model.dart';
import 'auth_viewmodel.dart';

class EmployeeViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthViewModel authViewModel;

  EmployeeViewModel({required this.authViewModel});

  List<Employee> _employees = [];
  List<Employee> _filteredEmployees = [];
  bool isLoading = false;

  // ── Current user properties for PerformanceViewModel ──────────────────────
  String? _currentUserId;
  String? _currentEmployeeName;
  double? _currentEmployeeSalary;
  bool? _isHRUser;

  List<Employee> get filteredEmployees => _filteredEmployees;
  List<Employee> get employees => _employees;
  int get totalEmployees => _employees.length;

  // Getters for PerformanceViewModel
  String? get currentUserId => _currentUserId;
  String? get currentEmployeeName => _currentEmployeeName;
  double? get currentEmployeeSalary => _currentEmployeeSalary;
  bool? get isHRUser => _isHRUser;

  /// Load employees from USERS collection where role == employee
  Future<void> loadEmployees(String userId) async {
    isLoading = true;
    notifyListeners();

    try {
      final currentUser = authViewModel.currentUser;

      if (currentUser == null) {
        debugPrint("⏳ User not ready yet, skipping loadEmployees()");
        isLoading = false;
        notifyListeners();
        return;
      }

      debugPrint(
        "📥 EmployeeViewModel: Loading data for user ${currentUser.uid}",
      );

      // ── Load current user's data ──────────────────────────────────────
      _currentUserId = currentUser.uid;
      _isHRUser = currentUser.role == 'hr';

      final currentUserDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (currentUserDoc.exists) {
        final userData = currentUserDoc.data() as Map<String, dynamic>;
        _currentEmployeeName = userData['name'] as String? ?? 'Unknown';
        _currentEmployeeSalary =
            (userData['salary'] as num?)?.toDouble() ?? 0.0;

        debugPrint(
          "✅ EmployeeViewModel: Loaded user data - Name: $_currentEmployeeName, Salary: $_currentEmployeeSalary",
        );
      } else {
        debugPrint("⚠️ EmployeeViewModel: User document does not exist");
        _currentEmployeeName = 'Unknown';
        _currentEmployeeSalary = 0.0;
      }

      // HR → fetch all employees
      if (currentUser.role == 'hr') {
        final snapshot = await _firestore
            .collection('users')
            .where('role', whereIn: ['employee', 'project lead'])
            .get();

        _employees = snapshot.docs
            .map((doc) => Employee.fromMap(doc.data(), uid: doc.id))
            .toList();
        debugPrint(
          "✅ EmployeeViewModel: Loaded ${_employees.length} employees",
        );
      }
      // Employee → fetch self only
      else {
        if (currentUserDoc.exists) {
          _employees = [
            Employee.fromMap(
              currentUserDoc.data() as Map<String, dynamic>,
              uid: currentUserDoc.id,
            ),
          ];
        } else {
          _employees = [];
        }
        debugPrint("✅ EmployeeViewModel: Employee loaded self data");
      }

      _filteredEmployees = List<Employee>.from(_employees);
    } catch (e) {
      debugPrint("❌ EmployeeViewModel Error: $e");
      // Fallback values
      _currentEmployeeName ??= 'Unknown';
      _currentEmployeeSalary ??= 0.0;
      _isHRUser ??= false;
    }

    isLoading = false;
    debugPrint(
      "📤 EmployeeViewModel: isLoading = false, currentEmployeeName = $_currentEmployeeName",
    );
    notifyListeners();
  }

  /// Unified search across emp_id, name, work email, and personal email.
  void filterEmployees(String query) {
    if (query.isEmpty) {
      _filteredEmployees = List<Employee>.from(_employees);
    } else {
      final q = query.toLowerCase().trim();
      _filteredEmployees = _employees.where((e) {
        return e.emp_id.toLowerCase().contains(q) ||
            e.name.toLowerCase().contains(q) ||
            e.email.toLowerCase().contains(q) ||
            (e.personalEmail ?? '').toLowerCase().contains(q);
      }).toList();
    }

    notifyListeners();
  }

  /// Add new employee (creates user with role employee)
  Future<void> addEmployee(Employee employee) async {
    try {
      final docRef = _firestore.collection('users').doc();

      final newEmployee = employee.copyWith(
        uid: docRef.id,
        role: 'employee', // enforce role
      );

      await docRef.set(newEmployee.toMap());

      _employees.add(newEmployee);
      _filteredEmployees = List<Employee>.from(_employees);

      notifyListeners();
    } catch (e) {
      debugPrint("Error adding employee: $e");
    }
  }

  /// Update employee. If `jobDescription` changed, also notifies the
  /// employee in-app so they know HR updated their JD.
  Future<void> updateEmployee(Employee employee) async {
    try {
      // Capture the previous JD before mutating local state, so we can
      // detect a change and notify the employee.
      final oldIndex = _employees.indexWhere((e) => e.uid == employee.uid);
      final oldJd = (oldIndex != -1 ? _employees[oldIndex].jobDescription : null) ?? '';
      final newJd = (employee.jobDescription ?? '').trim();
      final jdChanged = oldJd.trim() != newJd && newJd.isNotEmpty;

      await _firestore
          .collection('users')
          .doc(employee.uid)
          .update(employee.toMap());

      if (oldIndex != -1) {
        _employees[oldIndex] = employee;
      }

      _filteredEmployees = List<Employee>.from(_employees);
      notifyListeners();

      if (jdChanged && employee.emp_id.isNotEmpty) {
        await _firestore.collection('task_notifications').add({
          'lead_id': employee.emp_id,
          'title': 'Job Description Updated',
          'body': 'Your job description was updated by HR. '
              'Open your profile to review the changes.',
          'type': 'task',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (e) {
      debugPrint("Error updating employee: $e");
    }
  }

  /// Soft-delete: marks employee inactive but keeps the doc & all history.
  /// Optionally pass `archivedByUid` (HR's UID) for audit.
  Future<void> deleteEmployee(String uid, {String? archivedByUid}) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isActive': false,
        'archivedAt': FieldValue.serverTimestamp(),
        if (archivedByUid != null) 'archivedBy': archivedByUid,
      });

      _employees.removeWhere((e) => e.uid == uid);
      _filteredEmployees = List<Employee>.from(_employees);

      notifyListeners();
    } catch (e) {
      debugPrint("Error archiving employee: $e");
    }
  }

  // ── Ex-Employees (archived) ─────────────────────────────────────────────
  List<Employee> _exEmployees = [];
  List<Employee> get exEmployees => List.unmodifiable(_exEmployees);

  Future<void> loadExEmployees() async {
    try {
      final snap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .get();
      _exEmployees = snap.docs
          .map((d) => Employee.fromMap(d.data(), uid: d.id))
          .where((e) => !e.isActive)
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading ex-employees: $e");
    }
  }

  /// Restore an archived employee back to the active list.
  Future<void> restoreEmployee(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isActive': true,
        'archivedAt': FieldValue.delete(),
        'archivedBy': FieldValue.delete(),
      });
      _exEmployees.removeWhere((e) => e.uid == uid);
      notifyListeners();
    } catch (e) {
      debugPrint("Error restoring employee: $e");
    }
  }
}
