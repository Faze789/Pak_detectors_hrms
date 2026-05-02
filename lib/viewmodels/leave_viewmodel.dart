// lib/viewmodels/leave_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/leave_model.dart';
import '../services/leave_service.dart';

enum LeaveViewState { idle, loading, submitting, error }

class LeaveViewModel extends ChangeNotifier {
  final LeaveService _service;

  LeaveViewModel({LeaveService? service})
    : _service = service ?? LeaveService();

  // ── State ─────────────────────────────────────────────────────────────────

  LeaveViewState state = LeaveViewState.idle;
  String? errorMessage;

  // ── Employee data ─────────────────────────────────────────────────────────

  List<LeaveModel> myLeaves = [];
  StreamSubscription<List<LeaveModel>>? _myLeavesSub;

  // ── HR data ───────────────────────────────────────────────────────────────

  List<LeaveModel> allLeaves = [];
  StreamSubscription<List<LeaveModel>>? _allLeavesSub;

  // ── Computed stats for HR ─────────────────────────────────────────────────

  int get totalLeaves => allLeaves.length;
  int get pendingLeaves =>
      allLeaves.where((l) => l.status == LeaveStatus.pending).length;
  int get approvedLeaves =>
      allLeaves.where((l) => l.status == LeaveStatus.approved).length;
  int get rejectedLeaves =>
      allLeaves.where((l) => l.status == LeaveStatus.rejected).length;

  /// Total days on leave (counts half days as 0.5)
  double get totalDeductedDays =>
      allLeaves.fold(0.0, (sum, l) => sum + l.deductedDays);

  /// Half-day leave requests count
  int get halfDayLeaves => allLeaves.where((l) => l.isHalfDay).length;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> initForEmployee(String userId) async {
    await _service.saveFcmToken(userId);
    _myLeavesSub?.cancel();
    _myLeavesSub = _service.streamMyLeaves(userId).listen((list) {
      myLeaves = list;
      notifyListeners();
    });
  }

  Future<void> initForHR() async {
    _allLeavesSub?.cancel();
    _allLeavesSub = _service.streamAllLeaves().listen((list) {
      allLeaves = list;
      notifyListeners();
    });
  }

  // ── Employee: submit ──────────────────────────────────────────────────────

  Future<bool> submitLeave({
    required String userId,
    required String employeeName,
    required String emp_id,
    required String employeeRole,
    required LeaveType type,
    required LeaveDuration duration,
    required DateTime fromDate,
    required DateTime toDate,
    required String reason,
  }) async {
    // ── Validation ────────────────────────────────────────────────────────
    if (reason.trim().isEmpty) {
      _setError('Please enter a reason.');
      return false;
    }

    // Half-day leaves must be a single day
    if (duration.isHalfDay && !isSameDay(fromDate, toDate)) {
      _setError('Half-day leave must be for a single day only.');
      return false;
    }

    if (!duration.isHalfDay && toDate.isBefore(fromDate)) {
      _setError('End date cannot be before start date.');
      return false;
    }

    // Can't apply both first and second half on same day
    // (would amount to a full day — user should pick fullDay instead)
    if (duration.isHalfDay) {
      final existing = myLeaves
          .where(
            (l) =>
                l.status != LeaveStatus.rejected &&
                l.status != LeaveStatus.cancelled &&
                isSameDay(l.fromDate, fromDate) &&
                l.isHalfDay,
          )
          .toList();

      if (existing.isNotEmpty) {
        final other = existing.first;
        if (other.duration != duration) {
          _setError(
            'You already have a ${other.duration.label} leave on this day. '
            'Consider applying for a full day instead.',
          );
          return false;
        } else {
          _setError('You already have a ${duration.label} leave on this day.');
          return false;
        }
      }
    }

    // ── Submit ────────────────────────────────────────────────────────────
    state = LeaveViewState.submitting;
    errorMessage = null;
    notifyListeners();

    try {
      // For half days, toDate == fromDate; service enforces this too
      final effectiveTo = duration.isHalfDay ? fromDate : toDate;
      final days = effectiveTo.difference(fromDate).inDays + 1;
      final deductedDays = duration.isHalfDay ? 0.5 : days.toDouble();

      final leave = LeaveModel(
        id: '',
        userId: userId,
        employeeName: employeeName,
        emp_id: emp_id,
        employeeRole: employeeRole,
        type: type,
        duration: duration,
        fromDate: fromDate,
        toDate: effectiveTo,
        days: days,
        deductedDays: deductedDays,
        reason: reason.trim(),
        status: LeaveStatus.pending,
        submittedAt: DateTime.now(),
      );

      await _service.submitLeave(leave);
      state = LeaveViewState.idle;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to submit leave: $e');
      return false;
    }
  }

