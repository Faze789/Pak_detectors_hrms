// lib/viewmodels/attendance_viewmodel.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/attendance_model.dart';
import '../models/leave_model.dart';
import '../models/leave_policy.dart';
import '../models/leave_request_model.dart';
import '../models/office_settings_model.dart';
import '../models/work_hour_override_model.dart';
import '../services/attendance_service.dart';
import '../services/work_hour_override_service.dart';

enum ViewState { idle, loading, error }

class AttendanceViewModel extends ChangeNotifier {
  bool isLoading = false;
  List<Map<String, dynamic>> _pendingLeaveRequests = [];
  List<Map<String, dynamic>> get pendingLeaveRequests => _pendingLeaveRequests;
  final AttendanceService _service;

  // Exposed so HR dashboard can access streamTodayLiveAttendance()
  // directly without going through loadToday() which mutates ViewModel state.
  AttendanceService get service => _service;

  AttendanceViewModel({AttendanceService? service})
    : _service = service ?? AttendanceService();

  // ── State ─────────────────────────────────────────────────────────────────
  ViewState state = ViewState.idle;
  String? errorMessage;

  AttendanceModel? todayAttendance;

  // Cached HR-defined work-hour override for the signed-in user + today,
  // refreshed by loadToday(). Used by the UI to compute cutoff/late
  // boundaries synchronously without async calls in build().
  WorkHourOverride? todayOverride;
  WorkHourOverride? get activeOverride => todayOverride;
  final WorkHourOverrideService _overrideService = WorkHourOverrideService();

  /// Sync helper for the UI — checks the in-memory `todayOverride`. If
  /// none is cached, falls back to the global default cutoff (6:30 PM).
  bool isPastDailyCutoffSync(DateTime now) {
    final o = todayOverride;
    if (o != null && o.coversDate(now)) return o.isPastDailyCutoff(now);
    return AttendanceService.isPastDailyCutoff(now);
  }

  LeaveModel? _todayLeave;
  bool _isWeekend = false;
  String? _holidayName;
  OfficeSettings _officeSettings = OfficeSettings.defaults();
  List<AttendanceModel> history = [];

  final Map<String, MonthlyArchive> _archiveCache = {};
  Map<String, MonthlyArchive> get monthlyArchiveCache => _archiveCache;

  Timer? _uiTimer;
  Timer? _cleanupTimer;

  // ── Getters ───────────────────────────────────────────────────────────────
  LeaveModel? get todayLeave => _todayLeave;
  bool get isWeekend => _isWeekend;
  String? get holidayName => _holidayName;
  bool get isNonWorkday => _isWeekend || _holidayName != null;
  OfficeSettings get officeSettings => _officeSettings;

  String get cutoffLabel {
    final h = _officeSettings.checkInCutoff;
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:00 $period';
  }

  String get halfDayMarkLabel {
    final h = _officeSettings.halfDayMark;
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hour:00 $period';
  }

  AttendanceStatus get dailyStatus {
    if (todayAttendance == null) return AttendanceStatus.absent;
    return todayAttendance!.status;
  }

  bool get checkedIn =>
      todayAttendance?.checkInTime != null &&
      todayAttendance?.checkOutTime == null &&
      (todayAttendance?.status == AttendanceStatus.checkedIn ||
          todayAttendance?.status == AttendanceStatus.onBreak ||
          todayAttendance?.status == AttendanceStatus.late ||
          todayAttendance?.status == AttendanceStatus.firstHalfLeave ||
          todayAttendance?.status == AttendanceStatus.secondHalfLeave);

  bool get onBreak => todayAttendance?.status == AttendanceStatus.onBreak;

  bool get isFirstHalfLeave =>
      todayAttendance?.status == AttendanceStatus.firstHalfLeave;

  bool get isSecondHalfLeave =>
      todayAttendance?.status == AttendanceStatus.secondHalfLeave;

  bool get isOnLeave => dailyStatus.isAnyLeave;

  bool get isLate => todayAttendance?.status == AttendanceStatus.late;

  // ── FIX #3: wasLate derives lateness from checkInTime, not status.
  // This is the same logic used in checkOut() in the service — it stays
  // accurate even while the employee is on a break (status = onBreak).
  bool get wasLate {
    final checkIn = todayAttendance?.checkInTime;
    if (checkIn == null) return false;

    // Check if check-in was after the 15-minute grace period
    return checkIn.hour > _officeSettings.workStartHour ||
        (checkIn.hour == _officeSettings.workStartHour && checkIn.minute > 15);
  }

