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
  final String emp_id;
  String? project_title;
  String? project_description;
  String? project_duration;
  String? jobDescription;
  String? emergencyPhone;
  String? personalEmail;

  // ── HR-managed password (set via adminSetEmployeePassword Cloud Function) ──
  // These are READ-ONLY on the client — only the Cloud Function writes them.
  final String? lastSetPassword;
  final DateTime? passwordSetAt;

  // ── Soft delete / archival ────────────────────────────────────────────────
  final bool isActive;
  final DateTime? archivedAt;
  final String? archivedBy;

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

  // ── Station status (drives per-quarter leave quotas per policy) ───────────
  // 'in_station' or 'out_station'. Null → default in_station. HR toggles
  // this on the Add/Edit Employee screen; AttendanceViewModel.submitLeave
  // reads it to choose between 3-days-per-quarter (in) or 4-days-per-quarter
  // (out) for the regular leave cap.
  final String? station;

  // ── Gender ────────────────────────────────────────────────────────────────
  // 'male' / 'female' / null (unspecified). Used to gate maternity vs
  // paternity options on the leave-request dropdown. HR sets this on
  // Add/Edit Employee; when null, neither maternity nor paternity is shown.
  final String? gender;

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
    required this.emp_id,
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
    this.station,
    this.gender,
    this.project_title = '',
    this.project_description = '',
    this.project_duration = '',
    this.jobDescription,
    this.emergencyPhone,
    this.personalEmail,
    this.lastSetPassword,
    this.passwordSetAt,
    this.isActive = true,
    this.archivedAt,
    this.archivedBy,
  });

  factory Employee.fromMap(Map<String, dynamic> map, {String? uid}) {
    return Employee(
      uid: uid ?? map['uid'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      location: map['location'] ?? '',
      status: _statusFromString(map['status'] ?? 'active'),
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      department: map['department'] ?? '',
      joinDate: map['joinDate'] ?? '',
      salary: (map['salary'] ?? 0).toDouble(),
      emp_id: map['emp_id'] ?? '',
      project_title: map['project_title'] ?? '',
      project_description: map['project_description'] ?? '',
      project_duration: map['project_duration'] ?? '',
      jobDescription: map['jobDescription'] as String?,
      emergencyPhone: map['emergencyPhone'] as String?,
      personalEmail: map['personalEmail'] as String?,
      lastSetPassword: map['lastSetPassword'] as String?,
      passwordSetAt: map['passwordSetAt'] != null
          ? (map['passwordSetAt'] as Timestamp).toDate()
          : null,
      isActive: map['isActive'] as bool? ?? true,
      archivedAt: map['archivedAt'] != null
          ? (map['archivedAt'] as Timestamp).toDate()
          : null,
      archivedBy: map['archivedBy'] as String?,

      annualLeaveQuota: (map['annualLeaveQuota'] ?? 4).toInt(),
      sickLeaveQuota: (map['sickLeaveQuota'] ?? 3).toInt(),
      casualLeaveQuota: (map['casualLeaveQuota'] ?? 6).toInt(),
      unpaidLeaveQuota: (map['unpaidLeaveQuota'] ?? 0).toInt(),
      defaultBranchId: map['defaultBranchId'] as String?,
      defaultBranchName: map['defaultBranchName'] as String?,
      currentAssignedBranch: map['currentAssignedBranch'] as String?,
      currentAssignedBranchName: map['currentAssignedBranchName'] as String?,
      branchAssignmentExpiry: map['branchAssignmentExpiry'] != null
          ? (map['branchAssignmentExpiry'] as Timestamp).toDate()
          : null,
      fieldDuty: map['fieldDuty'] as bool? ?? false,
      station: (map['station'] as String?)?.trim().isNotEmpty == true
          ? (map['station'] as String).trim()
          : null,
      gender: (map['gender'] as String?)?.trim().isNotEmpty == true
          ? (map['gender'] as String).trim().toLowerCase()
          : null,
    );
  }

  /// True when the employee is treated as in-station (default when no
  /// explicit station is set on the user doc).
  bool get isInStation => (station ?? 'in_station') == 'in_station';
  bool get isOutOfStation => station == 'out_station';
  bool get isFemale => gender == 'female';
  bool get isMale => gender == 'male';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'role': role,
      'location': location,
      'status': status.name,
      'email': email,
      'phone': phone,
      'department': department,
      'joinDate': joinDate,
      'salary': salary,
      'emp_id': emp_id,
      'project_title': project_title,
      'project_description': project_description,
      'project_duration': project_duration,
      if (jobDescription != null) 'jobDescription': jobDescription,
      if (emergencyPhone != null) 'emergencyPhone': emergencyPhone,
      if (personalEmail != null) 'personalEmail': personalEmail,
      'annualLeaveQuota': annualLeaveQuota,
      'sickLeaveQuota': sickLeaveQuota,
      'casualLeaveQuota': casualLeaveQuota,
      'unpaidLeaveQuota': unpaidLeaveQuota,
      if (defaultBranchId != null) 'defaultBranchId': defaultBranchId,
      if (defaultBranchName != null) 'defaultBranchName': defaultBranchName,
      if (currentAssignedBranch != null)
        'currentAssignedBranch': currentAssignedBranch,
      if (currentAssignedBranchName != null)
        'currentAssignedBranchName': currentAssignedBranchName,
      if (branchAssignmentExpiry != null)
        'branchAssignmentExpiry': Timestamp.fromDate(branchAssignmentExpiry!),
      'fieldDuty': fieldDuty,
      // Default to in_station when not set so HR's view is consistent.
      'station': station ?? 'in_station',
      if (gender != null) 'gender': gender,
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
    String? emp_id,
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
    String? station,
    String? gender,
    String? jobDescription,
    String? emergencyPhone,
    String? personalEmail,
    String? lastSetPassword,
    DateTime? passwordSetAt,
    bool? isActive,
    DateTime? archivedAt,
    String? archivedBy,
  }) {
    return Employee(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      role: role ?? this.role,
      location: location ?? this.location,
      status: status ?? this.status,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      department: department ?? this.department,
      joinDate: joinDate ?? this.joinDate,
      salary: salary ?? this.salary,
      emp_id: emp_id ?? this.emp_id,
      annualLeaveQuota: annualLeaveQuota ?? this.annualLeaveQuota,
      sickLeaveQuota: sickLeaveQuota ?? this.sickLeaveQuota,
      casualLeaveQuota: casualLeaveQuota ?? this.casualLeaveQuota,
      unpaidLeaveQuota: unpaidLeaveQuota ?? this.unpaidLeaveQuota,
      defaultBranchId: defaultBranchId ?? this.defaultBranchId,
      defaultBranchName: defaultBranchName ?? this.defaultBranchName,
      currentAssignedBranch:
          currentAssignedBranch ?? this.currentAssignedBranch,
      currentAssignedBranchName:
          currentAssignedBranchName ?? this.currentAssignedBranchName,
      branchAssignmentExpiry:
          branchAssignmentExpiry ?? this.branchAssignmentExpiry,
      fieldDuty: fieldDuty ?? this.fieldDuty,
      station: station ?? this.station,
      gender: gender ?? this.gender,
      jobDescription: jobDescription ?? this.jobDescription,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      personalEmail: personalEmail ?? this.personalEmail,
      lastSetPassword: lastSetPassword ?? this.lastSetPassword,
      passwordSetAt: passwordSetAt ?? this.passwordSetAt,
      isActive: isActive ?? this.isActive,
      archivedAt: archivedAt ?? this.archivedAt,
      archivedBy: archivedBy ?? this.archivedBy,
    );
  }

  static EmployeeStatus _statusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return EmployeeStatus.active;
      case 'leave':
        return EmployeeStatus.leave;
      case 'inactive':
        return EmployeeStatus.inactive;
      default:
        return EmployeeStatus.active;
    }
  }
}
