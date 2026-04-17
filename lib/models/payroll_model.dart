// ============================================================
// PAYROLL MODELS — Simplified
// Basic + Allowances + Loan Deduction + Performance Deduction
//                   + Attendance Deduction (late/absent/early)
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

// ── Payslip status ────────────────────────────────────────────
enum PayslipStatus { draft, approved, paid }

// ── Payroll run status ────────────────────────────────────────
enum PayrollRunStatus { draft, approved, paid }

// ── Allowance type ────────────────────────────────────────────
enum AllowanceType { fixed, percentOfBasic }

// ─────────────────────────────────────────────────────────────
// ALLOWANCE ITEM
// ─────────────────────────────────────────────────────────────
class AllowanceItem {
  final String name;
  final double amount;
  final AllowanceType type;

  const AllowanceItem({
    required this.name,
    required this.amount,
    required this.type,
  });

  double resolve(double basic) =>
      type == AllowanceType.percentOfBasic ? basic * amount / 100 : amount;

  factory AllowanceItem.fromMap(Map<String, dynamic> m) => AllowanceItem(
    name: m['name'] ?? '',
    amount: (m['amount'] as num).toDouble(),
    type: m['type'] == 'percentOfBasic'
        ? AllowanceType.percentOfBasic
        : AllowanceType.fixed,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'amount': amount,
    'type': type == AllowanceType.percentOfBasic ? 'percentOfBasic' : 'fixed',
  };

  AllowanceItem copyWith({String? name, double? amount, AllowanceType? type}) =>
      AllowanceItem(
        name: name ?? this.name,
        amount: amount ?? this.amount,
        type: type ?? this.type,
      );
}

// ─────────────────────────────────────────────────────────────
// ATTENDANCE DEDUCTION — per-day reason
// ─────────────────────────────────────────────────────────────

/// The type of infraction for a single day.
enum AttendanceInfractionType {
  absent,       // no check-in, no approved leave
  lateMild,     // checked in 9:01–10:00 AM  →  25 % per-day wage
  lateSevere,   // checked in after 10:00 AM  →  50 % per-day wage
  earlyMild,    // checked out 17:01–17:59    →  25 % per-day wage
  earlySevere,  // checked out before 17:00   →  50 % per-day wage
  underworked,  // worked < 4 h (excl. break), not on approved leave → 50 %
}

extension AttendanceInfractionLabel on AttendanceInfractionType {
  String get label => switch (this) {
    AttendanceInfractionType.absent      => 'Absent',
    AttendanceInfractionType.lateMild    => 'Late (9–10 AM)',
    AttendanceInfractionType.lateSevere  => 'Late (after 10 AM)',
    AttendanceInfractionType.earlyMild   => 'Early departure (after 5 PM)',
    AttendanceInfractionType.earlySevere => 'Early departure (before 5 PM)',
    AttendanceInfractionType.underworked => 'Worked < 4 hours',
  };
}

/// One deduction entry for a single calendar day.
class AttendanceDayDeduction {
  final String date;     // "YYYY-MM-DD"
  final AttendanceInfractionType type;
  final double amount;   // PKR amount deducted

  const AttendanceDayDeduction({
    required this.date,
    required this.type,
    required this.amount,
  });

  factory AttendanceDayDeduction.fromMap(Map<String, dynamic> m) =>
      AttendanceDayDeduction(
        date: m['date'] ?? '',
        type: AttendanceInfractionType.values.firstWhere(
              (t) => t.name == m['type'],
          orElse: () => AttendanceInfractionType.absent,
        ),
        amount: (m['amount'] as num? ?? 0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
    'date':   date,
    'type':   type.name,
    'amount': amount,
  };
}

/// Month-level summary stored inside a payslip.
class AttendanceDeductionSummary {
  final int absentDays;
  final int lateMildDays;
  final int lateSevereDays;
  final int earlyMildDays;
  final int earlySevereDays;
  final int underworkedDays;
  final double totalDeduction;
  final List<AttendanceDayDeduction> breakdown;

  const AttendanceDeductionSummary({
    required this.absentDays,
    required this.lateMildDays,
    required this.lateSevereDays,
    required this.earlyMildDays,
    required this.earlySevereDays,
    required this.underworkedDays,
    required this.totalDeduction,
    required this.breakdown,
  });

