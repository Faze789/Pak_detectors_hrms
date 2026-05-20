// lib/services/attendance_service.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/attendance_model.dart';
import '../models/leave_model.dart';
import '../models/office_settings_model.dart';
import '../models/branch_model.dart';
import 'branch_service.dart';
import 'office_settings_service.dart';
import 'work_hour_override_service.dart';

class GeofenceException implements Exception {
  final String message;
  const GeofenceException(this.message);
  @override
  String toString() => message;
}

class AttendanceService {
  final FirebaseFirestore _db;
  final BranchService _branchService;
  final OfficeSettingsService _settingsService;

  AttendanceService({
    FirebaseFirestore? db,
    BranchService? branchService,
    OfficeSettingsService? settingsService,
  }) : _db = db ?? FirebaseFirestore.instance,
       _branchService = branchService ?? BranchService(),
       _settingsService = settingsService ?? OfficeSettingsService();

  CollectionReference<Map<String, dynamic>> get _live =>
      _db.collection('attendance_live');
  CollectionReference<Map<String, dynamic>> get _archives =>
      _db.collection('attendance_archive');
  CollectionReference<Map<String, dynamic>> get _leaves =>
      _db.collection('leaves');
  CollectionReference<Map<String, dynamic>> get _holidays =>
      _db.collection('public_holidays');

  static const List<int> weekendDays = [DateTime.saturday, DateTime.sunday];

  static const double _officeLat = 33.599232;
  static const double _officeLng = 73.154599;
  static const double _officeAlt = 508.0;
  static const double _allowedRadius = 300.0; // radius_check
  static const double _maxAccuracy = 300.0;
  static const double _maxIdleSpeed = 5.0;
  static const double _altTolerance = 100.0;
  static const int _sampleCount = 3;
  static const Duration _sampleDelay = Duration(seconds: 2);

  // ══════════════════════════════════════════════════════════════════════════
  // OFFICE SETTINGS
  // ══════════════════════════════════════════════════════════════════════════

  Future<OfficeSettings> getOfficeSettings() =>
      _settingsService.fetchSettings();

  // ══════════════════════════════════════════════════════════════════════════
  // WEEKEND & HOLIDAY
  // ══════════════════════════════════════════════════════════════════════════

  bool isWeekend(DateTime date) => weekendDays.contains(date.weekday);

  Future<String?> getPublicHolidayName(DateTime date) async {
    try {
      final snap = await _holidays.doc(DateTimeUtils.toDateKey(date)).get();
      if (!snap.exists || snap.data() == null) return null;
      return snap.data()!['name'] as String?;
    } catch (e) {
      debugPrint('[AttendanceService] getPublicHolidayName error: $e');
      return null;
    }
  }

  Future<void> ensureLocationPermission() async {
    // 1. Check if GPS hardware is actually ON
    bool serviceOn = await Geolocator.isLocationServiceEnabled();

    if (!serviceOn) {
      // Open settings. Note: Code continues after user returns to app.
      await Geolocator.openLocationSettings();

      // Give the OS 500ms to register the hardware change
      await Future.delayed(const Duration(milliseconds: 500));

      serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        throw const GeofenceException(
          'Location services are still disabled. Please enable GPS.',
        );
      }
    }

