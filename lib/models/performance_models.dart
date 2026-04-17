// ============================================================
// PERFORMANCE MANAGEMENT MODULE — MODELS
// Quarterly tasks + weekly breakdown, plus employee `goals`
// (daily / weekly / biWeekly / monthly cadence).
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

// ── Enums ────────────────────────────────────────────────────

enum GoalStatus { notStarted, inProgress, onTrack, atRisk, completed, failed }

/// Cadence for documents in the top-level `goals` collection (not quarterly).
enum GoalCadence { daily, weekly, biWeekly, monthly }

enum GoalCategory { sales, productivity, quality, attendance, project }

enum TaskStatus { pending, completed, missed, weekend }

enum TaskPriority { normal, prioritized }

enum BarrierStatus { open, resolved }

// Deduction frequency options
enum DeductionFrequency { monthly, weekly, biWeekly }

// ── Timestamp Helper ─────────────────────────────────────────

DateTime _parseTs(dynamic value, {DateTime? fallback}) {
  if (value == null) return fallback ?? DateTime.now();
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return fallback ?? DateTime.now();
}

// ── QuarterlyGoalModel ───────────────────────────────────────
// Weekly tasks always live in a sub-collection, never embedded.

class QuarterlyGoalModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final String title;
  final String description;
  final GoalCategory category;
  final DateTime startDate;
  final DateTime endDate;
  final double weight;
  final GoalStatus status;
  final double currentProgress;
  final DateTime createdAt;
  final String createdBy;

  const QuarterlyGoalModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.title,
    required this.description,
    required this.category,
    required this.startDate,
    required this.endDate,
    required this.weight,
    required this.status,
    required this.currentProgress,
    required this.createdAt,
    required this.createdBy,
  });

  factory QuarterlyGoalModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return QuarterlyGoalModel(
      id: doc.id,
      employeeId: d['employeeId'] ?? '',
      employeeName: d['employeeName'] ?? '',
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      category: GoalCategory.values.firstWhere(
            (e) => e.name == d['category'],
        orElse: () => GoalCategory.project,
      ),
      startDate: _parseTs(d['startDate']),
      endDate: _parseTs(d['endDate']),
      weight: (d['weight'] ?? 0).toDouble(),
      status: GoalStatus.values.firstWhere(
            (e) => e.name == d['status'],
        orElse: () => GoalStatus.notStarted,
      ),
      currentProgress: (d['currentProgress'] ?? 0).toDouble(),
      createdAt: _parseTs(d['createdAt']),
      createdBy: d['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'employeeId': employeeId,
    'employeeName': employeeName,
    'title': title,
    'description': description,
    'category': category.name,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'weight': weight,
    'status': status.name,
    'currentProgress': currentProgress,
    'createdAt': Timestamp.fromDate(createdAt),
    'createdBy': createdBy,
  };

  QuarterlyGoalModel copyWith({
    GoalStatus? status,
    double? currentProgress,
  }) =>
      QuarterlyGoalModel(
        id: id,
        employeeId: employeeId,
        employeeName: employeeName,
        title: title,
        description: description,
        category: category,
        startDate: startDate,
        endDate: endDate,
        weight: weight,
        status: status ?? this.status,
        currentProgress: currentProgress ?? this.currentProgress,
        createdAt: createdAt,
        createdBy: createdBy,
      );
}

// ── EmployeeGoalModel (`goals` collection) ─────────────────────
//
// Separate from quarterly_goals: short-horizon goals with cadence
// and normal vs prioritized flag. Does not affect quarterly score.

class EmployeeGoalModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final String title;
  final String description;
  final GoalCadence cadence;
  final TaskPriority priority;
  final GoalStatus status;
  final DateTime dueDate;
  final DateTime? completedAt;
  final DateTime createdAt;
  final String createdBy;

  const EmployeeGoalModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.title,
    required this.description,
    required this.cadence,
    required this.priority,
    required this.status,
    required this.dueDate,
    this.completedAt,
    required this.createdAt,
    required this.createdBy,
  });

  factory EmployeeGoalModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return EmployeeGoalModel(
      id: doc.id,
      employeeId: d['employeeId'] ?? '',
      employeeName: d['employeeName'] ?? '',
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      cadence: GoalCadence.values.firstWhere(
        (e) => e.name == d['cadence'],
        orElse: () => GoalCadence.monthly,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == d['priority'],
        orElse: () => TaskPriority.normal,
      ),
      status: GoalStatus.values.firstWhere(
        (e) => e.name == d['status'],
        orElse: () => GoalStatus.notStarted,
      ),
      dueDate: _parseTs(d['dueDate']),
      completedAt:
          d['completedAt'] != null ? _parseTs(d['completedAt']) : null,
      createdAt: _parseTs(d['createdAt']),
      createdBy: d['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'title': title,
        'description': description,
        'cadence': cadence.name,
        'priority': priority.name,
        'status': status.name,
        'dueDate': Timestamp.fromDate(dueDate),
        'completedAt':
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'createdAt': Timestamp.fromDate(createdAt),
        'createdBy': createdBy,
      };

  EmployeeGoalModel copyWith({
    GoalStatus? status,
    DateTime? completedAt,
  }) =>
      EmployeeGoalModel(
        id: id,
        employeeId: employeeId,
        employeeName: employeeName,
        title: title,
        description: description,
        cadence: cadence,
        priority: priority,
        status: status ?? this.status,
        dueDate: dueDate,
        completedAt: completedAt ?? this.completedAt,
        createdAt: createdAt,
        createdBy: createdBy,
      );
}

// ── WeeklyTaskModel ──────────────────────────────────────────
//
// attachmentType values (null treated same as 'quarterly'):
//   'quarterly'    → nested inside a quarterly goal sub-collection
//   'currentWeek'  → standalone task shown in employee's This Week section
//   'upcomingWeek' → standalone task shown in employee's Upcoming section

class WeeklyTaskModel {
  final String id;
  final String? attachmentType;
  final List<Map<String, String>>? teamRemarks;  // ← ADD
  final String goalId;
  final String employeeId;
  final int weekNumber;
  final String title;
  final String description;
  final DateTime dueDate;
  final TaskStatus status;
  final DateTime? completedAt;
  final bool isUnscheduled;
  final TaskPriority priority;

  /// Where this unscheduled task is attached.
  /// null / 'quarterly'   → nested inside a quarterly goal
  /// 'currentWeek'        → standalone, shown above quarterly cards
  /// 'upcomingWeek'       → standalone, shown above quarterly cards


  const WeeklyTaskModel({
    required this.id,
    required this.goalId,
    required this.employeeId,
    required this.weekNumber,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.status,
    this.completedAt,
    required this.isUnscheduled,
    required this.priority,
    this.attachmentType,
    this.teamRemarks,  // ← ADD
  });

  factory WeeklyTaskModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return WeeklyTaskModel(
      id: doc.id,
      goalId: d['goalId'] ?? '',
      employeeId: d['employeeId'] ?? '',
      weekNumber: d['weekNumber'] ?? 0,
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      dueDate: _parseTs(d['dueDate']),
      status: TaskStatus.values.firstWhere(
            (e) => e.name == d['status'],
        orElse: () => TaskStatus.pending,
      ),
      completedAt:
      d['completedAt'] != null ? _parseTs(d['completedAt']) : null,
      isUnscheduled: d['isUnscheduled'] ?? false,
      priority: TaskPriority.values.firstWhere(
            (e) => e.name == d['priority'],
        orElse: () => TaskPriority.normal,
      ),
      attachmentType: d['attachmentType'] as String?,
      teamRemarks: (d['teamRemarks'] as List<dynamic>?)  // ← ADD
          ?.map((e) => Map<String, String>.from(e as Map))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'goalId': goalId,
    'employeeId': employeeId,
    'weekNumber': weekNumber,
    'title': title,
    'description': description,
    'dueDate': Timestamp.fromDate(dueDate),
    'status': status.name,
    'completedAt':
    completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    'isUnscheduled': isUnscheduled,
    'priority': priority.name,
    if (attachmentType != null) 'attachmentType': attachmentType,
    if (teamRemarks != null) 'teamRemarks': teamRemarks,  // ← ADD
  };

  WeeklyTaskModel copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? completedAt,
    String? attachmentType,
    List<Map<String, String>>? teamRemarks,
  }) =>
      WeeklyTaskModel(
        id: id,
        goalId: goalId,
        employeeId: employeeId,
        weekNumber: weekNumber,
        title: title ?? this.title,
        description: description ?? this.description,
        dueDate: dueDate,
        status: status ?? this.status,
        completedAt: completedAt ?? this.completedAt,
        isUnscheduled: isUnscheduled,
        priority: priority,
        attachmentType: attachmentType ?? this.attachmentType,
        teamRemarks: teamRemarks ?? this.teamRemarks,
      );
}

