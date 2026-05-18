// lib/viewmodels/attendance_viewmodel.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/attendance_model.dart';
import '../models/leave_model.dart';
import '../models/office_settings_model.dart';
import '../services/attendance_service.dart';

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
    return checkIn.hour > _officeSettings.workStartHour ||
        (checkIn.hour == _officeSettings.workStartHour && checkIn.minute > 0);
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
    int days,
  ) async {
    try {
      final Set<String> leadIdsToNotify = {};
      String actualEmpId = uid;
      String userName = 'Employee';

      // 1. Get Employee Details (Name, EMP_ID, Primary Lead if any)
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

  @override
  void dispose() {
    _uiTimer?.cancel();
    _cleanupTimer?.cancel();
    super.dispose();
  }
}
