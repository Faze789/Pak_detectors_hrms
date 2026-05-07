import 'package:cloud_firestore/cloud_firestore.dart';

// ─── AttendanceStatus ─────────────────────────────────────────────────────────

enum AttendanceStatus {
  checkedIn,
  onBreak,
  checkedOut,
  absent,
  present,
  late,
  halfDay,
  onLeave,
  firstHalfLeave, // morning on leave, came in after 1 PM
  secondHalfLeave, // worked morning, left at 1 PM
}

extension AttendanceStatusX on AttendanceStatus {
  String get value {
    switch (this) {
      case AttendanceStatus.checkedIn:
        return 'checkedIn';
      case AttendanceStatus.onBreak:
        return 'onBreak';
      case AttendanceStatus.checkedOut:
        return 'checkedOut';
      case AttendanceStatus.absent:
        return 'absent';
      case AttendanceStatus.present:
        return 'present';
      case AttendanceStatus.late:
        return 'late';
      case AttendanceStatus.halfDay:
        return 'halfDay';
      case AttendanceStatus.onLeave:
        return 'onLeave';
      case AttendanceStatus.firstHalfLeave:
        return 'firstHalfLeave';
      case AttendanceStatus.secondHalfLeave:
        return 'secondHalfLeave';
    }
  }

  String get label {
    switch (this) {
      case AttendanceStatus.checkedIn:
        return 'Checked In';
      case AttendanceStatus.onBreak:
        return 'On Break';
      case AttendanceStatus.checkedOut:
        return 'Checked Out';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.halfDay:
        return 'Half Day';
      case AttendanceStatus.onLeave:
        return 'On Leave';
      case AttendanceStatus.firstHalfLeave:
        return 'First Half Leave';
      case AttendanceStatus.secondHalfLeave:
        return 'Second Half Leave';
    }
  }

  String get shortLabel {
    switch (this) {
      case AttendanceStatus.checkedIn:
        return 'In';
      case AttendanceStatus.onBreak:
        return 'Break';
      case AttendanceStatus.checkedOut:
        return 'Out';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.halfDay:
        return 'Half Day';
      case AttendanceStatus.onLeave:
        return 'Leave';
      case AttendanceStatus.firstHalfLeave:
        return '½ AM Leave';
      case AttendanceStatus.secondHalfLeave:
        return '½ PM Leave';
    }
  }

  /// Foreground color for chips/badges.
  int get colorValue {
    switch (this) {
      case AttendanceStatus.checkedIn:
        return 0xFF2563EB;
      case AttendanceStatus.onBreak:
        return 0xFFF97316;
      case AttendanceStatus.checkedOut:
        return 0xFF059669;
      case AttendanceStatus.absent:
        return 0xFFDC2626;
      case AttendanceStatus.present:
        return 0xFF059669;
      case AttendanceStatus.late:
        return 0xFFF59E0B;
      case AttendanceStatus.halfDay:
        return 0xFF8B5CF6;
      case AttendanceStatus.onLeave:
        return 0xFF0891B2;
      case AttendanceStatus.firstHalfLeave:
        return 0xFF7C3AED;
      case AttendanceStatus.secondHalfLeave:
        return 0xFF0E7490;
    }
  }

  /// Background color for chips/badges.
  int get bgColorValue {
    switch (this) {
      case AttendanceStatus.checkedIn:
        return 0xFFDBEAFE;
      case AttendanceStatus.onBreak:
        return 0xFFFFF7ED;
      case AttendanceStatus.checkedOut:
        return 0xFFD1FAE5;
      case AttendanceStatus.absent:
        return 0xFFFEE2E2;
      case AttendanceStatus.present:
        return 0xFFD1FAE5;
      case AttendanceStatus.late:
        return 0xFFFEF3C7;
      case AttendanceStatus.halfDay:
        return 0xFFEDE9FE;
      case AttendanceStatus.onLeave:
        return 0xFFCFFAFE;
      case AttendanceStatus.firstHalfLeave:
        return 0xFFF5F3FF;
      case AttendanceStatus.secondHalfLeave:
        return 0xFFECFEFF;
    }
  }

  /// True for any leave variant.
  bool get isAnyLeave =>
      this == AttendanceStatus.onLeave ||
      this == AttendanceStatus.firstHalfLeave ||
      this == AttendanceStatus.secondHalfLeave;

  bool get isAbsent => this == AttendanceStatus.absent;

  /// True if the employee was physically present for at least part of the day.
  bool get wasPresent =>
      this == AttendanceStatus.present ||
      this == AttendanceStatus.checkedIn ||
      this == AttendanceStatus.onBreak ||
      this == AttendanceStatus.checkedOut ||
      this == AttendanceStatus.late ||
      this == AttendanceStatus.halfDay ||
      this == AttendanceStatus.firstHalfLeave ||
      this == AttendanceStatus.secondHalfLeave;

