// lib/services/branch_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/branch_model.dart';

class BranchService {
  final FirebaseFirestore _db;
  BranchService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _branches    => _db.collection('branches');
  CollectionReference<Map<String, dynamic>> get _assignments => _db.collection('branch_assignments');
  CollectionReference<Map<String, dynamic>> get _users       => _db.collection('users');

  // ── Branches CRUD ─────────────────────────────────────────────────────────

  Stream<List<BranchModel>> streamBranches() => _branches
      .where('isActive', isEqualTo: true)
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(BranchModel.fromDoc).toList());

  Future<List<BranchModel>> getBranches() async {
    final snap = await _branches.where('isActive', isEqualTo: true).get();
    return snap.docs.map(BranchModel.fromDoc).toList();
  }

  Future<BranchModel?> getBranch(String branchId) async {
    final doc = await _branches.doc(branchId).get();
    if (!doc.exists) return null;
    return BranchModel.fromDoc(doc);
  }

  Future<String> addBranch(BranchModel branch) async {
    final ref = await _branches.add(branch.toMap());
    return ref.id;
  }

  Future<void> updateBranch(BranchModel branch) =>
      _branches.doc(branch.id).update(branch.toMap());

  Future<void> deleteBranch(String branchId) =>
      _branches.doc(branchId).update({'isActive': false});

  // ── Employee Branch Lookup ────────────────────────────────────────────────

  /// Returns the branch the employee should be checked against right now.
  /// Priority: currentAssignedBranch (if still valid) → defaultBranchId → null
  Future<BranchModel?> getEmployeeActiveBranch(String employeeId) async {
    final userDoc = await _users.doc(employeeId).get();
    if (!userDoc.exists) return null;

    final data = userDoc.data()!;
    final fieldDuty = data['fieldDuty'] as bool? ?? false;

    // Field duty = skip all location checks
    if (fieldDuty) return null;

    // Check temp assignment — look for active assignment for today
    final now = DateTime.now();
    final assignSnap = await _assignments
        .where('employeeId', isEqualTo: employeeId)
        .where('isActive',   isEqualTo: true)
        .get();

    for (final doc in assignSnap.docs) {
      final a = BranchAssignment.fromDoc(doc);
      final isValid = a.endDate == null || a.endDate!.isAfter(now);
      if (isValid) {
        final branch = await getBranch(a.toBranchId);
        if (branch != null) return branch;
      }
    }

    // Fall back to default branch
    final defaultBranchId = data['defaultBranchId'] as String?;
    if (defaultBranchId != null && defaultBranchId.isNotEmpty) {
      return getBranch(defaultBranchId);
    }

    return null;
  }

  // ── Branch Assignment CRUD ────────────────────────────────────────────────

  Stream<List<BranchAssignment>> streamAssignments() => _assignments
      .where('isActive', isEqualTo: true)
      .orderBy('startDate', descending: true)
      .snapshots()
      .map((s) => s.docs.map(BranchAssignment.fromDoc).toList());

  Future<List<BranchAssignment>> getEmployeeAssignments(String employeeId) async {
    final snap = await _assignments
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('startDate', descending: true)
        .get();
    return snap.docs.map(BranchAssignment.fromDoc).toList();
  }

  /// Assigns employee to a branch. Also updates users/{id}.currentAssignedBranch.
  Future<void> assignBranch(BranchAssignment assignment) async {
    final batch = _db.batch();

    // 1. Deactivate any existing active assignments for this employee
    final existing = await _assignments
        .where('employeeId', isEqualTo: assignment.employeeId)
        .where('isActive',   isEqualTo: true)
        .get();
    for (final doc in existing.docs) {
      batch.update(doc.reference, {'isActive': false});
    }

    // 2. Create new assignment
    final newRef = _assignments.doc();
    batch.set(newRef, assignment.toMap());

    // 3. Update user document
    final endDate = assignment.duration == AssignmentDuration.todayOnly
        ? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59)
        : assignment.endDate;

    batch.update(_users.doc(assignment.employeeId), {
      'currentAssignedBranch': assignment.toBranchId,
      'currentAssignedBranchName': assignment.toBranchName,
      'branchAssignmentExpiry': endDate != null ? Timestamp.fromDate(endDate) : null,
      'fieldDuty': false,
    });

    await batch.commit();
  }

  /// Revert employee back to their default branch
  Future<void> revertToDefault(String employeeId) async {
    final batch = _db.batch();

    final existing = await _assignments
        .where('employeeId', isEqualTo: employeeId)
        .where('isActive',   isEqualTo: true)
        .get();
    for (final doc in existing.docs) {
      batch.update(doc.reference, {'isActive': false});
    }

    batch.update(_users.doc(employeeId), {
      'currentAssignedBranch': FieldValue.delete(),
      'currentAssignedBranchName': FieldValue.delete(),
      'branchAssignmentExpiry': FieldValue.delete(),
    });

    await batch.commit();
  }

  /// Toggle field duty for employee
  Future<void> setFieldDuty(String employeeId, bool enabled) =>
      _users.doc(employeeId).update({'fieldDuty': enabled});

  /// Set default branch for employee
  Future<void> setDefaultBranch(String employeeId, String branchId, String branchName) =>
      _users.doc(employeeId).update({
        'defaultBranchId':   branchId,
        'defaultBranchName': branchName,
      });

  // ── Auto-expire cleanup (call on app start) ───────────────────────────────

  Future<void> expireStaleAssignments() async {
    final now = Timestamp.now();
    final snap = await _assignments
        .where('isActive', isEqualTo: true)
        .where('endDate', isLessThan: now)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isActive': false});
      final empId = doc.data()['employeeId'] as String;
      batch.update(_users.doc(empId), {
        'currentAssignedBranch':     FieldValue.delete(),
        'currentAssignedBranchName': FieldValue.delete(),
        'branchAssignmentExpiry':    FieldValue.delete(),
      });
    }
    await batch.commit();
  }
}