  // Employee's own submitted requests
  List<Map<String, dynamic>> _myLeaveRequests = [];
  List<Map<String, dynamic>> get myLeaveRequests => _myLeaveRequests;

  Future<void> fetchMyLeaveRequests(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('request_for_leave')
          .where('uid', isEqualTo: uid)
          .get();

      _myLeaveRequests = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Newest first, client-side sort (no index needed)
      _myLeaveRequests.sort((a, b) {
        final aTs = a['createdAt'] as Timestamp?;
        final bTs = b['createdAt'] as Timestamp?;
        if (aTs == null && bTs == null) return 0;
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        return bTs.compareTo(aTs);
      });

      notifyListeners();
    } catch (e) {
      debugPrint('🔴 fetchMyLeaveRequests error: $e');
    }
  }

  bool isCurrentUserLead = false;

  bool isCurrentUserHR = false; // ─── NEW: Track if user is HR
  // ── Add this method anywhere in the class ──────────────────────────────────
  Future<void> _checkLeadStatus(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!userDoc.exists) return;

      final empId = (userDoc.data()!['emp_id'] ?? userId).toString();
      final role = (userDoc.data()!['role'] ?? '').toString().toLowerCase();

      // 1. If their main role is HR, Admin, or Lead, they have access
      if (role == 'hr' || role == 'admin' || role.contains('lead')) {
        isCurrentUserLead = true;
        if (role == 'hr' || role == 'admin') {
          isCurrentUserHR = true; // Set HR flag
        }
        notifyListeners();
        return;
      }

      // 2. Otherwise, check if they are mapped as the lead_id in ANY active task
      final tasksSnap = await FirebaseFirestore.instance
          .collection('tasks')
          .where('lead_id', isEqualTo: empId)
          .where('status', isNotEqualTo: 'completed')
          .limit(1)
          .get();

      isCurrentUserLead = tasksSnap.docs.isNotEmpty;
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking lead status: $e');
    }
  }

  Future<void> fetchLeaveRequestsForLead(String leadEmpId) async {
    state = ViewState.loading;
    notifyListeners();

    try {
      Query query = FirebaseFirestore.instance.collection('request_for_leave');

      // ─── NEW: HR/Admins see all requests, Leads see only their team ────────
      if (!isCurrentUserHR) {
        query = query.where('leadsNotified', arrayContains: leadEmpId);
      }

      final snap = await query.get();

      _pendingLeaveRequests = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort newest first
      _pendingLeaveRequests.sort((a, b) {
        final aTs = a['createdAt'] as Timestamp?;
        final bTs = b['createdAt'] as Timestamp?;
        if (aTs == null || bTs == null) return 0;
        return bTs.compareTo(aTs);
      });
    } catch (e) {
      debugPrint('Error fetching leave requests: $e');
      errorMessage = 'Failed to load leave requests.';
    } finally {
      state = ViewState.idle;
      notifyListeners();
    }
  }

  /// Fetches all leave requests (all statuses) for a given employee UID.
  Future<List<Map<String, dynamic>>> fetchLeaveRequestsForEmployee(
    String uid,
  ) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('request_for_leave')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching leave requests for employee: $e');
      return [];
    }
  }

  /// Approve or Decline a leave request
  Future<bool> reviewLeaveRequest({
    required String requestId,
    required String employeeUid,
    required String employeeName,
    required String leadEmpId,
    required String newStatus, // 'approved' or 'declined'
    String? rejectionReason,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'reviewedBy': leadEmpId,
        'reviewedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'declined' && rejectionReason != null) {
        updateData['rejectionReason'] = rejectionReason;
      }

      // 1. Update the request document
      await FirebaseFirestore.instance
          .collection('request_for_leave')
          .doc(requestId)
          .update(updateData);

      // 2. Notify the employee about the decision
      await FirebaseFirestore.instance.collection('task_notifications').add({
        // We use the employee's UID or EMP_ID depending on how your notifications route to users
        // Assuming employeeUid maps to their auth UID for personal notifications
        'lead_id': employeeUid,
        'title': newStatus == 'approved' ? 'Leave Approved' : 'Leave Declined',
        'body': newStatus == 'approved'
            ? 'Your leave request has been approved by your lead.'
            : 'Your leave request was declined: $rejectionReason',
        'type': 'leave_response',
        'referenceId': requestId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // 3. Remove it from the local list to update UI immediately
      _pendingLeaveRequests.removeWhere((req) => req['id'] == requestId);
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error reviewing leave request: $e');
      return false;
    }
  }

  // ── statusBeforeBreak: the status that should be restored after a break.
  // Used by endBreak() so the service writes the right value back.
  AttendanceStatus get _statusBeforeBreak {
    if (isFirstHalfLeave) return AttendanceStatus.firstHalfLeave;
    if (wasLate) return AttendanceStatus.late;
    return AttendanceStatus.checkedIn;
  }

  Future<bool> submitLeaveRequest(
    String uid,
    DateTime start,
    DateTime end,
    int days, {
    // Categorical leave-type tag picked from the request UI dropdown.
    // Optional and informational only — does not change the per-quarter
    // cap (the regular bucket from LeavePolicy still applies).
    String? leaveType,
    String? leaveTypeLabel,
    String? reason,
  }) async {
    try {
      final Set<String> leadIdsToNotify = {};
      String actualEmpId = uid;
      String userName = 'Employee';
      bool isInStation = true; // default per policy

      // 1. Get Employee Details (Name, EMP_ID, Primary Lead, Station)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        actualEmpId = (userData['emp_id'] ?? uid).toString();
        userName = (userData['name'] ?? 'Employee').toString();
        final primaryLead = (userData['lead_id'] ?? '').toString();
        if (primaryLead.isNotEmpty) leadIdsToNotify.add(primaryLead);
        // station defaults to in_station when unset.
        final stationRaw = (userData['station'] ?? 'in_station').toString();
        isInStation = stationRaw != 'out_station';
      }

      // ── Per-quarter / per-station cap pre-check ───────────────────────
      // Policy:
      //   • In-station employees:    3 days per QUARTER
      //   • Out-of-station employees: 4 days per QUARTER
      // (Marriage / bereavement / medical / maternity / paternity have
      // separate quotas — wire those in alongside a leave-type picker.)
      //
      // The "quarter" is the calendar quarter that contains [start]. If
      // a request spans two quarters, we charge it to the starting one.
      final quotaPerQuarter = LeavePolicy.regularQuotaPerQuarter(
        isInStation: isInStation,
      );
      final qBounds = LeavePolicy.quarterBounds(start);
      final existingSnap = await FirebaseFirestore.instance
          .collection('request_for_leave')
          .where('uid', isEqualTo: uid)
          .get();
      int usedThisQuarter = 0;
      for (final doc in existingSnap.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString();
        if (status != 'approved' && status != 'pending') continue;
        final startTs = data['startDate'];
        if (startTs is! Timestamp) continue;
        final startDt = startTs.toDate();
        if (startDt.isBefore(qBounds.start) || startDt.isAfter(qBounds.end)) {
          continue;
        }
        usedThisQuarter += (data['totalDays'] as num? ?? 0).toInt();
      }
      if (usedThisQuarter + days > quotaPerQuarter) {
        final stationLabel = isInStation ? 'in-station' : 'out-of-station';
        final remaining = (quotaPerQuarter - usedThisQuarter).clamp(
          0,
          quotaPerQuarter,
        );
        throw Exception(
          'Quarterly leave cap for $stationLabel employees is '
          '$quotaPerQuarter days. You have already used $usedThisQuarter '
          'day(s) this quarter and have $remaining left — requesting '
          '$days more would exceed the limit.',
        );
      }

      // 2. Query ALL Active Tasks to check for multi-leads.
      // If the employee is mapped under any task's `members`, grab that `lead_id`
      final tasksSnap = await FirebaseFirestore.instance
          .collection('tasks')
          .where('status', isNotEqualTo: 'completed')
          .get();

      for (var doc in tasksSnap.docs) {
        final data = doc.data();
        final members = data['members'] as Map<String, dynamic>? ?? {};

        // Loop through the task's numbered members map
        bool isMember = members.values.any((m) {
          if (m is Map<String, dynamic>) {
            return (m['emp_id'] ?? '').toString() == actualEmpId;
          }
          return false;
        });

        if (isMember) {
          final taskLeadId = (data['lead_id'] ?? '').toString();
          if (taskLeadId.isNotEmpty) {
            leadIdsToNotify.add(taskLeadId);
          }
        }
      }

      final List<String> notificationTargets = leadIdsToNotify.toList();

      // 3. Fallback: If working under no leads, send directly to HR
      if (notificationTargets.isEmpty) {
        final hrUsersSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'hr')
            .get();

        for (var doc in hrUsersSnap.docs) {
          final hrEmpId = (doc.data()['emp_id'] ?? doc.id).toString();
          notificationTargets.add(hrEmpId);
        }
      }

      // 4. Create the request in the new collection
      final leaveRef = await FirebaseFirestore.instance
          .collection('request_for_leave')
          .add({
            'uid': uid,
            'emp_id': actualEmpId,
            'name': userName,
            'startDate': Timestamp.fromDate(start),
            'endDate': Timestamp.fromDate(end),
            'totalDays': days,
            'status': 'pending',
            'leadsNotified': notificationTargets,
            'sentToHR': leadIdsToNotify.isEmpty,
            'createdAt': FieldValue.serverTimestamp(),
            if (leaveType != null) 'leaveType': leaveType,
            if (leaveTypeLabel != null) 'leaveTypeLabel': leaveTypeLabel,
            if (reason != null && reason.trim().isNotEmpty)
              'reason': reason.trim(),
          });

      // 5. Send Notification(s) using your existing task_notifications structure
      for (var targetId in notificationTargets) {
        await FirebaseFirestore.instance.collection('task_notifications').add({
          'lead_id':
              targetId, // Treat 'lead_id' as the generic notification recipient ID
          'title': 'New Leave Request',
          'body': '$userName has requested $days day(s) of leave.',
          'type': 'leave_request',
          'referenceId': leaveRef.id,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      return true;
    } catch (e) {
      throw Exception('Error submitting leave: $e');
    }
  }

  List<BreakEntry> get breaks => todayAttendance?.breaks ?? [];
  int get workSeconds => todayAttendance?.totalWorkDuration.inSeconds ?? 0;
  int get breakSeconds => todayAttendance?.totalBreakDuration.inSeconds ?? 0;
  int get productivity => todayAttendance?.productivityPercent ?? 100;

  String get formattedWorkTime => _fmt(workSeconds);
  String get formattedBreakTime => _fmt(breakSeconds);

  static String _fmt(int secs) {
    final h = (secs ~/ 3600).toString().padLeft(2, '0');
    final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static String formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  // ══════════════════════════════════════════════════════════════════════════
  // INIT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> initForUser(String userId) async {
    await loadToday(userId);
    _scheduleCleanup(userId);
  }

  // // ══════════════════════════════════════════════════════════════════════════
  // // END-OF-DAY CLEANUP
  // // ══════════════════════════════════════════════════════════════════════════

  void _scheduleCleanup(String userId) {
    _cleanupTimer?.cancel();
    final now = DateTime.now();
    final endHour = _officeSettings.workEndHour;
    final endOfDay = DateTime(now.year, now.month, now.day, endHour, 55, 0);
    if (now.isAfter(endOfDay)) return;
    _cleanupTimer = Timer(endOfDay.difference(now), () async {
      try {
        await _service.deleteCheckedOutForToday(userId);
      } catch (e) {
        debugPrint('[AttendanceViewModel] Daily cleanup failed: $e');
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOAD TODAY
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> loadToday(String userId) async {
    _setLoading();

    _checkLeadStatus(userId);
    try {
      final today = DateTimeUtils.startOfDay(DateTime.now());

      _officeSettings = await _service.getOfficeSettings();

      // Refresh HR-defined work-hour override for this user + today.
      // Used by isPastDailyCutoffSync to slide the lockout boundary in
      // the UI without any async work in build().
      try {
        todayOverride = await _overrideService.activeFor(
          userId,
          DateTime.now(),
        );
      } catch (_) {
        todayOverride = null;
      }

      _isWeekend = _service.isWeekend(today);
      if (_isWeekend) {
        todayAttendance = null;
        _todayLeave = null;
        _holidayName = null;
        _setIdle();
        return;
      }

      _holidayName = await _service.getPublicHolidayName(today);
      if (_holidayName != null) {
        todayAttendance = null;
        _todayLeave = null;
        _setIdle();
        return;
      }

      todayAttendance = await _service.getTodayAttendanceWithAbsence(userId);

      if (todayAttendance?.status != null &&
          todayAttendance!.status.isAnyLeave &&
          todayAttendance?.leaveRequestId != null) {
        _todayLeave = await _service.getLeaveById(
          todayAttendance!.leaveRequestId!,
        );
      } else {
        _todayLeave = null;
      }

      if (checkedIn) _startUITimer();
      _scheduleCleanup(userId);
    } catch (e) {
      _setError('Failed to load attendance: $e');
    } finally {
      _setIdle();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHECK-IN / CHECK-OUT / BREAKS
  // ══════════════════════════════════════════════════════════════════════════

  /// City-based check-in — accepts user if at any of the 4 office cities
  /// (Lahore / Islamabad / Karachi / UAE). Used by the EmployeeDashboardScreen.
  Future<void> checkInFromCity(String userId) async {
    if (checkedIn) return;

    if (hasCompletedTodayCycle) {
      _setError(
        'You have already checked in and out for today. Check-in resets tomorrow.',
      );
      return;
    }
    if (await _service.isPastDailyCutoffFor(userId, DateTime.now())) {
      _setError(
        'Check-in window closed for today. Try again tomorrow at 8:00 AM.',
      );
      return;
    }
    _setLoading();
    try {
      final pos = await _service.getValidatedPositionFromCities();
      todayAttendance = await _service.checkIn(
        userId,
        lat: pos.latitude,
        lng: pos.longitude,
      );

      if (isFirstHalfLeave && todayAttendance?.leaveRequestId != null) {
        _todayLeave = await _service.getLeaveById(
          todayAttendance!.leaveRequestId!,
        );
      } else {
        _todayLeave = null;
      }

      _startUITimer();
    } on GeofenceException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Check-in failed. Please try again.');
    } finally {
      _setIdle();
    }
  }

  /// Check-out without location validation. Per company policy, checkout
  /// doesn't require being at an office location, just a valid GPS sample.
  /// Must be done before midnight; the day is "incomplete" otherwise.
  Future<void> checkOutAnywhere(String userId) async {
    if (!checkedIn || todayAttendance == null) return;

    // Block check-out if it's already past midnight (i.e. attendance is for a
    // previous day that the user is trying to close late).
    final now = DateTime.now();
    final attendanceDate = todayAttendance!.date;
    if (now.day != attendanceDate.day ||
        now.month != attendanceDate.month ||
        now.year != attendanceDate.year) {
      _setError('Check-out window expired (past midnight). Day not counted.');
      return;
    }

    _setLoading();
    try {
      // Still take a GPS reading for the audit trail, but no geofence check.
      double lat = todayAttendance!.checkInLatitude ?? 0;
      double lng = todayAttendance!.checkInLongitude ?? 0;
      try {
        final pos = await _service.getMedianPosition();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {
        // GPS unavailable → fall back to last known check-in coordinates.
      }

      todayAttendance = await _service.checkOut(
        userId,
        current: todayAttendance!,
        lat: lat,
        lng: lng,
      );
      _stopUITimer();
      if (todayAttendance != null) {
        await _service.archiveAttendance(todayAttendance!);
      }
    } catch (e) {
      _setError('Check-out failed. Please try again.');
    } finally {
      _setIdle();
    }
  }

  Future<void> checkIn(String userId) async {
    if (checkedIn) return;

    if (hasCompletedTodayCycle) {
      _setError(
        'You have already checked in and out for today. Check-in resets tomorrow.',
      );
      return;
    }
    // Fail loud and clear if we arrived here without a signed-in user.
    // Without this, the next line throws the cryptic Firestore error
    // "a document path must be a non-empty string" from _live.doc('').
    if (userId.trim().isEmpty) {
      _setError('Cannot check in: you are not signed in. Please log in again.');
      return;
    }
    // Hard daily cutoff. Surface the message immediately so we don't waste
    // GPS sampling time when the call would be rejected anyway. Honors any
    // per-employee work-hour override set by HR.
    if (await _service.isPastDailyCutoffFor(userId, DateTime.now())) {
      _setError(
        'Check-in window closed for today. Try again tomorrow at 8:00 AM.',
      );
      return;
    }
    _setLoading();
    try {
      final pos = await _service.getValidatedPositionFromCities();
      todayAttendance = await _service.checkIn(
        userId,
        lat: pos.latitude,
        lng: pos.longitude,
      );

      if (isFirstHalfLeave && todayAttendance?.leaveRequestId != null) {
        _todayLeave = await _service.getLeaveById(
          todayAttendance!.leaveRequestId!,
        );
      } else {
        _todayLeave = null;
      }

      _startUITimer();
    } on GeofenceException catch (e) {
      _setError(e.message);
    } on TimeoutException catch (_) {
      // Most common silent failure: indoor / weak signal causes the GPS
      // sampler in [AttendanceService.getMedianPosition] to time out after
      // 15s. Surface a clearer message instead of the generic catch-all.
      _setError(
        'Could not get your location in time. '
        'Move closer to a window or step outside, then try again.',
      );
    } on FirebaseException catch (e) {
      _setError(
        'Check-in could not be saved (${e.code}). '
        '${e.message ?? 'Network or permission issue — please try again.'}',
      );
    } catch (e) {
      // Surface the underlying error type/message so the actual cause is
      // visible on-screen and in debugPrint, instead of swallowing it
      // behind the previous "Check-in failed. Please try again." string.
      debugPrint('[AttendanceVM] checkIn failed: $e');
      _setError('Check-in failed: $e');
    } finally {
      _setIdle();
    }
  }

  Future<void> checkOut(String userId) async {
    if (!checkedIn || todayAttendance == null) return;
    if (userId.trim().isEmpty) {
      _setError(
        'Cannot check out: you are not signed in. Please log in again.',
      );
      return;
    }
    _setLoading();
    try {
      final pos = await _service.getValidatedPositionFromCities();
      todayAttendance = await _service.checkOut(
        userId,
        current: todayAttendance!,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      _stopUITimer();
      // archiveAttendance is now called inside service.checkOut() — this
      // call is kept for safety but will simply overwrite with same data.
      if (todayAttendance != null) {
        await _service.archiveAttendance(todayAttendance!);
      }
    } on GeofenceException catch (e) {
      _setError(e.message);
    } on TimeoutException catch (_) {
      _setError(
        'Could not get your location in time. '
        'Move closer to a window or step outside, then try again.',
      );
    } on FirebaseException catch (e) {
      _setError(
        'Check-out could not be saved (${e.code}). '
        '${e.message ?? 'Network or permission issue — please try again.'}',
      );
    } catch (e) {
      debugPrint('[AttendanceVM] checkOut failed: $e');
      _setError('Check-out failed: $e');
    } finally {
      _setIdle();
    }
  }

  Future<void> startBreak(String userId) async {
    if (!checkedIn || onBreak || todayAttendance == null) return;
    final updatedBreaks = List<BreakEntry>.from(breaks)
      ..add(BreakEntry(breakStart: DateTime.now()));

    // Snapshot the status before switching to onBreak so endBreak
    // can restore it correctly via _statusBeforeBreak.
    todayAttendance = todayAttendance!.copyWith(
      status: AttendanceStatus.onBreak,
      breaks: updatedBreaks,
    );
    notifyListeners();
    try {
      await _service.startBreak(userId, updatedBreaks);
    } catch (e) {
      final rolledBack = List<BreakEntry>.from(breaks)..removeLast();
      // Restore to correct pre-break status using wasLate
      final prevStatus = wasLate
          ? AttendanceStatus.late
          : isFirstHalfLeave
          ? AttendanceStatus.firstHalfLeave
          : AttendanceStatus.checkedIn;
      todayAttendance = todayAttendance!.copyWith(
        status: prevStatus,
        breaks: rolledBack,
      );
      _setError('Start break failed: $e');
      notifyListeners();
    }
  }

  // ── END BREAK ─────────────────────────────────────────────────────────────
  // FIX #3: Pass _statusBeforeBreak to the service so it writes the correct
  // status (late / firstHalfLeave / checkedIn) instead of always checkedIn.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> endBreak(String userId) async {
    if (!onBreak || todayAttendance == null) return;
    final now = DateTime.now();
    final updatedBreaks = List<BreakEntry>.from(breaks);
    if (updatedBreaks.isNotEmpty && updatedBreaks.last.breakEnd == null) {
      updatedBreaks[updatedBreaks.length - 1] = updatedBreaks.last.copyWith(
        breakEnd: now,
      );
    }

    // Restore the correct pre-break status using the immutable checkInTime
    final statusAfterBreak = _statusBeforeBreak;

    todayAttendance = todayAttendance!.copyWith(
      status: statusAfterBreak,
      breaks: updatedBreaks,
    );
    notifyListeners();
    try {
      await _service.endBreak(
        userId,
        updatedBreaks,
        previousStatus: statusAfterBreak,
      );
    } catch (e) {
      _setError('End break failed: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HISTORY & ARCHIVE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> loadHistory(String userId, {int days = 30}) async {
    _setLoading();
    try {
      history = await _service.getHistory(userId, days: days);
    } catch (e) {
      _setError('Failed to load history: $e');
    } finally {
      _setIdle();
    }
  }

  Future<MonthlyArchive?> getMonthlyArchive(
    String userId,
    int year,
    int month,
  ) async {
    final key = '${userId}_${year}_${month.toString().padLeft(2, '0')}';
    if (_archiveCache.containsKey(key)) return _archiveCache[key];
    _setLoading();
    MonthlyArchive? archive;
    try {
      archive = await _service.getMonthlyArchive(userId, year, month);
      if (archive != null) _archiveCache[key] = archive;
    } catch (e) {
      _setError('Failed to load monthly archive: $e');
    } finally {
      _setIdle();
    }
    return archive;
  }

  Future<MonthlyArchive?> getMonthlyArchiveSilent(
    String userId,
    int year,
    int month,
  ) async {
    final key = '${userId}_${year}_${month.toString().padLeft(2, '0')}';
    if (_archiveCache.containsKey(key)) return _archiveCache[key];
    try {
      final archive = await _service.getMonthlyArchive(userId, year, month);
      if (archive != null) _archiveCache[key] = archive;
      return archive;
    } catch (_) {
      return null;
    }
  }

  Future<AttendanceModel?> getArchivedAttendanceForDay(
    String userId,
    DateTime date,
  ) async {
    final archive = await getMonthlyArchiveSilent(
      userId,
      date.year,
      date.month,
    );
    return archive?.days[DateTimeUtils.toDateKey(date)];
  }

  Future<AttendanceModel?> getEmployeeLiveRecord(String userId) async {
    try {
      return await _service.getTodayAttendance(userId);
    } catch (e) {
      debugPrint('[AttendanceViewModel] getEmployeeLiveRecord error: $e');
      return null;
    }
  }

  /// True when the employee has a valid completed check-in → check-out cycle
  /// for today (i.e. the day is done and no re-check-in should be allowed).
  bool get hasCompletedTodayCycle {
    final att = todayAttendance;
    if (att == null) return false;
    // Only counts for today — stale records from yesterday don't block.
    if (!DateTimeUtils.isSameDay(att.date, DateTime.now())) return false;
    final ci = att.checkInTime;
    final co = att.checkOutTime;
    if (ci == null || co == null) return false;
    // Ignore glitch cycles shorter than 60 s (accidental double-tap etc.)
    return co.difference(ci).inSeconds > 60;
  }

  Future<AttendanceModel?> getLiveAttendance(String userId) async {
    await loadToday(userId);
    return todayAttendance;
  }

  // ── Stream for HR dashboard ───────────────────────────────────────────────
  // Exposes a stream of all live attendance records for today without touching
  // any ViewModel state. Safe to call from HR screens for any number of employees.
  Stream<List<AttendanceModel>> streamTodayLiveAttendance() =>
      _service.streamTodayLiveAttendance();

  // ══════════════════════════════════════════════════════════════════════════
  // UTILS
  // ══════════════════════════════════════════════════════════════════════════

  void _startUITimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
  }

  void _stopUITimer() => _uiTimer?.cancel();

  void _setLoading() {
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();
  }

  void _setIdle() {
    state = ViewState.idle;
    notifyListeners();
  }

  void _setError(String msg) {
    state = ViewState.error;
    errorMessage = msg;
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    state = ViewState.idle;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HR-side leave-review API
  //
  // - streamAllLeaveRequests   →  real-time list for HRLeaveApprovalsScreen
  // - streamPendingLeaveCount  →  badge count
  // - hrReviewLeaveRequest     →  approve / decline a request, push FCM,
  //                               and backfill `attendance_archive` for the
  //                               approved range so HR Monthly reflects the
  //                               leave instantly.
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<LeaveRequestModel>> streamAllLeaveRequests() {
    return FirebaseFirestore.instance
        .collection('request_for_leave')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(LeaveRequestModel.fromDoc).toList(),
        );
  }

  Stream<int> streamPendingLeaveCount() {
    return FirebaseFirestore.instance
        .collection('request_for_leave')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// HR approves or declines a leave request.
  /// • Updates `request_for_leave/{id}`.
  /// • Writes a live in-app card to `notifications/{employeeUid}/items`.
  /// • Pushes an FCM notification to the employee via `task_notifications`.
  /// • On approval, backfills `attendance_archive` so every weekday in
  ///   the leave range shows `onLeave` immediately (no waiting for the
  ///   6:30 PM cron).
  Future<bool> hrReviewLeaveRequest({
    required String requestId,
    required String employeeUid,
    required String employeeName,
    required String hrEmpId,
    required String hrName,
    required String newStatus, // 'approved' | 'declined'
    String? rejectionReason,
  }) async {
    try {
      final now = FieldValue.serverTimestamp();
      final batch = FirebaseFirestore.instance.batch();

      // 1. Update the leave request.
      final reqRef = FirebaseFirestore.instance
          .collection('request_for_leave')
          .doc(requestId);
      final update = <String, dynamic>{
        'status': newStatus,
        'hrReviewed': true,
        'reviewedBy': hrEmpId,
        'reviewedByName': hrName,
        'reviewedAt': now,
        'notified': true,
      };
      if (newStatus == 'declined' && rejectionReason != null) {
        update['rejectionReason'] = rejectionReason;
      }
      batch.update(reqRef, update);

      // 2. In-app notification card (LeaveNotificationsWidget reads this).
      final notifRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc(employeeUid)
          .collection('items')
          .doc();
      final title = newStatus == 'approved'
          ? '✅ Leave Approved'
          : '❌ Leave Declined';
      final body = newStatus == 'approved'
          ? 'Your leave request has been approved by HR ($hrName).'
          : 'Your leave request was declined by HR ($hrName).'
                '${rejectionReason != null ? ' Reason: $rejectionReason' : ''}';
      batch.set(notifRef, {
        'title': title,
        'body': body,
        'type': 'leave_review',
        'requestId': requestId,
        'status': newStatus,
        'reviewedByName': hrName,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
        'read': false,
        'createdAt': now,
      });

      await batch.commit();

      // 3. FCM push via task_notifications (lead_id routed by emp_id).
      try {
        final empDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(employeeUid)
            .get();
        final empId = (empDoc.data()?['emp_id'] ?? '').toString();
        if (empId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('task_notifications').add({
            'lead_id': empId,
            'title': title,
            'body': body,
            'type': 'leave_review',
            'referenceId': requestId,
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
        }
      } catch (e) {
        debugPrint('hrReviewLeaveRequest task_notifications push failed: $e');
      }

      // 4. On approval: backfill attendance_archive for each weekday.
      if (newStatus == 'approved') {
        try {
          final reqSnap = await reqRef.get();
          final reqData = reqSnap.data();
          if (reqData != null) {
            final startTs = reqData['startDate'];
            final endTs = reqData['endDate'];
            final leaveType =
                (reqData['leaveType'] ?? 'fullDay').toString();
            if (startTs is Timestamp && endTs is Timestamp) {
              await _backfillLeaveDays(
                userId: employeeUid,
                start: startTs.toDate(),
                end: endTs.toDate(),
                leaveType: leaveType,
                leaveRequestId: requestId,
              );
            }
          }
        } catch (e) {
          debugPrint('hrReviewLeaveRequest archive backfill failed: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('hrReviewLeaveRequest error: $e');
      return false;
    }
  }

  /// Writes a status=onLeave entry into attendance_archive/{uid}_{YYYY}_{MM}
  /// for every weekday between [start] and [end] inclusive. Lets HR's
  /// Monthly view reflect the approval immediately.
  Future<void> _backfillLeaveDays({
    required String userId,
    required DateTime start,
    required DateTime end,
    required String leaveType, // 'fullDay' | 'firstHalf' | 'secondHalf'
    required String leaveRequestId,
  }) async {
    String statusForDuration(String d) {
      switch (d) {
        case 'firstHalf':
          return 'firstHalfLeave';
        case 'secondHalf':
          return 'secondHalfLeave';
        default:
          return 'onLeave';
      }
    }

    final status = statusForDuration(leaveType);
    final now = DateTime.now();
    final firstDay = DateTime(start.year, start.month, start.day);
    final lastDay = DateTime(end.year, end.month, end.day);

    WriteBatch batch = FirebaseFirestore.instance.batch();
    var batchCount = 0;
    for (var cur = firstDay;
        !cur.isAfter(lastDay);
        cur = cur.add(const Duration(days: 1))) {
      if (cur.weekday == DateTime.saturday ||
          cur.weekday == DateTime.sunday) {
        continue;
      }
      final monthPad = cur.month.toString().padLeft(2, '0');
      final docId = '${userId}_${cur.year}_$monthPad';
      final dayKey =
          '${cur.year}-$monthPad-${cur.day.toString().padLeft(2, '0')}';
      final ref = FirebaseFirestore.instance
          .collection('attendance_archive')
          .doc(docId);
      batch.set(
        ref,
        {
          'userId': userId,
          'year': cur.year,
          'month': cur.month,
          'days': {
            dayKey: {
              'userId': userId,
              'date': Timestamp.fromDate(cur),
              'dateString': dayKey,
              'status': status,
              'leaveType': leaveType,
              'leaveRequestId': leaveRequestId,
              'checkInTime': null,
              'checkOutTime': null,
              'breaks': [],
              'totalWorkSeconds': 0,
              'totalBreakSeconds': 0,
              'autoMarkedAt': now.toIso8601String(),
              'autoMarkedBy': 'hrReviewLeaveRequest',
            },
          },
        },
        SetOptions(merge: true),
      );
      batchCount++;
      // Firestore caps batches at 500. WriteBatch is single-use after
      // commit, so we re-create it on each flush.
      if (batchCount >= 400) {
        await batch.commit();
        batch = FirebaseFirestore.instance.batch();
        batchCount = 0;
      }
    }
    if (batchCount > 0) await batch.commit();
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _cleanupTimer?.cancel();
    super.dispose();
  }

}