  static AttendanceDeductionSummary zero() => const AttendanceDeductionSummary(
    absentDays:      0,
    lateMildDays:    0,
    lateSevereDays:  0,
    earlyMildDays:   0,
    earlySevereDays: 0,
    underworkedDays: 0,
    totalDeduction:  0,
    breakdown:       [],
  );

  factory AttendanceDeductionSummary.fromMap(Map<String, dynamic> m) =>
      AttendanceDeductionSummary(
        absentDays:      m['absentDays']      ?? 0,
        lateMildDays:    m['lateMildDays']    ?? 0,
        lateSevereDays:  m['lateSevereDays']  ?? 0,
        earlyMildDays:   m['earlyMildDays']   ?? 0,
        earlySevereDays: m['earlySevereDays'] ?? 0,
        underworkedDays: m['underworkedDays'] ?? 0,
        totalDeduction:  (m['totalDeduction'] as num? ?? 0).toDouble(),
        breakdown: (m['breakdown'] as List<dynamic>? ?? [])
            .map((e) => AttendanceDayDeduction.fromMap(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
    'absentDays':      absentDays,
    'lateMildDays':    lateMildDays,
    'lateSevereDays':  lateSevereDays,
    'earlyMildDays':   earlyMildDays,
    'earlySevereDays': earlySevereDays,
    'underworkedDays': underworkedDays,
    'totalDeduction':  totalDeduction,
    'breakdown':       breakdown.map((d) => d.toMap()).toList(),
  };

  int get totalInfractionDays =>
      absentDays + lateMildDays + lateSevereDays +
          earlyMildDays + earlySevereDays + underworkedDays;
}

// ─────────────────────────────────────────────────────────────
// PAYROLL CONFIG
// ─────────────────────────────────────────────────────────────
class PayrollConfigModel {
  final String employeeId;
  final String employeeName;
  final double? basicSalaryOverride;
  final List<AllowanceItem> allowances;
  final double loanDeductionPerMonth;
  final String updatedBy;
  final DateTime updatedAt;

  const PayrollConfigModel({
    required this.employeeId,
    required this.employeeName,
    this.basicSalaryOverride,
    required this.allowances,
    required this.loanDeductionPerMonth,
    required this.updatedBy,
    required this.updatedAt,
  });

  factory PayrollConfigModel.empty(String employeeId, String employeeName) =>
      PayrollConfigModel(
        employeeId: employeeId,
        employeeName: employeeName,
        basicSalaryOverride: null,
        allowances: const [],
        loanDeductionPerMonth: 0,
        updatedBy: '',
        updatedAt: DateTime.now(),
      );

  factory PayrollConfigModel.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return PayrollConfigModel(
      employeeId: doc.id,
      employeeName: m['employeeName'] ?? '',
      basicSalaryOverride: m['basicSalaryOverride'] != null
          ? (m['basicSalaryOverride'] as num).toDouble()
          : null,
      allowances: (m['allowances'] as List<dynamic>? ?? [])
          .map((a) => AllowanceItem.fromMap(a as Map<String, dynamic>))
          .toList(),
      loanDeductionPerMonth:
      (m['loanDeductionPerMonth'] as num? ?? 0).toDouble(),
      updatedBy: m['updatedBy'] ?? '',
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'employeeName': employeeName,
    if (basicSalaryOverride != null)
      'basicSalaryOverride': basicSalaryOverride,
    'allowances': allowances.map((a) => a.toMap()).toList(),
    'loanDeductionPerMonth': loanDeductionPerMonth,
    'updatedBy': updatedBy,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  PayrollConfigModel copyWith({
    String? employeeName,
    Object? basicSalaryOverride = _sentinel,
    List<AllowanceItem>? allowances,
    double? loanDeductionPerMonth,
    String? updatedBy,
  }) =>
      PayrollConfigModel(
        employeeId: employeeId,
        employeeName: employeeName ?? this.employeeName,
        basicSalaryOverride: basicSalaryOverride == _sentinel
            ? this.basicSalaryOverride
            : basicSalaryOverride as double?,
        allowances: allowances ?? this.allowances,
        loanDeductionPerMonth:
        loanDeductionPerMonth ?? this.loanDeductionPerMonth,
        updatedBy: updatedBy ?? this.updatedBy,
        updatedAt: DateTime.now(),
      );
}

const _sentinel = Object();

// ─────────────────────────────────────────────────────────────
// PAYSLIP MODEL
// ─────────────────────────────────────────────────────────────
class PayslipModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeRole;
  final String month;
  final int monthNum;
  final int year;

  // ── Earnings ─────────────────────────────────────────────
  final double basicSalary;
  final List<AllowanceItem> allowances;

  // ── Deductions ───────────────────────────────────────────
  final double loanDeduction;
  final double performanceDeduction;
  final double performanceBonus;

  /// Attendance-based deduction (late arrivals + absences + early departures).
  final double attendanceDeduction;

  /// Full breakdown — shown in payslip detail screen.
  final AttendanceDeductionSummary attendanceSummary;

  // ── Status ───────────────────────────────────────────────
  final PayslipStatus status;
  final DateTime generatedAt;
  final DateTime? approvedAt;

  // ── Performance snapshot ─────────────────────────────────
  final int totalTasksInMonth;
  final int completedTasks;
  final int missedTasks;
  final int weekendTasks;
  final double performanceScore;

  const PayslipModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeRole,
    required this.month,
    required this.monthNum,
    required this.year,
    required this.basicSalary,
    required this.allowances,
    required this.loanDeduction,
    required this.performanceDeduction,
    required this.performanceBonus,
    this.attendanceDeduction = 0,
    AttendanceDeductionSummary? attendanceSummary,
    required this.status,
    required this.generatedAt,
    this.approvedAt,
    required this.totalTasksInMonth,
    required this.completedTasks,
    required this.missedTasks,
    required this.weekendTasks,
    required this.performanceScore,
  }) : attendanceSummary = attendanceSummary ?? const AttendanceDeductionSummary(
      absentDays: 0, lateMildDays: 0, lateSevereDays: 0,
      earlyMildDays: 0, earlySevereDays: 0, underworkedDays: 0,
      totalDeduction: 0, breakdown: []);

