// lib/models/leave_request_model.dart
//
// Unified model for a request_for_leave Firestore document.
// Firestore path: request_for_leave/{docId}
//
// Schema:
// {
//   uid           : string   — employee Firebase UID
//   emp_id        : string   — employee ID (e.g. EMP_009)
//   name          : string   — employee display name
//   role          : string   — employee role/designation
//   leaveType     : string   — RequestLeaveType.value
//   startDate     : Timestamp
//   endDate       : Timestamp
//   totalDays     : int
//   note          : string   — reason / description
//   status        : string   — 'pending' | 'approved' | 'declined'
//   leadsNotified : List<String>  — emp_ids of leads to notify
//   hrReviewed    : bool
//   rejectionReason: string? — filled on decline
//   reviewedBy    : string?  — HR emp_id or lead emp_id
//   reviewedByName: string?
//   reviewedAt    : Timestamp?
//   createdAt     : Timestamp
//   notified      : bool     — true once push/in-app notification sent
// }

import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveRequestModel {
  final String id;
  final String uid;
  final String empId;
  final String name;
  final String role;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final String note;
  final String status; // 'pending' | 'approved' | 'declined'
  final List<String> leadsNotified;
  final bool hrReviewed;
  final String? rejectionReason;
  final String? reviewedBy;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final bool notified;

  const LeaveRequestModel({
    required this.id,
    required this.uid,
    required this.empId,
    required this.name,
    required this.role,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.note,
    required this.status,
    required this.leadsNotified,
    required this.hrReviewed,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedAt,
    required this.createdAt,
    required this.notified,
  });

  factory LeaveRequestModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime ts(String k) {
      final v = d[k];
      if (v is Timestamp) return v.toDate();
      return DateTime.now();
    }

    DateTime? tsOpt(String k) {
      final v = d[k];
      if (v is Timestamp) return v.toDate();
      return null;
    }

    return LeaveRequestModel(
      id: doc.id,
      uid: (d['uid'] as String?) ?? '',
      empId: (d['emp_id'] as String?) ?? '',
      name: (d['name'] as String?) ?? '',
      role: (d['role'] as String?) ?? '',
      leaveType: (d['leaveType'] as String?) ?? 'annualCasualSick',
      startDate: ts('startDate'),
      endDate: ts('endDate'),
      totalDays: (d['totalDays'] as int?) ?? 1,
      note: (d['note'] as String?) ?? '',
      status: (d['status'] as String?) ?? 'pending',
      leadsNotified: List<String>.from(d['leadsNotified'] ?? []),
      hrReviewed: (d['hrReviewed'] as bool?) ?? false,
      rejectionReason: d['rejectionReason'] as String?,
      reviewedBy: d['reviewedBy'] as String?,
      reviewedByName: d['reviewedByName'] as String?,
      reviewedAt: tsOpt('reviewedAt'),
      createdAt: ts('createdAt'),
      notified: (d['notified'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'emp_id': empId,
    'name': name,
    'role': role,
    'leaveType': leaveType,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'totalDays': totalDays,
    'note': note,
    'status': status,
    'leadsNotified': leadsNotified,
    'hrReviewed': hrReviewed,
    'rejectionReason': rejectionReason,
    'reviewedBy': reviewedBy,
    'reviewedByName': reviewedByName,
    'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
    'createdAt': Timestamp.fromDate(createdAt),
    'notified': notified,
  };
}
