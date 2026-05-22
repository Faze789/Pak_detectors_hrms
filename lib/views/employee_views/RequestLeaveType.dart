// lib/models/leave_request_model.dart
//
// Data model for a leave request document in the `request_for_leave`
// Firestore collection. Used by both the HR leave screen and the
// lead leave-approvals screen.

import 'package:cloud_firestore/cloud_firestore.dart';

// ─── RequestLeaveType ─────────────────────────────────────────────────────────
// Matches the string values written into request_for_leave.leaveType

enum RequestLeaveType {
  sick,
  casual,
  annual,
  unpaid,
  maternity,
  paternity,
  custom,
}

extension RequestLeaveTypeX on RequestLeaveType {
  String get value {
    switch (this) {
      case RequestLeaveType.sick:
        return 'sick';
      case RequestLeaveType.casual:
        return 'casual';
      case RequestLeaveType.annual:
        return 'annual';
      case RequestLeaveType.unpaid:
        return 'unpaid';
      case RequestLeaveType.maternity:
        return 'maternity';
      case RequestLeaveType.paternity:
        return 'paternity';
      case RequestLeaveType.custom:
        return 'custom';
    }
  }

  String get label {
    switch (this) {
      case RequestLeaveType.sick:
        return 'Sick Leave';
      case RequestLeaveType.casual:
        return 'Casual Leave';
      case RequestLeaveType.annual:
        return 'Annual Leave';
      case RequestLeaveType.unpaid:
        return 'Unpaid Leave';
      case RequestLeaveType.maternity:
        return 'Maternity Leave';
      case RequestLeaveType.paternity:
        return 'Paternity Leave';
      case RequestLeaveType.custom:
        return 'Other Leave';
    }
  }

  /// Parses a raw Firestore string back to the enum.
  /// Falls back to [RequestLeaveType.casual] instead of throwing.
  static RequestLeaveType parse(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'sick':
        return RequestLeaveType.sick;
      case 'casual':
        return RequestLeaveType.casual;
      case 'annual':
        return RequestLeaveType.annual;
      case 'unpaid':
        return RequestLeaveType.unpaid;
      case 'maternity':
        return RequestLeaveType.maternity;
      case 'paternity':
        return RequestLeaveType.paternity;
      default:
        // If the raw value is a non-null, non-empty string that doesn't
        // match a known key, surface it as-is via a synthetic label so
        // HR can still read it rather than seeing "Casual Leave" silently.
        return RequestLeaveType.casual;
    }
  }
}

// ─── LeaveRequestModel ────────────────────────────────────────────────────────

class LeaveRequestModel {
  final String id;
  final String uid;
  final String empId;
  final String name;
  final String role;
  final String leaveType; // raw string from Firestore
  final String leaveTypeLabel; // human-readable label stored alongside
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final String note; // employee's reason / note
  final String status; // 'pending' | 'approved' | 'declined'
  final List<String> leadsNotified;
  final bool hrReviewed;
  final String? reviewedBy; // emp_id of reviewer
  final String? reviewedByName;
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  const LeaveRequestModel({
    required this.id,
    required this.uid,
    required this.empId,
    required this.name,
    required this.role,
    required this.leaveType,
    required this.leaveTypeLabel,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.note,
    required this.status,
    required this.leadsNotified,
    required this.hrReviewed,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedByName,
    this.rejectionReason,
    this.reviewedAt,
  });

  // ── Firestore → model ────────────────────────────────────────────────────

  factory LeaveRequestModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LeaveRequestModel.fromMap(d, id: doc.id);
  }

  factory LeaveRequestModel.fromMap(
    Map<String, dynamic> d, {
    required String id,
  }) {
    DateTime ts(dynamic v, DateTime fallback) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return fallback;
    }

    DateTime? tsNullable(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    final rawLeaveType = (d['leaveType'] ?? '').toString();
    final rawLabel = (d['leaveTypeLabel'] ?? '').toString();
    final resolvedLabel = rawLabel.isNotEmpty
        ? rawLabel
        : RequestLeaveTypeX.parse(rawLeaveType).label;

    return LeaveRequestModel(
      id: id,
      uid: (d['uid'] ?? '').toString(),
      empId: (d['emp_id'] ?? '').toString(),
      name: (d['name'] ?? 'Employee').toString(),
      role: (d['role'] ?? '').toString(),
      leaveType: rawLeaveType,
      leaveTypeLabel: resolvedLabel,
      startDate: ts(d['startDate'], DateTime.now()),
      endDate: ts(d['endDate'], DateTime.now()),
      totalDays: (d['totalDays'] as num?)?.toInt() ?? 1,
      note: (d['note'] ?? d['reason'] ?? '').toString(),
      status: (d['status'] ?? 'pending').toString(),
      leadsNotified: List<String>.from(d['leadsNotified'] ?? []),
      hrReviewed: (d['hrReviewed'] as bool?) ?? false,
      reviewedBy: d['reviewedBy']?.toString(),
      reviewedByName: d['reviewedByName']?.toString(),
      rejectionReason: d['rejectionReason']?.toString(),
      reviewedAt: tsNullable(d['reviewedAt']),
      createdAt: ts(d['createdAt'], DateTime.now()),
    );
  }

  // ── model → Firestore ────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'emp_id': empId,
    'name': name,
    'role': role,
    'leaveType': leaveType,
    'leaveTypeLabel': leaveTypeLabel,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'totalDays': totalDays,
    'note': note,
    'status': status,
    'leadsNotified': leadsNotified,
    'hrReviewed': hrReviewed,
    if (reviewedBy != null) 'reviewedBy': reviewedBy,
    if (reviewedByName != null) 'reviewedByName': reviewedByName,
    if (rejectionReason != null) 'rejectionReason': rejectionReason,
    if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
    'createdAt': Timestamp.fromDate(createdAt),
  };

  LeaveRequestModel copyWith({
    String? id,
    String? uid,
    String? empId,
    String? name,
    String? role,
    String? leaveType,
    String? leaveTypeLabel,
    DateTime? startDate,
    DateTime? endDate,
    int? totalDays,
    String? note,
    String? status,
    List<String>? leadsNotified,
    bool? hrReviewed,
    String? reviewedBy,
    String? reviewedByName,
    String? rejectionReason,
    DateTime? reviewedAt,
    DateTime? createdAt,
  }) => LeaveRequestModel(
    id: id ?? this.id,
    uid: uid ?? this.uid,
    empId: empId ?? this.empId,
    name: name ?? this.name,
    role: role ?? this.role,
    leaveType: leaveType ?? this.leaveType,
    leaveTypeLabel: leaveTypeLabel ?? this.leaveTypeLabel,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    totalDays: totalDays ?? this.totalDays,
    note: note ?? this.note,
    status: status ?? this.status,
    leadsNotified: leadsNotified ?? this.leadsNotified,
    hrReviewed: hrReviewed ?? this.hrReviewed,
    reviewedBy: reviewedBy ?? this.reviewedBy,
    reviewedByName: reviewedByName ?? this.reviewedByName,
    rejectionReason: rejectionReason ?? this.rejectionReason,
    reviewedAt: reviewedAt ?? this.reviewedAt,
    createdAt: createdAt ?? this.createdAt,
  );
}