  static AttendanceStatus fromString(String? s) {
    switch (s) {
      case 'checkedIn':
        return AttendanceStatus.checkedIn;
      case 'onBreak':
        return AttendanceStatus.onBreak;
      case 'checkedOut':
        return AttendanceStatus.checkedOut;
      case 'absent':
        return AttendanceStatus.absent;
      case 'present':
        return AttendanceStatus.present;
      case 'late':
        return AttendanceStatus.late;
      case 'halfDay':
        return AttendanceStatus.halfDay;
      case 'onLeave':
        return AttendanceStatus.onLeave;
      case 'firstHalfLeave':
        return AttendanceStatus.firstHalfLeave;
      case 'secondHalfLeave':
        return AttendanceStatus.secondHalfLeave;
      default:
        return AttendanceStatus.absent;
    }
  }
}

// ─── BreakEntry ───────────────────────────────────────────────────────────────

class BreakEntry {
  final DateTime breakStart;
  final DateTime? breakEnd;

  const BreakEntry({required this.breakStart, this.breakEnd});

  Duration get duration {
    final end = breakEnd ?? DateTime.now();
    return end.difference(breakStart);
  }

  bool get isOngoing => breakEnd == null;

  Map<String, dynamic> toMap() => {
    'breakStart': Timestamp.fromDate(breakStart),
    'breakEnd': breakEnd != null ? Timestamp.fromDate(breakEnd!) : null,
  };

  factory BreakEntry.fromMap(Map<String, dynamic> m) => BreakEntry(
    breakStart: (m['breakStart'] as Timestamp).toDate(),
    breakEnd: m['breakEnd'] != null
        ? (m['breakEnd'] as Timestamp).toDate()
        : null,
  );

  BreakEntry copyWith({DateTime? breakStart, DateTime? breakEnd}) => BreakEntry(
    breakStart: breakStart ?? this.breakStart,
    breakEnd: breakEnd ?? this.breakEnd,
  );
}

// ─── AttendanceModel (one day's record) ──────────────────────────────────────

class AttendanceModel {
  final String userId;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final List<BreakEntry> breaks;
  final AttendanceStatus status;

  // Leave info — leaveRequestId links to leaves/{id} collection
  final String? leaveRequestId;
  final String? leaveType; // 'fullDay' | 'firstHalf' | 'secondHalf'

  // Office settings snapshot stored by Cloud Function for audit
  final int? checkInCutoff;
  final int? halfDayMark;
  final int? halfDayCutoff;
  final int? workStartHour;
  final int? workEndHour;

  // Location at check-in
  final double? checkInLatitude;
  final double? checkInLongitude;
  final String? checkInAddress;

  // Location at check-out
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final String? checkOutAddress;

  // Cached totals
  final int totalWorkSeconds;
  final int totalBreakSeconds;

  const AttendanceModel({
    required this.userId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.breaks = const [],
    this.status = AttendanceStatus.absent,
    this.leaveRequestId,
    this.leaveType,
    this.checkInCutoff,
    this.halfDayMark,
    this.halfDayCutoff,
    this.workStartHour,
    this.workEndHour,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkInAddress,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.checkOutAddress,
    this.totalWorkSeconds = 0,
    this.totalBreakSeconds = 0,
  });

  // ── Convenience getters ──────────────────────────────────────────────────

  bool get isFirstHalfLeave => status == AttendanceStatus.firstHalfLeave;
  bool get isSecondHalfLeave => status == AttendanceStatus.secondHalfLeave;
  bool get isAnyLeave => status.isAnyLeave;
  bool get wasPresent => status.wasPresent;

  // ── Computed durations ───────────────────────────────────────────────────

  Duration get totalWorkDuration {
    if (checkInTime == null) return Duration.zero;
    final end = checkOutTime ?? DateTime.now();
    final totalBreak = breaks.fold<int>(
      0,
      (sum, b) =>
          sum +
          (b.breakEnd ?? DateTime.now()).difference(b.breakStart).inSeconds,
    );
    final raw = end.difference(checkInTime!).inSeconds - totalBreak;
    return Duration(seconds: raw < 0 ? 0 : raw);
  }

  Duration get totalBreakDuration => Duration(
    seconds: breaks.fold<int>(
      0,
      (sum, b) =>
          sum +
          (b.breakEnd ?? DateTime.now()).difference(b.breakStart).inSeconds,
    ),
  );

  int get productivityPercent {
    final work = totalWorkDuration.inSeconds;
    final brk = totalBreakDuration.inSeconds;
    final total = work + brk;
    if (total == 0) return 100;
    return ((work / total) * 100).round().clamp(0, 100);
  }