// ── PerformanceRulesModel ────────────────────────────────────
// HR can update these at any time. Fully flexible.

class PerformanceRulesModel {
  final String id;

  /// % deducted from salary per missed task
  final double missedTaskDeductionPercent;

  /// % added to quarterly progress per completed task
  final double completedTaskProgressPercent;

  /// Score above which performance bonus is awarded
  final double bonusThresholdScore;

  /// Fixed or % bonus amount
  final double bonusAmount;
  final String bonusAmountType; // 'fixed' | 'percentage'

  /// How often deductions are calculated
  final DeductionFrequency deductionFrequency;

  final String updatedBy;
  final DateTime updatedAt;

  const PerformanceRulesModel({
    required this.id,
    required this.missedTaskDeductionPercent,
    required this.completedTaskProgressPercent,
    required this.bonusThresholdScore,
    required this.bonusAmount,
    required this.bonusAmountType,
    required this.deductionFrequency,
    required this.updatedBy,
    required this.updatedAt,
  });

  factory PerformanceRulesModel.defaults() => PerformanceRulesModel(
    id: 'global',
    missedTaskDeductionPercent: 5.0,
    completedTaskProgressPercent: 8.0,
    bonusThresholdScore: 90.0,
    bonusAmount: 0,
    bonusAmountType: 'fixed',
    deductionFrequency: DeductionFrequency.monthly,
    updatedBy: 'system',
    updatedAt: DateTime.now(),
  );

