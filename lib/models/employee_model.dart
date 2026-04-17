import 'package:cloud_firestore/cloud_firestore.dart';

enum EmployeeStatus { active, leave, inactive }

class Employee {
  final String uid;
  final String name;
  final String role;
  final String location;
  final EmployeeStatus status;
  final String email;
  final String phone;
  final String department;
  final String joinDate;
  final double salary;

  // ── Leave Quotas ──────────────────────────────────────────────────────────
  final int annualLeaveQuota;
  final int sickLeaveQuota;
  final int casualLeaveQuota;
  final int unpaidLeaveQuota;

  // ── Branch assignment fields ───────────────────────────────────────────────
  final String? defaultBranchId;
  final String? defaultBranchName;
  final String? currentAssignedBranch;
  final String? currentAssignedBranchName;
  final DateTime? branchAssignmentExpiry;
  final bool fieldDuty;

  Employee({
    required this.uid,
    required this.name,
    required this.role,
    required this.location,
    required this.status,
    required this.email,
    required this.phone,
    required this.department,
    required this.joinDate,
    required this.salary,
    this.annualLeaveQuota = 4,
    this.sickLeaveQuota = 3,
    this.casualLeaveQuota = 6,
    this.unpaidLeaveQuota = 0,
    this.defaultBranchId,
    this.defaultBranchName,
    this.currentAssignedBranch,
    this.currentAssignedBranchName,
    this.branchAssignmentExpiry,
    this.fieldDuty = false,
  });

  factory Employee.fromMap(Map<String, dynamic> map, {String? uid}) {
    return Employee(
      uid:        uid ?? map['uid'] ?? '',
      name:       map['name']       ?? '',
      role:       map['role']       ?? '',
      location:   map['location']   ?? '',
      status:     _statusFromString(map['status'] ?? 'active'),
      email:      map['email']      ?? '',
      phone:      map['phone']      ?? '',
      department: map['department'] ?? '',
      joinDate:   map['joinDate']   ?? '',
      salary:     (map['salary']    ?? 0).toDouble(),
      annualLeaveQuota:  (map['annualLeaveQuota']  ?? 4).toInt(),
      sickLeaveQuota:    (map['sickLeaveQuota']    ?? 3).toInt(),
      casualLeaveQuota:  (map['casualLeaveQuota']  ?? 6).toInt(),
      unpaidLeaveQuota:  (map['unpaidLeaveQuota']  ?? 0).toInt(),
      defaultBranchId:           map['defaultBranchId']           as String?,
      defaultBranchName:         map['defaultBranchName']         as String?,
      currentAssignedBranch:     map['currentAssignedBranch']     as String?,
      currentAssignedBranchName: map['currentAssignedBranchName'] as String?,
      branchAssignmentExpiry: map['branchAssignmentExpiry'] != null
          ? (map['branchAssignmentExpiry'] as Timestamp).toDate()
          : null,
      fieldDuty: map['fieldDuty'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid':        uid,
      'name':       name,
      'role':       role,
      'location':   location,
      'status':     status.name,
      'email':      email,
      'phone':      phone,
      'department': department,
      'joinDate':   joinDate,
      'salary':     salary,
      'annualLeaveQuota':  annualLeaveQuota,
      'sickLeaveQuota':    sickLeaveQuota,
      'casualLeaveQuota':  casualLeaveQuota,
      'unpaidLeaveQuota':  unpaidLeaveQuota,
      if (defaultBranchId   != null) 'defaultBranchId':   defaultBranchId,
      if (defaultBranchName != null) 'defaultBranchName': defaultBranchName,
      if (currentAssignedBranch     != null) 'currentAssignedBranch':     currentAssignedBranch,
      if (currentAssignedBranchName != null) 'currentAssignedBranchName': currentAssignedBranchName,
      if (branchAssignmentExpiry    != null) 'branchAssignmentExpiry':    Timestamp.fromDate(branchAssignmentExpiry!),
      'fieldDuty': fieldDuty,
    };
  }

  String get effectiveBranchName {
    if (fieldDuty) return 'Field Duty';
    if (currentAssignedBranchName != null &&
        currentAssignedBranchName!.isNotEmpty) {
      return currentAssignedBranchName!;
    }
    return defaultBranchName ?? 'No Branch Assigned';
  }

  bool get hasTemporaryAssignment =>
      currentAssignedBranch != null && !fieldDuty;

  Employee copyWith({
    String? uid,
    String? name,
    String? role,
    String? location,
    EmployeeStatus? status,
    String? email,
    String? phone,
    String? department,
    String? joinDate,
    double? salary,
    int? annualLeaveQuota,
    int? sickLeaveQuota,
    int? casualLeaveQuota,
    int? unpaidLeaveQuota,
    String? defaultBranchId,
    String? defaultBranchName,
    String? currentAssignedBranch,
    String? currentAssignedBranchName,
    DateTime? branchAssignmentExpiry,
    bool? fieldDuty,
  }) {
    return Employee(
      uid:        uid        ?? this.uid,
      name:       name       ?? this.name,
      role:       role       ?? this.role,
      location:   location   ?? this.location,
      status:     status     ?? this.status,
      email:      email      ?? this.email,
      phone:      phone      ?? this.phone,
      department: department ?? this.department,
      joinDate:   joinDate   ?? this.joinDate,
      salary:     salary     ?? this.salary,
      annualLeaveQuota:  annualLeaveQuota  ?? this.annualLeaveQuota,
      sickLeaveQuota:    sickLeaveQuota    ?? this.sickLeaveQuota,
      casualLeaveQuota:  casualLeaveQuota  ?? this.casualLeaveQuota,
      unpaidLeaveQuota:  unpaidLeaveQuota  ?? this.unpaidLeaveQuota,
      defaultBranchId:           defaultBranchId           ?? this.defaultBranchId,
      defaultBranchName:         defaultBranchName         ?? this.defaultBranchName,
      currentAssignedBranch:     currentAssignedBranch     ?? this.currentAssignedBranch,
      currentAssignedBranchName: currentAssignedBranchName ?? this.currentAssignedBranchName,
      branchAssignmentExpiry:    branchAssignmentExpiry    ?? this.branchAssignmentExpiry,
      fieldDuty:  fieldDuty  ?? this.fieldDuty,
    );
  }

  static EmployeeStatus _statusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':   return EmployeeStatus.active;
      case 'leave':    return EmployeeStatus.leave;
      case 'inactive': return EmployeeStatus.inactive;
      default:         return EmployeeStatus.active;
    }
  }
}