  // ── Serialization ────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'date': Timestamp.fromDate(date),
    'checkInTime': checkInTime != null
        ? Timestamp.fromDate(checkInTime!)
        : null,
    'checkOutTime': checkOutTime != null
        ? Timestamp.fromDate(checkOutTime!)
        : null,
    'breaks': breaks.map((b) => b.toMap()).toList(),
    'status': status.value,
    if (leaveRequestId != null) 'leaveRequestId': leaveRequestId,
    if (leaveType != null) 'leaveType': leaveType,
    if (checkInCutoff != null) 'checkInCutoff': checkInCutoff,
    if (halfDayMark != null) 'halfDayMark': halfDayMark,
    if (halfDayCutoff != null) 'halfDayCutoff': halfDayCutoff,
    if (workStartHour != null) 'workStartHour': workStartHour,
    if (workEndHour != null) 'workEndHour': workEndHour,
    'checkInLatitude': checkInLatitude,
    'checkInLongitude': checkInLongitude,
    'checkInAddress': checkInAddress,
    'checkOutLatitude': checkOutLatitude,
    'checkOutLongitude': checkOutLongitude,
    'checkOutAddress': checkOutAddress,
    'totalWorkSeconds': totalWorkDuration.inSeconds,
    'totalBreakSeconds': totalBreakDuration.inSeconds,
  };

  /// Defensive Timestamp/String/DateTime parser. Never throws.
  /// Returns `fallback` (default = DateTime.now()) on any failure.
  static DateTime _parseDate(dynamic v) {
    // final fb = fallback ?? DateTime.now();
    // if (v == null) return fb;
    // if (v is DateTime) return v;
    // if (v is Timestamp) {
    //   try {
    //     return v.toDate();
    //   } catch (_) {
    //     return fb;
    //   }
    // }
    // if (v is String) {
    //   try {
    //     return DateTime.parse(v);
    //   } catch (_) {
    //     return fb;
    //   }
    // }
    // if (v is num) {
    //   try {
    //     return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    //   } catch (_) {
    //     return fb;
    //   }
    // }
    return DateTime.now();
  }

  static DateTime? _parseDateNullable(dynamic v) {
    if (v == null) return null;
    return _parseDate(v);
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> m) => AttendanceModel(
    userId: m['userId'] as String? ?? '',
    date: _parseDate(m['date']),
    checkInTime: _parseDateNullable(m['checkInTime']),
    checkOutTime: _parseDateNullable(m['checkOutTime']),
    breaks: (m['breaks'] as List<dynamic>? ?? [])
        .map((e) {
          try {
            return BreakEntry.fromMap(e as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<BreakEntry>()
        .toList(),
    status: AttendanceStatusX.fromString(m['status'] as String?),
    leaveRequestId: m['leaveRequestId'] as String?,
    leaveType: m['leaveType'] as String?,
    checkInCutoff: (m['checkInCutoff'] as num?)?.toInt(),
    halfDayMark: (m['halfDayMark'] as num?)?.toInt(),
    halfDayCutoff: (m['halfDayCutoff'] as num?)?.toInt(),
    workStartHour: (m['workStartHour'] as num?)?.toInt(),
    workEndHour: (m['workEndHour'] as num?)?.toInt(),
    checkInLatitude: (m['checkInLatitude'] as num?)?.toDouble(),
    checkInLongitude: (m['checkInLongitude'] as num?)?.toDouble(),
    checkInAddress: m['checkInAddress'] as String?,
    checkOutLatitude: (m['checkOutLatitude'] as num?)?.toDouble(),
    checkOutLongitude: (m['checkOutLongitude'] as num?)?.toDouble(),
    checkOutAddress: m['checkOutAddress'] as String?,
    totalWorkSeconds: (m['totalWorkSeconds'] as num?)?.toInt() ?? 0,
    totalBreakSeconds: (m['totalBreakSeconds'] as num?)?.toInt() ?? 0,
  );

  AttendanceModel copyWith({
    String? userId,
    DateTime? date,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    List<BreakEntry>? breaks,
    AttendanceStatus? status,
    String? leaveRequestId,
    String? leaveType,
    int? checkInCutoff,
    int? halfDayMark,
    int? halfDayCutoff,
    int? workStartHour,
    int? workEndHour,
    double? checkInLatitude,
    double? checkInLongitude,
    String? checkInAddress,
    double? checkOutLatitude,
    double? checkOutLongitude,
    String? checkOutAddress,
    int? totalWorkSeconds,
    int? totalBreakSeconds,
  }) => AttendanceModel(
    userId: userId ?? this.userId,
    date: date ?? this.date,
    checkInTime: checkInTime ?? this.checkInTime,
    checkOutTime: checkOutTime ?? this.checkOutTime,
    breaks: breaks ?? this.breaks,
    status: status ?? this.status,
    leaveRequestId: leaveRequestId ?? this.leaveRequestId,
    leaveType: leaveType ?? this.leaveType,
    checkInCutoff: checkInCutoff ?? this.checkInCutoff,
    halfDayMark: halfDayMark ?? this.halfDayMark,
    halfDayCutoff: halfDayCutoff ?? this.halfDayCutoff,
    workStartHour: workStartHour ?? this.workStartHour,
    workEndHour: workEndHour ?? this.workEndHour,
    checkInLatitude: checkInLatitude ?? this.checkInLatitude,
    checkInLongitude: checkInLongitude ?? this.checkInLongitude,
    checkInAddress: checkInAddress ?? this.checkInAddress,
    checkOutLatitude: checkOutLatitude ?? this.checkOutLatitude,
    checkOutLongitude: checkOutLongitude ?? this.checkOutLongitude,
    checkOutAddress: checkOutAddress ?? this.checkOutAddress,
    totalWorkSeconds: totalWorkSeconds ?? this.totalWorkSeconds,
    totalBreakSeconds: totalBreakSeconds ?? this.totalBreakSeconds,
  );
}

// ─── MonthlyArchive ───────────────────────────────────────────────────────────

class MonthlyArchive {
  final String userId;
  final int year;
  final int month;
  final Map<String, AttendanceModel> days;

  const MonthlyArchive({
    required this.userId,
    required this.year,
    required this.month,
    this.days = const {},
  });

  static String docId(String userId, int year, int month) =>
      '${userId}_${year}_${month.toString().padLeft(2, '0')}';

  static String dayKey(DateTime date) => DateTimeUtils.toDateKey(date);

  // ── Stats ────────────────────────────────────────────────────────────────

  int get totalDays => days.length;

  /// Includes half-day workers as present.
  int get presentDays => days.values.where((d) => d.wasPresent).length;

  int get absentDays => days.values.where((d) => d.status.isAbsent).length;

  /// All leave types combined.
  int get leaveDays => days.values.where((d) => d.status.isAnyLeave).length;

  /// Full day leaves only.
  int get fullDayLeaveDays =>
      days.values.where((d) => d.status == AttendanceStatus.onLeave).length;

  /// Each half-day counts as 0.5.
  double get halfDayLeaveCount =>
      days.values
          .where(
            (d) =>
                d.status == AttendanceStatus.firstHalfLeave ||
                d.status == AttendanceStatus.secondHalfLeave,
          )
          .length *
      0.5;

  /// Total leave deducted from balance.
  double get totalDeductedLeaveDays => fullDayLeaveDays + halfDayLeaveCount;

  double get avgDailyWorkHours {
    final worked = days.values.where((d) => d.checkInTime != null).toList();
    if (worked.isEmpty) return 0;
    final total = worked.fold<int>(
      0,
      (sum, d) => sum + d.totalWorkDuration.inSeconds,
    );
    return total / worked.length / 3600;
  }

  double get avgProductivity {
    final worked = days.values.where((d) => d.checkInTime != null).toList();
    if (worked.isEmpty) return 0;
    return worked.fold<double>(0, (sum, d) => sum + d.productivityPercent) /
        worked.length;
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'year': year,
    'month': month,
    'days': days.map((k, v) => MapEntry(k, v.toMap())),
  };

  factory MonthlyArchive.fromMap(Map<String, dynamic> m) {
    final daysRaw = m['days'] as Map<String, dynamic>? ?? {};
    final parsed = <String, AttendanceModel>{};
    for (final entry in daysRaw.entries) {
      final v = entry.value;
      if (v is! Map) continue;
      try {
        parsed[entry.key] = AttendanceModel.fromMap(
          Map<String, dynamic>.from(v),
        );
      } catch (_) {
        // Skip corrupted day records — better than crashing the whole month.
      }
    }
    return MonthlyArchive(
      userId: (m['userId'] as String?) ?? '',
      year: (m['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (m['month'] as num?)?.toInt() ?? DateTime.now().month,
      days: parsed,
    );
  }

  MonthlyArchive withDay(String dayKey, AttendanceModel record) {
    final updated = Map<String, AttendanceModel>.from(days);
    updated[dayKey] = record;
    return MonthlyArchive(
      userId: userId,
      year: year,
      month: month,
      days: updated,
    );
  }
}

// ─── DateTimeUtils ────────────────────────────────────────────────────────────

class DateTimeUtils {
  static String toDateKey(DateTime dt) =>
      '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  static DateTime startOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