  // ── Employee: cancel ──────────────────────────────────────────────────────

  Future<bool> cancelLeave(LeaveModel leave) async {
    if (leave.status != LeaveStatus.pending) {
      _setError('Only pending leaves can be cancelled.');
      return false;
    }
    try {
      await _service.cancelLeave(leave.id);
      return true;
    } catch (e) {
      _setError('Failed to cancel leave: $e');
      return false;
    }
  }

  // ── HR: approve ───────────────────────────────────────────────────────────

  Future<bool> approveLeave(LeaveModel leave, {String? note}) async {
    try {
      await _service.approveLeave(leave.id, leave.userId, note: note);
      return true;
    } catch (e) {
      _setError('Failed to approve: $e');
      return false;
    }
  }

  // ── HR: reject ────────────────────────────────────────────────────────────

  Future<bool> rejectLeave(LeaveModel leave, {String? note}) async {
    try {
      await _service.rejectLeave(leave.id, leave.userId, note: note);
      return true;
    } catch (e) {
      _setError('Failed to reject: $e');
      return false;
    }
  }

  // ── Lead: approve / reject (multi-lead workflow) ─────────────────────────

  Future<bool> leadApproveLeave({
    required LeaveModel leave,
    required String leadEmpId,
    required String leadName,
    String? note,
  }) async {
    try {
      await _service.leadApproveLeave(
        leaveId: leave.id,
        leadEmpId: leadEmpId,
        leadName: leadName,
        note: note,
      );
      return true;
    } catch (e) {
      _setError('Failed to approve: $e');
      return false;
    }
  }

  Future<bool> leadRejectLeave({
    required LeaveModel leave,
    required String leadEmpId,
    required String leadName,
    required String reason,
  }) async {
    try {
      await _service.leadRejectLeave(
        leaveId: leave.id,
        leadEmpId: leadEmpId,
        leadName: leadName,
        reason: reason,
      );
      return true;
    } catch (e) {
      _setError('Failed to reject: $e');
      return false;
    }
  }

  /// Stream pending leaves where this lead is in `requiredApproverEmpIds`
  /// and hasn't decided yet.
  Stream<List<LeaveModel>> streamLeavesPendingForLead(String leadEmpId) =>
      _service.streamLeavesPendingForLead(leadEmpId);

  // ── Filter helpers ────────────────────────────────────────────────────────

  List<LeaveModel> filtered({
    String? search,
    LeaveType? type,
    LeaveDuration? duration,
    LeaveStatus? status,
  }) {
    return allLeaves.where((l) {
      final matchSearch =
          search == null ||
          search.isEmpty ||
          l.employeeName.toLowerCase().contains(search.toLowerCase());
      final matchType = type == null || l.type == type;
      final matchDuration = duration == null || l.duration == duration;
      final matchStatus = status == null || l.status == status;
      return matchSearch && matchType && matchDuration && matchStatus;
    }).toList();
  }

  /// Returns leaves for a specific employee — useful on HR employee detail screen.
  List<LeaveModel> leavesForEmployee(String userId) =>
      allLeaves.where((l) => l.userId == userId).toList();

  /// Returns approved leaves for a specific date — useful for attendance view.
  List<LeaveModel> approvedLeavesOnDate(DateTime date) => allLeaves
      .where(
        (l) =>
            l.status == LeaveStatus.approved &&
            !date.isBefore(l.fromDate) &&
            !date.isAfter(l.toDate),
      )
      .toList();

  // ── Helpers ───────────────────────────────────────────────────────────────

  void clearError() {
    errorMessage = null;
    state = LeaveViewState.idle;
    notifyListeners();
  }

  void _setError(String message) {
    errorMessage = message;
    state = LeaveViewState.error;
    notifyListeners();
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void dispose() {
    _myLeavesSub?.cancel();
    _allLeavesSub?.cancel();
    super.dispose();
  }
}
