import 'package:cloud_firestore/cloud_firestore.dart';

class OfficeSettings {
  /// Hour after which employee is auto-marked absent if not checked in.
  final int checkInCutoff;

  /// Midday split — first half is before this, second half is after.
  /// Default 13 = 1 PM.
  final int halfDayMark;

  /// Hour by which a first-half-leave employee must check in.
  /// Default 14 = 2 PM.
  final int halfDayCutoff;

  /// Official work start hour.
  final int workStartHour;

  /// Official work end hour.
  final int workEndHour;

  /// IANA timezone string.
  final String timezone;

  final DateTime? updatedAt;
  final String? updatedBy;

  const OfficeSettings({
    required this.checkInCutoff,
    required this.halfDayMark,
    required this.halfDayCutoff,
    required this.workStartHour,
    required this.workEndHour,
    required this.timezone,
    this.updatedAt,
    this.updatedBy,
  });

  factory OfficeSettings.defaults() => const OfficeSettings(
    checkInCutoff: 15,
    halfDayMark: 13,
    halfDayCutoff: 14,
    workStartHour: 9,
    workEndHour: 18,
    timezone: 'Asia/Karachi',
  );

  factory OfficeSettings.fromMap(Map<String, dynamic> m) => OfficeSettings(
    checkInCutoff: (m['checkInCutoff'] as num?)?.toInt() ?? 15,
    halfDayMark: (m['halfDayMark'] as num?)?.toInt() ?? 13,
    halfDayCutoff: (m['halfDayCutoff'] as num?)?.toInt() ?? 14,
    workStartHour: (m['workStartHour'] as num?)?.toInt() ?? 9,
    workEndHour: (m['workEndHour'] as num?)?.toInt() ?? 18,
    timezone: m['timezone'] as String? ?? 'Asia/Karachi',
    updatedAt: m['updatedAt'] != null
        ? (m['updatedAt'] as Timestamp).toDate()
        : null,
    updatedBy: m['updatedBy'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'checkInCutoff': checkInCutoff,
    'halfDayMark': halfDayMark,
    'halfDayCutoff': halfDayCutoff,
    'workStartHour': workStartHour,
    'workEndHour': workEndHour,
    'timezone': timezone,
    if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    if (updatedBy != null) 'updatedBy': updatedBy,
  };

  OfficeSettings copyWith({
    int? checkInCutoff,
    int? halfDayMark,
    int? halfDayCutoff,
    int? workStartHour,
    int? workEndHour,
    String? timezone,
    DateTime? updatedAt,
    String? updatedBy,
  }) => OfficeSettings(
    checkInCutoff: checkInCutoff ?? this.checkInCutoff,
    halfDayMark: halfDayMark ?? this.halfDayMark,
    halfDayCutoff: halfDayCutoff ?? this.halfDayCutoff,
    workStartHour: workStartHour ?? this.workStartHour,
    workEndHour: workEndHour ?? this.workEndHour,
    timezone: timezone ?? this.timezone,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedBy: updatedBy ?? this.updatedBy,
  );

  @override
  String toString() =>
      'OfficeSettings(cutoff:$checkInCutoff halfMark:$halfDayMark '
      'halfCutoff:$halfDayCutoff start:$workStartHour end:$workEndHour tz:$timezone)';
}