  factory PerformanceRulesModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PerformanceRulesModel(
      id: doc.id,
      missedTaskDeductionPercent:
      (d['missedTaskDeductionPercent'] ?? 5).toDouble(),
      completedTaskProgressPercent:
      (d['completedTaskProgressPercent'] ?? 8).toDouble(),
      bonusThresholdScore: (d['bonusThresholdScore'] ?? 90).toDouble(),
      bonusAmount: (d['bonusAmount'] ?? 0).toDouble(),
      bonusAmountType: d['bonusAmountType'] ?? 'fixed',
      deductionFrequency: DeductionFrequency.values.firstWhere(
            (e) => e.name == d['deductionFrequency'],
        orElse: () => DeductionFrequency.monthly,
      ),
      updatedBy: d['updatedBy'] ?? '',
      updatedAt: _parseTs(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'missedTaskDeductionPercent': missedTaskDeductionPercent,
    'completedTaskProgressPercent': completedTaskProgressPercent,
    'bonusThresholdScore': bonusThresholdScore,
    'bonusAmount': bonusAmount,
    'bonusAmountType': bonusAmountType,
    'deductionFrequency': deductionFrequency.name,
    'updatedBy': updatedBy,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  PerformanceRulesModel copyWith({
    double? missedTaskDeductionPercent,
    double? completedTaskProgressPercent,
    double? bonusThresholdScore,
    double? bonusAmount,
    String? bonusAmountType,
    DeductionFrequency? deductionFrequency,
    String? updatedBy,
  }) =>
      PerformanceRulesModel(
        id: id,
        missedTaskDeductionPercent:
        missedTaskDeductionPercent ?? this.missedTaskDeductionPercent,
        completedTaskProgressPercent:
        completedTaskProgressPercent ?? this.completedTaskProgressPercent,
        bonusThresholdScore: bonusThresholdScore ?? this.bonusThresholdScore,
        bonusAmount: bonusAmount ?? this.bonusAmount,
        bonusAmountType: bonusAmountType ?? this.bonusAmountType,
        deductionFrequency: deductionFrequency ?? this.deductionFrequency,
        updatedBy: updatedBy ?? this.updatedBy,
        updatedAt: DateTime.now(),
      );
}

// ── MonthlyDeductionModel ─────────────────────────────────────
// One document per employee per month. Computed when needed.

class MonthlyDeductionModel {
  final String id; // {employeeId}_{YYYY_MM}
  final String employeeId;
  final String month; // "2026-03"
  final int totalTasksInMonth;
  final int completedTasks;
  final int missedTasks;
  final int weekendTasks;
  final double deductionAmount;
  final double bonusAmount;
  final double performanceScore; // 0-100
  final double salarySnapshot;
  final DateTime calculatedAt;

  const MonthlyDeductionModel({
    required this.id,
    required this.employeeId,
    required this.month,
    required this.totalTasksInMonth,
    required this.completedTasks,
    required this.missedTasks,
    required this.weekendTasks,
    required this.deductionAmount,
    required this.bonusAmount,
    required this.performanceScore,
    required this.salarySnapshot,
    required this.calculatedAt,
  });

  factory MonthlyDeductionModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MonthlyDeductionModel(
      id: doc.id,
      employeeId: d['employeeId'] ?? '',
      month: d['month'] ?? '',
      totalTasksInMonth: d['totalTasksInMonth'] ?? 0,
      completedTasks: d['completedTasks'] ?? 0,
      missedTasks: d['missedTasks'] ?? 0,
      weekendTasks: d['weekendTasks'] ?? 0,
      deductionAmount: (d['deductionAmount'] ?? 0).toDouble(),
      bonusAmount: (d['bonusAmount'] ?? 0).toDouble(),
      performanceScore: (d['performanceScore'] ?? 0).toDouble(),
      salarySnapshot: (d['salarySnapshot'] ?? 0).toDouble(),
      calculatedAt: _parseTs(d['calculatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'employeeId': employeeId,
    'month': month,
    'totalTasksInMonth': totalTasksInMonth,
    'completedTasks': completedTasks,
    'missedTasks': missedTasks,
    'weekendTasks': weekendTasks,
    'deductionAmount': deductionAmount,
    'bonusAmount': bonusAmount,
    'performanceScore': performanceScore,
    'salarySnapshot': salarySnapshot,
    'calculatedAt': Timestamp.fromDate(calculatedAt),
  };
}

// ── BarrierModel ─────────────────────────────────────────────

class BarrierModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final String recipientName;
  final String recipientEmail;
  final String description;
  final String? goalId;
  final BarrierStatus status;
  final DateTime createdAt;

  const BarrierModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.recipientName,
    required this.recipientEmail,
    required this.description,
    this.goalId,
    required this.status,
    required this.createdAt,
  });

  factory BarrierModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BarrierModel(
      id: doc.id,
      employeeId: d['employeeId'] ?? '',
      employeeName: d['employeeName'] ?? '',
      recipientName: d['recipientName'] ?? '',
      recipientEmail: d['recipientEmail'] ?? '',
      description: d['description'] ?? '',
      goalId: d['goalId'],
      status: BarrierStatus.values.firstWhere(
            (e) => e.name == d['status'],
        orElse: () => BarrierStatus.open,
      ),
      createdAt: _parseTs(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'employeeId': employeeId,
    'employeeName': employeeName,
    'recipientName': recipientName,
    'recipientEmail': recipientEmail,
    'description': description,
    'goalId': goalId,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

// ── UnscheduledEntry (HR adhoc tab) ──────────────────────────

class UnscheduledEntry {
  final WeeklyTaskModel task;
  final String goalTitle;
  final String empName;

  const UnscheduledEntry({
    required this.task,
    required this.goalTitle,
    required this.empName,
  });

}
class TaskCompletionData {
  final String taskId;
  final String goalId;
  final bool isSolo;
  final List<String> teamMembers;
  final String remarks;
  final DateTime completedAt;

  TaskCompletionData({
    required this.taskId,
    required this.goalId,
    required this.isSolo,
    required this.teamMembers,
    required this.remarks,
    required this.completedAt,
  });

  Map<String, dynamic> toMap() => {
    'taskId': taskId,
    'goalId': goalId,
    'isSolo': isSolo,
    'teamMembers': teamMembers,
    'remarks': remarks,
    'completedAt': completedAt.toIso8601String(),
  };

  factory TaskCompletionData.fromMap(Map<String, dynamic> map) => TaskCompletionData(
    taskId: map['taskId'] as String,
    goalId: map['goalId'] as String,
    isSolo: map['isSolo'] as bool,
    teamMembers: List<String>.from(map['teamMembers'] as List? ?? []),
    remarks: map['remarks'] as String? ?? '',
    completedAt: DateTime.parse(map['completedAt'] as String),
  );
}