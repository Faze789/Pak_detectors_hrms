// lib/models/leave_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum LeaveType { sick, annual, casual, unpaid }

enum LeaveStatus { pending, approved, rejected, cancelled }

/// How much of the day the leave covers.
enum LeaveDuration { fullDay, firstHalf, secondHalf }

extension LeaveTypeX on LeaveType {
  String get value {
    switch (this) {
      case LeaveType.sick:
        return 'sick';
      case LeaveType.annual:
        return 'annual';
      case LeaveType.casual:
        return 'casual';
      case LeaveType.unpaid:
        return 'unpaid';
    }
  }

  String get label {
    switch (this) {
      case LeaveType.sick:
        return 'Sick Leave';
      case LeaveType.annual:
        return 'Annual Leave';
      case LeaveType.casual:
        return 'Casual Leave';
      case LeaveType.unpaid:
        return 'Unpaid Leave';
    }
  }

  static LeaveType fromString(String s) {
    switch (s) {
      case 'sick':
        return LeaveType.sick;
      case 'annual':
        return LeaveType.annual;
      case 'casual':
        return LeaveType.casual;
      case 'unpaid':
        return LeaveType.unpaid;
      default:
        return LeaveType.casual;
    }
  }
}

extension LeaveStatusX on LeaveStatus {
  String get value {
    switch (this) {
      case LeaveStatus.pending:
        return 'pending';
      case LeaveStatus.approved:
        return 'approved';
      case LeaveStatus.rejected:
        return 'rejected';
      case LeaveStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case LeaveStatus.pending:
        return 'Pending';
      case LeaveStatus.approved:
        return 'Approved';
      case LeaveStatus.rejected:
        return 'Rejected';
      case LeaveStatus.cancelled:
        return 'Cancelled';
    }
  }

  static LeaveStatus fromString(String s) {
    switch (s) {
      case 'approved':
        return LeaveStatus.approved;
      case 'rejected':
        return LeaveStatus.rejected;
      case 'cancelled':
        return LeaveStatus.cancelled;
      default:
        return LeaveStatus.pending;
    }
  }
}

extension LeaveDurationX on LeaveDuration {
  String get value {
    switch (this) {
      case LeaveDuration.fullDay:
        return 'fullDay';
      case LeaveDuration.firstHalf:
        return 'firstHalf';
      case LeaveDuration.secondHalf:
        return 'secondHalf';
    }
  }

  String get label {
    switch (this) {
      case LeaveDuration.fullDay:
        return 'Full Day';
      case LeaveDuration.firstHalf:
        return 'First Half (Morning)';
      case LeaveDuration.secondHalf:
        return 'Second Half (Afternoon)';
    }
  }

  /// How many days this duration counts as for leave balance deduction.
  double get deductionDays {
    switch (this) {
      case LeaveDuration.fullDay:
        return 1.0;
      case LeaveDuration.firstHalf:
        return 0.5;
      case LeaveDuration.secondHalf:
        return 0.5;
    }
  }