  // ── Computed ─────────────────────────────────────────────
  double get totalAllowances =>
      allowances.fold(0.0, (s, a) => s + a.resolve(basicSalary));

  double get grossPay => basicSalary + totalAllowances + performanceBonus;

  double get totalDeductions =>
      loanDeduction + performanceDeduction + attendanceDeduction;

  double get netPay => grossPay - totalDeductions;

  factory PayslipModel.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return PayslipModel(
      id: doc.id,
      employeeId: m['employeeId'] ?? '',
      employeeName: m['employeeName'] ?? '',
      employeeRole: m['employeeRole'] ?? '',
      month: m['month'] ?? '',
      monthNum: m['monthNum'] ?? 1,
      year: m['year'] ?? DateTime.now().year,
      basicSalary: (m['basicSalary'] as num? ?? 0).toDouble(),
      allowances: (m['allowances'] as List<dynamic>? ?? [])
          .map((a) => AllowanceItem.fromMap(a as Map<String, dynamic>))
          .toList(),
      loanDeduction: (m['loanDeduction'] as num? ?? 0).toDouble(),
      performanceDeduction:
      (m['performanceDeduction'] as num? ?? 0).toDouble(),
      performanceBonus: (m['performanceBonus'] as num? ?? 0).toDouble(),
      attendanceDeduction:
      (m['attendanceDeduction'] as num? ?? 0).toDouble(),
      attendanceSummary: m['attendanceSummary'] != null
          ? AttendanceDeductionSummary.fromMap(
          m['attendanceSummary'] as Map<String, dynamic>)
          : AttendanceDeductionSummary.zero(),
      status: PayslipStatus.values.firstWhere(
            (s) => s.name == m['status'],
        orElse: () => PayslipStatus.draft,
      ),
      generatedAt:
      (m['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt: (m['approvedAt'] as Timestamp?)?.toDate(),
      totalTasksInMonth: m['totalTasksInMonth'] ?? 0,
      completedTasks: m['completedTasks'] ?? 0,
      missedTasks: m['missedTasks'] ?? 0,
      weekendTasks: m['weekendTasks'] ?? 0,
      performanceScore: (m['performanceScore'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'employeeId': employeeId,
    'employeeName': employeeName,
    'employeeRole': employeeRole,
    'month': month,
    'monthNum': monthNum,
    'year': year,
    'basicSalary': basicSalary,
    'allowances': allowances.map((a) => a.toMap()).toList(),
    'loanDeduction': loanDeduction,
    'performanceDeduction': performanceDeduction,
    'performanceBonus': performanceBonus,
    'attendanceDeduction': attendanceDeduction,
    'attendanceSummary': attendanceSummary.toMap(),
    'status': status.name,
    'generatedAt': Timestamp.fromDate(generatedAt),
    if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
    'totalTasksInMonth': totalTasksInMonth,
    'completedTasks': completedTasks,
    'missedTasks': missedTasks,
    'weekendTasks': weekendTasks,
    'performanceScore': performanceScore,
  };

  PayslipModel copyWith({PayslipStatus? status, DateTime? approvedAt}) =>
      PayslipModel(
        id: id,
        employeeId: employeeId,
        employeeName: employeeName,
        employeeRole: employeeRole,
        month: month,
        monthNum: monthNum,
        year: year,
        basicSalary: basicSalary,
        allowances: allowances,
        loanDeduction: loanDeduction,
        performanceDeduction: performanceDeduction,
        performanceBonus: performanceBonus,
        attendanceDeduction: attendanceDeduction,
        attendanceSummary: attendanceSummary,
        status: status ?? this.status,
        generatedAt: generatedAt,
        approvedAt: approvedAt ?? this.approvedAt,
        totalTasksInMonth: totalTasksInMonth,
        completedTasks: completedTasks,
        missedTasks: missedTasks,
        weekendTasks: weekendTasks,
        performanceScore: performanceScore,
      );
}

// ─────────────────────────────────────────────────────────────
// PAYROLL RUN MODEL
// ─────────────────────────────────────────────────────────────
class PayrollRunModel {
  final String id;
  final String month;
  final int monthNum;
  final int year;
  final int totalEmployees;
  final double totalGross;
  final double totalDeductions;
  final double totalNetPay;
  final double totalPerformanceDeductions;
  final double totalPerformanceBonuses;
  final double totalAttendanceDeductions;
  final PayrollRunStatus status;
  final String runBy;
  final DateTime runAt;

  const PayrollRunModel({
    required this.id,
    required this.month,
    required this.monthNum,
    required this.year,
    required this.totalEmployees,
    required this.totalGross,
    required this.totalDeductions,
    required this.totalNetPay,
    required this.totalPerformanceDeductions,
    required this.totalPerformanceBonuses,
    this.totalAttendanceDeductions = 0,
    required this.status,
    required this.runBy,
    required this.runAt,
  });

  factory PayrollRunModel.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return PayrollRunModel(
      id: doc.id,
      month: m['month'] ?? '',
      monthNum: m['monthNum'] ?? 1,
      year: m['year'] ?? DateTime.now().year,
      totalEmployees: m['totalEmployees'] ?? 0,
      totalGross: (m['totalGross'] as num? ?? 0).toDouble(),
      totalDeductions: (m['totalDeductions'] as num? ?? 0).toDouble(),
      totalNetPay: (m['totalNetPay'] as num? ?? 0).toDouble(),
      totalPerformanceDeductions:
      (m['totalPerformanceDeductions'] as num? ?? 0).toDouble(),
      totalPerformanceBonuses:
      (m['totalPerformanceBonuses'] as num? ?? 0).toDouble(),
      totalAttendanceDeductions:
      (m['totalAttendanceDeductions'] as num? ?? 0).toDouble(),
      status: PayrollRunStatus.values.firstWhere(
            (s) => s.name == m['status'],
        orElse: () => PayrollRunStatus.draft,
      ),
      runBy: m['runBy'] ?? '',
      runAt: (m['runAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'month': month,
    'monthNum': monthNum,
    'year': year,
    'totalEmployees': totalEmployees,
    'totalGross': totalGross,
    'totalDeductions': totalDeductions,
    'totalNetPay': totalNetPay,
    'totalPerformanceDeductions': totalPerformanceDeductions,
    'totalPerformanceBonuses': totalPerformanceBonuses,
    'totalAttendanceDeductions': totalAttendanceDeductions,
    'status': status.name,
    'runBy': runBy,
    'runAt': Timestamp.fromDate(runAt),
  };
}