    // 2. Check App-level Permissions
    LocationPermission perm = await Geolocator.checkPermission();

    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        throw const GeofenceException(
          'Location permission denied. Verification requires access.',
        );
      }
    }

    if (perm == LocationPermission.deniedForever) {
      // If permanently denied, system dialog won't show anymore.
      // User MUST go to App Settings.
      await Geolocator.openAppSettings();
      throw const GeofenceException(
        'Permissions permanently denied. Please enable in App Settings.',
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CORE METHOD — TODAY WITH FULL LOGIC
  // ══════════════════════════════════════════════════════════════════════════

  Future<AttendanceModel?> getTodayAttendanceWithAbsence(String userId) async {
    final today = DateTimeUtils.startOfDay(DateTime.now());

    if (isWeekend(today)) return null;

    final holidayName = await getPublicHolidayName(today);
    if (holidayName != null) return null;

    final dayKey = DateTimeUtils.toDateKey(today);

    final live = await getTodayAttendance(userId);
    if (live != null) return live;

    final settings = await getOfficeSettings();
    final currentHour = DateTime.now().hour;

    final existingArchive = await getMonthlyArchive(
      userId,
      today.year,
      today.month,
    );
    if (existingArchive != null && existingArchive.days.containsKey(dayKey)) {
      final existing = existingArchive.days[dayKey]!;

      if (existing.status == AttendanceStatus.absent &&
          currentHour < settings.checkInCutoff) {
        debugPrint(
          '[Attendance] Stale absent record found but still within '
          'check-in window (${settings.checkInCutoff}:00) — ignoring.',
        );
        return null;
      }

      return existing;
    }

    final leave = await fetchApprovedLeaveModel(userId, today);
    if (leave != null) {
      AttendanceStatus status;

      if (leave.isFirstHalf) {
        if (currentHour < settings.halfDayCutoff) {
          return null;
        }
        status = AttendanceStatus.absent;
      } else if (leave.isSecondHalf) {
        status = AttendanceStatus.secondHalfLeave;
      } else {
        status = AttendanceStatus.onLeave;
      }

      final record = AttendanceModel(
        userId: userId,
        date: today,
        status: status,
        leaveRequestId: leave.id,
        leaveType: leave.duration.value,
        halfDayMark: settings.halfDayMark,
        halfDayCutoff: settings.halfDayCutoff,
        checkInCutoff: settings.checkInCutoff,
        workStartHour: settings.workStartHour,
        workEndHour: settings.workEndHour,
      );
      await archiveAttendance(record);
      return record;
    }

    if (currentHour >= settings.checkInCutoff) {
      debugPrint(
        '[Attendance] Past cutoff (${settings.checkInCutoff}:00) — marking absent.',
      );
      final record = AttendanceModel(
        userId: userId,
        date: today,
        status: AttendanceStatus.absent,
        checkInCutoff: settings.checkInCutoff,
        workStartHour: settings.workStartHour,
        workEndHour: settings.workEndHour,
      );
      await archiveAttendance(record);
      return record;
    }

    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOCATION PERMISSION
  // ══════════════════════════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════════════════════════
  // ANTI-CHEAT POSITION
  // ══════════════════════════════════════════════════════════════════════════

  Future<Position> getMedianPosition() async {
    await ensureLocationPermission();
    final samples = <Position>[];
    for (int i = 0; i < _sampleCount; i++) {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15),
      );
      samples.add(pos);
      if (i < _sampleCount - 1) await Future.delayed(_sampleDelay);
    }
    samples.sort((a, b) => a.latitude.compareTo(b.latitude));
    return samples[samples.length ~/ 2];
  }

  Future<Position> getValidatedPosition({
    BranchModel? branch,
    bool fieldDuty = false,
  }) async {
    final pos = await getMedianPosition();

    if (pos.isMocked) {
      throw const GeofenceException(
        'Fake GPS detected. Disable mock location apps and try again.',
      );
    }
    if (pos.accuracy > _maxAccuracy) {
      throw GeofenceException(
        'GPS signal too weak (accuracy: ${pos.accuracy.toStringAsFixed(0)}m). '
        'Move to an open area and try again.',
      );
    }
    if (pos.accuracy == 0.0) {
      throw const GeofenceException(
        'Suspicious GPS reading detected. Please disable mock location apps.',
      );
    }
    if (pos.speed > _maxIdleSpeed) {
      throw GeofenceException(
        'Unusual movement detected (${pos.speed.toStringAsFixed(1)} m/s). '
        'Please stand still and try again.',
      );
    }

    if (fieldDuty) return pos;

    final double targetLat = branch?.latitude ?? _officeLat;
    final double targetLng = branch?.longitude ?? _officeLng;
    final double targetAlt = branch?.altitude ?? _officeAlt;
    final double radius = branch?.radius ?? _allowedRadius;
    final String branchName = branch?.name ?? 'the office';

    if (pos.altitude.abs() > 1.0) {
      final altDiff = (pos.altitude - targetAlt).abs();
      if (altDiff > _altTolerance) {
        throw GeofenceException(
          'Location verification failed. '
          'Please ensure you are inside $branchName.',
        );
      }
    }

    final distance = Geolocator.distanceBetween(
      targetLat,
      targetLng,
      pos.latitude,
      pos.longitude,
    );
    if (distance > radius) {
      throw GeofenceException(
        'You are ${distance.toStringAsFixed(0)}m from $branchName. '
        'You must be within ${radius.toStringAsFixed(0)}m to mark attendance.',
      );
    }

    return pos;
  }

  Future<Position> getValidatedPositionForEmployee(String employeeId) async {
    final userDoc = await _db.collection('users').doc(employeeId).get();
    final fieldDuty = userDoc.data()?['fieldDuty'] as bool? ?? false;
    if (fieldDuty) return getValidatedPosition(fieldDuty: true);
    final branch = await _branchService.getEmployeeActiveBranch(employeeId);
    return getValidatedPosition(branch: branch, fieldDuty: false);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // OFFICE GEOFENCE — strict, allows check-in only AT the office premises
  // ══════════════════════════════════════════════════════════════════════════

  /// Exact office coordinates. Check-in is allowed only if the user is
  /// within `_officeRadiusMeters` of one of these points.
  static const Map<String, Map<String, double>> _allowedOffices = {
    'Lahore': {'lat': 31.3766365, 'lng': 74.1745807},
    'Islamabad': {'lat': 33.5992083, 'lng': 73.154657},
    'Islamabad site office': {'lat': 33.6048609, 'lng': 73.1956127},
    'Karachi': {'lat': 25.0297457, 'lng': 67.3077112},
    'UAE': {'lat': 24.341405248663627, 'lng': 54.533140184353535},
    'Hanif Medical Complex': {'lat': 33.6088744, 'lng': 72.8658331},
  };

  /// 200 m — allows check-in from inside the office building or its
  /// immediate perimeter (parking, lobby, adjacent block). Per spec the
  /// user is "still able to check in / check out even when they are
  /// 200 metres away from the listed locations", so `distance <= 200 m`
  /// is the accept threshold.
  static const double _officeRadiusMeters = 200.0;

  /// Returns the user's GPS position if they are within
  /// [_officeRadiusMeters] of ANY office in [_allowedOffices].
  /// Throws GeofenceException otherwise. Anti-cheat checks
  /// (mock GPS, accuracy, speed) are still applied.
  Future<Position> getValidatedPositionFromCities() async {
    final pos = await getMedianPosition();

    debugPrint(
      '📍 //n /n /n MY EXACT LAT/LNG: ${pos.latitude}, ${pos.longitude} /n/n/n/n',
    );

    if (pos.isMocked) {
      throw const GeofenceException(
        'Fake GPS detected. Disable mock location apps and try again.',
      );
    }
    if (pos.accuracy > _maxAccuracy) {
      throw GeofenceException(
        'GPS signal too weak (accuracy: ${pos.accuracy.toStringAsFixed(0)}m). '
        'Move to an open area and try again.',
      );
    }
    if (pos.accuracy == 0.0) {
      throw const GeofenceException(
        'Suspicious GPS reading. Disable mock location apps.',
      );
    }
    if (pos.speed > _maxIdleSpeed) {
      throw GeofenceException(
        'Unusual movement detected (${pos.speed.toStringAsFixed(1)} m/s). '
        'Stand still and try again.',
      );
    }

    double closest = double.infinity;
    bool insideAny = false;
    for (final entry in _allowedOffices.entries) {
      final cityLat = entry.value['lat']!;
      final cityLng = entry.value['lng']!;
      final distance = Geolocator.distanceBetween(
        cityLat,
        cityLng,
        pos.latitude,
        pos.longitude,
      );
      if (distance < closest) closest = distance;
      if (distance <= _officeRadiusMeters) {
        insideAny = true;
        break;
      }
    }

    if (!insideAny) {
      throw GeofenceException(
        'You are not at any office location. '
        'Closest office is ${closest.toStringAsFixed(0)} m away — '
        'must be within ${_officeRadiusMeters.toStringAsFixed(0)} m. '
        'Allowed offices: Lahore, Islamabad, Islamabad site office, '
        'Karachi, UAE, Hanif Medical Complex.',
      );
    }
    return pos;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REVERSE GEOCODING
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lng&format=json&zoom=18&addressdetails=1',
      );
      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'HRMSApp/1.0 (your@email.com)',
              'Accept-Language': 'en',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final parts = <String>[
            if (_str(address['road']) != null) _str(address['road'])!,
            if (_str(address['suburb']) != null) _str(address['suburb'])!,
            if (_str(address['city_district']) != null)
              _str(address['city_district'])!,
            if (_str(address['city']) != null)
              _str(address['city'])!
            else if (_str(address['town']) != null)
              _str(address['town'])!,
          ];
          if (parts.isNotEmpty) return parts.take(3).join(', ');
        }
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          return displayName.split(',').take(3).map((s) => s.trim()).join(', ');
        }
      }
    } catch (_) {}
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LIVE DOC
  // ══════════════════════════════════════════════════════════════════════════

  Future<AttendanceModel?> getTodayAttendance(String userId) async {
    final snap = await _live.doc(userId).get();
    if (!snap.exists || snap.data() == null) return null;
    final model = AttendanceModel.fromMap(snap.data()!);
    if (!DateTimeUtils.isSameDay(model.date, DateTime.now())) {
      await _archiveStaleRecord(userId, model);
      return null;
    }
    return model;
  }

  // ── CHECK-IN ──────────────────────────────────────────────────────────────

  /// Hard daily cutoff after which check-in (and check-out) are blocked at
  /// every layer. Mirrors the existing check-out button cutoff on the
  /// attendance screen and the `markAbsentAtSixPM` Cloud Function so the
  /// three stay locked together.
  static const int dailyCutoffHour = 18;
  static const int dailyCutoffMinute = 30;

  /// True when [now] is at or after the **default** daily cutoff (6:30 PM).
  /// Use [isPastDailyCutoffFor] instead when you know the employee — it
  /// honours per-employee work-hour overrides set by HR.
  static bool isPastDailyCutoff(DateTime now) =>
      now.hour > dailyCutoffHour ||
      (now.hour == dailyCutoffHour && now.minute >= dailyCutoffMinute);

  /// Per-employee cutoff helper. Looks up the active work-hour override
  /// for ([userId], [now])'s date; if one exists, the cutoff slides to
  /// `override.endHour:endMinute + 30 min`. Otherwise falls back to the
  /// global 6:30 PM cutoff.
  Future<bool> isPastDailyCutoffFor(String userId, DateTime now) async {
    if (userId.trim().isEmpty) return isPastDailyCutoff(now);
    try {
      final override = await _overrideService.activeFor(userId, now);
      if (override != null) return override.isPastDailyCutoff(now);
    } catch (_) {
      // fall through to default on any lookup failure
    }
    return isPastDailyCutoff(now);
  }

  final WorkHourOverrideService _overrideService = WorkHourOverrideService();

  Future<AttendanceModel> checkIn(
    String userId, {
    required double lat,
    required double lng,
  }) async {
    if (userId.trim().isEmpty) {
      // Belt-and-braces: refuse to call _live.doc('') which produces the
      // generic "a document path must be a non-empty string" error from
      // Firestore. The viewmodel guards this too, but other call sites
      // (tests, future code paths) get the same protection here.
      throw ArgumentError(
        'AttendanceService.checkIn requires a non-empty userId.',
      );
    }

    // Hard cutoff at 6:30 PM. After this point the `markAbsentAtSixPM`
    // cron will record today as absent; allowing a check-in here would
    // overwrite that record on the next archive write.
    // AFTER
    final _now = DateTime.now();

    // ── Per-employee window check ──────────────────────────────────────────
    // Fetch the active override first so both bounds use the same object.
    final activeOv = await _overrideService.activeFor(userId, _now);

    // 1. Too early? (before override.workStart OR before 8:00 AM default)
    final bool tooEarly;
    if (activeOv != null) {
      tooEarly =
          _now.hour < activeOv.workStartHour ||
          (_now.hour == activeOv.workStartHour &&
              _now.minute < activeOv.workStartMinute);
    } else {
      tooEarly = _now.hour < 8; // global default: window opens at 8 AM
    }
    if (tooEarly) {
      final opensAt = activeOv != null
          ? '${activeOv.workStartHour}:${activeOv.workStartMinute.toString().padLeft(2, '0')}'
          : '8:00';
      throw StateError(
        'Check-in window has not opened yet. '
        'Your shift starts at $opensAt. Try again then.',
      );
    }

    // 2. Too late? (past override cutoff OR past global 6:30 PM)
    final bool tooLate = activeOv != null
        ? activeOv.isPastDailyCutoff(_now)
        : isPastDailyCutoff(_now);
    if (tooLate) {
      throw StateError('Check-in window closed for today. Try again tomorrow.');
    }

    final today = DateTimeUtils.startOfDay(DateTime.now());
    final dayKey = DateTimeUtils.toDateKey(today);

    // Check live doc first (fastest path — live doc still present pre-cleanup).
    final existingLive = await getTodayAttendance(userId);
    if (existingLive != null) {
      final ci = existingLive.checkInTime;
      final co = existingLive.checkOutTime;
      if (ci != null && co != null && co.difference(ci).inSeconds > 60) {
        throw Exception(
          'Attendance already recorded for today. '
          'Check-in resets tomorrow at 8:00 AM.',
        );
      }
    }

    // Fallback: check archive in case the live doc was cleaned up already
    // (cleanStaleLiveRecords or deleteCheckedOutForToday deleted it).
    if (existingLive == null) {
      final archive = await getMonthlyArchive(userId, today.year, today.month);
      final archivedToday = archive?.days[dayKey];
      if (archivedToday != null) {
        final ci = archivedToday.checkInTime;
        final co = archivedToday.checkOutTime;
        if (ci != null && co != null && co.difference(ci).inSeconds > 60) {
          throw Exception(
            'Attendance already recorded for today. '
            'Check-in resets tomorrow at 8:00 AM.',
          );
        }
      }
    }

    final now = DateTime.now();
    final address = await reverseGeocode(lat, lng);
    final settings = await getOfficeSettings();
    final leave = await fetchApprovedLeaveModel(userId, today);

    // Block check-in entirely for full-day approved leave. The day already
    // belongs to the leave — overwriting it with a "checkedIn" record
    // would corrupt the archive. First-half (afternoon check-in) and
    // second-half (morning check-in then 1 PM departure) leaves still
    // allow a check-in, handled below.
    if (leave != null && !leave.isFirstHalf && !leave.isSecondHalf) {
      throw StateError(
        'You are on approved leave today. Check-in is not allowed.',
      );
    }

    AttendanceStatus status = AttendanceStatus.checkedIn;
    String? leaveRequestId;
    String? leaveType;

    if (leave != null && leave.isFirstHalf) {
      status = AttendanceStatus.firstHalfLeave;
      leaveRequestId = leave.id;
      leaveType = leave.duration.value;
    } else {
      // Honor any HR-defined work-hour override for this employee + date.
      // When an override is active, the late boundary becomes
      // override.workStart + 15 min grace; otherwise it's the office
      // default (settings.workStartHour + 15 min).
      final override = await _overrideService.activeFor(userId, now);
      final startHour = override?.workStartHour ?? settings.workStartHour;
      final startMinute = override?.workStartMinute ?? 0;
      final isLate =
          now.hour > startHour ||
          (now.hour == startHour && now.minute > startMinute + 15);

      if (isLate) {
        status = AttendanceStatus.late;
        debugPrint(
          '[Attendance] Late check-in at '
          '${now.hour}:${now.minute.toString().padLeft(2, '0')} '
          '(Grace ends at $startHour:${(startMinute + 15).toString().padLeft(2, '0')}'
          '${override != null ? ', custom shift' : ''})',
        );
      }
    }

    final record = AttendanceModel(
      userId: userId,
      date: today,
      checkInTime: now,
      status: status,
      leaveRequestId: leaveRequestId,
      leaveType: leaveType,
      halfDayMark: settings.halfDayMark,
      halfDayCutoff: settings.halfDayCutoff,
      checkInCutoff: settings.checkInCutoff,
      workStartHour: settings.workStartHour,
      workEndHour: settings.workEndHour,
      checkInLatitude: lat,
      checkInLongitude: lng,
      checkInAddress: address,
    );

    await _live.doc(userId).set(record.toMap());
    await archiveAttendance(record);

    return record;
  }

  Future<void> startBreak(String userId, List<BreakEntry> breaks) async {
    await _live.doc(userId).update({
      'status': AttendanceStatus.onBreak.value,
      'breaks': breaks.map((b) => b.toMap()).toList(),
    });
  }

  // ── END BREAK ─────────────────────────────────────────────────────────────
  // FIX #3: Restore the correct pre-break status instead of always
  // writing checkedIn.
  //
  // Problem: endBreak() was hardcoded to set status = "checkedIn" regardless
  // of how the employee arrived. A late employee who took a break would have
  // their "late" status silently overwritten with "checkedIn" when the break
  // ended. The same issue existed in the viewmodel's endBreak().
  //
  // Fix: The [previousStatus] parameter is passed in from the viewmodel
  // (which already knows the pre-break status via isLate / isFirstHalfLeave).
  // The service writes exactly that status back — never hardcodes checkedIn.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> endBreak(
    String userId,
    List<BreakEntry> breaks, {
    AttendanceStatus previousStatus = AttendanceStatus.checkedIn,
  }) async {
    await _live.doc(userId).update({
      'status': previousStatus.value,
      'breaks': breaks.map((b) => b.toMap()).toList(),
    });
  }

  // ── CHECK-OUT ─────────────────────────────────────────────────────────────
  // FIX #2: archiveAttendance() is now called INSIDE checkOut() itself.
  //
  // FIX #3 (continued): finalStatus is now derived from checkInTime, NOT
  // from current.status.
  //
  // Problem: current.status could be "onBreak" if the employee checks out
  // while a break is still open (or if they ended break and the status was
  // wrongly reset to checkedIn). In both cases the switch's default branch
  // fired → status became "checkedOut" → the late marker was lost.
  //
  // Fix: We look at the actual checkInTime timestamp to decide if the
  // employee was late. This is immutable — it was recorded at check-in and
  // nothing in the break/checkout flow changes it. Leave statuses
  // (firstHalfLeave, secondHalfLeave) are detected from leaveType, which
  // is also immutable after check-in.
  // ─────────────────────────────────────────────────────────────────────────
  Future<AttendanceModel> checkOut(
    String userId, {
    required AttendanceModel current,
    required double lat,
    required double lng,
  }) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError(
        'AttendanceService.checkOut requires a non-empty userId.',
      );
    }
    final now = DateTime.now();
    final address = await reverseGeocode(lat, lng);
    final closedBreaks = current.breaks
        .map((b) => b.breakEnd == null ? b.copyWith(breakEnd: now) : b)
        .toList();

    // Derive the correct final status from immutable check-in data,
    // not from current.status which may have been mutated by break flows.
    final AttendanceStatus finalStatus;

    if (current.leaveType == LeaveDuration.firstHalf.value) {
      // Employee checked in on first-half leave
      finalStatus = AttendanceStatus.firstHalfLeave;
    } else if (current.leaveType == LeaveDuration.secondHalf.value) {
      // Employee worked morning on second-half leave
      finalStatus = AttendanceStatus.secondHalfLeave;
    } else if (current.checkInTime != null) {
      // Use checkInTime to decide late vs on-time — this never changes
      final settings = await getOfficeSettings();
      final checkInHour = current.checkInTime!.hour;
      final checkInMin = current.checkInTime!.minute;
      // Use the override active on the check-in date if any.
      final override = await _overrideService.activeFor(
        userId,
        current.checkInTime!,
      );
      final startHour = override?.workStartHour ?? settings.workStartHour;
      final startMinute = override?.workStartMinute ?? 0;
      final wasLate =
          checkInHour > startHour ||
          (checkInHour == startHour && checkInMin > startMinute);
      finalStatus = wasLate
          ? AttendanceStatus.late
          : AttendanceStatus.checkedOut;
    } else {
      finalStatus = AttendanceStatus.checkedOut;
    }

    final finalRecord = current.copyWith(
      checkOutTime: now,
      breaks: closedBreaks,
      status: finalStatus,
      checkOutLatitude: lat,
      checkOutLongitude: lng,
      checkOutAddress: address,
    );

    // Update live doc first
    await _live.doc(userId).update({
      ...finalRecord.toMap(),
      'totalWorkSeconds': finalRecord.totalWorkDuration.inSeconds,
      'totalBreakSeconds': finalRecord.totalBreakDuration.inSeconds,
    });

    // FIX #2: Write the completed record to the archive immediately.
    // This guarantees payroll can always read checkOutTime, totalWorkSeconds,
    // and totalBreakSeconds — even if the app crashes or closes right after
    // the live doc update above.
    final archivableRecord = finalRecord.copyWith(
      totalWorkSeconds: finalRecord.totalWorkDuration.inSeconds,
      totalBreakSeconds: finalRecord.totalBreakDuration.inSeconds,
    );
    await archiveAttendance(archivableRecord);

    debugPrint(
      '[Attendance] checkOut archived — '
      'workSecs: ${archivableRecord.totalWorkSeconds} '
      'breakSecs: ${archivableRecord.totalBreakSeconds}',
    );

    return finalRecord;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LEAVE HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<LeaveModel?> fetchApprovedLeaveModel(
    String userId,
    DateTime date,
  ) async {
    // The active leave-request flow (submit + lead/HR review) writes to
    // `request_for_leave` with field `uid` (not `userId`). The older
    // `leaves` collection is queried as a fallback for any leftover docs
    // from the legacy path. First match wins.
    try {
      final reqSnap = await _db
          .collection('request_for_leave')
          .where('uid', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(date))
          .where('endDate', isGreaterThanOrEqualTo: Timestamp.fromDate(date))
          .limit(1)
          .get();
      if (reqSnap.docs.isNotEmpty) {
        final data = Map<String, dynamic>.from(reqSnap.docs.first.data());
        // Normalize uid → userId so LeaveModel.fromMap reads the right field.
        if (data['userId'] == null && data['uid'] != null) {
          data['userId'] = data['uid'];
        }
        return LeaveModel.fromMap(data, id: reqSnap.docs.first.id);
      }
    } catch (e) {
      debugPrint('[AttendanceService] request_for_leave query error: $e');
    }
    try {
      final snap = await _leaves
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(date))
          .where('endDate', isGreaterThanOrEqualTo: Timestamp.fromDate(date))
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return LeaveModel.fromMap(snap.docs.first.data(), id: snap.docs.first.id);
    } catch (e) {
      debugPrint('[AttendanceService] fetchApprovedLeaveModel error: $e');
      return null;
    }
  }

  Future<LeaveModel?> fetchApprovedLeave(String userId, DateTime date) =>
      fetchApprovedLeaveModel(userId, date);

  Future<LeaveModel?> getLeaveById(String leaveId) async {
    try {
      final snap = await _leaves.doc(leaveId).get();
      if (!snap.exists || snap.data() == null) return null;
      return LeaveModel.fromMap(snap.data()!, id: snap.id);
    } catch (e) {
      debugPrint('[AttendanceService] getLeaveById error: $e');
      return null;
    }
  }

  Future<void> approveLeave({
    required String leaveId,
    required String hrUid,
  }) async {
    await _leaves.doc(leaveId).update({
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': hrUid,
    });

    final snap = await _leaves.doc(leaveId).get();
    if (!snap.exists) return;
    final leave = LeaveModel.fromMap(snap.data()!, id: snap.id);

    DateTime cursor = DateTimeUtils.startOfDay(leave.fromDate);
    final end = DateTimeUtils.startOfDay(leave.toDate);

    while (!cursor.isAfter(end)) {
      if (!isWeekend(cursor)) {
        final dayKey = DateTimeUtils.toDateKey(cursor);
        final docId = MonthlyArchive.docId(
          leave.userId,
          cursor.year,
          cursor.month,
        );
        final archiveSnap = await _archives.doc(docId).get();

        final AttendanceStatus leaveStatus;
        if (leave.isFirstHalf) {
          leaveStatus = AttendanceStatus.firstHalfLeave;
        } else if (leave.isSecondHalf) {
          leaveStatus = AttendanceStatus.secondHalfLeave;
        } else {
          leaveStatus = AttendanceStatus.onLeave;
        }

        if (archiveSnap.exists) {
          final daysMap =
              archiveSnap.data()?['days'] as Map<String, dynamic>? ?? {};
          if (daysMap.containsKey(dayKey)) {
            final existing = AttendanceModel.fromMap(
              daysMap[dayKey] as Map<String, dynamic>,
            );
            if (existing.status == AttendanceStatus.absent) {
              await _archives.doc(docId).update({
                'days.$dayKey.status': leaveStatus.value,
                'days.$dayKey.leaveRequestId': leaveId,
                'days.$dayKey.leaveType': leave.duration.value,
              });
            }
          } else {
            await _archives.doc(docId).set({
              'userId': leave.userId,
              'year': cursor.year,
              'month': cursor.month,
              'days': {
                dayKey: AttendanceModel(
                  userId: leave.userId,
                  date: cursor,
                  status: leaveStatus,
                  leaveRequestId: leaveId,
                  leaveType: leave.duration.value,
                ).toMap(),
              },
            }, SetOptions(merge: true));
          }
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ARCHIVE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> archiveAttendance(AttendanceModel record) async {
    final docId = MonthlyArchive.docId(
      record.userId,
      record.date.year,
      record.date.month,
    );
    final dayKey = DateTimeUtils.toDateKey(record.date);
    await _archives.doc(docId).set({
      'userId': record.userId,
      'year': record.date.year,
      'month': record.date.month,
      'days': {dayKey: record.toMap()}, // full overwrite of this day's map
    }, SetOptions(merge: true));
  }

  Future<void> deleteCheckedOutForToday(String userId) async {
    final todayKey = DateTimeUtils.toDateKey(
      DateTimeUtils.startOfDay(DateTime.now()),
    );
    final snap = await _live.doc(userId).get();
    if (!snap.exists || snap.data() == null) return;
    final data = snap.data()!;
    final status = data['status'] as String?;
    final df = data['date'];
    String? storedKey;
    if (df is Timestamp) {
      storedKey = DateTimeUtils.toDateKey(df.toDate());
    } else if (df is String)
      storedKey = df;
    if (status == AttendanceStatus.checkedOut.value && storedKey == todayKey) {
      await _live.doc(userId).delete();
    }
  }

  Future<void> _archiveStaleRecord(
    String userId,
    AttendanceModel record,
  ) async {
    if (record.checkInTime != null) {
      await archiveAttendance(record);
    }
    await _live.doc(userId).delete();
  }

  Future<MonthlyArchive?> getMonthlyArchive(
    String userId,
    int year,
    int month,
  ) async {
    final snap = await _archives
        .doc(MonthlyArchive.docId(userId, year, month))
        .get();
    if (!snap.exists || snap.data() == null) return null;
    return MonthlyArchive.fromMap(snap.data()!);
  }

  Future<List<MonthlyArchive>> getRecentArchives(
    String userId, {
    int months = 3,
  }) async {
    final now = DateTime.now();
    final futures = List.generate(months, (i) {
      final dt = DateTime(now.year, now.month - i, 1);
      return getMonthlyArchive(userId, dt.year, dt.month);
    });
    return (await Future.wait(futures)).whereType<MonthlyArchive>().toList();
  }

  List<AttendanceModel> flattenArchives(List<MonthlyArchive> archives) {
    final all = archives.expand((a) => a.days.values).toList();
    all.sort((a, b) => b.date.compareTo(a.date));
    return all;
  }

  Future<List<AttendanceModel>> getHistory(
    String userId, {
    int days = 30,
  }) async {
    final archives = await getRecentArchives(userId, months: 2);
    final all = flattenArchives(archives);
    final cutoff = DateTimeUtils.startOfDay(
      DateTime.now(),
    ).subtract(Duration(days: days));
    return all.where((r) => r.date.isAfter(cutoff)).toList();
  }

  Future<void> markAbsent(String userId) async {
    final today = DateTimeUtils.startOfDay(DateTime.now());
    await archiveAttendance(
      AttendanceModel(
        userId: userId,
        date: today,
        status: AttendanceStatus.absent,
      ),
    );
  }

  Stream<List<AttendanceModel>> streamTodayLiveAttendance() {
    return _live.snapshots().map((snapshot) {
      final today = DateTimeUtils.startOfDay(DateTime.now());
      return snapshot.docs
          .map((doc) => AttendanceModel.fromMap(doc.data()))
          .where((r) => DateTimeUtils.isSameDay(r.date, today))
          .toList();
    });
  }
}
