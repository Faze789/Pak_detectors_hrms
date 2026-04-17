// lib/viewmodels/branch_viewmodel.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/branch_model.dart';
import '../services/branch_service.dart';

class BranchViewModel extends ChangeNotifier {
  final BranchService _svc;
  BranchViewModel({BranchService? service})
      : _svc = service ?? BranchService();

  List<BranchModel>      _branches     = [];
  List<BranchAssignment> _assignments  = [];
  bool                   _loading      = false;
  String?                _error;

  List<BranchModel>      get branches    => _branches;
  List<BranchAssignment> get assignments => _assignments;
  bool                   get loading     => _loading;
  String?                get error       => _error;

  StreamSubscription? _branchSub;
  StreamSubscription? _assignSub;

  void init() {
    _branchSub?.cancel();
    _assignSub?.cancel();
    _branchSub = _svc.streamBranches().listen((v) {
      _branches = v;
      notifyListeners();
    });
    _assignSub = _svc.streamAssignments().listen((v) {
      _assignments = v;
      notifyListeners();
    });
    _svc.expireStaleAssignments(); // clean up on start
  }

  @override
  void dispose() {
    _branchSub?.cancel();
    _assignSub?.cancel();
    super.dispose();
  }

  // ── Branches ──────────────────────────────────────────────────────────────

  Future<void> addBranch(BranchModel branch) async {
    _setLoading(true);
    try {
      await _svc.addBranch(branch);
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  Future<void> updateBranch(BranchModel branch) async {
    try {
      await _svc.updateBranch(branch);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteBranch(String id) async {
    try {
      await _svc.deleteBranch(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Assignments ───────────────────────────────────────────────────────────

  Future<void> assignBranch(BranchAssignment assignment) async {
    _setLoading(true);
    try {
      await _svc.assignBranch(assignment);
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  Future<void> revertToDefault(String employeeId) async {
    try {
      await _svc.revertToDefault(employeeId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> setFieldDuty(String employeeId, bool enabled) async {
    try {
      await _svc.setFieldDuty(employeeId, enabled);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> setDefaultBranch(String employeeId, String branchId, String branchName) async {
    try {
      await _svc.setDefaultBranch(employeeId, branchId, branchName);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  BranchModel? branchById(String id) {
    try { return _branches.firstWhere((b) => b.id == id); }
    catch (_) { return null; }
  }

  List<BranchAssignment> assignmentsForEmployee(String empId) =>
      _assignments.where((a) => a.employeeId == empId).toList();

  void _setLoading(bool v) { _loading = v; notifyListeners(); }
  void clearError() { _error = null; notifyListeners(); }
}