import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee_model.dart';

class EmployeeService {
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final CollectionReference _usersCollection = FirebaseFirestore.instance
      .collection('users');

  /// Get all ACTIVE employees (excludes soft-deleted / archived).
  Future<List<Employee>> getEmployees() async {
    try {
      final snapshot = await _usersCollection
          .where('role', isEqualTo: 'employee')
          .get();

      return snapshot.docs
          .map(
            (doc) => Employee.fromMap(
              doc.data() as Map<String, dynamic>,
              uid: doc.id,
            ),
          )
          .where((e) => e.isActive)
          .toList();
    } catch (e) {
      print("Error fetching employees: $e");
      return [];
    }
  }

  /// Get archived (soft-deleted) employees — for the Ex-Employees tab.
  Future<List<Employee>> getExEmployees() async {
    try {
      final snapshot = await _usersCollection
          .where('role', isEqualTo: 'employee')
          .get();

      return snapshot.docs
          .map(
            (doc) => Employee.fromMap(
              doc.data() as Map<String, dynamic>,
              uid: doc.id,
            ),
          )
          .where((e) => !e.isActive)
          .toList();
    } catch (e) {
      print("Error fetching ex-employees: $e");
      return [];
    }
  }

  /// Get single employee by UID
  Future<Employee?> getEmployeeByUid(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();

      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;

      // Ensure it is actually an employee
      if (data['role'] != 'employee') return null;

      return Employee.fromMap(data, uid: doc.id);
    } catch (e) {
      print("Error fetching employee by uid: $e");
      return null;
    }
  }

  /// Add new employee (creates user with role = employee)
  Future<Employee?> addEmployee(Employee employee) async {
    try {
      final docRef = employee.uid.isNotEmpty
          ? _usersCollection.doc(employee.uid)
          : _usersCollection.doc();

      final newEmployee = employee.copyWith(
        uid: docRef.id,
        role: 'employee', // enforce role
      );

      await docRef.set(newEmployee.toMap());

      return newEmployee;
    } catch (e) {
      print("Error adding employee: $e");
      return null;
    }
  }

  /// Update employee
  Future<Employee?> updateEmployee(Employee employee) async {
    try {
      await _usersCollection.doc(employee.uid).update(employee.toMap());

      final updatedDoc = await _usersCollection.doc(employee.uid).get();

      return Employee.fromMap(
        updatedDoc.data() as Map<String, dynamic>,
        uid: updatedDoc.id,
      );
    } catch (e) {
      print("Error updating employee: $e");
      return null;
    }
  }

  /// Soft-delete (archive) an employee. The doc and all related history
  /// stays in Firestore — it just won't appear in the active list anymore.
  /// `archivedByUid` should be the HR user's UID for audit.
  Future<void> deleteEmployee(String uid, {String? archivedByUid}) async {
    try {
      await _usersCollection.doc(uid).update({
        'isActive': false,
        'archivedAt': FieldValue.serverTimestamp(),
        if (archivedByUid != null) 'archivedBy': archivedByUid,
      });
    } catch (e) {
      print("Error archiving employee: $e");
    }
  }

  /// Restore a soft-deleted employee back to the active list.
  Future<void> restoreEmployee(String uid) async {
    try {
      await _usersCollection.doc(uid).update({
        'isActive': true,
        'archivedAt': FieldValue.delete(),
        'archivedBy': FieldValue.delete(),
      });
    } catch (e) {
      print("Error restoring employee: $e");
    }
  }

  /// Search employees (client-side filtering after role filter)
  Future<List<Employee>> searchEmployees(String query) async {
    try {
      final snapshot = await _usersCollection
          .where('role', isEqualTo: 'employee')
          .get();

      final lowerQuery = query.toLowerCase();

      return snapshot.docs
          .map(
            (doc) => Employee.fromMap(
              doc.data() as Map<String, dynamic>,
              uid: doc.id,
            ),
          )
          .where(
            (emp) =>
                emp.name.toLowerCase().contains(lowerQuery) ||
                emp.email.toLowerCase().contains(lowerQuery) ||
                emp.department.toLowerCase().contains(lowerQuery),
          )
          .toList();
    } catch (e) {
      print("Error searching employees: $e");
      return [];
    }
  }

  /// Filter by department
  Future<List<Employee>> getEmployeesByDepartment(String department) async {
    try {
      final snapshot = await _usersCollection
          .where('role', isEqualTo: 'employee')
          .where('department', isEqualTo: department)
          .get();

      return snapshot.docs
          .map(
            (doc) => Employee.fromMap(
              doc.data() as Map<String, dynamic>,
              uid: doc.id,
            ),
          )
          .toList();
    } catch (e) {
      print("Error fetching by department: $e");
      return [];
    }
  }

  /// Filter by status
  Future<List<Employee>> getEmployeesByStatus(EmployeeStatus status) async {
    try {
      final snapshot = await _usersCollection
          .where('role', isEqualTo: 'employee')
          .where('status', isEqualTo: status.name)
          .get();

      return snapshot.docs
          .map(
            (doc) => Employee.fromMap(
              doc.data() as Map<String, dynamic>,
              uid: doc.id,
            ),
          )
          .toList();
    } catch (e) {
      print("Error fetching by status: $e");
      return [];
    }
  }

  /// 🔥 Optional: Real-time stream (recommended for HR dashboard)
  Stream<List<Employee>> getEmployeesStream() {
    return _usersCollection
        .where('role', isEqualTo: 'employee')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => Employee.fromMap(
                  doc.data() as Map<String, dynamic>,
                  uid: doc.id,
                ),
              )
              .toList();
        });
  }
}
