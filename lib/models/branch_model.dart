// lib/models/branch_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BranchModel  →  Firestore: /branches/{branchId}
// ─────────────────────────────────────────────────────────────────────────────

class BranchModel {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double altitude;      // metres — used for altitude anti-cheat check
  final double radius;        // metres — geofence radius
  final bool   isActive;
  final DateTime createdAt;

  const BranchModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.altitude  = 0.0,
    this.radius    = 40.0,
    this.isActive  = true,
    required this.createdAt,
  });

  factory BranchModel.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return BranchModel(
      id:        doc.id,
      name:      m['name']      as String,
      address:   m['address']   as String? ?? '',
      latitude:  (m['latitude']  as num).toDouble(),
      longitude: (m['longitude'] as num).toDouble(),
      altitude:  (m['altitude']  as num? ?? 0).toDouble(),
      radius:    (m['radius']    as num? ?? 40).toDouble(),
      isActive:  m['isActive']  as bool? ?? true,
      createdAt: (m['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name':      name,
    'address':   address,
    'latitude':  latitude,
    'longitude': longitude,
    'altitude':  altitude,
    'radius':    radius,
    'isActive':  isActive,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  BranchModel copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? altitude,
    double? radius,
    bool?   isActive,
  }) => BranchModel(
    id:        id,
    name:      name      ?? this.name,
    address:   address   ?? this.address,
    latitude:  latitude  ?? this.latitude,
    longitude: longitude ?? this.longitude,
    altitude:  altitude  ?? this.altitude,
    radius:    radius    ?? this.radius,
    isActive:  isActive  ?? this.isActive,
    createdAt: createdAt,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BranchAssignment  →  Firestore: /branch_assignments/{assignmentId}
// Audit trail: every time HR reassigns an employee this is created.
// ─────────────────────────────────────────────────────────────────────────────

enum AssignmentDuration { permanent, temporary, todayOnly }

extension AssignmentDurationX on AssignmentDuration {
  String get label => switch (this) {
    AssignmentDuration.permanent  => 'Permanent',
    AssignmentDuration.temporary  => 'Temporary',
    AssignmentDuration.todayOnly  => 'Today Only',
  };
  static AssignmentDuration fromString(String v) => switch (v) {
    'Temporary' => AssignmentDuration.temporary,
    'Today Only' => AssignmentDuration.todayOnly,
    _ => AssignmentDuration.permanent,
  };
}

class BranchAssignment {
  final String id;
  final String employeeId;
  final String employeeName;
  final String fromBranchId;
  final String fromBranchName;
  final String toBranchId;
  final String toBranchName;
  final String assignedBy;       // HR uid
  final AssignmentDuration duration;
  final DateTime startDate;
  final DateTime? endDate;       // null for permanent / today-only
  final String reason;
  final bool isActive;

  const BranchAssignment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.fromBranchId,
    required this.fromBranchName,
    required this.toBranchId,
    required this.toBranchName,
    required this.assignedBy,
    required this.duration,
    required this.startDate,
    this.endDate,
    required this.reason,
    this.isActive = true,
  });

  factory BranchAssignment.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return BranchAssignment(
      id:             doc.id,
      employeeId:     m['employeeId']     as String,
      employeeName:   m['employeeName']   as String? ?? '',
      fromBranchId:   m['fromBranchId']   as String? ?? '',
      fromBranchName: m['fromBranchName'] as String? ?? '',
      toBranchId:     m['toBranchId']     as String,
      toBranchName:   m['toBranchName']   as String? ?? '',
      assignedBy:     m['assignedBy']     as String? ?? '',
      duration: AssignmentDurationX.fromString(m['duration'] as String? ?? 'Permanent'),
      startDate: (m['startDate'] as Timestamp).toDate(),
      endDate:   m['endDate'] != null ? (m['endDate'] as Timestamp).toDate() : null,
      reason:    m['reason']   as String? ?? '',
      isActive:  m['isActive'] as bool?   ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'employeeId':     employeeId,
    'employeeName':   employeeName,
    'fromBranchId':   fromBranchId,
    'fromBranchName': fromBranchName,
    'toBranchId':     toBranchId,
    'toBranchName':   toBranchName,
    'assignedBy':     assignedBy,
    'duration':       duration.label,
    'startDate':      Timestamp.fromDate(startDate),
    if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
    'reason':         reason,
    'isActive':       isActive,
  };
}