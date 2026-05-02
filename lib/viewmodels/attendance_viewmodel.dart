// lib/viewmodels/attendance_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/attendance_model.dart';
import '../models/leave_model.dart';
import '../models/office_settings_model.dart';
import '../services/attendance_service.dart';

enum ViewState { idle, loading, error }

class AttendanceViewModel extends ChangeNotifier {
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

  // ── statusBeforeBreak: the status that should be restored after a break.
  // Used by endBreak() so the service writes the right value back.
  AttendanceStatus get _statusBeforeBreak {
    if (isFirstHalfLeave) return AttendanceStatus.firstHalfLeave;
    if (wasLate) return AttendanceStatus.late;
    return AttendanceStatus.checkedIn;
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

  // ══════════════════════════════════════════════════════════════════════════
  // END-OF-DAY CLEANUP
  // ══════════════════════════════════════════════════════════════════════════

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
    try {
      final today = DateTimeUtils.startOfDay(DateTime.now());

      _officeSettings = await _service.getOfficeSettings();

      _isWeekend = _service.isWeekend(today);
      if (_isWeekend) {
        todayAttendance = null;
        _todayLeave     = null;
        _holidayName    = null;
        _setIdle();
        return;
      }

      _holidayName = await _service.getPublicHolidayName(today);
      if (_holidayName != null) {
        todayAttendance = null;
        _todayLeave     = null;
        _setIdle();
        return;
      }

      todayAttendance =
          await _service.getTodayAttendanceWithAbsence(userId);

      if (todayAttendance?.status != null &&
          todayAttendance!.status.isAnyLeave &&
          todayAttendance?.leaveRequestId != null) {
        _todayLeave =
        await _service.getLeaveById(todayAttendance!.leaveRequestId!);
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
  /// (Lahore / Islamabad / Karachi / UAE). Enforces weekend block and
  /// the 9:00–18:00 (Pakistan time) attendance window.
  Future<void> checkInFromCity(String userId) async {
    if (checkedIn) return;

    // ── Weekend block ──────────────────────────────────────────────────
    if (_service.isWeekend(DateTime.now())) {
      _setError('Attendance is disabled on weekends.');
      return;
    }

    // ── 9:00–18:00 attendance window (Pakistan time) ───────────────────
    // The device runs in local time. If the device IS in Asia/Karachi the
    // hours line up directly; otherwise the user gets the window in their
    // local time which is still the right behavior for travel.
    final hour = DateTime.now().hour;
    if (hour < 9) {
      _setError(
        'Check-in opens at 9:00 AM. Please try again then.',
      );
      return;
    }
    if (hour >= 18) {
      _setError(
        'Check-in closed at 6:00 PM. You can check in tomorrow at 9:00 AM.',
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
    _setLoading();
    try {
      final pos = await _service.getValidatedPositionForEmployee(userId);
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

  Future<void> checkOut(String userId) async {
    if (!checkedIn || todayAttendance == null) return;
    _setLoading();
    try {
      final pos = await _service.getValidatedPositionForEmployee(userId);
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
    } catch (e) {
      _setError('Check-out failed. Please try again.');
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
