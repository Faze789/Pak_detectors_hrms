import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/attendance_model.dart';
import '../services/attendance_service.dart';
import '../viewmodels/employee_viewmodel.dart';

// ══════════════════════════════════════════════════════════════════════════════
// DashboardViewModel
//
// Combines:
//   • A real-time Firestore stream of attendance_live (who is checked in today)
//   • EmployeeViewModel.totalEmployees (total registered headcount)
//
// Absent = totalEmployees − (present + onBreak + checkedOut today)
// ══════════════════════════════════════════════════════════════════════════════

class DashboardViewModel extends ChangeNotifier {
  final AttendanceService _service;
  final EmployeeViewModel _employeeVM;

  DashboardViewModel({
    required EmployeeViewModel employeeViewModel,
    AttendanceService? service,
  }) : _employeeVM = employeeViewModel,
       _service = service ?? AttendanceService() {
    // Re-notify whenever employee list changes (e.g. after loadEmployees())
    _employeeVM.addListener(_onEmployeeVMChanged);
  }

  // ── Live attendance state ─────────────────────────────────────────────────

  /// All live docs from attendance_live collection (checked-in today)
  List<AttendanceModel> _liveRecords = [];
  StreamSubscription<List<AttendanceModel>>? _liveSub;
  bool isLoading = true;
  String? errorMessage;

  // ── Computed counts ───────────────────────────────────────────────────────

  int get totalEmployees => _employeeVM.totalEmployees;

  /// Present = checked in + on break (both are physically at work)
  int get presentCount => _liveRecords
      .where(
        (r) =>
            r.status == AttendanceStatus.checkedIn ||
            r.status == AttendanceStatus.onBreak,
      )
      .length;

  /// On break right now
  int get onBreakCount =>
      _liveRecords.where((r) => r.status == AttendanceStatus.onBreak).length;

  /// Already checked out today (live doc deleted after check-out, so this
  /// counts only those still in live — typically 0, but kept for safety)
  int get checkedOutTodayCount =>
      _liveRecords.where((r) => r.status == AttendanceStatus.checkedOut).length;

  /// Anyone with a live doc = has checked in at some point today
  int get checkedInTodayCount => _liveRecords.length;

  /// Absent = total employees who have NO live doc today
  int get absentCount {
    final active = checkedInTodayCount;
    final absent = totalEmployees - active;
    return absent < 0 ? 0 : absent;
  }

  /// Attendance rate % = (present + onBreak) / total * 100
  int get attendanceRate {
    if (totalEmployees == 0) return 0;
    return (((presentCount + onBreakCount) / totalEmployees) * 100).round();
  }

  // ── Stream lifecycle ──────────────────────────────────────────────────────

  /// Call once from the screen's initState (after EmployeeViewModel has loaded)
  void startListening() {
    _liveSub?.cancel();
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    _liveSub = _service.streamTodayLiveAttendance().listen(
      (records) {
        _liveRecords = records;
        isLoading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (e) {
        errorMessage = 'Failed to load attendance: $e';
        isLoading = false;
        notifyListeners();
      },
    );
  }

  void _onEmployeeVMChanged() {
    // Employee count changed — recompute absent count
    notifyListeners();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _employeeVM.removeListener(_onEmployeeVMChanged);
    super.dispose();
  }
}
