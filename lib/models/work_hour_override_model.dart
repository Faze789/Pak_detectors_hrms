// lib/models/work_hour_override_model.dart
//
// HR-defined per-employee work-hour override. While an override is active
// for a given (userId, date), the attendance pipeline uses these hours
// instead of the global OfficeSettings defaults (9 AM – 6 PM).
//
// Stored at `work_hour_overrides/{overrideId}` so multiple overrides per
// employee coexist as separate docs (atomic create / delete; history kept).

import 'package:cloud_firestore/cloud_firestore.dart';

class WorkHourOverride {
  final String id;
  final String userId;
  final DateTime startDate;       // inclusive, midnight local
  final DateTime endDate;         // inclusive, midnight local
  final String startDateKey;      // "YYYY-MM-DD" — enables single-inequality
  final String endDateKey;        //   range queries without composite indexes.
  final int workStartHour;
  final int workStartMinute;
  final int workEndHour;
  final int workEndMinute;
  final String? reason;
  final String createdBy;
  final DateTime createdAt;

  const WorkHourOverride({
    required this.id,
    required this.userId,
    required this.startDate,
    required this.endDate,
    required this.startDateKey,
    required this.endDateKey,
    required this.workStartHour,
    required this.workStartMinute,
    required this.workEndHour,
    required this.workEndMinute,
    this.reason,
    required this.createdBy,
    required this.createdAt,
  });

  /// True when [d] is a weekday Mon–Fri AND falls inside this override's
  /// [startDate]..[endDate] window (both inclusive). Weekends are never
  /// covered — they're not working days per the company calendar.
  bool coversDate(DateTime d) {
    if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
      return false;
    }
    final day = DateTime(d.year, d.month, d.day);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return !day.isBefore(s) && !day.isAfter(e);
  }

  /// Cutoff for the hard daily check-in/out lockout on a day this
  /// override applies to. Mirrors the default semantics of
  /// `AttendanceService.isPastDailyCutoff` — work end + 30 min grace.
  bool isPastDailyCutoff(DateTime now) {
    final cutoffMinutes = workEndHour * 60 + workEndMinute + 30;
    final nowMinutes = now.hour * 60 + now.minute;
    return nowMinutes >= cutoffMinutes;
  }

  static String _toDateKey(DateTime d) =>
      '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'startDateKey': startDateKey,
        'endDateKey': endDateKey,
        'workStartHour': workStartHour,
        'workStartMinute': workStartMinute,
        'workEndHour': workEndHour,
        'workEndMinute': workEndMinute,
        if (reason != null) 'reason': reason,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory WorkHourOverride.fromMap(Map<String, dynamic> m, {required String id}) {
    final startTs = m['startDate'] as Timestamp?;
    final endTs = m['endDate'] as Timestamp?;
    final createdTs = m['createdAt'] as Timestamp?;
    final start = startTs?.toDate() ?? DateTime.now();
    final end = endTs?.toDate() ?? DateTime.now();
    return WorkHourOverride(
      id: id,
      userId: (m['userId'] ?? '').toString(),
      startDate: DateTime(start.year, start.month, start.day),
      endDate: DateTime(end.year, end.month, end.day),
      startDateKey: (m['startDateKey'] ?? _toDateKey(start)).toString(),
      endDateKey: (m['endDateKey'] ?? _toDateKey(end)).toString(),
      workStartHour: (m['workStartHour'] as num?)?.toInt() ?? 9,
      workStartMinute: (m['workStartMinute'] as num?)?.toInt() ?? 0,
      workEndHour: (m['workEndHour'] as num?)?.toInt() ?? 18,
      workEndMinute: (m['workEndMinute'] as num?)?.toInt() ?? 0,
      reason: (m['reason'] as String?)?.trim().isNotEmpty == true
          ? m['reason'] as String
          : null,
      createdBy: (m['createdBy'] ?? '').toString(),
      createdAt: createdTs?.toDate() ?? DateTime.now(),
    );
  }

  /// Build a new override (id is filled in after Firestore add).
  static WorkHourOverride forCreate({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    required int workStartHour,
    required int workStartMinute,
    required int workEndHour,
    required int workEndMinute,
    String? reason,
    required String createdBy,
  }) {
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(endDate.year, endDate.month, endDate.day);
    return WorkHourOverride(
      id: '',
      userId: userId,
      startDate: s,
      endDate: e,
      startDateKey: _toDateKey(s),
      endDateKey: _toDateKey(e),
      workStartHour: workStartHour,
      workStartMinute: workStartMinute,
      workEndHour: workEndHour,
      workEndMinute: workEndMinute,
      reason: (reason ?? '').trim().isEmpty ? null : reason!.trim(),
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
  }
}
