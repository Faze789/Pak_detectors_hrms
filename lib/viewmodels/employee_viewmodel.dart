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

  /// Search filter
  void filterEmployees(String query) {
    if (query.isEmpty) {
      _filteredEmployees = List<Employee>.from(_employees);
    } else {
      _filteredEmployees = _employees.where((e) {
        return e.name.toLowerCase().contains(query.toLowerCase()) ||
            e.email.toLowerCase().contains(query.toLowerCase());
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

  /// Update employee
  Future<void> updateEmployee(Employee employee) async {
    try {
      await _firestore
          .collection('users')
          .doc(employee.uid)
          .update(employee.toMap());

      final index = _employees.indexWhere((e) => e.uid == employee.uid);
      if (index != -1) {
        _employees[index] = employee;
      }

      _filteredEmployees = List<Employee>.from(_employees);
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating employee: $e");
    }
  }

  /// Optional: Delete employee
  Future<void> deleteEmployee(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();

      _employees.removeWhere((e) => e.uid == uid);
      _filteredEmployees = List<Employee>.from(_employees);

      notifyListeners();
    } catch (e) {
      debugPrint("Error deleting employee: $e");
    }
  }
}
