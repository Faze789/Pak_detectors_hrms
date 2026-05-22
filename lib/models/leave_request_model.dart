// lib/models/leave_request_model.dart
//
// Strongly-typed wrapper around a single `request_for_leave/{id}` doc.
// HRLeaveApprovalsScreen and AttendanceViewModel both consume this via
// `LeaveRequestModel.fromDoc(snapshot)`.

import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveRequestModel {
  final String id;
  final String uid;
  final String empId;
  final String name;
  final String role;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;

  /// 'pending' | 'approved' | 'declined'
  final String status;

  /// Recipient emp_ids the request was originally pushed to (leads + HR).
  final List<String> leadsNotified;
  final bool sentToHR;
  final bool hrReviewed;
  final bool notified;

  /// Free-text reason / note attached by the requester.
  final String note;

  /// 'annualCasualSick' | 'marriageOwn' | … — see RequestLeaveType.
  final String leaveType;

  /// Human-readable label snapshot, optional.
  final String? leaveTypeLabel;
  final String? reviewedBy;
  final String? reviewedByName;
  final DateTime? reviewedAt;

  /// Populated only when `status == 'declined'`.
  final String? rejectionReason;
  final DateTime? createdAt;

  const LeaveRequestModel({
    required this.id,
    required this.uid,
    required this.empId,
    required this.name,
    required this.role,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.status,
    required this.leadsNotified,
    required this.sentToHR,
    required this.hrReviewed,
    required this.notified,
    required this.note,
    required this.leaveType,
    this.leaveTypeLabel,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedAt,
    this.rejectionReason,
    this.createdAt,
  });

  factory LeaveRequestModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final m = doc.data() ?? const <String, dynamic>{};
    DateTime ts(dynamic v, [DateTime? fallback]) {
      if (v is Timestamp) return v.toDate();
      return fallback ?? DateTime.now();
    }

    return LeaveRequestModel(
      id: doc.id,
      uid: (m['uid'] ?? '').toString(),
      empId: (m['emp_id'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      role: (m['role'] ?? '').toString(),
      startDate: ts(m['startDate']),
      endDate: ts(m['endDate'], ts(m['startDate'])),
      totalDays: (m['totalDays'] as num?)?.toInt() ?? 0,
      status: (m['status'] ?? 'pending').toString(),
      leadsNotified:
          (m['leadsNotified'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      sentToHR: m['sentToHR'] as bool? ?? false,
      hrReviewed: m['hrReviewed'] as bool? ?? false,
      notified: m['notified'] as bool? ?? false,
      // We've seen this stored under both `note` (newer flow) and
      // `reason` (older callers) — coalesce so the UI sees one field.
      note: ((m['note'] ?? m['reason']) ?? '').toString(),
      leaveType: (m['leaveType'] ?? 'annualCasualSick').toString(),
      leaveTypeLabel: m['leaveTypeLabel']?.toString(),
      reviewedBy: m['reviewedBy']?.toString(),
      reviewedByName: m['reviewedByName']?.toString(),
      reviewedAt: m['reviewedAt'] is Timestamp
          ? (m['reviewedAt'] as Timestamp).toDate()
          : null,
      rejectionReason: m['rejectionReason']?.toString(),
      createdAt: m['createdAt'] is Timestamp
          ? (m['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}