  static LeaveDuration fromString(String s) {
    switch (s) {
      case 'firstHalf':
        return LeaveDuration.firstHalf;
      case 'secondHalf':
        return LeaveDuration.secondHalf;
      default:
        return LeaveDuration.fullDay;
    }
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────

class LeaveModel {
  final String id;
  final String userId;
  final String employeeName;
  final String emp_id;
  final String employeeRole;
  final LeaveType type; // sick / annual / casual / unpaid
  final LeaveDuration duration; // fullDay / firstHalf / secondHalf
  final DateTime fromDate;
  final DateTime toDate;
  final int days; // calendar days spanned
  final double deductedDays; // actual deduction (0.5 for half day)
  final String reason;
  final LeaveStatus status;
  final DateTime submittedAt;
  final String? hrNote;

  // ── Multi-lead approval ───────────────────────────────────────────────────
  /// emp_ids of leads who must approve. Empty for legacy / HR-only flows.
  final List<String> requiredApproverEmpIds;
  /// History of decisions, in chronological order. Each entry:
  /// {empId, name, action: 'approved'|'rejected', decidedAt, note}
  final List<Map<String, dynamic>> approvals;

  const LeaveModel({
    required this.id,
    required this.userId,
    required this.employeeName,
    required this.emp_id,
    required this.employeeRole,
    required this.type,
    required this.duration,
    required this.fromDate,
    required this.toDate,
    required this.days,
    required this.deductedDays,
    required this.reason,
    required this.status,
    required this.submittedAt,
    this.hrNote,
    this.requiredApproverEmpIds = const [],
    this.approvals = const [],
  });

  /// Convenience — is this a half-day leave of any kind?
  bool get isHalfDay =>
      duration == LeaveDuration.firstHalf ||
      duration == LeaveDuration.secondHalf;

  bool get isFirstHalf => duration == LeaveDuration.firstHalf;
  bool get isSecondHalf => duration == LeaveDuration.secondHalf;

  // ── Firestore serialization ───────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'employeeName': employeeName,
    'emp_id': emp_id,
    'employeeRole': employeeRole,
    'type': type.value,
    'leaveType': duration.value, // ← what the Cloud Function reads
    'duration': duration.value, // ← Flutter-side field name
    'fromDate': Timestamp.fromDate(fromDate),
    'toDate': Timestamp.fromDate(toDate),
    // Cloud Function uses startDate / endDate for its queries
    'startDate': Timestamp.fromDate(fromDate),
    'endDate': Timestamp.fromDate(toDate),
    'days': days,
    'deductedDays': deductedDays,
    'reason': reason,
    'status': status.value,
    'submittedAt': Timestamp.fromDate(submittedAt),
    if (hrNote != null) 'hrNote': hrNote,
    'requiredApproverEmpIds': requiredApproverEmpIds,
    'approvals': approvals,
  };

  factory LeaveModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime ts(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return DateTime.now();
    }

    final duration = LeaveDurationX.fromString(
      // support both field names for backwards compatibility
      map['leaveType'] as String? ?? map['duration'] as String? ?? 'fullDay',
    );

    return LeaveModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      employeeName: map['employeeName'] as String? ?? '',
      emp_id: map['emp_id'] as String? ?? '',
      employeeRole: map['employeeRole'] as String? ?? '',
      type: LeaveTypeX.fromString(map['type'] as String? ?? ''),
      duration: duration,
      fromDate: ts(map['fromDate'] ?? map['startDate']),
      toDate: ts(map['toDate'] ?? map['endDate']),
      days: (map['days'] as num?)?.toInt() ?? 1,
      deductedDays:
          (map['deductedDays'] as num?)?.toDouble() ?? duration.deductionDays,
      reason: map['reason'] as String? ?? '',
      status: LeaveStatusX.fromString(map['status'] as String? ?? ''),
      submittedAt: ts(map['submittedAt']),
      hrNote: map['hrNote'] as String?,
      requiredApproverEmpIds: List<String>.from(
        (map['requiredApproverEmpIds'] as List?) ?? const [],
      ),
      approvals: List<Map<String, dynamic>>.from(
        ((map['approvals'] as List?) ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      ),
    );
  }

  LeaveModel copyWith({
    LeaveStatus? status,
    LeaveDuration? duration,
    String? hrNote,
    double? deductedDays,
    List<String>? requiredApproverEmpIds,
    List<Map<String, dynamic>>? approvals,
  }) => LeaveModel(
    id: id,
    userId: userId,
    employeeName: employeeName,
    emp_id: emp_id,
    employeeRole: employeeRole,
    type: type,
    duration: duration ?? this.duration,
    fromDate: fromDate,
    toDate: toDate,
    days: days,
    deductedDays: deductedDays ?? this.deductedDays,
    reason: reason,
    status: status ?? this.status,
    submittedAt: submittedAt,
    hrNote: hrNote ?? this.hrNote,
    requiredApproverEmpIds:
        requiredApproverEmpIds ?? this.requiredApproverEmpIds,
    approvals: approvals ?? this.approvals,
  );

  @override
  String toString() =>
      'LeaveModel($id, $employeeName, ${type.value}, ${duration.value}, '
      '${status.value}, $fromDate→$toDate)';
}
